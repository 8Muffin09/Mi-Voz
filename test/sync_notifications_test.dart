import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/application/outbox.dart';
import 'package:mi_voz/features/communication/data/demo_requests_repository.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/features/profiles/data/demo_children_repository.dart';
import 'package:mi_voz/features/settings/presentation/general_settings_screen.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'access_flows_test.dart' show scrollTo;
import 'helpers.dart';
import 'widget_flows_test.dart' show launch, settle, signedInAs, tapKey;

void main() {
  group('Regla "si nadie acompaña" (backend local)', () {
    late DemoDatabase db;
    late DemoChildrenRepository children;
    late DemoRequestsRepository requests;
    late List<List<String>> pushes;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = DemoDatabase(LocalStore(prefs), seedSampleData: true);
      children = DemoChildrenRepository(db);
      pushes = [];
      requests = DemoRequestsRepository(
        db,
        onSimulatedPush: (r, uids) => pushes.add(uids),
      );
      await db.setSession(DemoSeed.maria.uid);
    });

    ChildProfile juan() =>
        ChildProfile.fromMap(db.get(DemoDatabase.children, 'demo-juan')!);

    AppUser user(String uid) =>
        AppUser.fromMap(db.get(DemoDatabase.users, uid)!);

    /// Juan sin nadie acompañando (María administra; Luis y Ana vinculados).
    void withoutCompanion() {
      db.put(
        DemoDatabase.children,
        'demo-juan',
        juan()
            .copyWith(
              responsibleUid: () => null,
              responsibleName: () => null,
              responsibleSince: () => null,
            )
            .toMap(),
      );
      db.commit();
    }

    Future<CommunicationRequest> send() async {
      final r = CommunicationService.buildRequest(
        child: juan(),
        draft: PhraseDraft(
          category: null,
          items: const [],
          fixedText: 'Necesito ayuda',
          fixedEmoji: '🙋',
          fixedCategoryId: 'ayuda',
        ),
        senderUid: DemoSeed.maria.uid,
      );
      await requests.deliver(r);
      return CommunicationRequest.fromMap(db.get(DemoDatabase.requests, r.id)!);
    }

    test('por defecto avisa solo al administrador, no a todos', () async {
      withoutCompanion();
      final saved = await send();
      expect(pushes.single, [DemoSeed.maria.uid]);
      expect(saved.notifiedUids, [DemoSeed.maria.uid]);
      expect(saved.route, NotificationRoute.rule);
      expect(saved.recipientLabel, startsWith('Sin acompañante'));
    });

    test('con acompañante el aviso va solo a esa persona', () async {
      final saved = await send();
      expect(saved.route, NotificationRoute.companion);
      expect(pushes.single, [DemoSeed.maria.uid]);
    });

    test('el administrador elige a quién avisar; otros no pueden', () async {
      withoutCompanion();
      await children.setNoCompanionRule(
        child: juan(),
        actor: user(DemoSeed.maria.uid),
        rule: NoCompanionRule.chosen,
        backupUids: [DemoSeed.ana.uid, 'desconocido'],
      );
      expect(juan().backupUids, [DemoSeed.ana.uid]);
      await send();
      expect(pushes.single, [DemoSeed.ana.uid]);

      await db.setSession(DemoSeed.luis.uid);
      await expectLater(
        children.setNoCompanionRule(
          child: juan(),
          actor: user(DemoSeed.luis.uid),
          rule: NoCompanionRule.all,
          backupUids: const [],
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('si nadie puede recibirlo, no se simula un aviso', () async {
      withoutCompanion();
      await children.setLinkPermissions(
        child: juan(),
        actor: user(DemoSeed.maria.uid),
        adultUid: DemoSeed.maria.uid,
        receivesRequests: false,
        canViewPassport: true,
      );
      final saved = await send();
      expect(saved.notification, NotificationStatus.noRecipients);
      expect(saved.notification.reachedNobody, isTrue);
      expect(pushes, isEmpty);
    });

    test('quitar a un adulto lo saca de los elegidos', () async {
      await children.setNoCompanionRule(
        child: juan(),
        actor: user(DemoSeed.maria.uid),
        rule: NoCompanionRule.chosen,
        backupUids: [DemoSeed.ana.uid, DemoSeed.luis.uid],
      );
      await children.removeLink(
        child: juan(),
        actor: user(DemoSeed.maria.uid),
        adultUid: DemoSeed.ana.uid,
      );
      expect(juan().backupUids, [DemoSeed.luis.uid]);
    });
  });

  group('Modelos y cola', () {
    test('la regla y el motivo del aviso se guardan y se leen', () {
      final child = ChildProfile.fromMap(
        const ChildProfile(
          id: 'c',
          name: 'Leo',
          avatar: '🦁',
          avatarColor: 0,
          gender: GrammaticalGender.masculine,
          ownerUid: 'a',
          memberUids: ['a', 'b'],
          noCompanionRule: NoCompanionRule.chosen,
          backupUids: ['b'],
        ).toMap(),
      );
      expect(child.noCompanionRule, NoCompanionRule.chosen);
      expect(child.backupUids, ['b']);
      expect(
        ChildProfile.fromMap(const {'name': 'X'}).noCompanionRule,
        NoCompanionRule.admin,
        reason: 'los perfiles antiguos avisan solo al administrador',
      );

      final r = CommunicationRequest.fromMap({
        'id': 'r',
        'notification': {
          'status': 'sent',
          'recipientUids': ['b'],
          'recipientNames': ['Bea'],
          'route': 'ruleAfterCompanion',
        },
      });
      expect(r.notifiedUids, ['b']);
      expect(r.route, NotificationRoute.ruleAfterCompanion);
      expect(r.notification.reachedNobody, isFalse);
    });

    test('los reintentos se espacian hasta 5 minutos', () {
      expect(OutboxNotifier.retryDelay(0), const Duration(seconds: 15));
      expect(OutboxNotifier.retryDelay(1), const Duration(seconds: 30));
      expect(OutboxNotifier.retryDelay(3), const Duration(minutes: 2));
      expect(OutboxNotifier.retryDelay(10), const Duration(minutes: 5));
    });
  });

  group('Pantallas', () {
    testWidgets('si el aviso no llega a nadie, el niño lo sabe', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
      );
      // Nadie acompaña y la regla elegida no tiene a nadie.
      final db = container.read(demoDatabaseProvider);
      final juan = ChildProfile.fromMap(
        db.get(DemoDatabase.children, 'demo-juan')!,
      );
      db.put(
        DemoDatabase.children,
        juan.id,
        juan
            .copyWith(
              responsibleUid: () => null,
              noCompanionRule: NoCompanionRule.chosen,
              backupUids: const [],
            )
            .toMap(),
      );
      db.commit();
      await settle(tester);

      await tapKey(tester, 'quick-phrases');
      await tapKey(tester, 'phrase-fp_agua');
      await tapKey(tester, 'action-communicate');
      expect(find.byKey(const Key('status-nobody')), findsOneWidget);
      expect(find.byKey(const Key('status-look-for-adult')), findsOneWidget);
      expect(find.byKey(const Key('status-delivered')), findsNothing);
    });

    testWidgets('ayuda urgente sin internet: lo dice antes y después', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
          LocalStore.keyDemoOffline: true,
        },
        connectivity: FakeConnectivity()..online = false,
      );
      await tapKey(tester, 'urgent-button');
      await tapKey(tester, 'urgent-urg_miedo');
      expect(find.byKey(const Key('urgent-offline')), findsOneWidget);
      await tapKey(tester, 'urgent-confirm');
      expect(find.byKey(const Key('status-pending')), findsOneWidget);
      expect(find.byKey(const Key('status-look-for-adult')), findsOneWidget);

      // Vuelve la conexión: se envía y la cola queda vacía (sin reintentos).
      await container.read(demoOfflineProvider.notifier).set(false);
      await settle(tester);
      expect(find.byKey(const Key('status-pending')), findsNothing);
      expect(container.read(outboxProvider), isEmpty);
    });

    testWidgets('la administradora elige a quién avisar si nadie acompaña', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await scrollTo(
        tester,
        find.byKey(Key('family-card-${DemoSeed.familyLopez}')),
      );
      await tapKey(tester, 'family-card-${DemoSeed.familyLopez}');
      await tapKey(tester, 'family-child-demo-juan');
      expect(find.byKey(const Key('no-companion-rule')), findsOneWidget);
      expect(find.textContaining('Acompaña ahora'), findsOneWidget);

      await tapKey(tester, 'no-companion-rule');
      await tapKey(tester, 'rule-chosen');
      expect(find.text('Elige al menos un adulto.'), findsOneWidget);
      await tapKey(tester, 'backup-${DemoSeed.ana.uid}');
      await tapKey(tester, 'rule-save');

      final saved = ChildProfile.fromMap(
        container
            .read(demoDatabaseProvider)
            .get(DemoDatabase.children, 'demo-juan')!,
      );
      expect(saved.noCompanionRule, NoCompanionRule.chosen);
      expect(saved.backupUids, [DemoSeed.ana.uid]);
      expect(find.textContaining('a los adultos que yo elija'), findsOneWidget);
    });

    testWidgets('el panel avisa de lo pendiente de envío', (tester) async {
      final container = await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyDemoOffline: true,
        },
      );
      final juan = ChildProfile.fromMap(
        container
            .read(demoDatabaseProvider)
            .get(DemoDatabase.children, 'demo-juan')!,
      );
      await container
          .read(outboxProvider.notifier)
          .submit(
            CommunicationService.buildRequest(
              child: juan,
              draft: PhraseDraft(
                category: null,
                items: const [],
                fixedText: 'Necesito agua',
                fixedEmoji: '💧',
                fixedCategoryId: 'quiero',
              ),
              senderUid: DemoSeed.maria.uid,
            ),
          );
      await settle(tester);
      expect(find.byKey(const Key('sync-banner')), findsOneWidget);
      expect(find.textContaining('1 solicitud'), findsOneWidget);

      await container.read(demoOfflineProvider.notifier).set(false);
      await settle(tester);
      expect(find.byKey(const Key('sync-banner')), findsNothing);
    });
  });
}
