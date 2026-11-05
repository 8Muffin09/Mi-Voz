import '../core/utils/json_utils.dart';

/// Clase o grupo escolar.
///
/// El docente propietario ([ownerUid]) la administra. Los alumnos son
/// perfiles infantiles existentes ([studentIds]): un mismo niño puede estar
/// en su familia y en varias clases sin duplicar sus datos.
class Classroom {
  const Classroom({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.teacherUids,
    this.description = '',
    this.studentIds = const [],
    this.teacherNames = const {},
    this.archived = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String description;
  final String ownerUid;
  final List<String> teacherUids;
  final List<String> studentIds;

  /// Nombre visible de cada docente (`uid → nombre`).
  final Map<String, String> teacherNames;

  /// Archivada: se conserva su historial, pero no aparece entre las activas.
  final bool archived;
  final DateTime? createdAt;

  bool isTeacher(String? uid) => uid != null && teacherUids.contains(uid);
  bool isOwner(String? uid) => uid != null && uid == ownerUid && isTeacher(uid);

  Classroom copyWith({
    String? name,
    String? description,
    List<String>? studentIds,
    bool? archived,
  }) => Classroom(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    ownerUid: ownerUid,
    teacherUids: teacherUids,
    studentIds: studentIds ?? this.studentIds,
    teacherNames: teacherNames,
    archived: archived ?? this.archived,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'ownerUid': ownerUid,
    'teacherUids': teacherUids,
    'studentIds': studentIds,
    'teacherNames': teacherNames,
    'archived': archived,
    'createdAt': createdAt,
  };

  factory Classroom.fromMap(Map<String, dynamic> map, {String? id}) =>
      Classroom(
        id: id ?? readString(map['id']) ?? '',
        name: readString(map['name']) ?? 'Clase',
        description: readString(map['description']) ?? '',
        ownerUid: readString(map['ownerUid']) ?? '',
        teacherUids: readStringList(map['teacherUids']),
        studentIds: readStringList(map['studentIds']),
        teacherNames: {
          for (final e in readMap(map['teacherNames']).entries)
            if (e.value is String) e.key: e.value as String,
        },
        archived: readBool(map['archived'], false),
        createdAt: parseDate(map['createdAt']),
      );
}
