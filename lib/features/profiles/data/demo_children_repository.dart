import '../../../core/demo/demo_database.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../features/pictograms/data/pictogram_catalog.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';
import '../../../models/family.dart';
import '../../../models/pictogram.dart';
import '../../../models/sensory_settings.dart';
import 'children_repository.dart';

/// Perfiles y vínculos en la base local del modo demostración. Aplica las
/// mismas reglas de permisos que las reglas de seguridad de Firestore.
class DemoChildrenRepository implements ChildrenRepository {
  DemoChildrenRepository(this._db);

  final DemoDatabase _db;

  ChildProfile? _child(String id) {
    final row = _db.get(DemoDatabase.children, id);
    return row == null ? null : ChildProfile.fromMap(row);
  }

  ChildProfile _requireChild(String id) =>
      _child(id) ?? (throw const AppException('El perfil ya no existe.'));

  @override
  Stream<List<ChildProfile>> watchChildrenForAdult(String uid) => _db.watch(
    () =>
        _db
            .where(
              DemoDatabase.children,
              (r) => (r['memberUids'] as List?)?.contains(uid) ?? false,
            )
            .map(ChildProfile.fromMap)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  /// Como las reglas de Firestore: solo un adulto vinculado lee el perfil.
  @override
  Stream<ChildProfile?> watchChild(String childId) => _db.watch(() {
    final child = _child(childId);
    if (child == null || !Permissions.canView(child, _db.sessionUid)) {
      return null;
    }
    return child;
  });

  @override
  Future<ChildProfile> createChild({
    required AppUser owner,
    required String name,
    required String avatar,
    required int avatarColor,
    required GrammaticalGender gender,
    String? lastName,
    SensorySettings settings = const SensorySettings(),
    String? familyId,
    String? id,
  }) async {
    if (owner.uid != _db.sessionUid) throw const PermissionDeniedException();
    Family? family;
    if (familyId != null) {
      final row = _db.get(DemoDatabase.families, familyId);
      family = row == null ? null : Family.fromMap(row);
      if (family == null || !family.isAdult(owner.uid)) {
        throw const PermissionDeniedException(
          'Solo los adultos de la familia pueden crear sus perfiles.',
        );
      }
    }
    final child = ChildProfile(
      id: id ?? newId(),
      name: name.trim(),
      lastName: _clean(lastName),
      settings: settings,
      avatar: avatar,
      avatarColor: avatarColor,
      gender: gender,
      ownerUid: owner.uid,
      memberUids: family?.adultUids ?? [owner.uid],
      familyId: family?.id,
      createdAt: DateTime.now(),
    );
    _db.put(DemoDatabase.children, child.id, child.toMap());
    // Un vínculo por adulto: el creador administra; el resto de la familia
    // queda autorizado.
    for (final uid in child.memberUids) {
      final isOwner = uid == owner.uid;
      final link = CaregiverLink(
        childId: child.id,
        adultUid: uid,
        adultName: isOwner ? owner.displayName : family!.adultName(uid),
        adultEmail: isOwner ? owner.email : '',
        role: isOwner ? owner.role : family!.adultRole(uid),
        permission: isOwner ? LinkPermission.owner : LinkPermission.caregiver,
        source: family == null ? LinkSource.direct : LinkSource.family,
        createdAt: DateTime.now(),
      );
      _db.put(DemoDatabase.links, link.id, link.toMap());
    }
    _db.put(
      DemoDatabase.content,
      child.id,
      const ChildContent(
        favoritePictogramIds: PictogramCatalog.defaultFavoriteIds,
        frequentPhrases: PictogramCatalog.defaultFrequentPhrases,
      ).toMap(),
    );
    _db.commit();
    return child;
  }

  @override
  Future<void> updateChildProfile(
    ChildProfile child, {
    required String name,
    required String avatar,
    required int avatarColor,
    required GrammaticalGender gender,
    String? lastName,
    String? photo,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canEditSupport(current, _db.sessionUid)) {
      throw const PermissionDeniedException();
    }
    _db.put(
      DemoDatabase.children,
      child.id,
      current
          .copyWith(
            name: name.trim(),
            lastName: () => _clean(lastName),
            photo: () => photo,
            avatar: avatar,
            avatarColor: avatarColor,
            gender: gender,
          )
          .toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> updateSettings(String childId, SensorySettings settings) async {
    final current = _requireChild(childId);
    if (!Permissions.canEditSupport(current, _db.sessionUid)) {
      throw const PermissionDeniedException();
    }
    _db.put(
      DemoDatabase.children,
      childId,
      current.copyWith(settings: settings).toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> setResponsible({
    required ChildProfile child,
    required AppUser actor,
    required CaregiverLink? adult,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canSetResponsible(
      current,
      actorUid: actor.uid,
      targetUid: adult?.adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    _db.put(
      DemoDatabase.children,
      child.id,
      current
          .copyWith(
            responsibleUid: () => adult?.adultUid,
            responsibleName: () => adult?.adultName,
            responsibleSince: () => adult == null ? null : DateTime.now(),
          )
          .toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> deleteChild(ChildProfile child, {required AppUser actor}) async {
    final current = _requireChild(child.id);
    if (!Permissions.canDeleteChild(current, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil puede eliminarlo.',
      );
    }
    bool sameChild(Map<String, dynamic> r) => r['childId'] == child.id;
    _db.deleteWhere(DemoDatabase.links, sameChild);
    _db.deleteWhere(DemoDatabase.invitations, sameChild);
    _db.deleteWhere(DemoDatabase.requests, sameChild);
    _db.deleteWhere(DemoDatabase.strategies, sameChild);
    _db.delete(DemoDatabase.passports, child.id);
    _db.delete(DemoDatabase.content, child.id);
    _db.delete(DemoDatabase.children, child.id);
    // Como `cleanupOnChildDeleted`: sale de las clases en las que estaba.
    for (final row in _db.where(
      DemoDatabase.classes,
      (r) => (r['studentIds'] as List?)?.contains(child.id) ?? false,
    )) {
      final classroom = Classroom.fromMap(row);
      _db.put(
        DemoDatabase.classes,
        classroom.id,
        classroom
            .copyWith(
              studentIds: classroom.studentIds
                  .where((s) => s != child.id)
                  .toList(),
            )
            .toMap(),
      );
    }
    _db.commit();
  }

  @override
  Stream<List<CaregiverLink>> watchLinks(String childId) => _db.watch(() {
    final child = _child(childId);
    if (child == null || !Permissions.canView(child, _db.sessionUid)) {
      return <CaregiverLink>[];
    }
    return _db
        .where(DemoDatabase.links, (r) => r['childId'] == childId)
        .map(CaregiverLink.fromMap)
        .where((l) => child.memberUids.contains(l.adultUid))
        .toList()
      ..sort((a, b) => a.permission.index - b.permission.index);
  });

  @override
  Stream<List<Invitation>> watchInvitations(ChildProfile child, String uid) =>
      _db.watch(
        () =>
            _db
                .where(
                  DemoDatabase.invitations,
                  (r) => r['childId'] == child.id && r['createdBy'] == uid,
                )
                .map(Invitation.fromMap)
                .where((i) => !i.isUsed)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<Invitation> createInvitation({
    required ChildProfile child,
    required AdultRole role,
    required AppUser createdBy,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canManageCaregivers(current, createdBy.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil puede invitar adultos.',
      );
    }
    final now = DateTime.now();
    final invitation = Invitation(
      code: newInvitationCode(),
      childId: child.id,
      childName: current.name,
      role: role,
      createdByUid: createdBy.uid,
      createdByName: createdBy.displayName,
      createdAt: now,
      expiresAt: now.add(Invitation.validity),
    );
    _db.put(DemoDatabase.invitations, invitation.code, invitation.toMap());
    _db.commit();
    return invitation;
  }

  @override
  Future<void> revokeInvitation(Invitation invitation) async {
    _db.delete(DemoDatabase.invitations, invitation.code);
    _db.commit();
  }

  @override
  Future<CaregiverLink> acceptInvitation({
    required String code,
    required AppUser adult,
  }) async {
    final normalized = code.trim().toUpperCase();
    final row = _db.get(DemoDatabase.invitations, normalized);
    if (row == null) {
      throw const AppException(
        'El código no existe. Revisa que esté bien escrito.',
      );
    }
    final invitation = Invitation.fromMap(row);
    if (invitation.isUsed) {
      throw const AppException('Este código ya fue utilizado.');
    }
    if (invitation.isExpired()) {
      throw const AppException('Este código caducó. Pide uno nuevo.');
    }
    final child = _requireChild(invitation.childId);
    if (child.memberUids.contains(adult.uid)) {
      throw const AppException('Ya estás vinculado a este perfil.');
    }
    final link = CaregiverLink(
      childId: child.id,
      adultUid: adult.uid,
      adultName: adult.displayName,
      adultEmail: adult.email,
      role: invitation.role,
      permission: LinkPermission.caregiver,
      invitationCode: invitation.code,
      invitedByUid: invitation.createdByUid,
      createdAt: DateTime.now(),
    );
    _db.put(
      DemoDatabase.children,
      child.id,
      child.copyWith(memberUids: [...child.memberUids, adult.uid]).toMap(),
    );
    _db.put(DemoDatabase.links, link.id, link.toMap());
    _db.put(DemoDatabase.invitations, invitation.code, {
      ...row,
      'usedBy': adult.uid,
      'usedAt': DateTime.now(),
    });
    _db.commit();
    return link;
  }

  @override
  Future<void> removeLink({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canRemoveLink(
      current,
      actorUid: actor.uid,
      targetUid: adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    final wasResponsible = current.responsibleUid == adultUid;
    _db.put(
      DemoDatabase.children,
      child.id,
      current
          .copyWith(
            memberUids: current.memberUids.where((u) => u != adultUid).toList(),
            backupUids: current.backupUids.where((u) => u != adultUid).toList(),
            responsibleUid: wasResponsible ? () => null : null,
            responsibleName: wasResponsible ? () => null : null,
            responsibleSince: wasResponsible ? () => null : null,
          )
          .toMap(),
    );
    _db.delete(DemoDatabase.links, '${child.id}_$adultUid');
    _db.commit();
  }

  @override
  Future<void> setLinkPermissions({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
    required bool receivesRequests,
    required bool canViewPassport,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canManageLinkPermissions(current, actor.uid) ||
        actor.uid != _db.sessionUid) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil cambia los permisos.',
      );
    }
    final linkId = '${child.id}_$adultUid';
    final row = _db.get(DemoDatabase.links, linkId);
    if (row == null) {
      throw const AppException('El adulto ya no está vinculado.');
    }
    _db.put(
      DemoDatabase.links,
      linkId,
      CaregiverLink.fromMap(row)
          .copyWith(
            receivesRequests: receivesRequests,
            canViewPassport: canViewPassport,
          )
          .toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> setNoCompanionRule({
    required ChildProfile child,
    required AppUser actor,
    required NoCompanionRule rule,
    required List<String> backupUids,
  }) async {
    final current = _requireChild(child.id);
    if (!Permissions.canManageLinkPermissions(current, actor.uid) ||
        actor.uid != _db.sessionUid) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil decide a quién se avisa.',
      );
    }
    _db.put(
      DemoDatabase.children,
      child.id,
      current
          .copyWith(
            noCompanionRule: rule,
            backupUids: [
              for (final uid in backupUids)
                if (current.memberUids.contains(uid)) uid,
            ],
          )
          .toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> syncAdultName(AppUser adult, List<ChildProfile> children) async {
    if (adult.uid != _db.sessionUid) throw const PermissionDeniedException();
    for (final child in children) {
      final current = _child(child.id);
      if (current == null || !current.memberUids.contains(adult.uid)) continue;
      final linkId = '${child.id}_${adult.uid}';
      final link = _db.get(DemoDatabase.links, linkId);
      if (link != null) {
        _db.put(DemoDatabase.links, linkId, {
          ...link,
          'adultName': adult.displayName,
        });
      }
      if (current.responsibleUid == adult.uid) {
        _db.put(
          DemoDatabase.children,
          child.id,
          current.copyWith(responsibleName: () => adult.displayName).toMap(),
        );
      }
    }
    _db.commit();
  }

  static String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
