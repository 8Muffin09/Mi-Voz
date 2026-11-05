import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/app/router.dart';
import 'package:mi_voz/app/routes.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/application/requests_providers.dart';
import 'package:mi_voz/features/communication/data/demo_requests_repository.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/features/profiles/application/profiles_providers.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';

import 'access_flows_test.dart' show scrollTo;
import 'helpers.dart';
import 'widget_flows_test.dart' show launch, settle, signedInAs, tapKey;

/// Cuenta cuántas veces se abre una consulta de solicitudes al servidor.
class CountingRequestsRepository extends DemoRequestsRepository {
  CountingRequestsRepository(super.db);

  int watches = 0;

  @override
  Stream<List<CommunicationRequest>> watchChildRequests(String childId) {
    watches++;
    return super.watchChildRequests(childId);
  }
}

/// Toca el elemento resaltado de la simulación mientras haya uno.
Future<int> playDemo(WidgetTester tester) async {
  var taps = 0;
  Finder target() => find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('tour-target-'),
  );
  while (target().evaluate().isNotEmpty && taps < 6) {
    await tester.ensureVisible(target().first);
    await tester.pump();
    await tester.tap(target().first);
    await settle(tester, steps: 3);
    taps++;
  }
  return taps;
}

CommunicationRequest sample(ChildProfile child, int i) =>
    CommunicationService.buildRequest(
      child: child,
      draft: PhraseDraft(
        category: null,
        items: const [],
        fixedText: 'Mensaje $i',
        fixedEmoji: '💬',
        fixedCategoryId: 'quiero',
      ),
      senderUid: child.ownerUid,
      id: 'hist-$i',
      now: DateTime(2026, 1, 1).add(Duration(minutes: i)),
    );

