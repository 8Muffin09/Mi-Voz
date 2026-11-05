import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/group_invitation.dart';

/// Motivos por los que el servidor rechaza un código o una operación.
/// Los mismos códigos (`reason`) los devuelven las Cloud Functions.
enum InvitationError {
  invalid(
    'El código no existe. Revisa que esté bien escrito o pide uno nuevo.',
  ),
  expired('Este código ya venció. Pide al responsable que genere uno nuevo.'),
  revoked('Este código fue revocado por quien lo creó.'),
  exhausted('Este código ya fue utilizado.'),
  alreadyMember(
    'Ya formas parte de este grupo; no hace falta unirse otra vez.',
  ),
  alreadyLinked('Este niño ya está vinculado con esta clase.'),
  alreadyRequested(
    'Ya enviaste una solicitud con este código. Espera la aprobación.',
  ),
  childRequired('Elige qué niño quieres vincular con la clase.'),
  childNotAllowed(
    'Solo un adulto de la familia del niño puede vincularlo con una clase.',
  ),
  tooManyAttempts(
    'Demasiados códigos incorrectos. Espera unos minutos e inténtalo de nuevo.',
  ),
  notAllowed('No tienes permiso para esta invitación.'),
  emailNotVerified('Verifica tu correo antes de generar invitaciones.');

  const InvitationError(this.message);
  final String message;
}

class InvitationException extends AppException {
  InvitationException(this.reason) : super(reason.message, code: reason.name);

  final InvitationError reason;
}

/// Invitaciones a familias y clases y solicitudes de incorporación.
///
/// Toda la validación ocurre en el servidor: caducidad, revocación, límite
/// de usos, intentos incorrectos, permisos y duplicados. La vinculación
/// inicial requiere conexión (lanza [OfflineException] sin ella).
abstract class InvitationsRepository {
  /// Genera una invitación (solo el administrador de la familia o el docente
  /// de la clase, con el correo verificado).
  Future<GroupInvitation> create({
    required InviteTargetType type,
    required String targetId,
    required Duration validity,
    required int maxUses,
    required bool requiresApproval,
    AdultRole? role,
  });

  /// Invitaciones de un grupo, visibles para su responsable.
  Stream<List<GroupInvitation>> watchForTarget(
    InviteTargetType type,
    String targetId,
  );

  Future<void> revoke(GroupInvitation invitation);

  /// Muestra a qué clase o familia corresponde un código, sin canjearlo.
  Future<InvitationPreview> preview(String code);

  /// Canjea el código. Para una clase hay que indicar [childId] (el niño de
  /// la familia que se vincula).
  Future<RedeemOutcome> redeem(String code, {String? childId});

  /// Solicitudes que la cuenta actual debe aprobar.
  Stream<List<JoinRequest>> watchPendingForApprover(String uid);

  /// Solicitudes enviadas por la cuenta actual.
  Stream<List<JoinRequest>> watchMyRequests(String uid);

  Future<void> review(JoinRequest request, {required bool approve});
}
