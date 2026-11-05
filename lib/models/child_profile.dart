import '../core/utils/json_utils.dart';
import '../core/visuals/avatar_catalog.dart';
import 'sensory_settings.dart';

/// Concordancia gramatical para las frases ("cansado" / "cansada").
enum GrammaticalGender {
  masculine('Masculino (cansado)'),
  feminine('Femenino (cansada)');

  const GrammaticalGender(this.label);
  final String label;
}

/// A quién avisar cuando nadie marcó "Estoy acompañando" (o cuando quien
/// acompaña no tiene dispositivos para recibir avisos). La decide el
/// administrador del perfil; nunca se avisa a todos sin que él lo elija.
enum NoCompanionRule {
  admin(
    'Solo al administrador del perfil',
    'Le llega el aviso a quien administra el perfil.',
  ),
  chosen(
    'A los adultos que yo elija',
    'Le llega el aviso solo a los adultos marcados.',
  ),
  all(
    'A todos los adultos autorizados',
    'Le llega el aviso a cada adulto que recibe solicitudes.',
  );

  const NoCompanionRule(this.label, this.description);
  final String label;
  final String description;
}

/// Perfil de un niño. Los adultos con acceso están en [memberUids];
/// el adulto que lo creó ([ownerUid]) administra los vínculos.
class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.name,
    required this.avatar,
    required this.avatarColor,
    required this.gender,
    required this.ownerUid,
    required this.memberUids,
    this.familyId,
    this.classIds = const [],
    this.lastName,
    this.photo,
    this.responsibleUid,
    this.responsibleName,
    this.responsibleSince,
    this.noCompanionRule = NoCompanionRule.admin,
    this.backupUids = const [],
    this.settings = const SensorySettings(),
    this.createdAt,
  });

  final String id;

  /// Nombre o nombre preferido (lo único obligatorio).
  final String name;
  final String? lastName;

  /// Identificador del avatar ilustrado (`AvatarCatalog`; los perfiles
  /// anteriores guardaban un emoji, que el catálogo traduce). La foto es
  /// opcional: no es necesario subir fotografías reales de los niños.
  final String avatar;

  /// Fotografía opcional (ver `PhotoStore`): `file:` local o `storage:`.
  final String? photo;
  final int avatarColor;
  final GrammaticalGender gender;
  final String ownerUid;

  /// Lista de acceso: adultos que pueden ver y atender al niño (familia,
  /// docentes de sus clases y vínculos directos). Las reglas la verifican.
  final List<String> memberUids;

  /// Familia a la que pertenece (una sola).
  final String? familyId;

  /// Clases a las que está vinculado (puede ser más de una).
  final List<String> classIds;

  /// Adulto que acompaña al niño en este momento.
  final String? responsibleUid;
  final String? responsibleName;
  final DateTime? responsibleSince;

  /// Destinatarios cuando nadie acompaña (ver [NoCompanionRule]).
  final NoCompanionRule noCompanionRule;

  /// Adultos elegidos para [NoCompanionRule.chosen].
  final List<String> backupUids;
  final SensorySettings settings;
  final DateTime? createdAt;

  static const colorOptions = [
    0xFFB8E0D2,
    0xFFA0C4FF,
    0xFFFFD6A5,
    0xFFFDFFB6,
    0xFFFFC6C6,
    0xFFD7C4F0,
    0xFFC1E1C1,
    0xFFFFE5EC,
  ];

  String get fullName {
    final last = lastName?.trim() ?? '';
    return last.isEmpty ? name : '$name $last';
  }

  bool get hasResponsible =>
      responsibleUid != null && memberUids.contains(responsibleUid);

  ChildProfile copyWith({
    String? name,
    String? Function()? lastName,
    String? Function()? photo,
    String? avatar,
    int? avatarColor,
    GrammaticalGender? gender,
    List<String>? memberUids,
    String? Function()? familyId,
    List<String>? classIds,
    SensorySettings? settings,
    String? Function()? responsibleUid,
    String? Function()? responsibleName,
    DateTime? Function()? responsibleSince,
    NoCompanionRule? noCompanionRule,
    List<String>? backupUids,
  }) => ChildProfile(
    id: id,
    name: name ?? this.name,
    lastName: lastName != null ? lastName() : this.lastName,
    photo: photo != null ? photo() : this.photo,
    avatar: avatar ?? this.avatar,
    avatarColor: avatarColor ?? this.avatarColor,
    gender: gender ?? this.gender,
    ownerUid: ownerUid,
    memberUids: memberUids ?? this.memberUids,
    familyId: familyId != null ? familyId() : this.familyId,
    classIds: classIds ?? this.classIds,
    responsibleUid: responsibleUid != null
        ? responsibleUid()
        : this.responsibleUid,
    responsibleName: responsibleName != null
        ? responsibleName()
        : this.responsibleName,
    responsibleSince: responsibleSince != null
        ? responsibleSince()
        : this.responsibleSince,
    noCompanionRule: noCompanionRule ?? this.noCompanionRule,
    backupUids: backupUids ?? this.backupUids,
    settings: settings ?? this.settings,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'lastName': lastName,
    'photo': photo,
    'avatar': avatar,
    'avatarColor': avatarColor,
    'gender': gender.name,
    'ownerUid': ownerUid,
    'memberUids': memberUids,
    'familyId': familyId,
    'classIds': classIds,
    'responsibleUid': responsibleUid,
    'responsibleName': responsibleName,
    'responsibleSince': responsibleSince,
    'noCompanionRule': noCompanionRule.name,
    'backupUids': backupUids,
    'settings': settings.toMap(),
    'createdAt': createdAt,
  };

  factory ChildProfile.fromMap(Map<String, dynamic> map, {String? id}) =>
      ChildProfile(
        id: id ?? readString(map['id']) ?? '',
        name: readString(map['name']) ?? 'Niño',
        lastName: readString(map['lastName']),
        photo: readString(map['photo']),
        avatar: readString(map['avatar']) ?? AvatarCatalog.defaultChild,
        avatarColor: readInt(map['avatarColor'], colorOptions.first),
        gender: enumByName(
          GrammaticalGender.values,
          map['gender'],
          GrammaticalGender.masculine,
        ),
        ownerUid: readString(map['ownerUid']) ?? '',
        memberUids: readStringList(map['memberUids']),
        familyId: readString(map['familyId']),
        classIds: readStringList(map['classIds']),
        responsibleUid: readString(map['responsibleUid']),
        responsibleName: readString(map['responsibleName']),
        responsibleSince: parseDate(map['responsibleSince']),
        noCompanionRule: enumByName(
          NoCompanionRule.values,
          map['noCompanionRule'],
          NoCompanionRule.admin,
        ),
        backupUids: readStringList(map['backupUids']),
        settings: SensorySettings.fromMap(readMap(map['settings'])),
        createdAt: parseDate(map['createdAt']),
      );
}
