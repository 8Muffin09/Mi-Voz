import '../core/utils/json_utils.dart';
import 'app_user.dart';

/// Familia: adultos responsables (padres, madres, tutores) y sus niños.
///
/// Un niño pertenece a una sola familia (`ChildProfile.familyId`). Los
/// adultos de la familia tienen acceso a todos sus niños. Solo el
/// administrador ([ownerUid]) cambia el nombre o retira adultos.
class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.adultUids,
    this.adultNames = const {},
    this.adultRoles = const {},
    this.createdAt,
  });

  final String id;
  final String name;
  final String ownerUid;
  final List<String> adultUids;

  /// Nombre visible de cada adulto (`uid → nombre`), para mostrarlo sin
  /// leer perfiles privados de otras cuentas.
  final Map<String, String> adultNames;

  /// Relación de cada adulto con los niños (madre, padre, tutor…).
  final Map<String, AdultRole> adultRoles;
  final DateTime? createdAt;

  bool isAdult(String? uid) => uid != null && adultUids.contains(uid);
  bool isOwner(String? uid) => uid != null && uid == ownerUid && isAdult(uid);

  String adultName(String uid) => adultNames[uid] ?? 'Adulto';
  AdultRole adultRole(String uid) => adultRoles[uid] ?? AdultRole.tutor;

  Family copyWith({
    String? name,
    List<String>? adultUids,
    Map<String, String>? adultNames,
    Map<String, AdultRole>? adultRoles,
  }) => Family(
    id: id,
    name: name ?? this.name,
    ownerUid: ownerUid,
    adultUids: adultUids ?? this.adultUids,
    adultNames: adultNames ?? this.adultNames,
    adultRoles: adultRoles ?? this.adultRoles,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'ownerUid': ownerUid,
    'adultUids': adultUids,
    'adultNames': adultNames,
    'adultRoles': {for (final e in adultRoles.entries) e.key: e.value.name},
    'createdAt': createdAt,
  };

  factory Family.fromMap(Map<String, dynamic> map, {String? id}) => Family(
    id: id ?? readString(map['id']) ?? '',
    name: readString(map['name']) ?? 'Familia',
    ownerUid: readString(map['ownerUid']) ?? '',
    adultUids: readStringList(map['adultUids']),
    adultNames: {
      for (final e in readMap(map['adultNames']).entries)
        if (e.value is String) e.key: e.value as String,
    },
    adultRoles: {
      for (final e in readMap(map['adultRoles']).entries)
        e.key: enumByName(AdultRole.values, e.value, AdultRole.tutor),
    },
    createdAt: parseDate(map['createdAt']),
  );
}
