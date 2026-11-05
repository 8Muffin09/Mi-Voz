import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../models/communication_request.dart';
import '../../child/application/child_mode.dart';
import '../../communication/application/requests_providers.dart';
import 'in_app_notifications.dart';

/// Decide qué solicitudes nuevas deben avisarse a [uid]: las que llegan
/// después de empezar a observar y en las que el servidor lo incluyó entre
/// los destinatarios (misma regla que las notificaciones push).
class RequestWatcher {
  RequestWatcher(this.uid);

  final String uid;
  final _handled = <String>{};
  var _primed = false;

  /// Devuelve las solicitudes que hay que avisar ahora.
  List<CommunicationRequest> update(List<CommunicationRequest> requests) {
    if (!_primed) {
      // Lo que ya existía al abrir la app no se vuelve a avisar.
      _handled.addAll(requests.map((r) => r.id));
      _primed = true;
      return const [];
    }
    final toNotify = <CommunicationRequest>[];
    for (final r in requests) {
      if (_handled.contains(r.id)) continue;
      // El servidor aún no decide a quién avisar: se espera.
      if (r.delivery == DeliveryStatus.pendingSync ||
          r.notification == NotificationStatus.pending) {
        continue;
      }
      _handled.add(r.id);
      if (r.notifiedUids.contains(uid) &&
          r.status == RequestStatus.newRequest) {
        toNotify.add(r);
      }
    }
    return toNotify;
  }
}

/// Donde no hay notificaciones push (Windows), mientras la app está abierta
/// muestra un aviso por cada solicitud nueva dirigida a esta cuenta. Con la
/// app cerrada no llega nada: así se indica en la documentación.
final requestWatcherProvider = Provider<void>((ref) {
  if (!ref.watch(isFirebaseModeProvider) ||
      ref.watch(pushNotificationsSupportedProvider)) {
    return;
  }
  final uid = ref.watch(sessionUidProvider);
  if (uid == null || ref.watch(childModeProvider) != null) return;

  final watcher = RequestWatcher(uid);
  ref.listen(adultRequestsProvider, (_, next) {
    final list = next.value;
    if (list == null) return;
    for (final r in watcher.update(list)) {
      ref
          .read(inAppNotificationsProvider.notifier)
          .show(
            InAppNotice(
              title: r.notificationTitle,
              body: r.message,
              simulated: false,
              childId: r.childId,
              requestId: r.id,
              urgent: r.isUrgent,
            ),
          );
    }
  }, fireImmediately: true);
});
