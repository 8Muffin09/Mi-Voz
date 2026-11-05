import '../../../core/demo/demo_database.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';
import 'classes_repository.dart';

/// Clases en la base local. Aplica las mismas reglas que Firestore.
class DemoClassesRepository implements ClassesRepository {
  DemoClassesRepository(this._db);

  final DemoDatabase _db;

  Classroom? _class(String id) {
    final row = _db.get(DemoDatabase.classes, id);
    return row == null ? null : Classroom.fromMap(row);
  }

  Classroom _require(String id) =>
      _class(id) ?? (throw const AppException('La clase ya no existe.'));

  ChildProfile _child(String id) {
    final row = _db.get(DemoDatabase.children, id);
    if (row == null) throw const AppException('El perfil ya no existe.');
    return ChildProfile.fromMap(row);
  }

  @override
  Stream<List<Classroom>> watchClassesForTeacher(String uid) => _db.watch(
    () =>
        _db
            .where(
              DemoDatabase.classes,
              (r) => (r['teacherUids'] as List?)?.contains(uid) ?? false,
            )
            .map(Classroom.fromMap)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );

  @override
  Stream<Classroom?> watchClass(String classId) => _db.watch(() {
    final classroom = _class(classId);
    return classroom != null && classroom.isTeacher(_db.sessionUid)
        ? classroom
        : null;
  });

  @override
  Future<Classroom> createClass({
    required AppUser owner,
    required String name,
    String description = '',
  }) async {
    if (owner.uid != _db.sessionUid) throw const PermissionDeniedException();
    final classroom = Classroom(
      id: newId(),
      name: name.trim(),
      description: description.trim(),
      ownerUid: owner.uid,
      teacherUids: [owner.uid],
      teacherNames: {owner.uid: owner.displayName},
      createdAt: DateTime.now(),
    );
    _db.put(DemoDatabase.classes, classroom.id, classroom.toMap());
    _db.commit();
    return classroom;
  }

  void _requireOwner(Classroom classroom, AppUser actor) {
    if (!Permissions.canManageClass(classroom, actor.uid) ||
        actor.uid != _db.sessionUid) {
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
    final current = _require(classroom.id);
    _requireOwner(current, actor);
    _db.put(
      DemoDatabase.classes,
      current.id,
      current
          .copyWith(name: name.trim(), description: description.trim())
          .toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> setArchived(
    Classroom classroom,
    bool archived, {
    required AppUser actor,
  }) async {
    final current = _require(classroom.id);
    _requireOwner(current, actor);
    _db.put(
      DemoDatabase.classes,
      current.id,
      current.copyWith(archived: archived).toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> addAuthorizedStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  }) async {
    final current = _require(classroom.id);
    final student = _child(child.id);
    if (!Permissions.canAddAuthorizedStudent(current, student, actor.uid)) {
      throw const PermissionDeniedException(
        'Solo puedes agregar alumnos que ya te autorizaron. Los alumnos '
        'nuevos se incorporan con una invitación.',
      );
    }
    if (current.studentIds.contains(student.id)) return;
    _db.put(
      DemoDatabase.classes,
      current.id,
      current.copyWith(studentIds: [...current.studentIds, student.id]).toMap(),
    );
    _db.put(
      DemoDatabase.children,
      student.id,
      student
          .copyWith(classIds: {...student.classIds, current.id}.toList())
          .toMap(),
    );
    final linkId = '${student.id}_${actor.uid}';
    final linkRow = _db.get(DemoDatabase.links, linkId);
    if (linkRow != null) {
      final link = CaregiverLink.fromMap(linkRow);
      _db.put(
        DemoDatabase.links,
        linkId,
        link
            .copyWith(classIds: {...link.classIds, current.id}.toList())
            .toMap(),
      );
    }
    _db.commit();
  }

  @override
  Future<void> releaseForAccountDeletion(
    Classroom classroom, {
    required AppUser actor,
  }) async {
    final current = _class(classroom.id);
    if (current == null) return;
    _requireOwner(current, actor);
    for (final studentId in current.studentIds) {
      if (_db.get(DemoDatabase.children, studentId) == null) continue;
      await removeStudent(
        _require(current.id),
        _child(studentId),
        actor: actor,
      );
    }
    _db.delete(DemoDatabase.classes, current.id);
    for (final row in _db.where(
      DemoDatabase.groupInvitations,
      (r) => r['targetId'] == current.id,
    )) {
      _db.delete(DemoDatabase.groupInvitations, row['code'] as String);
    }
    _db.commit();
  }

  @override
  Future<void> removeStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  }) async {
    final current = _require(classroom.id);
    _requireOwner(current, actor);
    final student = _child(child.id);
    _db.put(
      DemoDatabase.classes,
      current.id,
      current
          .copyWith(
            studentIds: current.studentIds
                .where((s) => s != student.id)
                .toList(),
          )
          .toMap(),
    );
    var updated = student.copyWith(
      classIds: student.classIds.where((c) => c != current.id).toList(),
    );
    // Los docentes de la clase pierden el acceso que les daba esta clase.
    for (final teacher in current.teacherUids) {
      final linkId = '${student.id}_$teacher';
      final linkRow = _db.get(DemoDatabase.links, linkId);
      if (linkRow == null) continue;
      final link = CaregiverLink.fromMap(linkRow);
      final remaining = link.classIds.where((c) => c != current.id).toList();
      if (link.source == LinkSource.classroom && remaining.isEmpty) {
        final wasResponsible = updated.responsibleUid == teacher;
        updated = updated.copyWith(
          memberUids: updated.memberUids.where((u) => u != teacher).toList(),
          responsibleUid: wasResponsible ? () => null : null,
          responsibleName: wasResponsible ? () => null : null,
          responsibleSince: wasResponsible ? () => null : null,
        );
        _db.delete(DemoDatabase.links, linkId);
      } else {
        _db.put(
          DemoDatabase.links,
          linkId,
          link.copyWith(classIds: remaining).toMap(),
        );
      }
    }
    _db.put(DemoDatabase.children, student.id, updated.toMap());
    _db.commit();
  }
}
