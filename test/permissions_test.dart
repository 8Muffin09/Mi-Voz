import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/permissions/permissions.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:mi_voz/models/support_strategy.dart';

ChildProfile juan({String? responsible}) => ChildProfile(
  id: 'juan',
  name: 'Juan',
  avatar: '🦁',
  avatarColor: 0,
  gender: GrammaticalGender.masculine,
  ownerUid: 'mama',
  memberUids: const ['mama', 'papa', 'maestra'],
  responsibleUid: responsible,
  responsibleName: responsible == null ? null : 'Nombre $responsible',
);

SupportStrategy strategyBy(String uid) => SupportStrategy(
  id: 's',
  childId: 'juan',
  title: 'Audífonos',
  place: StrategyPlace.home,
  result: StrategyResult.worked,
  createdByUid: uid,
  createdByName: uid,
  createdByRole: AdultRole.madre,
  createdAt: DateTime(2026),
);

void main() {
  group('Permisos por rol', () {
    final child = juan();

    test('solo los adultos vinculados pueden ver datos del niño', () {
      expect(Permissions.canView(child, 'maestra'), isTrue);
      expect(Permissions.canView(child, 'extraño'), isFalse);
      expect(Permissions.canView(child, null), isFalse);
      expect(Permissions.canCreateRequest(child, 'extraño'), isFalse);
    });

    test('solo el administrador gestiona vínculos y elimina el perfil', () {
      expect(Permissions.canManageCaregivers(child, 'mama'), isTrue);
      expect(Permissions.canManageCaregivers(child, 'maestra'), isFalse);
      expect(Permissions.canDeleteChild(child, 'papa'), isFalse);
      expect(Permissions.canDeleteChild(child, 'mama'), isTrue);
    });

    test('quitar vínculos: el administrador a otros, cada uno a sí mismo', () {
      expect(
        Permissions.canRemoveLink(
          child,
          actorUid: 'mama',
          targetUid: 'maestra',
        ),
        isTrue,
      );
      expect(
        Permissions.canRemoveLink(
          child,
          actorUid: 'maestra',
          targetUid: 'maestra',
        ),
        isTrue,
      );
      expect(
        Permissions.canRemoveLink(
          child,
          actorUid: 'papa',
          targetUid: 'maestra',
        ),
        isFalse,
      );
      expect(
        Permissions.canRemoveLink(child, actorUid: 'mama', targetUid: 'mama'),
        isFalse,
      );
    });

    test('adulto responsable: cada uno se marca a sí mismo', () {
      expect(
        Permissions.canSetResponsible(
          child,
          actorUid: 'maestra',
          targetUid: 'maestra',
        ),
        isTrue,
      );
      expect(
        Permissions.canSetResponsible(
          child,
          actorUid: 'maestra',
          targetUid: 'papa',
        ),
        isFalse,
      );
      expect(
        Permissions.canSetResponsible(
          child,
          actorUid: 'mama',
          targetUid: 'papa',
        ),
        isTrue,
      );
      expect(
        Permissions.canSetResponsible(
          child,
          actorUid: 'mama',
          targetUid: 'extraño',
        ),
        isFalse,
      );
      expect(
        Permissions.canSetResponsible(
          child,
          actorUid: 'extraño',
          targetUid: 'extraño',
        ),
        isFalse,
      );
    });

    test('dejar de acompañar: solo el responsable o el administrador', () {
      final withTeacher = juan(responsible: 'maestra');
      expect(
        Permissions.canSetResponsible(
          withTeacher,
          actorUid: 'maestra',
          targetUid: null,
        ),
        isTrue,
      );
      expect(
        Permissions.canSetResponsible(
          withTeacher,
          actorUid: 'papa',
          targetUid: null,
        ),
        isFalse,
      );
      expect(
        Permissions.canSetResponsible(
          withTeacher,
          actorUid: 'mama',
          targetUid: null,
        ),
        isTrue,
      );
    });

    test('estrategias: editar solo el autor o el administrador', () {
      expect(
        Permissions.canEditStrategy(child, strategyBy('maestra'), 'maestra'),
        isTrue,
      );
      expect(
        Permissions.canEditStrategy(child, strategyBy('maestra'), 'papa'),
        isFalse,
      );
      expect(
        Permissions.canEditStrategy(child, strategyBy('maestra'), 'mama'),
        isTrue,
      );
    });
  });

  group('Estados de solicitud', () {
    test('solo avanzan', () {
      expect(
        Permissions.isValidTransition(
          RequestStatus.newRequest,
          RequestStatus.seen,
        ),
        isTrue,
      );
      expect(
        Permissions.isValidTransition(
          RequestStatus.seen,
          RequestStatus.resolved,
        ),
        isTrue,
      );
      expect(
        Permissions.isValidTransition(
          RequestStatus.resolved,
          RequestStatus.seen,
        ),
        isFalse,
      );
      expect(
        Permissions.isValidTransition(RequestStatus.seen, RequestStatus.seen),
        isFalse,
      );
    });
  });

  group('Destinatario', () {
    test('va al adulto responsable si está vinculado', () {
      final child = juan(responsible: 'maestra');
      expect(RecipientResolver.recipientUid(child), 'maestra');
      expect(RecipientResolver.recipients(child), ['maestra']);
    });

    test(
      'sin responsable no se avisa a todos: por defecto al administrador',
      () {
        expect(RecipientResolver.recipientUid(juan()), isNull);
        expect(RecipientResolver.recipients(juan()), ['mama']);
      },
    );

    test('regla "a los que yo elija": solo los elegidos y vinculados', () {
      final child = juan().copyWith(
        noCompanionRule: NoCompanionRule.chosen,
        backupUids: ['papa', 'exmaestra'],
      );
      expect(RecipientResolver.recipients(child), ['papa']);
    });

    test('regla "a todos" solo si el administrador la eligió', () {
      final child = juan().copyWith(noCompanionRule: NoCompanionRule.all);
      expect(RecipientResolver.recipients(child), ['mama', 'papa', 'maestra']);
    });

    test('se respeta "no recibe solicitudes" y puede quedar sin nadie', () {
      final links = [
        CaregiverLink(
          childId: 'juan',
          adultUid: 'mama',
          adultName: 'Mamá',
          adultEmail: 'mama@ejemplo.mx',
          role: AdultRole.madre,
          permission: LinkPermission.owner,
          receivesRequests: false,
        ),
      ];
      expect(RecipientResolver.recipients(juan(), links: links), isEmpty);
      final plan = RecipientResolver.plan(
        juan(responsible: 'maestra'),
        links: links,
      );
      expect(plan.primary, ['maestra']);
      // Si la maestra no tiene dispositivos, la regla no tiene a nadie.
      expect(plan.fallback, isEmpty);
    });

    test('si quien acompaña no tiene dispositivos se usa la regla', () {
      final plan = RecipientResolver.plan(juan(responsible: 'papa'));
      expect(plan.primary, ['papa']);
      expect(plan.fallback, ['mama']);
    });

    test('un responsable que ya no está vinculado no recibe nada', () {
      final child = juan(responsible: 'exmaestra');
      expect(RecipientResolver.recipientUid(child), isNull);
      expect(RecipientResolver.recipients(child), isNot(contains('exmaestra')));
    });
  });
}
