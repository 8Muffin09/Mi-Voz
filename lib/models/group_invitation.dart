import '../core/utils/json_utils.dart';
import 'app_user.dart';

/// A qué se invita: a una familia (adultos responsables) o a una clase
/// (una familia vincula a un niño con la clase).
enum InviteTargetType {
  family('Familia'),
  classroom('Clase');

  const InviteTargetType(this.label);
  final String label;
}

/// Estado de una invitación, calculado en el servidor.
enum InvitationStatus {
  active('Vigente'),
  expired('Vencida'),
  revoked('Revocada'),
  exhausted('Ya utilizada');

  const InvitationStatus(this.label);
  final String label;
}

/// Invitación de familia o de clase con caducidad, revocación y límite de
/// usos. La crea, revoca y valida el servidor (Cloud Functions); el cliente
/// solo la muestra.
class GroupInvitation {
  const GroupInvitation({
    required this.code,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
    this.maxUses = 1,
    this.uses = 0,
    this.revoked = false,
    this.requiresApproval = true,
    this.role,
  });

  static const allowedValidity = [Duration(hours: 48), Duration(days: 7)];
  static const allowedMaxUses = [1, 5, 30];

  final String code;
  final InviteTargetType type;
  final String targetId;
  final String targetName;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int maxUses;
  final int uses;
  final bool revoked;

  /// El responsable (administrador de la familia o docente) aprueba cada
  /// incorporación antes de que se registre.
  final bool requiresApproval;

  /// Rol que tendrá el adulto que se une a una familia.
  final AdultRole? role;

  InvitationStatus status([DateTime? now]) {
    if (revoked) return InvitationStatus.revoked;
    if (uses >= maxUses) return InvitationStatus.exhausted;
    if (!(now ?? DateTime.now()).isBefore(expiresAt)) {
      return InvitationStatus.expired;
    }
    return InvitationStatus.active;
  }

  bool isActive([DateTime? now]) => status(now) == InvitationStatus.active;

  /// Contenido del QR: solo el código, sin datos personales.
  String get link => InvitationLink.build(code);

  GroupInvitation copyWith({int? uses, bool? revoked}) => GroupInvitation(
    code: code,
    type: type,
    targetId: targetId,
    targetName: targetName,
    createdByUid: createdByUid,
    createdByName: createdByName,
    createdAt: createdAt,
    expiresAt: expiresAt,
    maxUses: maxUses,
    uses: uses ?? this.uses,
    revoked: revoked ?? this.revoked,
    requiresApproval: requiresApproval,
    role: role,
  );

  Map<String, dynamic> toMap() => {
    'code': code,
    'type': type.name,
    'targetId': targetId,
    'targetName': targetName,
    'createdBy': createdByUid,
    'createdByName': createdByName,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
    'maxUses': maxUses,
    'uses': uses,
    'revoked': revoked,
    'requiresApproval': requiresApproval,
    'role': role?.name,
  };

  factory GroupInvitation.fromMap(Map<String, dynamic> map) => GroupInvitation(
    code: readString(map['code']) ?? '',
    type: enumByName(
      InviteTargetType.values,
      map['type'],
      InviteTargetType.family,
    ),
    targetId: readString(map['targetId']) ?? '',
    targetName: readString(map['targetName']) ?? '',
    createdByUid: readString(map['createdBy']) ?? '',
    createdByName: readString(map['createdByName']) ?? '',
    createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    expiresAt: parseDate(map['expiresAt']) ?? DateTime.now(),
    maxUses: readInt(map['maxUses'], 1),
    uses: readInt(map['uses'], 0),
    revoked: readBool(map['revoked'], false),
    requiresApproval: readBool(map['requiresApproval'], true),
    role: map['role'] is String
        ? enumByName(AdultRole.values, map['role'], AdultRole.tutor)
        : null,
  );
}

/// Lo que se muestra antes de confirmar: a qué clase o familia corresponde.
/// No incluye datos de los niños.
class InvitationPreview {
  const InvitationPreview({
    required this.code,
    required this.type,
    required this.targetName,
    required this.inviterName,
    required this.requiresApproval,
    this.role,
  });

  final String code;
  final InviteTargetType type;
  final String targetName;
  final String inviterName;
  final bool requiresApproval;
  final AdultRole? role;

  factory InvitationPreview.fromMap(Map<String, dynamic> map) =>
      InvitationPreview(
        code: readString(map['code']) ?? '',
        type: enumByName(
          InviteTargetType.values,
          map['type'],
          InviteTargetType.family,
        ),
        targetName: readString(map['targetName']) ?? '',
        inviterName: readString(map['inviterName']) ?? '',
        requiresApproval: readBool(map['requiresApproval'], true),
        role: map['role'] is String
            ? enumByName(AdultRole.values, map['role'], AdultRole.tutor)
            : null,
      );
}

