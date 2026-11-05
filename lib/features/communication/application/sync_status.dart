import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'outbox.dart';

/// Estado de la cuenta y la sincronización, en palabras para el usuario (sin
/// nombres de servicios ni rutas técnicas).
enum SyncState {
  /// Sin sesión iniciada.
  signedOut('Iniciar sesión'),

  /// Esta versión no tiene la nube configurada: todo queda en el dispositivo.
  localOnly('Guardado en este dispositivo'),

  /// El sistema informa que no hay red. Lo esencial sigue funcionando.
  offline('Sin conexión'),

  /// Hay solicitudes guardadas aquí que el servidor aún no confirmó.
  pending('Cambios pendientes'),

  /// El último intento de envío falló aunque parece haber red.
  failed('No pudimos conectar. Intentar nuevamente'),

  /// Todo lo de este dispositivo está confirmado por el servidor.
  synced('Datos sincronizados');

  const SyncState(this.label);
  final String label;
}

class SyncStatus {
  const SyncStatus(this.state, {this.pending = 0});

  final SyncState state;

  /// Solicitudes en la cola de envío.
  final int pending;

  String get label => switch (state) {
    SyncState.pending when pending == 1 => 'Cambios pendientes: 1 solicitud',
    SyncState.pending => 'Cambios pendientes: $pending solicitudes',
    SyncState.failed when pending == 1 =>
      'No pudimos conectar. Intentar nuevamente (1 solicitud pendiente)',
    SyncState.failed =>
      'No pudimos conectar. Intentar nuevamente ($pending solicitudes '
          'pendientes)',
    SyncState.offline when pending > 0 =>
      'Sin conexión · $pending pendiente${pending == 1 ? '' : 's'}',
    _ => state.label,
  };

  bool get canRetry => pending > 0 && state != SyncState.offline;
}

final syncStatusProvider = Provider<SyncStatus>((ref) {
  if (ref.watch(currentUserProvider) == null) {
    return const SyncStatus(SyncState.signedOut);
  }
  final pending = ref.watch(outboxProvider).length;
  if (!ref.watch(isFirebaseModeProvider) && pending == 0) {
    return const SyncStatus(SyncState.localOnly);
  }
  if (ref.watch(onlineProvider).value == false) {
    return SyncStatus(SyncState.offline, pending: pending);
  }
  if (pending > 0) {
    return SyncStatus(
      ref.watch(outboxFailuresProvider) > 0
          ? SyncState.failed
          : SyncState.pending,
      pending: pending,
    );
  }
  return const SyncStatus(SyncState.synced);
});