void main() {
  group('Tutorial interactivo', () {
    testWidgets('cada paso se puede probar y no toca ningún dato', (
      tester,
    ) async {
      final container = await launch(tester);
      final db = container.read(demoDatabaseProvider);
      final before = {
        for (final t in [
          DemoDatabase.users,
          DemoDatabase.children,
          DemoDatabase.requests,
          DemoDatabase.families,
          DemoDatabase.classes,
          DemoDatabase.groupInvitations,
        ])
          t: db.all(t).length,
      };

      for (final role in ['guardian', 'teacher', 'child']) {
        await tapKey(tester, 'welcome-tour');
        await tapKey(tester, 'tour-role-$role');
        var steps = 0;
        while (true) {
          steps++;
          expect(find.byKey(const Key('tour-demo')), findsOneWidget);
          expect(find.text('SIMULACIÓN · EJEMPLO FICTICIO'), findsOneWidget);
          final taps = await playDemo(tester);
          expect(taps, greaterThan(0), reason: 'paso $steps de $role');
          expect(find.byKey(const Key('tour-demo-done')), findsOneWidget);
          if (find.byKey(const Key('tour-finish')).evaluate().isNotEmpty) {
            break;
          }
          await tapKey(tester, 'tour-next');
        }
        expect(steps, role == 'child' ? 4 : 8);
        await tapKey(tester, 'tour-finish');
      }

      for (final e in before.entries) {
        expect(db.all(e.key).length, e.value, reason: e.key);
      }
      expect(container.read(currentUserProvider), isNull);
    });

    testWidgets('se maneja con el teclado y Esc lo cierra', (tester) async {
      await launch(tester);
      await tapKey(tester, 'welcome-tour');
      await tapKey(tester, 'tour-role-teacher');
      expect(find.textContaining('Paso 1 de 8'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await settle(tester, steps: 3);
      expect(find.textContaining('Paso 2 de 8'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await settle(tester, steps: 3);
      expect(find.textContaining('Paso 1 de 8'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      expect(find.byKey(const Key('tour-demo')), findsNothing);
    });

    testWidgets('desde Ayuda empieza en el rol de la cuenta', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await tapKey(tester, 'nav-3');
      await scrollTo(tester, find.byKey(const Key('settings-tour')));
      await tapKey(tester, 'settings-tour');
      expect(
        find.textContaining('Paso 1 de 8 · Padre, madre o tutor'),
        findsOneWidget,
      );
      // No hay selector de rol al que volver.
      final previous = tester.widget<OutlinedButton>(
        find.byKey(const Key('tour-previous')),
      );
      expect(previous.onPressed, isNull);
      expect(container.read(currentUserProvider)?.uid, DemoSeed.maria.uid);
    });
  });

  group('Accesibilidad', () {
    Future<void> checkGuidelines(WidgetTester tester) async {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }

    testWidgets('bienvenida y tutorial cumplen las pautas', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester);
      await checkGuidelines(tester);
      await tapKey(tester, 'welcome-tour');
      await checkGuidelines(tester);
      await tapKey(tester, 'tour-role-guardian');
      await checkGuidelines(tester);
      handle.dispose();
    });

    testWidgets('pantallas del niño cumplen las pautas', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
      );
      await checkGuidelines(tester);
      await tapKey(tester, 'category-quiero');
      await checkGuidelines(tester);
      await tapKey(tester, 'pictogram-quiero_agua');
      await checkGuidelines(tester);
      await tapKey(tester, 'action-communicate');
      await checkGuidelines(tester);
      handle.dispose();
    });

    testWidgets('panel del adulto cumple las pautas', (tester) async {
      final handle = tester.ensureSemantics();
      await launch(tester, prefs: signedInAs(DemoSeed.maria.uid));
      await checkGuidelines(tester);
      await tapKey(tester, 'nav-1');
      await checkGuidelines(tester);
      await tapKey(tester, 'nav-2');
      await checkGuidelines(tester);
      handle.dispose();
    });

    for (final (name, prefs, keys) in [
      (
        'modo niño',
        signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
        ['category-quiero', 'pictogram-quiero_agua', 'action-communicate'],
      ),
      (
        'panel del adulto',
        signedInAs(DemoSeed.maria.uid),
        ['nav-1', 'nav-2', 'nav-3', 'nav-0'],
      ),
      (
        'ayuda urgente',
        signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
        ['urgent-button', 'urgent-urg_miedo', 'urgent-confirm'],
      ),
      (
        'tutorial',
        <String, Object>{},
        ['welcome-tour', 'tour-role-teacher', 'tour-next'],
      ),
    ]) {
      testWidgets('texto al 200 %: $name sin cortes ni desbordes', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2.0;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await launch(tester, prefs: prefs);
        expect(tester.takeException(), isNull);
        for (final key in keys) {
          await tapKey(tester, key);
          expect(tester.takeException(), isNull, reason: 'tras $key');
        }
      });
    }
  });

  group('Rendimiento', () {
    test('la cola y los cambios de perfil no reabren las consultas', () async {
      final prefs = await demoPrefs(extra: signedInAs(DemoSeed.maria.uid));
      late CountingRequestsRepository repo;
      final scoped = ProviderContainer(
        overrides: [
          ...testOverrides(prefs),
          requestsRepositoryProvider.overrideWith(
            (ref) => repo = CountingRequestsRepository(
              ref.watch(demoDatabaseProvider),
            ),
          ),
        ],
      );
      addTearDown(scoped.dispose);
      scoped
        ..listen(authStateProvider, (_, _) {})
        ..listen(childrenProvider, (_, _) {})
        ..listen(adultRequestsProvider, (_, _) {});
      await scoped.read(authStateProvider.future);
      await scoped.read(childrenProvider.future);
      final first = await scoped.read(adultRequestsProvider.future);
      final opened = repo.watches;
      expect(opened, greaterThan(0));

      // Cambiar quién acompaña modifica el perfil, no la lista de niños.
      final db = scoped.read(demoDatabaseProvider);
      final juan = ChildProfile.fromMap(
        db.get(DemoDatabase.children, 'demo-juan')!,
      );
      db.put(
        DemoDatabase.children,
        juan.id,
        juan.copyWith(responsibleUid: () => null).toMap(),
      );
      db.commit();

      // Una solicitud nueva llega por la suscripción ya abierta.
      db.put(DemoDatabase.requests, 'nueva', sample(juan, 999).toMap());
      db.commit();
      for (var i = 0; i < 5; i++) {
        await flush();
      }
      final next = await scoped.read(adultRequestsProvider.future);
      expect(next.length, first.length + 1);
      expect(repo.watches, opened);
    });

    testWidgets('el historial se muestra por bloques de 50', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      final db = container.read(demoDatabaseProvider);
      final juan = ChildProfile.fromMap(
        db.get(DemoDatabase.children, 'demo-juan')!,
      );
      for (var i = 0; i < 80; i++) {
        final r = sample(juan, i);
        db.put(
          DemoDatabase.requests,
          r.id,
          r.copyWith(delivery: DeliveryStatus.delivered).toMap(),
        );
      }
      db.commit();
      container.read(routerProvider).push(Routes.childHistory(juan.id));
      await settle(tester);
      final total = db
          .where(DemoDatabase.requests, (r) => r['childId'] == juan.id)
          .length;
      expect(find.text('Mostrando 50 de $total solicitudes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('history-more')),
        600,
        scrollable: find.descendant(
          of: find.byKey(const Key('history-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tapKey(tester, 'history-more');
      if (total <= 100) {
        expect(find.byKey(const Key('history-more')), findsNothing);
      }
      await tester.fling(
        find.byKey(const Key('history-list')),
        const Offset(0, 20000),
        5000,
      );
      await settle(tester);
      expect(
        find.text(
          total > 100
              ? 'Mostrando 100 de $total solicitudes'
              : '$total solicitud(es)',
        ),
        findsOneWidget,
      );
    });
  });
}
