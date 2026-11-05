import '../core/utils/json_utils.dart';
import '../core/visuals/avatar_catalog.dart';

/// Relación del adulto con el niño.
enum AdultRole {
  madre('Madre'),
  padre('Padre'),
  tutor('Tutor/a'),
  docente('Docente'),
  cuidador('Cuidador/a');

  const AdultRole(this.label);
  final String label;

  /// Relaciones que se ofrecen al registrarse como familia.
  static const familyRoles = [madre, padre, tutor];

  bool get isFamily => this != docente;
}

/// Experiencia con la que un adulto usa Mi Voz. Una misma cuenta puede tener
/// las dos (por ejemplo, una madre que también es maestra) sin duplicarse.
enum UserExperience {
  guardian('Padre, madre o tutor', 'Familia'),
  teacher('Docente', 'Docente');

  const UserExperience(this.label, this.shortLabel);
  final String label;
  final String shortLabel;
}

/// Cuenta de un adulto (padre, madre, tutor, docente o cuidador).
class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.lastName,
    this.avatar,
    this.avatarColor,
    this.photo,
    this.schoolName,
    this.groupName,
    this.teacherTitle,
    this.experiences = const {},
    this.createdAt,
    this.emailVerified = true,
  });

  final String uid;
  final String email;

  /// Nombre completo visible para los otros adultos ("María López").
  final String displayName;
  final AdultRole role;
  final String? lastName;

  /// Identificador del avatar ilustrado (`AvatarCatalog`). Los perfiles
  /// anteriores guardaban un emoji, que el catálogo traduce. `null` = avatar
  /// neutro (ningún rol impone una apariencia).
  final String? avatar;
  final int? avatarColor;

  /// Fotografía opcional (ver `PhotoStore`): `file:` local o `storage:`.
  final String? photo;

  // Datos opcionales del perfil docente.
  final String? schoolName;
  final String? groupName;

  /// Cómo lo llaman sus alumnos: "Maestra", "Maestro", "Profe"...
  final String? teacherTitle;

  /// Experiencias autorizadas en esta cuenta. Vacío = deducir del rol.
  final Set<UserExperience> experiences;
  final DateTime? createdAt;

  /// Estado de verificación del correo (lo informa la autenticación; no se
  /// guarda en la base de datos).
  final bool emailVerified;

  static const colorOptions = [
    0xFFDCEBFF,
    0xFFDFF3E8,
    0xFFFFEBD6,
    0xFFFFF6CC,
    0xFFFFE1E6,
    0xFFEADFFF,
  ];

  static const teacherTitles = ['Maestra', 'Maestro', 'Profe', 'Miss'];

  /// Primer nombre para el saludo ("¡Hola, María!").
  String get firstName {
    final full = displayName.trim();
    final last = lastName?.trim() ?? '';
    final given = last.isNotEmpty && full.endsWith(' $last')
        ? full.substring(0, full.length - last.length - 1)
        : full;
    return given.split(' ').first;
  }

  /// Valor del avatar para mostrar (`AvatarCatalog.resolve`).
  String get avatarRef => avatar ?? AvatarCatalog.defaultAdult;
  int get avatarColorValue => avatarColor ?? colorOptions.first;

  /// Experiencias efectivas (si no se guardaron, según el rol).
  Set<UserExperience> get effectiveExperiences => experiences.isNotEmpty
      ? experiences
      : {role.isFamily ? UserExperience.guardian : UserExperience.teacher};

  bool get isGuardian => effectiveExperiences.contains(UserExperience.guardian);
  bool get isTeacher => effectiveExperiences.contains(UserExperience.teacher);
  bool hasExperience(UserExperience e) => effectiveExperiences.contains(e);

  /// "Maestra Ana" en la experiencia docente.
  String get teacherGreetingName {
    final title = teacherTitle?.trim() ?? '';
    return title.isEmpty ? firstName : '$title $firstName';
  }

  AppUser copyWith({
    String? displayName,
    AdultRole? role,
    String? Function()? lastName,
    String? Function()? avatar,
    int? Function()? avatarColor,
    String? Function()? photo,
    String? Function()? schoolName,
    String? Function()? groupName,
    String? Function()? teacherTitle,
    Set<UserExperience>? experiences,
    bool? emailVerified,
  }) => AppUser(
    uid: uid,
    email: email,
    displayName: displayName ?? this.displayName,
    role: role ?? this.role,
    lastName: lastName != null ? lastName() : this.lastName,
    avatar: avatar != null ? avatar() : this.avatar,
    avatarColor: avatarColor != null ? avatarColor() : this.avatarColor,
    photo: photo != null ? photo() : this.photo,
    schoolName: schoolName != null ? schoolName() : this.schoolName,
    groupName: groupName != null ? groupName() : this.groupName,
    teacherTitle: teacherTitle != null ? teacherTitle() : this.teacherTitle,
    experiences: experiences ?? this.experiences,
    createdAt: createdAt,
    emailVerified: emailVerified ?? this.emailVerified,
  );

  /// Campos editables del perfil (lo que el propio adulto puede escribir).
  Map<String, dynamic> profileMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'lastName': lastName,
    'avatar': avatar,
    'avatarColor': avatarColor,
    'photo': photo,
    'schoolName': schoolName,
    'groupName': groupName,
    'teacherTitle': teacherTitle,
    'experiences': [for (final e in effectiveExperiences) e.name],
  };

  Map<String, dynamic> toMap() => {...profileMap(), 'createdAt': createdAt};

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    uid: readString(map['uid']) ?? '',
    email: readString(map['email']) ?? '',
    displayName: readString(map['displayName']) ?? 'Adulto',
    role: enumByName(AdultRole.values, map['role'], AdultRole.tutor),
    lastName: readString(map['lastName']),
    avatar: readString(map['avatar']),
    avatarColor: map['avatarColor'] is num
        ? (map['avatarColor'] as num).toInt()
        : null,
    photo: readString(map['photo']),
    schoolName: readString(map['schoolName']),
    groupName: readString(map['groupName']),
    teacherTitle: readString(map['teacherTitle']),
    experiences: {
      for (final name in readStringList(map['experiences']))
        if (UserExperience.values.any((e) => e.name == name))
          UserExperience.values.byName(name),
    },
    createdAt: parseDate(map['createdAt']),
  );
}
