import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/family.dart';
import 'demo_families_repository.dart' show defaultFamilyName;
import 'families_repository.dart';

/// Familias en Firestore (`families/{id}`). Las reglas de seguridad aplican
/// los permisos reales; aquí se validan antes para dar mensajes claros.
class FirebaseFamiliesRepository implements FamiliesRepository {
  FirebaseFamiliesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.doc(FirestorePaths.family(id));

  @override
  Stream<List<Family>> watchFamiliesForAdult(String uid) => _db
      .collection(FirestorePaths.families)
      .where('adultUids', arrayContains: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => Family.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Stream<Family?> watchFamily(String familyId) =>
      _ref(familyId)
          .snapshots()
          .map((s) {
            final data = s.data();
            return data == null ? null : Family.fromMap(data, id: s.id);
          })
          .handleError((Object _) {}, test: _isPermissionDenied);

  static bool _isPermissionDenied(dynamic e) =>
      e is FirebaseException && e.code == 'permission-denied';

  @override
  Future<Family> createFamily({
    required AppUser owner,
    required String name,
  }) async {
    final family = Family(
      id: newId(),
      name: name.trim(),
      ownerUid: owner.uid,
      adultUids: [owner.uid],
      adultNames: {owner.uid: owner.displayName},
      adultRoles: {owner.uid: owner.role},
    );
    await _ref(family.id)
        .set({...family.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return family;
  }

  @override
  Future<void> renameFamily(
    Family family,
    String name, {
    required AppUser actor,
  }) async {
    if (!Permissions.canManageFamily(family, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador de la familia puede cambiar su nombre.',
      );
    }
    await _ref(family.id).update({'name': name.trim()});
  }

  @override
  Future<void> removeAdult(
    Family family, {
    required AppUser actor,
    required String adultUid,
  }) async {
    if (!Permissions.canRemoveFamilyAdult(
      family,
      actorUid: actor.uid,
      targetUid: adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    // Niños de la familia que el actor puede leer (las reglas exigen filtrar
    // por pertenencia).
    final children = await _db
        .collection(FirestorePaths.children)
        .where('memberUids', arrayContains: actor.uid)
        .where('familyId', isEqualTo: family.id)
        .get();
    final batch = _db.batch()
      ..update(_ref(family.id), {
        'adultUids': FieldValue.arrayRemove([adultUid]),
        'adultNames.$adultUid': FieldValue.delete(),
        'adultRoles.$adultUid': FieldValue.delete(),
      });
    for (final doc in children.docs) {
      final child = ChildProfile.fromMap(doc.data(), id: doc.id);
      if (!child.memberUids.contains(adultUid)) continue;
      final linkRef = doc.reference
          .collection(FirestorePaths.caregiverLinks)
          .doc(adultUid);
      final link = await linkRef.get();
      final source = link.data() == null
          ? LinkSource.family
          : CaregiverLink.fromMap(link.data()!).source;
      if (source != LinkSource.family) continue;
      batch
        ..update(doc.reference, {
          'memberUids': FieldValue.arrayRemove([adultUid]),
          if (child.responsibleUid == adultUid) ...{
            'responsibleUid': null,
            'responsibleName': null,
            'responsibleSince': null,
          },
        })
        ..delete(linkRef);
    }
    await batch.commit();
  }

  @override
  Future<void> releaseForAccountDeletion(
    Family family, {
    required AppUser actor,
  }) async {
    if (family.ownerUid != actor.uid) {
      return removeAdult(family, actor: actor, adultUid: actor.uid);
    }
    if (family.adultUids.every((u) => u == actor.uid)) {
      await _ref(family.id).delete();
    }
    // Con otros adultos, `cleanupOnUserDeleted` la entrega al siguiente.
  }

  @override
  Future<Family?> adoptOrphanChildren(AppUser owner) async {
    final owned = await _db
        .collection(FirestorePaths.children)
        .where('memberUids', arrayContains: owner.uid)
        .where('ownerUid', isEqualTo: owner.uid)
        .get();
    final orphans = owned.docs
        .where((d) => d.data()['familyId'] == null)
        .toList();
    if (orphans.isEmpty) return null;
    final mine = await _db
        .collection(FirestorePaths.families)
        .where('adultUids', arrayContains: owner.uid)
        .where('ownerUid', isEqualTo: owner.uid)
        .limit(1)
        .get();
    final family = mine.docs.isNotEmpty
        ? Family.fromMap(mine.docs.first.data(), id: mine.docs.first.id)
        : await createFamily(owner: owner, name: defaultFamilyName(owner));
    final batch = _db.batch();
    for (final doc in orphans) {
      batch.update(doc.reference, {'familyId': family.id});
    }
    await batch.commit();
    return family;
  }
}
