import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/features/notifications/application/request_watcher.dart';
import 'package:mi_voz/models/communication_request.dart';

CommunicationRequest req(
  String id, {
  NotificationStatus notification = NotificationStatus.sent,
  List<String> notified = const ['ana'],
  RequestStatus status = RequestStatus.newRequest,
}) => CommunicationRequest(
  id: id,
  childId: 'leo',
  childName: 'Leo',
  categoryId: 'quiero',
  categoryTitle: 'QUIERO',
  message: 'Quiero agua',
  emoji: '💧',
  priority: RequestPriority.normal,
  createdByUid: 'pedro',
  createdAt: DateTime(2026),
  delivery: DeliveryStatus.delivered,
  notification: notification,
  notifiedUids: notified,
  status: status,
);

void main() {
  group('Avisos sin notificaciones push (Windows, app abierta)', () {
    test('lo que ya existía al abrir no se avisa', () {
      final w = RequestWatcher('ana');
      expect(w.update([req('a'), req('b')]), isEmpty);
      expect(w.update([req('a'), req('b')]), isEmpty);
    });

    test('espera a que el servidor decida y avisa una sola vez', () {
      final w = RequestWatcher('ana')..update(const []);
      expect(
        w.update([req('n', notification: NotificationStatus.pending)]),
        isEmpty,
      );
      expect(w.update([req('n')]).map((r) => r.id), ['n']);
      expect(w.update([req('n')]), isEmpty);
    });

    test('no avisa si el servidor eligió a otros adultos o ya se atendió', () {
      final w = RequestWatcher('ana')..update(const []);
      expect(
        w.update([
          req('x', notified: ['luis']),
        ]),
        isEmpty,
      );
      expect(w.update([req('y', status: RequestStatus.seen)]), isEmpty);
      expect(
        w.update([
          req('z', notification: NotificationStatus.noRecipients, notified: []),
        ]),
        isEmpty,
      );
    });
  });
}
