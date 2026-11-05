import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/app/router.dart';
import 'package:mi_voz/app/routes.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/features/invitations/data/invitations_repository.dart';
import 'package:mi_voz/models/group_invitation.dart';

import 'access_flows_test.dart' show scrollTo, tapKey;
import 'widget_flows_test.dart' show launch, settle, signedInAs;

/// Invitación de la clase 2.º B creada por la maestra Ana.
GroupInvitation classInvitation() => GroupInvitation(
  code: 'CQAS2B77',
  type: InviteTargetType.classroom,
  targetId: DemoSeed.class2b,
  targetName: '2.º B',
  createdByUid: DemoSeed.ana.uid,
  createdByName: DemoSeed.ana.displayName,
  createdAt: DateTime.now(),
  expiresAt: DateTime.now().add(const Duration(days: 7)),
  maxUses: 30,
);

void main() {
  testWidgets('la docente genera un código con QR para su clase', (
    tester,
  ) async {
    await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
    await tapKey(tester, 'open-classes');
    await tapKey(tester, 'class-${DemoSeed.class2b}');
    await tapKey(tester, 'create-invitation');
    expect(find.text('Invitar familias'), findsOneWidget);
    await tapKey(tester, 'invite-create');
    expect(find.byKey(const Key('invitation-qr')), findsOneWidget);
    final code = tester
        .widget<SelectableText>(find.byKey(const Key('invitation-code')))
        .data!;
    expect(InvitationLink.isWellFormed(code), isTrue);
    expect(find.textContaining('no sirve para iniciar sesión'), findsOneWidget);
    await tester.tap(find.text('Listo'));
    await settle(tester);
    expect(find.byKey(Key('invitation-$code')), findsOneWidget);
    expect(find.byKey(Key('revoke-$code')), findsOneWidget);
  });

  testWidgets('la familia escribe el código, elige a su hija y lo solicita', (
    tester,
  ) async {
    final container = await launch(
      tester,
      prefs: signedInAs(DemoSeed.maria.uid),
    );
    container
        .read(demoDatabaseProvider)
        .put(
          DemoDatabase.groupInvitations,
          'CQAS2B77',
          classInvitation().toMap(),
        );
    container.read(demoDatabaseProvider).commit();
    container.read(routerProvider).push(Routes.join);
    await settle(tester);

    // En Windows (donde corren las pruebas) no hay escáner: se escribe.
    expect(find.textContaining('no hay escáner'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-code')), 'cqas2b77');
    await tapKey(tester, 'join-check');
    expect(find.byKey(const Key('join-preview')), findsOneWidget);
    expect(find.text('2.º B'), findsOneWidget);
    expect(
      find.text('Invitación de ${DemoSeed.ana.displayName}'),
      findsOneWidget,
    );
    // Solo sus niños: Juan y Sofía, no Mateo.
    expect(find.byKey(const Key('join-child-demo-mateo')), findsNothing);
    await tapKey(tester, 'join-child-demo-sofia');
    await tapKey(tester, 'join-confirm');
    expect(find.textContaining('Solicitud enviada'), findsOneWidget);
    await scrollTo(tester, find.text('Mis solicitudes'));
    expect(find.text('Sofía → 2.º B'), findsOneWidget);
    expect(find.textContaining('Pendiente de aprobación'), findsOneWidget);
  });

  testWidgets('un código inexistente muestra un mensaje claro', (tester) async {
    final container = await launch(
      tester,
      prefs: signedInAs(DemoSeed.maria.uid),
    );
    container.read(routerProvider).push(Routes.join);
    await settle(tester);
    await tester.enterText(find.byKey(const Key('join-code')), 'ZZZZZZZZ');
    await tapKey(tester, 'join-check');
    expect(find.text(InvitationError.invalid.message), findsOneWidget);
    expect(find.byKey(const Key('join-preview')), findsNothing);
  });

  testWidgets('la docente aprueba la solicitud desde su panel', (tester) async {
    final container = await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
    final db = container.read(demoDatabaseProvider);
    final request = JoinRequest(
      id: 'req-sofia',
      code: 'CQAS2B77',
      type: InviteTargetType.classroom,
      targetId: DemoSeed.class2b,
      targetName: '2.º B',
      requesterUid: DemoSeed.maria.uid,
      requesterName: DemoSeed.maria.displayName,
      approverUid: DemoSeed.ana.uid,
      createdAt: DateTime.now(),
      childId: 'demo-sofia',
      childName: 'Sofía',
    );
    db.put(DemoDatabase.joinRequests, request.id, request.toMap());
    db.commit();
    await settle(tester);

    await scrollTo(tester, find.byKey(const Key('join-request-req-sofia')));
    expect(
      find.text('María López quiere vincular a Sofía con 2.º B'),
      findsOneWidget,
    );
    await tapKey(tester, 'approve-req-sofia');
    expect(find.byKey(const Key('join-request-req-sofia')), findsNothing);
    final sofia = db.get(DemoDatabase.children, 'demo-sofia')!;
    expect(sofia['classIds'], [DemoSeed.class2b]);
    expect(sofia['memberUids'], contains(DemoSeed.ana.uid));
  });
}
