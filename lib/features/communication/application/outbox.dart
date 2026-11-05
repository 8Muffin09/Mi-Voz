import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/communication_request.dart';
import '../../notifications/application/in_app_notifications.dart';

/// Cola de solicitudes "Pendientes de envío".
///
/// Toda solicitud se guarda primero en el dispositivo y solo sale de la cola
/// cuando el servidor confirma su recepción. Como el id se genera en el
/// cliente y la entrega es idempotente, los reintentos nunca duplican.
class OutboxNotifier extends Notifier<List<CommunicationRequest>> {
  /// Espera entre reintentos: 15 s, 30 s, 1 min, 2 min… hasta 5 min. Se
  /// reintenta además al volver la conexión y al volver a abrir la app.
  static Duration retryDelay(int failures) {
    final seconds = 15 * (1 << failures.clamp(0, 5));
    return Duration(seconds: seconds.clamp(15, 300));
  }

  bool _syncing = false;
  int _failures = 0;
  Timer? _retry;
  late String _key;

  @override
  List<CommunicationRequest> build() {
    final store = ref.watch(localStoreProvider);
    final firebase = ref.watch(isFirebaseModeProvider);
    ref.watch(requestsRepositoryProvider);
    _key = '${LocalStore.keyOutbox}_${firebase ? 'firebase' : 'demo'}';

    final sub = ref.watch(connectivityServiceProvider).onlineChanges.listen((
      online,
    ) {
      if (online) sync(force: true);
    });
    ref.onDispose(() {
      sub.cancel();
      _retry?.cancel();
    });

    final items = store
        .getJsonList(_key)
        .map(
          (m) => CommunicationRequest.fromMap(
            m,
            delivery: DeliveryStatus.pendingSync,
          ),
        )
        .toList();
    if (items.isNotEmpty) Future.microtask(sync);
    return items;
  }

  Future<void> _persist() => ref
      .read(localStoreProvider)
      .setJsonList(_key, state.map((r) => r.toMap()).toList());

  /// Encola y trata de entregar. Devuelve el estado tras el intento.
  Future<CommunicationRequest> submit(CommunicationRequest request) async {
    final pending = request.copyWith(delivery: DeliveryStatus.pendingSync);
    state = [...state.where((r) => r.id != request.id), pending];
    await _persist();
    await sync();
    if (!ref.mounted) return pending;
    final stillPending = state.any((r) => r.id == request.id);
    return stillPending
        ? pending
        : request.copyWith(delivery: DeliveryStatus.delivered);
  }

  /// Envía en orden todo lo pendiente. [force] reinicia la espera entre
  /// reintentos (conexión recuperada, app de nuevo en primer plano o\n  /// "Reintentar").
  Future<void> sync({bool force = false}) async {
    if (force) {
      _failures = 0;
      ref.read(outboxFailuresProvider.notifier).set(0);
    }
    if (_syncing || !ref.mounted || state.isEmpty) return;
    _syncing = true;
    _retry?.cancel();
    var failed = false;
    final repo = ref.read(requestsRepositoryProvider);
    try {
      for (final request in [...state]) {
        try {
          await repo.deliver(request);
          if (!ref.mounted) return;
          state = state.where((r) => r.id != request.id).toList();
          await _persist();
        } on OfflineException {
          failed = true;
          break;
        } on PermissionDeniedException catch (e) {
          // No se reintenta: el adulto ya no está vinculado al niño.
          if (!ref.mounted) return;
          state = state.where((r) => r.id != request.id).toList();
          await _persist();
          ref
              .read(inAppNotificationsProvider.notifier)
              .show(
                InAppNotice(
                  title: 'No se pudo enviar una solicitud',
                  body: '"${request.message}": ${e.message}',
                  simulated: false,
                ),
              );
        } catch (e) {
          debugPrint('Error al entregar ${request.id}: $e');
          failed = true;
          break;
        }
      }
    } finally {
      _syncing = false;
    }
    if (!ref.mounted) return;
    _failures = failed ? _failures + 1 : 0;
    ref.read(outboxFailuresProvider.notifier).set(_failures);
    if (state.isNotEmpty) {
      _retry = Timer(retryDelay(_failures - 1), sync);
    }
  }
}

final outboxProvider =
    NotifierProvider<OutboxNotifier, List<CommunicationRequest>>(
      OutboxNotifier.new,
    );

/// Intentos de envío fallidos seguidos (0 = el último intento funcionó o
/// aún no hubo ninguno). Lo usa `syncStatusProvider` para mostrar "No
/// pudimos conectar".
class OutboxFailuresNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int value) {
    if (state != value) state = value;
  }
}

final outboxFailuresProvider = NotifierProvider<OutboxFailuresNotifier, int>(
  OutboxFailuresNotifier.new,
);
