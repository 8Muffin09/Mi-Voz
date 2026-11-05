import '../../../core/demo/demo_database.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import 'requests_repository.dart';

/// Se invoca cuando el "backend" local simula una notificación push.
typedef SimulatedPushCallback = void Function(
  CommunicationRequest request,
  List<String> recipientUids,
);

/// Solicitudes en la base local. Reproduce el comportamiento de la Cloud
/// Function: valida al emisor, resuelve destinatarios autorizados y marca
/// la notificación como **simulada**.
class DemoRequestsRepository implements RequestsRepository {
  DemoRequestsRepository(this._db, {this.onSimulatedPush});

  final DemoDatabase _db;
  final SimulatedPushCallback? onSimulatedPush;

  List<CommunicationRequest> _forChild(String childId) =>
      _db
          .where(DemoDatabase.requests, (r) => r['childId'] == childId)
          .map((r) => CommunicationRequest.fromMap(r))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  bool _canRead(String childId) {
    final row = _db.get(DemoDatabase.children, childId);
    return row != null &&
        Permissions.canView(ChildProfile.fromMap(row), _db.sessionUid);
  }

  @override
  Stream<List<CommunicationRequest>> watchChildRequests(String childId) =>
      _db.watch(() => _canRead(childId) ? _forChild(childId) : []);

  @override
  Stream<CommunicationRequest?> watchRequest(
    String childId,
    String requestId,
  ) => _db.watch(() {
    if (!_canRead(childId)) return null;
    final row = _db.get(DemoDatabase.requests, requestId);
    return row == null ? null : CommunicationRequest.fromMap(row);
  });

  @override
  Future<void> deliver(CommunicationRequest request) async {
    if (_db.simulateOffline) throw const OfflineException();

    // Idempotente: si ya llegó, no se vuelve a crear ni a notificar.
    if (_db.get(DemoDatabase.requests, request.id) != null) return;

    final childRow = _db.get(DemoDatabase.children, request.childId);
    if (childRow == null) throw const AppException('El perfil ya no existe.');
    final child = ChildProfile.fromMap(childRow);
    if (!Permissions.canCreateRequest(child, request.createdByUid)) {
      throw const PermissionDeniedException();
    }

    final links = _db
        .where(DemoDatabase.links, (r) => r['childId'] == child.id)
        .map(CaregiverLink.fromMap);
    // Misma lógica que la Cloud Function. En este modo todos los adultos
    // "tienen dispositivo" (el propio), así que no hay segundo intento.
    final plan = RecipientResolver.plan(child, links: links);
    final recipients = plan.primary;
    final names = _db
        .where(
          DemoDatabase.links,
          (r) => r['childId'] == child.id && recipients.contains(r['adultUid']),
        )
        .map((r) => CaregiverLink.fromMap(r).adultName)
        .toList();

    final now = DateTime.now();
    final stored = request.copyWith(
      delivery: DeliveryStatus.delivered,
      deliveredAt: now,
      notification: recipients.isEmpty
          ? NotificationStatus.noRecipients
          : NotificationStatus.simulated,
      notifiedAt: now,
      notifiedNames: names,
      notifiedUids: recipients,
      route: plan.companion != null
          ? NotificationRoute.companion
          : NotificationRoute.rule,
    );
    _db.put(DemoDatabase.requests, request.id, stored.toMap());
    _db.commit();
    if (recipients.isNotEmpty) onSimulatedPush?.call(stored, recipients);
  }

  @override
  Future<void> updateStatus({
    required CommunicationRequest request,
    required RequestStatus status,
    required AppUser actor,
    String? note,
  }) async {
    final row = _db.get(DemoDatabase.requests, request.id);
    final childRow = _db.get(DemoDatabase.children, request.childId);
    if (row == null || childRow == null) {
      throw const AppException('La solicitud ya no existe.');
    }
    final child = ChildProfile.fromMap(childRow);
    if (!Permissions.canUpdateRequest(child, actor.uid)) {
      throw const PermissionDeniedException();
    }
    final current = CommunicationRequest.fromMap(row);
    if (!Permissions.isValidTransition(current.status, status)) return;

    final now = DateTime.now();
    final updated = current.copyWith(
      status: status,
      statusUpdatedAt: now,
      statusUpdatedByUid: actor.uid,
      statusUpdatedByName: actor.displayName,
      seenAt: current.seenAt ?? now,
      attendingAt: status.index >= RequestStatus.attending.index
          ? current.attendingAt ?? now
          : null,
      resolvedAt: status == RequestStatus.resolved ? now : null,
      note: note,
    );
    _db.put(DemoDatabase.requests, request.id, updated.toMap());
    _db.commit();
  }
}
