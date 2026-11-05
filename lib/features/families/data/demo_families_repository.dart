import '../../../core/demo/demo_database.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/family.dart';
import 'families_repository.dart';

/// Familias en la base local. Aplica las mismas reglas que Firestore.
class DemoFamiliesRepository implements FamiliesRepository {
  DemoFamiliesRepository(this._db);

  final DemoDatabase _db;

  Family? _family(String id) {
    final row = _db.get(DemoDatabase.families, id);
    return row == null ? null : Family.fromMap(row);
  }

  Family _require(String id) =>
      _family(id) ?? (throw const AppException('La familia ya no existe.'));

  @override
  Stream<List<Family>> watchFamiliesForAdult(String uid) => _db.watch(
    () =>
        _db
            .where(
              DemoDatabase.families,
              (r) => (r['adultUids'] as List?)?.contains(uid) ?? false,
            )
            .map(Family.fromMap)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Stream<Family?> watchFamily(String familyId) => _db.watch(() {
    final family = _family(familyId);
    return family != null && family.isAdult(_db.sessionUid) ? family : null;
  });

  @override
  Future<Family> createFamily({
    required AppUser owner,
    required String name,
  }) async {
    if (owner.uid != _db.sessionUid) throw const PermissionDeniedException();
    final family = Family(
      id: newId(),
      name: name.trim(),
      ownerUid: owner.uid,
      adultUids: [owner.uid],
      adultNames: {owner.uid: owner.displayName},
      adultRoles: {owner.uid: owner.role},
      createdAt: DateTime.now(),
    );
    _db.put(DemoDatabase.families, family.id, family.toMap());
    _db.commit();
    return family;
  }

  @override
  Future<void> renameFamily(
    Family family,
    String name, {
    required AppUser actor,
  }) async {
    final current = _require(family.id);
    if (!Permissions.canManageFamily(current, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador de la familia puede cambiar su nombre.',
      );
    }
    _db.put(
      DemoDatabase.families,
      family.id,
      current.copyWith(name: name.trim()).toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> removeAdult(
    Family family, {
    required AppUser actor,
    required String adultUid,
  }) async {
    final current = _require(family.id);
    if (!Permissions.canRemoveFamilyAdult(
      current,
      actorUid: actor.uid,
      targetUid: adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    _db.put(
      DemoDatabase.families,
      family.id,
      current
          .copyWith(
            adultUids: current.adultUids.where((u) => u != adultUid).toList(),
            adultNames: {...current.adultNames}..remove(adultUid),
            adultRoles: {...current.adultRoles}..remove(adultUid),
          )
          .toMap(),
    );
    // Pierde el acceso que le daba la familia; los datos del niño se quedan.
    for (final row in _db.where(
      DemoDatabase.children,
      (r) => r['familyId'] == family.id,
    )) {
      final child = ChildProfile.fromMap(row);
      final linkId = '${child.id}_$adultUid';
      final linkRow = _db.get(DemoDatabase.links, linkId);
      final link = linkRow == null ? null : CaregiverLink.fromMap(linkRow);
      if (link != null && link.source != LinkSource.family) continue;
      final wasResponsible = child.responsibleUid == adultUid;
      _db.put(
        DemoDatabase.children,
        child.id,
        child
            .copyWith(
              memberUids: child.memberUids.where((u) => u != adultUid).toList(),
              responsibleUid: wasResponsible ? () => null : null,
              responsibleName: wasResponsible ? () => null : null,
              responsibleSince: wasResponsible ? () => null : null,
            )
            .toMap(),
      );
      _db.delete(DemoDatabase.links, linkId);
    }
    _db.commit();
  }

  @override
  Future<void> releaseForAccountDeletion(
    Family family, {
    required AppUser actor,
  }) async {
    final current = _require(family.id);
    if (actor.uid != _db.sessionUid) throw const PermissionDeniedException();
    if (current.ownerUid != actor.uid) {
      return removeAdult(current, actor: actor, adultUid: actor.uid);
    }
    final others = current.adultUids.where((u) => u != actor.uid).toList();
    if (others.isEmpty) {
      _db.delete(DemoDatabase.families, current.id);
      for (final row in _db.where(
        DemoDatabase.groupInvitations,
        (r) => r['targetId'] == current.id,
      )) {
        _db.delete(DemoDatabase.groupInvitations, row['code'] as String);
      }
    } else {
      // Igual que la Cloud Function: la administra el siguiente adulto.
      _db.put(
        DemoDatabase.families,
        current.id,
        Family.fromMap({
          ...current
              .copyWith(
                adultUids: others,
                adultNames: {...current.adultNames}..remove(actor.uid),
                adultRoles: {...current.adultRoles}..remove(actor.uid),
              )
              .toMap(),
          'ownerUid': others.first,
        }).toMap(),
      );
    }
    _db.commit();
  }

  @override
  Future<Family?> adoptOrphanChildren(AppUser owner) async {
    if (owner.uid != _db.sessionUid) throw const PermissionDeniedException();
    final orphans = _db
        .where(
          DemoDatabase.children,
          (r) => r['ownerUid'] == owner.uid && r['familyId'] == null,
        )
        .map(ChildProfile.fromMap)
        .toList();
    if (orphans.isEmpty) return null;
    final existing = _db
        .where(DemoDatabase.families, (r) => r['ownerUid'] == owner.uid)
        .map(Family.fromMap)
        .firstOrNull;
    final family =
        existing ??
        await createFamily(owner: owner, name: defaultFamilyName(owner));
    for (final child in orphans) {
      _db.put(
        DemoDatabase.children,
        child.id,
        child.copyWith(familyId: () => family.id).toMap(),
      );
      final linkId = '${child.id}_${owner.uid}';
      final linkRow = _db.get(DemoDatabase.links, linkId);
      if (linkRow != null) {
        _db.put(
          DemoDatabase.links,
          linkId,
          CaregiverLink.fromMap(linkRow)
              .copyWith(source: LinkSource.family)
              .toMap(),
        );
      }
    }
    _db.commit();
    return family;
  }
}

/// "Familia López" a partir del apellido (o del nombre) del adulto.
String defaultFamilyName(AppUser owner) {
  final last = owner.lastName?.trim() ?? '';
  return 'Familia ${last.isNotEmpty ? last : owner.firstName}';
}
