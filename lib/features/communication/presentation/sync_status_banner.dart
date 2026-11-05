import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../application/outbox.dart';
import '../application/sync_status.dart';

/// Franja del panel del adulto: solo aparece si hay algo que atender (sin
/// conexión, cambios pendientes o un envío que falló).
class SyncStatusBanner extends ConsumerWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    final visible = switch (status.state) {
      SyncState.offline || SyncState.failed => true,
      SyncState.pending => true,
      SyncState.localOnly => status.pending > 0,
      _ => false,
    };
    if (!visible) return const SizedBox.shrink();

    final detail = switch (status.state) {
      SyncState.offline =>
        'Puedes seguir usando Mi Voz; los cambios se enviarán al volver '
            'internet.',
      SyncState.failed => 'Se volverá a intentar automáticamente.',
      _ => null,
    };
    return Material(
      key: const Key('sync-banner'),
      color: AppColors.warning.withValues(alpha: 0.15),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(syncIcon(status.state), color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  liveRegion: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.label,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      if (detail != null)
                        Text(detail, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ),
              if (status.canRetry)
                TextButton(
                  key: const Key('sync-retry'),
                  onPressed: () =>
                      ref.read(outboxProvider.notifier).sync(force: true),
                  child: const Text('Reintentar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData syncIcon(SyncState state) => switch (state) {
  SyncState.signedOut => Icons.login_rounded,
  SyncState.localOnly => Icons.phone_android_rounded,
  SyncState.offline => Icons.cloud_off_rounded,
  SyncState.pending => Icons.cloud_upload_outlined,
  SyncState.failed => Icons.sync_problem_rounded,
  SyncState.synced => Icons.cloud_done_rounded,
};

/// Estado compacto (ajustes, "Mi perfil"): siempre visible.
class SyncStatusTile extends ConsumerWidget {
  const SyncStatusTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider);
    return ListTile(
      key: const Key('sync-status'),
      leading: Icon(syncIcon(status.state), color: AppColors.primary),
      title: Text(status.label),
      subtitle: Text(switch (status.state) {
        SyncState.localOnly =>
          'Esta versión guarda la cuenta y los datos solo en este dispositivo.',
        SyncState.synced =>
          'Puedes iniciar sesión en otro dispositivo y ver los perfiles a los '
              'que tienes acceso.',
        SyncState.offline =>
          'Pictogramas, frases, favoritos y voz siguen disponibles.',
        _ =>
          'Las solicitudes quedan guardadas hasta que el servidor confirma '
              'que las recibió.',
      }),
      trailing: status.canRetry
          ? TextButton(
              onPressed: () =>
                  ref.read(outboxProvider.notifier).sync(force: true),
              child: const Text('Reintentar'),
            )
          : null,
    );
  }
}
