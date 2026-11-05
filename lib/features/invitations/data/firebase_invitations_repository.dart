import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/group_invitation.dart';
import 'invitations_repository.dart';

/// Invitaciones con Firebase. Crear, previsualizar, canjear, revocar y
/// aprobar son Cloud Functions (`functions/index.js`): el cliente no puede
/// escribir invitaciones, solicitudes ni membresías por su cuenta. Requiere
/// el plan Blaze y las funciones desplegadas.
class FirebaseInvitationsRepository implements InvitationsRepository {
  FirebaseInvitationsRepository(this._db, this._functions, {this.uid});

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  /// Cuenta con sesión (el proveedor recrea el repositorio al cambiarla).
  final String? uid;

  static const invitationsCollection = 'group_invitations';
  static const requestsCollection = 'join_requests';

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call<Object?>(data);
      final value = result.data;
      return value is Map ? Map<String, dynamic>.from(value) : const {};
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      final reason = details is Map ? details['reason'] : null;
      final known = InvitationError.values
          .where((r) => r.name == reason)
          .firstOrNull;
      if (known != null) throw InvitationException(known);
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const OfflineException(
          'Se necesita conexión para validar el código. Inténtalo cuando '
          'vuelva internet.',
        );
      }
      if (e.code == 'permission-denied' || e.code == 'unauthenticated') {
        throw const PermissionDeniedException();
      }
      throw AppException(e.message ?? 'No se pudo completar la operación.');
    }
  }

  @override
  Future<GroupInvitation> create({
    required InviteTargetType type,
    required String targetId,
    required Duration validity,
    required int maxUses,
    required bool requiresApproval,
    AdultRole? role,
  }) async {
    final data = await _call('createInvitation', {
      'type': type.name,
      'targetId': targetId,
      'validityHours': validity.inHours,
      'maxUses': maxUses,
      'requiresApproval': requiresApproval,
      'role': role?.name,
    });
    return GroupInvitation.fromMap(data);
  }

  @override
  Stream<List<GroupInvitation>> watchForTarget(
    InviteTargetType type,
    String targetId,
  ) {
    if (uid == null) return Stream.value(const []);
    // Las reglas solo dejan leer las invitaciones del responsable del grupo.
    return _db
        .collection(invitationsCollection)
        .where('ownerUid', isEqualTo: uid)
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map(
          (q) =>
              q.docs
                  .map((d) => GroupInvitation.fromMap(d.data()))
                  .where((i) => i.type == type)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  @override
  Future<void> revoke(GroupInvitation invitation) =>
      _call('revokeInvitation', {'code': invitation.code});

  @override
  Future<InvitationPreview> preview(String code) async {
    final data = await _call('previewInvitation', {
      'code': InvitationLink.normalize(code),
    });
    return InvitationPreview.fromMap(data);
  }

  @override
  Future<RedeemOutcome> redeem(String code, {String? childId}) async {
    final data = await _call('redeemInvitation', {
      'code': InvitationLink.normalize(code),
      'childId': childId,
    });
    return data['outcome'] == 'joined'
        ? RedeemOutcome.joined
        : RedeemOutcome.pendingApproval;
  }

  @override
  Stream<List<JoinRequest>> watchPendingForApprover(String uid) => _db
      .collection(requestsCollection)
      .where('approverUid', isEqualTo: uid)
      .where('status', isEqualTo: JoinRequestStatus.pending.name)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => JoinRequest.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Stream<List<JoinRequest>> watchMyRequests(String uid) => _db
      .collection(requestsCollection)
      .where('requesterUid', isEqualTo: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => JoinRequest.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  @override
  Future<void> review(JoinRequest request, {required bool approve}) =>
      _call('reviewJoinRequest', {'requestId': request.id, 'approve': approve});
}
