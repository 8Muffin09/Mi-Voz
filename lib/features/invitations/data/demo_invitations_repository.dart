import 'dart:math';

import '../../../core/demo/demo_database.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';
import '../../../models/family.dart';
import '../../../models/group_invitation.dart';
import 'invitations_repository.dart';

/// "Servidor" local de invitaciones para el modo "Solo en este dispositivo".
/// Aplica exactamente las mismas validaciones que las Cloud Functions de
/// `functions/index.js` (permisos, caducidad, revocación, usos, duplicados,
/// intentos incorrectos y conexión).
class DemoInvitationsRepository implements InvitationsRepository {
  DemoInvitationsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DemoDatabase _db;
  final DateTime Function() _clock;
  final _random = Random.secure();

  /// Intentos incorrectos permitidos en la ventana antes de bloquear.
  static const maxFailures = 5;
  static const failureWindow = Duration(minutes: 15);
  static const lockDuration = Duration(minutes: 15);

  // ---------------------------------------------------------------- ayuda

  AppUser _session() {
    final uid = _db.sessionUid;
    final row = uid == null ? null : _db.get(DemoDatabase.users, uid);
    if (row == null) throw const PermissionDeniedException();
    return AppUser.fromMap(row);
  }

  void _requireOnline() {
    if (_db.simulateOffline) {
      throw const OfflineException(
        'Se necesita conexión para validar el código. Inténtalo cuando '
        'vuelva internet.',
      );
    }
  }

  Family? _family(String id) {
    final row = _db.get(DemoDatabase.families, id);
    return row == null ? null : Family.fromMap(row);
  }

  Classroom? _class(String id) {
    final row = _db.get(DemoDatabase.classes, id);
    return row == null ? null : Classroom.fromMap(row);
  }

  ChildProfile? _child(String id) {
    final row = _db.get(DemoDatabase.children, id);
    return row == null ? null : ChildProfile.fromMap(row);
  }

  GroupInvitation? _invitation(String code) {
    final row = _db.get(DemoDatabase.groupInvitations, code);
    return row == null ? null : GroupInvitation.fromMap(row);
  }

  String _ownerOf(InviteTargetType type, String targetId) => switch (type) {
    InviteTargetType.family => _family(targetId)?.ownerUid ?? '',
    InviteTargetType.classroom => _class(targetId)?.ownerUid ?? '',
  };

  String _newCode() {
    while (true) {
      final code = List.generate(
        InvitationLink.codeLength,
        (_) =>
            InvitationLink.alphabet[_random.nextInt(
              InvitationLink.alphabet.length,
            )],
      ).join();
      if (_invitation(code) == null) return code;
    }
  }

  // ------------------------------------------------- intentos incorrectos

  void _checkRateLimit(String uid) {
    final row = _db.get(DemoDatabase.rateLimits, uid);
    final locked = DateTime.tryParse(row?['lockedUntil'] as String? ?? '');
    if (locked != null && _clock().isBefore(locked)) {
      throw InvitationException(InvitationError.tooManyAttempts);
    }
  }

  void _registerFailure(String uid) {
    final now = _clock();
    final row = _db.get(DemoDatabase.rateLimits, uid) ?? {};
    final start = DateTime.tryParse(row['windowStart'] as String? ?? '');
    final inWindow = start != null && now.difference(start) < failureWindow;
    final failures = (inWindow ? (row['failures'] as int? ?? 0) : 0) + 1;
    _db.put(DemoDatabase.rateLimits, uid, {
      'failures': failures,
      'windowStart': (inWindow ? start : now).toUtc().toIso8601String(),
      if (failures >= maxFailures)
        'lockedUntil': now.add(lockDuration).toUtc().toIso8601String(),
    });
    _db.commit();
  }

