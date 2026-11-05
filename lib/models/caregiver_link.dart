import '../core/utils/json_utils.dart';
import 'app_user.dart';

/// Nivel de permiso de un adulto sobre un perfil infantil.
enum LinkPermission {
  /// Creó el perfil: administra vínculos, puede eliminar el perfil.
  owner('Administrador'),

  /// Adulto autorizado: recibe solicitudes y edita el apoyo del niño.
  caregiver('Autorizado');

  const LinkPermission(this.label);
  final String label;
}

/// De dónde viene el acceso de un adulto a un niño.
enum LinkSource {
  /// Adulto de la familia del niño.
  family('Familia'),

  /// Docente de una clase a la que está vinculado el niño.
  classroom('Clase'),

  /// Vínculo individual con código (anterior a familias y clases).
  direct('Vínculo directo');

  const LinkSource(this.label);
  final String label;
}

/// Vínculo verificable entre un adulto y un niño.
class CaregiverLink {
  const CaregiverLink({
    required this.childId,
    required this.adultUid,
    required this.adultName,
    required this.adultEmail,
    required this.role,
    required this.permission,
    this.source = LinkSource.direct,
    this.classIds = const [],
    this.receivesRequests = true,
    this.canViewPassport = true,
    this.invitationCode,
    this.invitedByUid,
    this.createdAt,
  });

  final String childId;
  final String adultUid;
  final String adultName;
  final String adultEmail;
  final AdultRole role;
  final LinkPermission permission;
  final LinkSource source;

  /// Clases que dan este acceso (si [source] es `classroom`).
  final List<String> classIds;

  /// Puede recibir las solicitudes del niño (lo decide la familia).
  final bool receivesRequests;

  /// Puede consultar el Pasaporte Sensorial (lo decide la familia).
  final bool canViewPassport;
  final String? invitationCode;
  final String? invitedByUid;
  final DateTime? createdAt;

  String get id => '${childId}_$adultUid';
  bool get isOwner => permission == LinkPermission.owner;

  CaregiverLink copyWith({
    String? adultName,
    LinkSource? source,
    List<String>? classIds,
    bool? receivesRequests,
    bool? canViewPassport,
  }) => CaregiverLink(
    childId: childId,
    adultUid: adultUid,
    adultName: adultName ?? this.adultName,
    adultEmail: adultEmail,
    role: role,
    permission: permission,
    source: source ?? this.source,
    classIds: classIds ?? this.classIds,
    receivesRequests: receivesRequests ?? this.receivesRequests,
    canViewPassport: canViewPassport ?? this.canViewPassport,
    invitationCode: invitationCode,
    invitedByUid: invitedByUid,
    createdAt: createdAt,
  );

  Map<String, dynamic> toMap() => {
    'childId': childId,
    'adultUid': adultUid,
    'adultName': adultName,
    'adultEmail': adultEmail,
    'role': role.name,
    'permission': permission.name,
    'source': source.name,
    'classIds': classIds,
    'receivesRequests': receivesRequests,
    'canViewPassport': canViewPassport,
    'invitationCode': invitationCode,
    'invitedByUid': invitedByUid,
    'createdAt': createdAt,
  };

  factory CaregiverLink.fromMap(Map<String, dynamic> map) => CaregiverLink(
    childId: readString(map['childId']) ?? '',
    adultUid: readString(map['adultUid']) ?? '',
    adultName: readString(map['adultName']) ?? 'Adulto',
    adultEmail: readString(map['adultEmail']) ?? '',
    role: enumByName(AdultRole.values, map['role'], AdultRole.tutor),
    permission: enumByName(
      LinkPermission.values,
      map['permission'],
      LinkPermission.caregiver,
    ),
    source: enumByName(LinkSource.values, map['source'], LinkSource.direct),
    classIds: readStringList(map['classIds']),
    receivesRequests: readBool(map['receivesRequests'], true),
    canViewPassport: readBool(map['canViewPassport'], true),
    invitationCode: readString(map['invitationCode']),
    invitedByUid: readString(map['invitedByUid']),
    createdAt: parseDate(map['createdAt']),
  );
}

/// Invitación de un solo uso y con caducidad para vincular a otro adulto.
class Invitation {
  const Invitation({
    required this.code,
    required this.childId,
    required this.childName,
    required this.role,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
    this.usedByUid,
    this.usedAt,
  });

  static const validity = Duration(hours: 48);

  final String code;
  final String childId;
  final String childName;
  final AdultRole role;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? usedByUid;
  final DateTime? usedAt;

  bool get isUsed => usedByUid != null;
  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);
  bool isValid([DateTime? now]) => !isUsed && !isExpired(now);

  Map<String, dynamic> toMap() => {
    'code': code,
    'childId': childId,
    'childName': childName,
    'role': role.name,
    'createdBy': createdByUid,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'usedBy': usedByUid,
    'usedAt': usedAt,
  };

  factory Invitation.fromMap(Map<String, dynamic> map) => Invitation(
    code: readString(map['code']) ?? '',
    childId: readString(map['childId']) ?? '',
    childName: readString(map['childName']) ?? '',
    role: enumByName(AdultRole.values, map['role'], AdultRole.tutor),
    createdByUid: readString(map['createdBy']) ?? '',
    createdByName: readString(map['createdByName']) ?? '',
    createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    expiresAt: parseDate(map['expiresAt']) ?? DateTime.now(),
    usedByUid: readString(map['usedBy']),
    usedAt: parseDate(map['usedAt']),
  );
}
