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
    String? support,
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
    final supportText = support?.trim() ?? '';
    final withSupport = supportText.isEmpty
        ? updated
        : updated.copyWith(
            supportProvided: supportText,
            supportByUid: actor.uid,
            supportByName: actor.displayName,
            supportAt: now,
          );
    _db.put(DemoDatabase.requests, request.id, {
      ...withSupport.toMap(),
      'events': [
        ..._eventRows(row),
        _eventRow(status.key, actor, now),
        if (supportText.isNotEmpty)
          _eventRow('support', actor, now, supportText),
      ],
    });
    _db.commit();
  }

  @override
  Future<void> saveSupport({
    required CommunicationRequest request,
    required AppUser actor,
    required String support,
  }) async {
    final row = _requireMemberRow(request, actor);
    final current = CommunicationRequest.fromMap(row);
    if (current.status.index < RequestStatus.attending.index) {
      throw const AppException('Primero marca la solicitud como en atención.');
    }
    final now = DateTime.now();
    _db.put(DemoDatabase.requests, request.id, {
      ...current
          .copyWith(
            supportProvided: support.trim(),
            supportByUid: actor.uid,
            supportByName: actor.displayName,
            supportAt: now,
          )
          .toMap(),
      'events': [
        ..._eventRows(row),
        _eventRow('support', actor, now, support.trim()),
      ],
    });
    _db.commit();
  }

  @override
  Future<void> setChildFeedback({
    required CommunicationRequest request,
    required AppUser actor,
    required SupportFeedback feedback,
  }) async {
    final row = _requireMemberRow(request, actor);
    final now = DateTime.now();
    _db.put(DemoDatabase.requests, request.id, {
      ...CommunicationRequest.fromMap(row)
          .copyWith(childFeedback: feedback, childFeedbackAt: now)
          .toMap(),
      'events': [
        ..._eventRows(row),
        _eventRow('feedback', actor, now, feedback.name),
      ],
    });
    _db.commit();
  }

  @override
  Stream<List<RequestEvent>> watchEvents(String childId, String requestId) =>
      _db.watch(() {
        if (!_db.sessionIsMemberOf(childId)) return const <RequestEvent>[];
        final row = _db.get(DemoDatabase.requests, requestId);
        return row == null
            ? const <RequestEvent>[]
            : [for (final e in _eventRows(row)) RequestEvent.fromMap(e)];
      });

  Map<String, dynamic> _requireMemberRow(
    CommunicationRequest request,
    AppUser actor,
  ) {
    final row = _db.get(DemoDatabase.requests, request.id);
    final childRow = _db.get(DemoDatabase.children, request.childId);
    if (row == null || childRow == null) {
      throw const AppException('La solicitud ya no existe.');
    }
    final child = ChildProfile.fromMap(childRow);
    if (!Permissions.canUpdateRequest(child, actor.uid)) {
      throw const PermissionDeniedException();
    }
    return row;
  }

  static Map<String, dynamic> _eventRow(
    String type,
    AppUser actor,
    DateTime at, [
    String? detail,
  ]) => RequestEvent(
    type: type,
    byUid: actor.uid,
    byName: actor.displayName,
    at: at,
    detail: detail,
  ).toMap();

  static List<Map<String, dynamic>> _eventRows(Map<String, dynamic> row) => [
    for (final e in (row['events'] as List?) ?? const [])
      if (e is Map) Map<String, dynamic>.from(e),
  ];
}
