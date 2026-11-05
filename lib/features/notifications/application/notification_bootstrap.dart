import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../app/router.dart';
import '../../../app/routes.dart';
import '../../child/application/child_mode.dart';
import 'in_app_notifications.dart';

/// En modo Firebase: registra el dispositivo, muestra los avisos recibidos
/// con la app abierta y abre la solicitud al tocar una notificación.
final notificationBootstrapProvider = Provider<void>((ref) {
  final push = ref.watch(pushNotificationServiceProvider);
  final user = ref.watch(currentUserProvider);
  final childModeId = ref.watch(childModeProvider);
  if (push == null || user == null) return;

  push.registerDevice(uid: user.uid, childModeChildId: childModeId);

  void open(RemoteMessage m) {
    if (childModeId != null) return;
    // Solicitud para unirse a una familia o clase: se aprueba en el panel.
    if (m.data['type'] == 'join_request') {
      ref.read(routerProvider).go(Routes.adult);
      return;
    }
    final childId = m.data['childId'];
    final requestId = m.data['requestId'];
    if (childId is String && requestId is String) {
      ref.read(routerProvider).push(Routes.requestDetail(childId, requestId));
    }
  }

  final foreground = push.foregroundMessages.listen((m) {
    if (childModeId != null) return;
    final isRequest = m.data['type'] != 'join_request';
    final childId = isRequest ? m.data['childId'] : null;
    final requestId = isRequest ? m.data['requestId'] : null;
    ref
        .read(inAppNotificationsProvider.notifier)
        .show(
          InAppNotice(
            title: m.notification?.title ?? 'Mi Voz',
            body: m.notification?.body ?? '',
            simulated: false,
            childId: childId is String ? childId : null,
            requestId: requestId is String ? requestId : null,
            urgent: m.data['urgent'] == 'true',
          ),
        );
  });
  final opened = push.openedMessages.listen(open);
  push.initialMessage().then((m) {
    if (m != null) open(m);
  });

  ref.onDispose(() {
    foreground.cancel();
    opened.cancel();
  });
});