enum JoinRequestStatus {
  pending('Pendiente de aprobación'),
  approved('Aprobada'),
  rejected('Rechazada');

  const JoinRequestStatus(this.label);
  final String label;
}

/// Solicitud de incorporación creada al canjear un código que requiere
/// aprobación. La revisa el responsable; el servidor registra el vínculo.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.code,
    required this.type,
    required this.targetId,
    required this.targetName,
    required this.requesterUid,
    required this.requesterName,
    required this.approverUid,
    required this.createdAt,
    this.childId,
    this.childName,
    this.role,
    this.status = JoinRequestStatus.pending,
    this.reviewedAt,
  });

  final String id;
  final String code;
  final InviteTargetType type;
  final String targetId;
  final String targetName;
  final String requesterUid;
  final String requesterName;

  /// Quien puede aprobarla: el administrador de la familia o el docente.
  final String approverUid;
  final DateTime createdAt;

  /// Niño que la familia quiere vincular con la clase.
  final String? childId;
  final String? childName;
  final AdultRole? role;
  final JoinRequestStatus status;
  final DateTime? reviewedAt;

  JoinRequest copyWith({JoinRequestStatus? status, DateTime? reviewedAt}) =>
      JoinRequest(
        id: id,
        code: code,
        type: type,
        targetId: targetId,
        targetName: targetName,
        requesterUid: requesterUid,
        requesterName: requesterName,
        approverUid: approverUid,
        createdAt: createdAt,
        childId: childId,
        childName: childName,
        role: role,
        status: status ?? this.status,
        reviewedAt: reviewedAt ?? this.reviewedAt,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'code': code,
    'type': type.name,
    'targetId': targetId,
    'targetName': targetName,
    'requesterUid': requesterUid,
    'requesterName': requesterName,
    'approverUid': approverUid,
    'createdAt': createdAt,
    'childId': childId,
    'childName': childName,
    'role': role?.name,
    'status': status.name,
    'reviewedAt': reviewedAt,
  };

  factory JoinRequest.fromMap(Map<String, dynamic> map, {String? id}) =>
      JoinRequest(
        id: id ?? readString(map['id']) ?? '',
        code: readString(map['code']) ?? '',
        type: enumByName(
          InviteTargetType.values,
          map['type'],
          InviteTargetType.family,
        ),
        targetId: readString(map['targetId']) ?? '',
        targetName: readString(map['targetName']) ?? '',
        requesterUid: readString(map['requesterUid']) ?? '',
        requesterName: readString(map['requesterName']) ?? '',
        approverUid: readString(map['approverUid']) ?? '',
        createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
        childId: readString(map['childId']),
        childName: readString(map['childName']),
        role: map['role'] is String
            ? enumByName(AdultRole.values, map['role'], AdultRole.tutor)
            : null,
        status: enumByName(
          JoinRequestStatus.values,
          map['status'],
          JoinRequestStatus.pending,
        ),
        reviewedAt: parseDate(map['reviewedAt']),
      );
}

/// Resultado de canjear un código.
enum RedeemOutcome {
  /// La incorporación quedó registrada.
  joined,

  /// Se envió una solicitud que el responsable debe aprobar.
  pendingApproval,
}

/// Enlace que contiene el QR: `mivoz://invite?code=AB12CD34`. Solo el código;
/// nunca datos del menor ni credenciales. Canjearlo exige una sesión de
/// adulto: no sirve para iniciar sesión.
class InvitationLink {
  const InvitationLink._();

  static const scheme = 'mivoz';
  static const host = 'invite';

  /// Sin letras ni números que se confunden (0/O, 1/I/L).
  static const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  static const codeLength = 8;

  static String build(String code) => '$scheme://$host?code=$code';

  /// Devuelve el código si [raw] es un enlace de invitación de Mi Voz o un
  /// código escrito válido; si no, `null`.
  static String? parse(String raw) {
    final text = raw.trim();
    final uri = Uri.tryParse(text);
    final candidate = uri != null && uri.scheme == scheme && uri.host == host
        ? uri.queryParameters['code'] ?? ''
        : text;
    final code = normalize(candidate);
    return isWellFormed(code) ? code : null;
  }

  static String normalize(String code) =>
      code.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

  static bool isWellFormed(String code) =>
      code.length == codeLength && code.split('').every(alphabet.contains);
}