  /// Valida el código como lo hace el servidor. Los códigos inexistentes
  /// cuentan como intento incorrecto; los vencidos o revocados, no.
  GroupInvitation _validate(String rawCode, AppUser user) {
    _requireOnline();
    _checkRateLimit(user.uid);
    final code = InvitationLink.normalize(rawCode);
    final invitation = InvitationLink.isWellFormed(code)
        ? _invitation(code)
        : null;
    if (invitation == null) {
      _registerFailure(user.uid);
      throw InvitationException(InvitationError.invalid);
    }
    switch (invitation.status(_clock())) {
      case InvitationStatus.expired:
        throw InvitationException(InvitationError.expired);
      case InvitationStatus.revoked:
        throw InvitationException(InvitationError.revoked);
      case InvitationStatus.exhausted:
        throw InvitationException(InvitationError.exhausted);
      case InvitationStatus.active:
        return invitation;
    }
  }

  // ------------------------------------------------------------ crear

  @override
  Future<GroupInvitation> create({
    required InviteTargetType type,
    required String targetId,
    required Duration validity,
    required int maxUses,
    required bool requiresApproval,
    AdultRole? role,
  }) async {
    final user = _session();
    if (!user.emailVerified) {
      throw InvitationException(InvitationError.emailNotVerified);
    }
    if (!GroupInvitation.allowedValidity.contains(validity) ||
        !GroupInvitation.allowedMaxUses.contains(maxUses)) {
      throw InvitationException(InvitationError.notAllowed);
    }
    final String targetName;
    switch (type) {
      case InviteTargetType.family:
        final family = _family(targetId);
        if (family == null || !family.isOwner(user.uid)) {
          throw InvitationException(InvitationError.notAllowed);
        }
        targetName = family.name;
      case InviteTargetType.classroom:
        final classroom = _class(targetId);
        if (classroom == null ||
            !classroom.isOwner(user.uid) ||
            classroom.archived) {
          throw InvitationException(InvitationError.notAllowed);
        }
        targetName = classroom.name;
    }
    final now = _clock();
    final invitation = GroupInvitation(
      code: _newCode(),
      type: type,
      targetId: targetId,
      targetName: targetName,
      createdByUid: user.uid,
      createdByName: user.displayName,
      createdAt: now,
      expiresAt: now.add(validity),
      maxUses: maxUses,
      requiresApproval: requiresApproval,
      role: type == InviteTargetType.family
          ? (role != null && role.isFamily ? role : AdultRole.tutor)
          : null,
    );
    _db.put(DemoDatabase.groupInvitations, invitation.code, invitation.toMap());
    _db.commit();
    return invitation;
  }

