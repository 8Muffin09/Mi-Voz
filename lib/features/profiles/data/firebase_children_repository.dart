import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../features/pictograms/data/pictogram_catalog.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/family.dart';
import '../../../models/sensory_settings.dart';
import 'children_repository.dart';

/// Perfiles y vínculos en Firestore. La autorización real la aplican las
/// reglas de `firebase/firestore.rules`; aquí se valida antes para dar
/// mensajes claros.
class FirebaseChildrenRepository implements ChildrenRepository {
  FirebaseChildrenRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  DocumentReference<Map<String, dynamic>> _childRef(String id) =>
      _db.doc(FirestorePaths.child(id));

  CollectionReference<Map<String, dynamic>> _sub(String childId, String sub) =>
      _db.collection(FirestorePaths.childSub(childId, sub));

  @override
  Stream<List<ChildProfile>> watchChildrenForAdult(String uid) => _db
      .collection(FirestorePaths.children)
      .where('memberUids', arrayContains: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => ChildProfile.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Stream<ChildProfile?> watchChild(String childId) => _childRef(childId)
      .snapshots()
      .map((s) {
        final data = s.data();
        return data == null ? null : ChildProfile.fromMap(data, id: s.id);
      })
      .transform(
        StreamTransformer<ChildProfile?, ChildProfile?>.fromHandlers(
          handleError: (error, stack, sink) {
            // Si se revocó el acceso, el perfil deja de estar disponible.
            if (error is FirebaseException &&
                error.code == 'permission-denied') {
              sink.add(null);
            } else {
              sink.addError(error, stack);
            }
          },
        ),
      );

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
    Family? family;
    if (familyId != null) {
      final snap = await _db.doc(FirestorePaths.family(familyId)).get();
      final data = snap.data();
      family = data == null ? null : Family.fromMap(data, id: snap.id);
      if (family == null || !family.isAdult(owner.uid)) {
        throw const PermissionDeniedException(
          'Solo los adultos de la familia pueden crear sus perfiles.',
        );
      }
    }
    final childId = id ?? newId();
    final child = ChildProfile(
      id: childId,
      name: name.trim(),
      lastName: _clean(lastName),
      settings: settings,
      avatar: avatar,
      avatarColor: avatarColor,
      gender: gender,
      ownerUid: owner.uid,
      memberUids: family?.adultUids ?? [owner.uid],
      familyId: family?.id,
    );
    // Las reglas comprueban que memberUids coincide con la familia y que
    // cada vínculo corresponde a un adulto de esa familia.
    final batch = _db.batch()
      ..set(_childRef(childId), {
        ...child.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    for (final uid in child.memberUids) {
      final isOwner = uid == owner.uid;
      final link = CaregiverLink(
        childId: childId,
        adultUid: uid,
        adultName: isOwner ? owner.displayName : family!.adultName(uid),
        adultEmail: isOwner ? owner.email : '',
        role: isOwner ? owner.role : family!.adultRole(uid),
        permission: isOwner ? LinkPermission.owner : LinkPermission.caregiver,
        source: family == null ? LinkSource.direct : LinkSource.family,
      );
      batch.set(_sub(childId, FirestorePaths.caregiverLinks).doc(uid), {
        ...link.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    // Favoritos y frases iniciales (en un segundo lote: las reglas exigen
    // que el perfil ya exista para escribir en sus subcolecciones).
    final favorites = _sub(childId, FirestorePaths.favorites);
    final defaults = _db.batch();
    for (final picId in PictogramCatalog.defaultFavoriteIds) {
      defaults.set(favorites.doc('pic_$picId'), {
        'type': 'pictogram',
        'pictogramId': picId,
      });
    }
    for (final phrase in PictogramCatalog.defaultFrequentPhrases) {
      defaults.set(favorites.doc('phr_${phrase.id}'), {
        'type': 'phrase',
        ...phrase.toMap(),
      });
    }
    await defaults.commit();
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
  }) => _childRef(child.id).update({
    'name': name.trim(),
    'lastName': _clean(lastName),
    'photo': photo,
    'avatar': avatar,
    'avatarColor': avatarColor,
    'gender': gender.name,
  });

  @override
  Future<void> updateSettings(String childId, SensorySettings settings) =>
      _childRef(childId).update({'settings': settings.toMap()});

  @override
  Future<void> setResponsible({
    required ChildProfile child,
    required AppUser actor,
    required CaregiverLink? adult,
  }) async {
    if (!Permissions.canSetResponsible(
      child,
      actorUid: actor.uid,
      targetUid: adult?.adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    await _childRef(child.id).update({
      'responsibleUid': adult?.adultUid,
      'responsibleName': adult?.adultName,
      'responsibleSince': adult == null ? null : FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteChild(ChildProfile child, {required AppUser actor}) async {
    if (!Permissions.canDeleteChild(child, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil puede eliminarlo.',
      );
    }
    // Foto de perfil y fotos de pictogramas propios en Storage.
    if (child.photo != null) {
      try {
        await _storage.ref(FirestorePaths.childAvatar(child.id)).delete();
      } on FirebaseException {
        // La foto ya no existe.
      }
    }
    final pics = await _sub(child.id, FirestorePaths.pictograms).get();
    for (final doc in pics.docs) {
      if (doc.data()['imageUrl'] != null) {
        try {
          await _storage
              .ref(FirestorePaths.pictogramImage(child.id, doc.id))
              .delete();
        } on FirebaseException {
          // La foto ya no existe.
        }
      }
    }
    // Subcolecciones; los vínculos se borran al final mientras el perfil
    // aún existe (las reglas verifican al administrador con el perfil).
    for (final sub in [
      FirestorePaths.requests,
      FirestorePaths.passports,
      FirestorePaths.strategies,
      FirestorePaths.favorites,
      FirestorePaths.pictograms,
      FirestorePaths.caregiverLinks,
    ]) {
      await _deleteCollection(_sub(child.id, sub));
    }
    final invitations = await _db
        .collection(FirestorePaths.invitations)
        .where('childId', isEqualTo: child.id)
        .where('createdBy', isEqualTo: actor.uid)
        .get();
    for (final doc in invitations.docs) {
      await doc.reference.delete();
    }
    await _childRef(child.id).delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> ref,
  ) async {
    while (true) {
      final page = await ref.limit(400).get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  @override
  Stream<List<CaregiverLink>> watchLinks(String childId) =>
      _sub(childId, FirestorePaths.caregiverLinks).snapshots().map(
        (q) =>
            q.docs.map((d) => CaregiverLink.fromMap(d.data())).toList()
              ..sort((a, b) => a.permission.index - b.permission.index),
      );

  @override
  Stream<List<Invitation>> watchInvitations(ChildProfile child, String uid) =>
      _db
          .collection(FirestorePaths.invitations)
          .where('childId', isEqualTo: child.id)
          .where('createdBy', isEqualTo: uid)
          .snapshots()
          .map(
            (q) =>
                q.docs
                    .map((d) => Invitation.fromMap(d.data()))
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
    if (!Permissions.canManageCaregivers(child, createdBy.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil puede invitar adultos.',
      );
    }
    final now = DateTime.now();
    final invitation = Invitation(
      code: newInvitationCode(),
      childId: child.id,
      childName: child.name,
      role: role,
      createdByUid: createdBy.uid,
      createdByName: createdBy.displayName,
      createdAt: now,
      expiresAt: now.add(Invitation.validity),
    );
    await _db
        .collection(FirestorePaths.invitations)
        .doc(invitation.code)
        .set(invitation.toMap());
    return invitation;
  }

  @override
  Future<void> revokeInvitation(Invitation invitation) =>
      _db.collection(FirestorePaths.invitations).doc(invitation.code).delete();

  @override
  Future<CaregiverLink> acceptInvitation({
    required String code,
    required AppUser adult,
  }) async {
    final normalized = code.trim().toUpperCase();
    final invRef = _db.collection(FirestorePaths.invitations).doc(normalized);
    final DocumentSnapshot<Map<String, dynamic>> snap;
    try {
      snap = await invRef.get(const GetOptions(source: Source.server));
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable') throw const OfflineException();
      rethrow;
    }
    final data = snap.data();
    if (data == null) {
      throw const AppException(
        'El código no existe. Revisa que esté bien escrito.',
      );
    }
    final invitation = Invitation.fromMap(data);
    if (invitation.isUsed) {
      throw const AppException('Este código ya fue utilizado.');
    }
    if (invitation.isExpired()) {
      throw const AppException('Este código caducó. Pide uno nuevo.');
    }

    final link = CaregiverLink(
      childId: invitation.childId,
      adultUid: adult.uid,
      adultName: adult.displayName,
      adultEmail: adult.email,
      role: invitation.role,
      permission: LinkPermission.caregiver,
      invitationCode: invitation.code,
      invitedByUid: invitation.createdByUid,
    );
    // Las reglas verifican en este lote que el código es válido, que no se
    // ha usado, que no ha caducado y que el adulto solo se agrega a sí mismo.
    final batch = _db.batch()
      ..update(_childRef(invitation.childId), {
        'memberUids': FieldValue.arrayUnion([adult.uid]),
        'joinCode': invitation.code,
      })
      ..set(
        _sub(invitation.childId, FirestorePaths.caregiverLinks).doc(adult.uid),
        {...link.toMap(), 'createdAt': FieldValue.serverTimestamp()},
      )
      ..update(invRef, {
        'usedBy': adult.uid,
        'usedAt': FieldValue.serverTimestamp(),
      });
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const AppException(
          'No se pudo usar el código. Puede que ya estés vinculado o que el '
          'código haya caducado.',
        );
      }
      rethrow;
    }
    return link;
  }

  @override
  Future<void> removeLink({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
  }) async {
    if (!Permissions.canRemoveLink(
      child,
      actorUid: actor.uid,
      targetUid: adultUid,
    )) {
      throw const PermissionDeniedException();
    }
    final update = <String, dynamic>{
      'memberUids': FieldValue.arrayRemove([adultUid]),
    };
    // Solo el administrador puede cambiar la regla "si nadie acompaña"; si
    // otro adulto se desvincula, la función ignora a los no vinculados.
    if (child.ownerUid == actor.uid && child.backupUids.contains(adultUid)) {
      update['backupUids'] = FieldValue.arrayRemove([adultUid]);
    }
    if (child.responsibleUid == adultUid) {
      update['responsibleUid'] = null;
      update['responsibleName'] = null;
      update['responsibleSince'] = null;
    }
    final batch = _db.batch()
      ..delete(_sub(child.id, FirestorePaths.caregiverLinks).doc(adultUid))
      ..update(_childRef(child.id), update);
    await batch.commit();
  }

  @override
  Future<void> setLinkPermissions({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
    required bool receivesRequests,
    required bool canViewPassport,
  }) async {
    if (!Permissions.canManageLinkPermissions(child, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil cambia los permisos.',
      );
    }
    await _sub(child.id, FirestorePaths.caregiverLinks).doc(adultUid).update({
      'receivesRequests': receivesRequests,
      'canViewPassport': canViewPassport,
    });
  }

  @override
  Future<void> setNoCompanionRule({
    required ChildProfile child,
    required AppUser actor,
    required NoCompanionRule rule,
    required List<String> backupUids,
  }) async {
    if (!Permissions.canManageLinkPermissions(child, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el administrador del perfil decide a quién se avisa.',
      );
    }
    await _childRef(child.id).update({
      'noCompanionRule': rule.name,
      'backupUids': [
        for (final uid in backupUids)
          if (child.memberUids.contains(uid)) uid,
      ],
    });
  }

  @override
  Future<void> syncAdultName(AppUser adult, List<ChildProfile> children) async {
    // Las reglas permiten al adulto actualizar el nombre de su propio vínculo
    // y su nombre como responsable.
    final batch = _db.batch();
    for (final child in children) {
      if (!child.memberUids.contains(adult.uid)) continue;
      batch.update(
        _sub(child.id, FirestorePaths.caregiverLinks).doc(adult.uid),
        {'adultName': adult.displayName},
      );
      if (child.responsibleUid == adult.uid) {
        batch.update(_childRef(child.id), {
          'responsibleName': adult.displayName,
        });
      }
    }
    await batch.commit();
  }

  static String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
