import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/permissions/permissions.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';
import 'classes_repository.dart';

/// Clases en Firestore (`classes/{id}`). Al tocar `classIds` de un niño se
/// escribe también `lastClassChange` con la clase afectada: las reglas lo
/// usan para comprobar que el docente administra esa clase.
class FirebaseClassesRepository implements ClassesRepository {
  FirebaseClassesRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _ref(String id) =>
      _db.doc(FirestorePaths.classroom(id));

  DocumentReference<Map<String, dynamic>> _child(String id) =>
      _db.doc(FirestorePaths.child(id));

  @override
  Stream<List<Classroom>> watchClassesForTeacher(String uid) => _db
      .collection(FirestorePaths.classes)
      .where('teacherUids', arrayContains: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => Classroom.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => a.name.compareTo(b.name)),
      );

  @override
  Stream<Classroom?> watchClass(String classId) => _ref(classId)
      .snapshots()
      .map((s) {
        final data = s.data();
        return data == null ? null : Classroom.fromMap(data, id: s.id);
      })
      .handleError(
        (Object _) {},
        test: (e) => e is FirebaseException && e.code == 'permission-denied',
      );

  @override
  Future<Classroom> createClass({
    required AppUser owner,
    required String name,
    String description = '',
  }) async {
    final classroom = Classroom(
      id: newId(),
      name: name.trim(),
      description: description.trim(),
      ownerUid: owner.uid,
      teacherUids: [owner.uid],
      teacherNames: {owner.uid: owner.displayName},
    );
    await _ref(classroom.id)
        .set({...classroom.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    return classroom;
  }

  void _requireOwner(Classroom classroom, AppUser actor) {
    if (!Permissions.canManageClass(classroom, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo el docente que administra la clase puede hacer este cambio.',
      );
    }
  }

  @override
  Future<void> updateClass(
    Classroom classroom, {
    required String name,
    required String description,
    required AppUser actor,
  }) async {
    _requireOwner(classroom, actor);
    await _ref(classroom.id)
        .update({'name': name.trim(), 'description': description.trim()});
  }

  @override
  Future<void> setArchived(
    Classroom classroom,
    bool archived, {
    required AppUser actor,
  }) async {
    _requireOwner(classroom, actor);
    await _ref(classroom.id).update({'archived': archived});
  }

  @override
  Future<void> releaseForAccountDeletion(
    Classroom classroom, {
    required AppUser actor,
  }) async {
    _requireOwner(classroom, actor);
    for (final id in classroom.studentIds) {
      final DocumentSnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _child(id).get();
      } on FirebaseException {
        continue; // Ya no tiene acceso a ese niño.
      }
      final data = snap.data();
      if (data == null) continue;
      await removeStudent(
        classroom,
        ChildProfile.fromMap(data, id: snap.id),
        actor: actor,
      );
    }
    // Las reglas no permiten borrar clases desde la app: queda archivada y
    // la Cloud Function `cleanupOnUserDeleted` la borra.
    await _ref(classroom.id).update({'archived': true});
  }

  @override
  Future<void> addAuthorizedStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  }) async {
    if (!Permissions.canAddAuthorizedStudent(classroom, child, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo puedes agregar alumnos que ya te autorizaron. Los alumnos '
        'nuevos se incorporan con una invitación.',
      );
    }
    final batch = _db.batch()
      ..update(_ref(classroom.id), {
        'studentIds': FieldValue.arrayUnion([child.id]),
      })
      ..update(_child(child.id), {
        'classIds': FieldValue.arrayUnion([classroom.id]),
        'lastClassChange': classroom.id,
      })
      ..update(
        _child(child.id)
            .collection(FirestorePaths.caregiverLinks)
            .doc(actor.uid),
        {
          'classIds': FieldValue.arrayUnion([classroom.id]),
        },
      );
    await batch.commit();
  }

  @override
  Future<void> removeStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  }) async {
    _requireOwner(classroom, actor);
    final childUpdate = <String, dynamic>{
      'classIds': FieldValue.arrayRemove([classroom.id]),
      'lastClassChange': classroom.id,
    };
    final batch = _db.batch()
      ..update(_ref(classroom.id), {
        'studentIds': FieldValue.arrayRemove([child.id]),
      });
    final losing = <String>[];
    for (final teacher in classroom.teacherUids) {
      final linkRef = _child(child.id)
          .collection(FirestorePaths.caregiverLinks)
          .doc(teacher);
      final snap = await linkRef.get();
      final data = snap.data();
      if (data == null) continue;
      final link = CaregiverLink.fromMap(data);
      final remaining = link.classIds.where((c) => c != classroom.id);
      if (link.source == LinkSource.classroom && remaining.isEmpty) {
        losing.add(teacher);
        batch.delete(linkRef);
      } else {
        batch.update(linkRef, {
          'classIds': FieldValue.arrayRemove([classroom.id]),
        });
      }
    }
    if (losing.isNotEmpty) {
      childUpdate['memberUids'] = FieldValue.arrayRemove(losing);
      if (losing.contains(child.responsibleUid)) {
        childUpdate['responsibleUid'] = null;
        childUpdate['responsibleName'] = null;
        childUpdate['responsibleSince'] = null;
      }
    }
    batch.update(_child(child.id), childUpdate);
    await batch.commit();
  }
}
