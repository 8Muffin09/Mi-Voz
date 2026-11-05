import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/communication/application/outbox.dart';
import '../features/notifications/application/notification_bootstrap.dart';
import '../features/notifications/application/request_watcher.dart';
import '../features/notifications/presentation/notification_host.dart';
import 'router.dart';
import 'routes.dart';

class MiVozApp extends ConsumerStatefulWidget {
  const MiVozApp({super.key});

  @override
  ConsumerState<MiVozApp> createState() => _MiVozAppState();
}

class _MiVozAppState extends ConsumerState<MiVozApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Al volver a primer plano se reintenta enseguida lo pendiente de envío.
    _lifecycle = AppLifecycleListener(
      onResume: () => ref.read(outboxProvider.notifier).sync(force: true),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    void openRequest(String childId, String requestId) =>
        router.push(Routes.requestDetail(childId, requestId));

    // Servicios de fondo: cola de envío y notificaciones.
    ref.watch(outboxProvider);
    ref.watch(notificationBootstrapProvider);
    ref.watch(requestWatcherProvider);

    return MaterialApp.router(
      title: 'Mi Voz',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.adult(),
      routerConfig: router,
      locale: const Locale('es', 'MX'),
      supportedLocales: const [Locale('es', 'MX'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => NotificationHost(
        onOpen: (notice) {
          final childId = notice.childId;
          final requestId = notice.requestId;
          if (childId != null && requestId != null) {
            openRequest(childId, requestId);
          }
        },
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
