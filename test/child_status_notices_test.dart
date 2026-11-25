import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/features/child/application/child_status_notices.dart';
import 'package:mi_voz/features/child/presentation/widgets/child_status_notice_host.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/models/communication_request.dart';

import 'helpers.dart';

CommunicationRequest _request(
  String id,
  RequestStatus status, {
  DateTime? createdAt,
  String? by,
}) => CommunicationRequest(
  id: id,
  childId: 'demo-juan',
  childName: 'Juan',
  categoryId: 'necesito',
  categoryTitle: 'NECESITO',
  message: 'Necesito agua',
  emoji: 'necesito_agua',
  priority: RequestPriority.normal,
  createdByUid: 'u',
  createdAt: createdAt ?? DateTime.now(),
  status: status,
  statusUpdatedByName: by,
);

void main() {
  group('ChildStatusWatcher', () {
    test('lo que ya estaba al abrir la app no se anuncia', () {
      final w = ChildStatusWatcher();
      expect(w.update([_request('a', RequestStatus.attending)]), isEmpty);
    });

    test('al pasar a "en atención" avisa una vez con el nombre del adulto', () {
      final w = ChildStatusWatcher();
      w.update([_request('a', RequestStatus.newRequest)]);
      final notices = w.update([
        _request('a', RequestStatus.attending, by: 'Ana López'),
      ]);
      expect(notices.single.title, '¡Ana va en camino!');
      expect(notices.single.spoken, '¡Ana va en camino!. Necesito agua');
      // El mismo estado otra vez no repite el aviso.
      expect(
        w.update([_request('a', RequestStatus.attending, by: 'Ana López')]),
        isEmpty,
      );
    });

    test('una solicitud nueva que ya llega atendida también avisa', () {
      final w = ChildStatusWatcher();
      w.update(const []);
      expect(
        w.update([_request('b', RequestStatus.resolved)]).single.title,
        '¡Listo! Ya atendieron tu mensaje',
      );
    });

    test('mensajes de hace horas no interrumpen al niño', () {
      final w = ChildStatusWatcher();
      final old = DateTime.now().subtract(const Duration(hours: 7));
      w.update([_request('a', RequestStatus.newRequest, createdAt: old)]);
      expect(
        w.update([_request('a', RequestStatus.attending, createdAt: old)]),
        isEmpty,
      );
    });
  });

  testWidgets('en modo niño, "va en camino" aparece sobre cualquier pantalla y '
      'se lee en voz alta', (tester) async {
    final speech = FakeSpeechService();
    final prefs = await demoPrefs(
      extra: {
        LocalStore.keyDemoSession: DemoSeed.maria.uid,
        LocalStore.keyChildMode: 'demo-juan',
      },
    );
    final container = ProviderContainer(
      overrides: testOverrides(prefs, speech: speech),
    );
    addTearDown(container.dispose);
    String? opened;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ChildStatusNoticeHost(
            onOpen: (id) => opened = id,
            child: const Scaffold(body: Text('Inicio del niño')),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await container.read(authStateProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    // El niño comunica y sale a su pantalla de inicio.
    final juan = (await tester.runAsync(
      () => container
          .read(childrenRepositoryProvider)
          .watchChild('demo-juan')
          .first,
    ))!;
    final service = container.read(communicationServiceProvider);
    final sent = (await tester.runAsync(
      () => service.send(
        child: juan,
        draft: const PhraseDraft.fixed(
          text: 'Necesito agua',
          emoji: 'necesito_agua',
        ),
      ),
    ))!;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byKey(const Key('child-status-notice')), findsNothing);

    // Su adulto (desde otro dispositivo) marca "Voy en camino".
    await tester.runAsync(() async {
      final fresh = (await container
          .read(requestsRepositoryProvider)
          .watchRequest('demo-juan', sent.id)
          .first)!;
      await service.updateStatus(fresh, RequestStatus.attending);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const Key('child-status-notice')), findsOneWidget);
    expect(find.textContaining('va en camino'), findsOneWidget);
    expect(speech.spoken.last, contains('va en camino'));

    await tester.tap(find.byKey(const Key('child-status-notice')));
    await tester.pump();
    expect(opened, sent.id);
    expect(find.byKey(const Key('child-status-notice')), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 16));
  });
}
