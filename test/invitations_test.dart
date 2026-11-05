import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/invitations/data/demo_invitations_repository.dart';
import 'package:mi_voz/features/invitations/data/invitations_repository.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/classroom.dart';
import 'package:mi_voz/models/family.dart';
import 'package:mi_voz/models/group_invitation.dart';

import 'helpers.dart';

/// Reloj controlable para probar caducidad y bloqueos.
class FakeClock {
  DateTime now = DateTime(2026, 10, 27, 9);
  DateTime call() => now;
}

Matcher throwsInvitation(InvitationError reason) => throwsA(
  isA<InvitationException>().having((e) => e.reason, 'reason', reason),
);

void main() {
  late ProviderContainer c;
  late DemoDatabase db;
  late FakeClock clock;
  late DemoInvitationsRepository repo;

  Future<void> as(AppUser user) => db.setSession(user.uid);

  Family family(String id) =>
      Family.fromMap(db.get(DemoDatabase.families, id)!);
  Classroom classroom(String id) =>
      Classroom.fromMap(db.get(DemoDatabase.classes, id)!);
  ChildProfile child(String id) =>
      ChildProfile.fromMap(db.get(DemoDatabase.children, id)!);
  CaregiverLink? link(String childId, String uid) {
    final row = db.get(DemoDatabase.links, '${childId}_$uid');
    return row == null ? null : CaregiverLink.fromMap(row);
  }

  Future<GroupInvitation> familyInvite({
    bool approval = true,
    int maxUses = 1,
    AdultRole role = AdultRole.padre,
  }) async {
    await as(DemoSeed.maria);
    return repo.create(
      type: InviteTargetType.family,
      targetId: DemoSeed.familyLopez,
      validity: const Duration(hours: 48),
      maxUses: maxUses,
      requiresApproval: approval,
      role: role,
    );
  }

  Future<GroupInvitation> classInvite({bool approval = true}) async {
    await as(DemoSeed.ana);
    return repo.create(
      type: InviteTargetType.classroom,
      targetId: DemoSeed.class2b,
      validity: const Duration(days: 7),
      maxUses: 30,
      requiresApproval: approval,
    );
  }

  setUp(() async {
    c = await signedInContainer(DemoSeed.maria.uid);
    db = c.read(demoDatabaseProvider);
    clock = FakeClock();
    repo = DemoInvitationsRepository(db, clock: clock.call);
  });

  tearDown(() => c.dispose());

  group('Crear y compartir', () {
    test('solo el responsable de la familia o de la clase invita', () async {
      final inv = await familyInvite();
      expect(InvitationLink.isWellFormed(inv.code), isTrue);
      expect(
        inv.expiresAt.difference(inv.createdAt),
        const Duration(hours: 48),
      );
      expect(inv.role, AdultRole.padre);

      await as(DemoSeed.luis); // adulto de la familia, no administrador
      await expectLater(
        repo.create(
          type: InviteTargetType.family,
          targetId: DemoSeed.familyLopez,
          validity: const Duration(hours: 48),
          maxUses: 1,
          requiresApproval: true,
        ),
        throwsInvitation(InvitationError.notAllowed),
      );
      await as(DemoSeed.maria); // no es docente de la clase
      await expectLater(
        repo.create(
          type: InviteTargetType.classroom,
          targetId: DemoSeed.class2b,
          validity: const Duration(hours: 48),
          maxUses: 1,
          requiresApproval: true,
        ),
        throwsInvitation(InvitationError.notAllowed),
      );
    });

    test(
      'vigencias y límites de uso fuera de lo permitido se rechazan',
      () async {
        await as(DemoSeed.maria);
        await expectLater(
          repo.create(
            type: InviteTargetType.family,
            targetId: DemoSeed.familyLopez,
            validity: const Duration(days: 365),
            maxUses: 1,
            requiresApproval: true,
          ),
          throwsInvitation(InvitationError.notAllowed),
        );
      },
    );

    test('una clase archivada no genera invitaciones', () async {
      await as(DemoSeed.ana);
      final b2 = classroom(DemoSeed.class2b);
      await c
          .read(classesRepositoryProvider)
          .setArchived(b2, true, actor: DemoSeed.ana);
      await expectLater(
        classInvite(),
        throwsInvitation(InvitationError.notAllowed),
      );
    });

    test('el QR solo lleva el código y no sirve sin una sesión', () async {
      final inv = await familyInvite();
      expect(inv.link, 'mivoz://invite?code=${inv.code}');
      expect(inv.link, isNot(contains('López')));
      expect(InvitationLink.parse(inv.link), inv.code);
      expect(InvitationLink.parse(' ${inv.code.toLowerCase()} '), inv.code);
      expect(
        InvitationLink.parse('https://ejemplo.com/?code=${inv.code}'),
        isNull,
      );
      expect(InvitationLink.parse('ABC'), isNull);

      await db.setSession(null);
      await expectLater(
        repo.preview(inv.code),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test(
      'solo el responsable ve y revoca las invitaciones del grupo',
      () async {
        final inv = await familyInvite();
        expect(
          await repo
              .watchForTarget(InviteTargetType.family, DemoSeed.familyLopez)
              .first,
          hasLength(1),
        );
        await as(DemoSeed.luis);
        expect(
          await repo
              .watchForTarget(InviteTargetType.family, DemoSeed.familyLopez)
              .first,
          isEmpty,
        );
        await expectLater(
          repo.revoke(inv),
          throwsInvitation(InvitationError.notAllowed),
        );
      },
    );
  });

  group('Familias', () {
    test(
      'con aprobación: solicitud, aprobación y acceso a todos sus niños',
      () async {
        final inv = await familyInvite();
        await as(DemoSeed.carlos);
        final preview = await repo.preview(inv.code);
        expect(preview.targetName, 'Familia López');
        expect(preview.inviterName, DemoSeed.maria.displayName);
        expect(await repo.redeem(inv.code), RedeemOutcome.pendingApproval);
        expect(
          family(DemoSeed.familyLopez).isAdult(DemoSeed.carlos.uid),
          isFalse,
        );
        expect(
          child('demo-juan').memberUids,
          isNot(contains(DemoSeed.carlos.uid)),
        );

        // Otra cuenta no puede aprobarla.
        final request =
            (await repo.watchMyRequests(DemoSeed.carlos.uid).first).single;
        await expectLater(
          repo.review(request, approve: true),
          throwsInvitation(InvitationError.notAllowed),
        );

        await as(DemoSeed.maria);
        final pending = await repo
            .watchPendingForApprover(DemoSeed.maria.uid)
            .first;
        expect(pending.single.requesterName, DemoSeed.carlos.displayName);
        await repo.review(pending.single, approve: true);

        final lopez = family(DemoSeed.familyLopez);
        expect(lopez.isAdult(DemoSeed.carlos.uid), isTrue);
        expect(lopez.adultRole(DemoSeed.carlos.uid), AdultRole.padre);
        for (final id in ['demo-juan', 'demo-sofia']) {
          expect(child(id).memberUids, contains(DemoSeed.carlos.uid));
          final l = link(id, DemoSeed.carlos.uid)!;
          expect(l.source, LinkSource.family);
          expect(
            l.permission,
            LinkPermission.caregiver,
            reason: 'nunca administrador',
          );
        }
        final mine = await repo.watchMyRequests(DemoSeed.carlos.uid).first;
        expect(mine.single.status, JoinRequestStatus.approved);
      },
    );

    test('sin aprobación se incorpora al momento', () async {
      final inv = await familyInvite(approval: false);
      await as(DemoSeed.carlos);
      expect(await repo.redeem(inv.code), RedeemOutcome.joined);
      expect(family(DemoSeed.familyLopez).isAdult(DemoSeed.carlos.uid), isTrue);
    });

    test('una solicitud rechazada no da acceso', () async {
      final inv = await familyInvite();
      await as(DemoSeed.carlos);
      await repo.redeem(inv.code);
      await as(DemoSeed.maria);
      final pending = await repo
          .watchPendingForApprover(DemoSeed.maria.uid)
          .first;
      await repo.review(pending.single, approve: false);
      expect(
        family(DemoSeed.familyLopez).isAdult(DemoSeed.carlos.uid),
        isFalse,
      );
      expect(
        child('demo-sofia').memberUids,
        isNot(contains(DemoSeed.carlos.uid)),
      );
    });

    test('quien ya es miembro no se vuelve a unir', () async {
      final inv = await familyInvite(maxUses: 5);
      await as(DemoSeed.luis);
      await expectLater(
        repo.redeem(inv.code),
        throwsInvitation(InvitationError.alreadyMember),
      );
    });

    test('no se duplican solicitudes pendientes', () async {
      final inv = await familyInvite(maxUses: 5);
      await as(DemoSeed.carlos);
      await repo.redeem(inv.code);
      await expectLater(
        repo.redeem(inv.code),
        throwsInvitation(InvitationError.alreadyRequested),
      );
      expect(
        await repo.watchMyRequests(DemoSeed.carlos.uid).first,
        hasLength(1),
      );
    });
  });

  group('Clases', () {
    test('la familia vincula a su hijo y el docente aprueba', () async {
      // Sofía todavía no está en 2.º B.
      final inv = await classInvite();
      await as(DemoSeed.maria);
      final preview = await repo.preview(inv.code);
      expect(preview.type, InviteTargetType.classroom);
      expect(preview.targetName, '2.º B');
      await expectLater(
        repo.redeem(inv.code),
        throwsInvitation(InvitationError.childRequired),
      );
      expect(
        await repo.redeem(inv.code, childId: 'demo-sofia'),
        RedeemOutcome.pendingApproval,
      );
      expect(child('demo-sofia').memberUids, isNot(contains(DemoSeed.ana.uid)));

      await as(DemoSeed.ana);
      final pending = await repo
          .watchPendingForApprover(DemoSeed.ana.uid)
          .first;
      expect(pending.single.childName, 'Sofía');
      await repo.review(pending.single, approve: true);

      final sofia = child('demo-sofia');
      expect(sofia.classIds, [DemoSeed.class2b]);
      expect(
        sofia.familyId,
        DemoSeed.familyLopez,
        reason: 'sigue en su familia',
      );
      expect(sofia.memberUids, contains(DemoSeed.ana.uid));
      expect(
        link('demo-sofia', DemoSeed.ana.uid)!.source,
        LinkSource.classroom,
      );
      expect(classroom(DemoSeed.class2b).studentIds, contains('demo-sofia'));
      // Un solo perfil: no se duplicó.
      expect(
        db.where(DemoDatabase.children, (r) => r['name'] == 'Sofía'),
        hasLength(1),
      );
    });

    test('solo un adulto de la familia del niño puede vincularlo', () async {
      final inv = await classInvite(approval: false);
      await as(DemoSeed.maria);
      await expectLater(
        repo.redeem(inv.code, childId: 'demo-mateo'),
        throwsInvitation(InvitationError.childNotAllowed),
      );
      // María no obtuvo acceso a Mateo ni se tocó su perfil.
      expect(
        child('demo-mateo').memberUids,
        isNot(contains(DemoSeed.maria.uid)),
      );
      expect(child('demo-mateo').familyId, DemoSeed.familyRuiz);
    });

    test('un niño ya vinculado no se vuelve a vincular', () async {
      final inv = await classInvite();
      await as(DemoSeed.maria);
      await expectLater(
        repo.redeem(inv.code, childId: 'demo-juan'),
        throwsInvitation(InvitationError.alreadyLinked),
      );
    });

    test('al aprobar se vuelve a comprobar la autorización', () async {
      final inv = await classInvite();
      await as(DemoSeed.luis);
      await repo.redeem(inv.code, childId: 'demo-sofia');
      // Luis deja la familia antes de que la docente apruebe.
      await c
          .read(familiesRepositoryProvider)
          .removeAdult(
            family(DemoSeed.familyLopez),
            actor: DemoSeed.luis,
            adultUid: DemoSeed.luis.uid,
          );
      await as(DemoSeed.ana);
      final pending = await repo
          .watchPendingForApprover(DemoSeed.ana.uid)
          .first;
      await expectLater(
        repo.review(pending.single, approve: true),
        throwsInvitation(InvitationError.notAllowed),
      );
      expect(child('demo-sofia').memberUids, isNot(contains(DemoSeed.ana.uid)));
    });
  });

  group('Códigos inválidos y abuso', () {
    test('vencido, revocado y ya utilizado tienen mensajes claros', () async {
      final expired = await familyInvite(maxUses: 5);
      final revoked = await familyInvite(maxUses: 5);
      final once = await familyInvite(approval: false);
      await repo.revoke(revoked);

      await as(DemoSeed.carlos);
      await repo.redeem(once.code);
      await as(DemoSeed.ana);
      await expectLater(
        repo.preview(once.code),
        throwsInvitation(InvitationError.exhausted),
      );
      await expectLater(
        repo.preview(revoked.code),
        throwsInvitation(InvitationError.revoked),
      );
      clock.now = clock.now.add(const Duration(hours: 49));
      await expectLater(
        repo.preview(expired.code),
        throwsInvitation(InvitationError.expired),
      );
    });

    test(
      '5 códigos incorrectos bloquean 15 minutos (incluso uno válido)',
      () async {
        final inv = await familyInvite();
        await as(DemoSeed.carlos);
        for (var i = 0; i < 5; i++) {
          await expectLater(
            repo.preview('ZZZZZZZZ'),
            throwsInvitation(InvitationError.invalid),
          );
        }
        await expectLater(
          repo.preview(inv.code),
          throwsInvitation(InvitationError.tooManyAttempts),
        );
        clock.now = clock.now.add(const Duration(minutes: 16));
        expect((await repo.preview(inv.code)).targetName, 'Familia López');
      },
    );

    test('sin conexión no se valida ni se gasta el código', () async {
      final inv = await familyInvite(approval: false);
      await db.setSimulateOffline(true);
      await as(DemoSeed.carlos);
      await expectLater(
        repo.redeem(inv.code),
        throwsA(isA<OfflineException>()),
      );
      await db.setSimulateOffline(false);
      expect(await repo.redeem(inv.code), RedeemOutcome.joined);
    });

    test(
      'el límite de usos se respeta aunque haya solicitudes pendientes',
      () async {
        final inv = await familyInvite(); // un solo uso
        await as(DemoSeed.carlos);
        await repo.redeem(inv.code);
        await as(DemoSeed.ana);
        await expectLater(
          repo.redeem(inv.code),
          throwsInvitation(InvitationError.exhausted),
        );
      },
    );
  });
}
