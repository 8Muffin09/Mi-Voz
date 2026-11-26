import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/application/outbox.dart';
import 'package:mi_voz/features/communication/application/requests_providers.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/features/settings/presentation/general_settings_screen.dart';
import 'package:mi_voz/models/communication_request.dart';

import 'helpers.dart';

void main() {
  test(
    'sin conexión queda "Pendiente de envío" y al volver se envía una sola vez',
    () async {
      final connectivity = FakeConnectivity();
      final container = await demoContainer(connectivity: connectivity);
      addTearDown(container.dispose);

      final db = container.read(demoDatabaseProvider);
      await db.setSession(DemoSeed.maria.uid);
      container.listen(currentUserProvider, (_, _) {});
      container.listen(childRequestsProvider('demo-juan'), (_, _) {});
      await container.read(authStateProvider.future);
      await container.read(demoOfflineProvider.notifier).set(true);

      final child = (await container
          .read(childrenRepositoryProvider)
          .watchChild('demo-juan')
          .first)!;
      final result = await container
          .read(communicationServiceProvider)
          .send(
            child: child,
            draft: const PhraseDraft.fixed(text: 'Tengo frío', emoji: '🥶'),
          );

      expect(result.delivery, DeliveryStatus.pendingSync);
      expect(container.read(outboxProvider), hasLength(1));
      expect(db.get(DemoDatabase.requests, result.id), isNull);

      // La solicitud pendiente se ve en el historial del niño.
      final merged = await container.read(
        childRequestsProvider('demo-juan').future,
      );
      expect(
        merged.firstWhere((r) => r.id == result.id).delivery,
        DeliveryStatus.pendingSync,
      );

      // Vuelve la conexión: se sincroniza.
      await container.read(demoOfflineProvider.notifier).set(false);
      expect(container.read(outboxProvider), isEmpty);
      expect(db.get(DemoDatabase.requests, result.id), isNotNull);

      // Reintentar no duplica.
      await container.read(requestsRepositoryProvider).deliver(result);
      expect(
        db.where(DemoDatabase.requests, (r) => r['id'] == result.id),
        hasLength(1),
      );
    },
  );

  test('la cola sobrevive a un reinicio de la app', () async {
    final container = await demoContainer();
    final db = container.read(demoDatabaseProvider);
    await db.setSession(DemoSeed.maria.uid);
    await db.setSimulateOffline(true);
    container.listen(currentUserProvider, (_, _) {});
    await container.read(authStateProvider.future);
    final child = (await container
        .read(childrenRepositoryProvider)
        .watchChild('demo-juan')
        .first)!;
    final request = CommunicationService.buildRequest(
      child: child,
      draft: const PhraseDraft.fixed(text: 'Necesito agua', emoji: '💧'),
      senderUid: DemoSeed.maria.uid,
    );
    await container.read(outboxProvider.notifier).submit(request);
    final prefs = container.read(sharedPreferencesProvider);
    container.dispose();

    // "Reinicio": nuevo contenedor con las mismas preferencias.
    final restarted = ProviderContainer(overrides: testOverrides(prefs));
    addTearDown(restarted.dispose);
    restarted.listen(currentUserProvider, (_, _) {});
    await restarted.read(authStateProvider.future);
    expect(restarted.read(outboxProvider).single.id, request.id);
    await restarted.read(demoDatabaseProvider).setSimulateOffline(false);
    await restarted.read(outboxProvider.notifier).sync();
    expect(restarted.read(outboxProvider), isEmpty);
  });

  test(
    'la cola de una cuenta no se envía ni se muestra con otra sesión',
    () async {
      final container = await demoContainer();
      final db = container.read(demoDatabaseProvider);
      await db.setSession(DemoSeed.maria.uid);
      await db.setSimulateOffline(true);
      container.listen(currentUserProvider, (_, _) {});
      await container.read(authStateProvider.future);
      final child = (await container
          .read(childrenRepositoryProvider)
          .watchChild('demo-juan')
          .first)!;
      final request = CommunicationService.buildRequest(
        child: child,
        draft: const PhraseDraft.fixed(text: 'Necesito agua', emoji: '💧'),
        senderUid: DemoSeed.maria.uid,
      );
      await container.read(outboxProvider.notifier).submit(request);
      expect(container.read(outboxProvider), hasLength(1));

      // Otra cuenta en el mismo teléfono: no ve la solicitud de María.
      await db.setSession(DemoSeed.ana.uid);
      container.invalidate(authStateProvider);
      await container.read(authStateProvider.future);
      await Future<void>.delayed(Duration.zero);
      expect(container.read(currentUserProvider)?.uid, DemoSeed.ana.uid);
      expect(container.read(outboxProvider), isEmpty);
      // Y no puede encolar algo a nombre de María.
      expect(
        () => container.read(outboxProvider.notifier).submit(request),
        throwsA(isA<PermissionDeniedException>()),
      );
    },
  );

  test(
    'cola de versiones anteriores: cada solicitud pasa a su cuenta',
    () async {
      final legacy = '${LocalStore.keyOutbox}_demo';
      final container = await demoContainer();
      final db = container.read(demoDatabaseProvider);
      final store = container.read(localStoreProvider);
      await store.setJsonList(legacy, [
        {
          'id': 'r-maria',
          'childId': 'demo-juan',
          'message': 'Hola',
          'createdByUid': DemoSeed.maria.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'new',
          'priority': 'normal',
        },
        {
          'id': 'r-ana',
          'childId': 'demo-juan',
          'message': 'Adiós',
          'createdByUid': DemoSeed.ana.uid,
          'createdAt': DateTime.now().toIso8601String(),
          'status': 'new',
          'priority': 'normal',
        },
      ]);
      await db.setSimulateOffline(true);
      await db.setSession(DemoSeed.maria.uid);
      container.listen(currentUserProvider, (_, _) {});
      await container.read(authStateProvider.future);
      expect(
        [for (final r in container.read(outboxProvider)) r.id],
        ['r-maria'],
      );
      // La de Ana sigue esperando a Ana.
      expect([for (final m in store.getJsonList(legacy)) m['id']], ['r-ana']);
    },
  );
}