  @override
  Stream<List<GroupInvitation>> watchForTarget(
    InviteTargetType type,
    String targetId,
  ) => _db.watch(() {
    if (_ownerOf(type, targetId) != _db.sessionUid) {
      return <GroupInvitation>[];
    }
    return _db
        .where(
          DemoDatabase.groupInvitations,
          (r) => r['type'] == type.name && r['targetId'] == targetId,
        )
        .map(GroupInvitation.fromMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });

  @override
  Future<void> revoke(GroupInvitation invitation) async {
    final user = _session();
    final current = _invitation(invitation.code);
    if (current == null) throw InvitationException(InvitationError.invalid);
    if (current.createdByUid != user.uid &&
        _ownerOf(current.type, current.targetId) != user.uid) {
      throw InvitationException(InvitationError.notAllowed);
    }
    _db.put(
      DemoDatabase.groupInvitations,
      current.code,
      current.copyWith(revoked: true).toMap(),
    );
    _db.commit();
  }

  // ------------------------------------------------------- vista previa

  @override
  Future<InvitationPreview> preview(String code) async {
    final user = _session();
    final invitation = _validate(code, user);
    return InvitationPreview(
      code: invitation.code,
      type: invitation.type,
      targetName: invitation.targetName,
      inviterName: invitation.createdByName,
      requiresApproval: invitation.requiresApproval,
      role: invitation.role,
    );
  }

  // ------------------------------------------------------------- canjear

  bool _hasPendingRequest(String uid, GroupInvitation inv, String? childId) =>
      _db
          .where(
            DemoDatabase.joinRequests,
            (r) =>
                r['requesterUid'] == uid &&
                r['targetId'] == inv.targetId &&
                r['status'] == JoinRequestStatus.pending.name &&
                (childId == null || r['childId'] == childId),
          )
          .isNotEmpty;

  @override
  Future<RedeemOutcome> redeem(String code, {String? childId}) async {
    final user = _session();
    final invitation = _validate(code, user);
    ChildProfile? child;
    final String approver;
    switch (invitation.type) {
      case InviteTargetType.family:
        final family = _family(invitation.targetId);
        if (family == null) throw InvitationException(InvitationError.invalid);
        if (family.isAdult(user.uid)) {
          throw InvitationException(InvitationError.alreadyMember);
        }
        approver = family.ownerUid;
      case InviteTargetType.classroom:
        final classroom = _class(invitation.targetId);
        if (classroom == null || classroom.archived) {
          throw InvitationException(InvitationError.invalid);
        }
        if (childId == null) {
          throw InvitationException(InvitationError.childRequired);
        }
        child = _child(childId);
        if (child == null || !_canLinkChild(child, user.uid)) {
          throw InvitationException(InvitationError.childNotAllowed);
        }
        if (child.classIds.contains(classroom.id)) {
          throw InvitationException(InvitationError.alreadyLinked);
        }
        approver = classroom.ownerUid;
    }
    if (_hasPendingRequest(user.uid, invitation, childId)) {
      throw InvitationException(InvitationError.alreadyRequested);
    }
    // El uso se cuenta al canjear: así se respeta el límite aunque la
    // solicitud quede pendiente.
    _db.put(
      DemoDatabase.groupInvitations,
      invitation.code,
      invitation.copyWith(uses: invitation.uses + 1).toMap(),
    );
    if (invitation.requiresApproval) {
      final request = JoinRequest(
        id: newId(),
        code: invitation.code,
        type: invitation.type,
        targetId: invitation.targetId,
        targetName: invitation.targetName,
        requesterUid: user.uid,
        requesterName: user.displayName,
        approverUid: approver,
        createdAt: _clock(),
        childId: child?.id,
        childName: child?.name,
        role: invitation.role,
      );
      _db.put(DemoDatabase.joinRequests, request.id, request.toMap());
      _db.commit();
      return RedeemOutcome.pendingApproval;
    }
    _apply(
      type: invitation.type,
      targetId: invitation.targetId,
      requester: user,
      role: invitation.role,
      childId: child?.id,
    );
    _db.commit();
    return RedeemOutcome.joined;
  }

  /// Solo un adulto de la familia del niño (o su administrador) lo vincula.
  bool _canLinkChild(ChildProfile child, String uid) {
    final familyId = child.familyId;
    if (familyId != null) return _family(familyId)?.isAdult(uid) ?? false;
    return child.ownerUid == uid;
  }

  // ------------------------------------------------------------ aprobar

  @override
  Stream<List<JoinRequest>> watchPendingForApprover(String uid) => _db.watch(
    () =>
        _db
            .where(
              DemoDatabase.joinRequests,
              (r) =>
                  r['approverUid'] == uid &&
                  r['status'] == JoinRequestStatus.pending.name,
            )
            .map(JoinRequest.fromMap)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  @override
  Stream<List<JoinRequest>> watchMyRequests(String uid) => _db.watch(
    () =>
        _db
            .where(DemoDatabase.joinRequests, (r) => r['requesterUid'] == uid)
            .map(JoinRequest.fromMap)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> review(JoinRequest request, {required bool approve}) async {
    _requireOnline();
    final user = _session();
    final row = _db.get(DemoDatabase.joinRequests, request.id);
    final current = row == null ? null : JoinRequest.fromMap(row);
    if (current == null ||
        current.approverUid != user.uid ||
        current.status != JoinRequestStatus.pending) {
      throw InvitationException(InvitationError.notAllowed);
    }
    if (approve) {
      final requesterRow = _db.get(DemoDatabase.users, current.requesterUid);
      if (requesterRow == null) {
        throw InvitationException(InvitationError.notAllowed);
      }
      final requester = AppUser.fromMap(requesterRow);
      if (current.type == InviteTargetType.classroom) {
        final child = current.childId == null ? null : _child(current.childId!);
        final classroom = _class(current.targetId);
        // Se vuelve a comprobar: pudo cambiar desde la solicitud.
        if (child == null ||
            classroom == null ||
            classroom.archived ||
            !_canLinkChild(child, requester.uid)) {
          throw InvitationException(InvitationError.notAllowed);
        }
      } else if (_family(current.targetId) == null) {
        throw InvitationException(InvitationError.notAllowed);
      }
      _apply(
        type: current.type,
        targetId: current.targetId,
        requester: requester,
        role: current.role,
        childId: current.childId,
      );
    }
    _db.put(
      DemoDatabase.joinRequests,
      current.id,
      current
          .copyWith(
            status: approve
                ? JoinRequestStatus.approved
                : JoinRequestStatus.rejected,
            reviewedAt: _clock(),
          )
          .toMap(),
    );
    _db.commit();
  }

  // ------------------------------------------- registrar el vínculo

  void _apply({
    required InviteTargetType type,
    required String targetId,
    required AppUser requester,
    required AdultRole? role,
    required String? childId,
  }) {
    switch (type) {
      case InviteTargetType.family:
        _joinFamily(_family(targetId)!, requester, role ?? AdultRole.tutor);
      case InviteTargetType.classroom:
        _linkChildToClass(_class(targetId)!, _child(childId!)!);
    }
  }

  void _joinFamily(Family family, AppUser adult, AdultRole role) {
    if (family.isAdult(adult.uid)) return;
    _db.put(
      DemoDatabase.families,
      family.id,
      family
          .copyWith(
            adultUids: [...family.adultUids, adult.uid],
            adultNames: {...family.adultNames, adult.uid: adult.displayName},
            adultRoles: {...family.adultRoles, adult.uid: role},
          )
          .toMap(),
    );
    // Acceso a todos los niños de la familia.
    for (final row in _db.where(
      DemoDatabase.children,
      (r) => r['familyId'] == family.id,
    )) {
      final child = ChildProfile.fromMap(row);
      if (!child.memberUids.contains(adult.uid)) {
        _db.put(
          DemoDatabase.children,
          child.id,
          child.copyWith(memberUids: [...child.memberUids, adult.uid]).toMap(),
        );
      }
      final link = CaregiverLink(
        childId: child.id,
        adultUid: adult.uid,
        adultName: adult.displayName,
        adultEmail: adult.email,
        role: role,
        permission: LinkPermission.caregiver,
        source: LinkSource.family,
        invitedByUid: family.ownerUid,
        createdAt: _clock(),
      );
      _db.put(DemoDatabase.links, link.id, link.toMap());
    }
  }

  void _linkChildToClass(Classroom classroom, ChildProfile child) {
    if (!classroom.studentIds.contains(child.id)) {
      _db.put(
        DemoDatabase.classes,
        classroom.id,
        classroom
            .copyWith(studentIds: [...classroom.studentIds, child.id])
            .toMap(),
      );
    }
    var updated = child.copyWith(
      classIds: {...child.classIds, classroom.id}.toList(),
    );
    for (final teacher in classroom.teacherUids) {
      final linkId = '${child.id}_$teacher';
      final row = _db.get(DemoDatabase.links, linkId);
      if (row != null) {
        final link = CaregiverLink.fromMap(row);
        _db.put(
          DemoDatabase.links,
          linkId,
          link
              .copyWith(classIds: {...link.classIds, classroom.id}.toList())
              .toMap(),
        );
        continue;
      }
      if (!updated.memberUids.contains(teacher)) {
        updated = updated.copyWith(
          memberUids: [...updated.memberUids, teacher],
        );
      }
      final link = CaregiverLink(
        childId: child.id,
        adultUid: teacher,
        adultName: classroom.teacherNames[teacher] ?? 'Docente',
        adultEmail: '',
        role: AdultRole.docente,
        permission: LinkPermission.caregiver,
        source: LinkSource.classroom,
        classIds: [classroom.id],
        invitedByUid: child.ownerUid,
        createdAt: _clock(),
      );
      _db.put(DemoDatabase.links, link.id, link.toMap());
    }
    _db.put(DemoDatabase.children, child.id, updated.toMap());
  }
}
