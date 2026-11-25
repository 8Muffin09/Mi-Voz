import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/communication_request.dart';
import '../../communication/application/requests_providers.dart';
import 'active_child.dart';
import 'child_mode.dart';

/// Aviso para el niño: su adulto ya vio su mensaje, va en camino o lo
/// resolvió. Se muestra en cualquier pantalla del modo niño (no solo en
/// "Mi mensaje") y se lee en voz alta.
class ChildStatusNotice {
  const ChildStatusNotice({
    required this.requestId,
    required this.status,
    required this.message,
    required this.symbol,
    required this.adultName,
  });

  final String requestId;
  final RequestStatus status;

  /// Lo que el niño comunicó ("Necesito agua").
  final String message;
  final String symbol;
  final String? adultName;

  /// Texto grande del aviso.
  String get title => switch (status) {
    RequestStatus.attending =>
      adultName == null
          ? '¡Tu adulto va en camino!'
          : '¡${_first(adultName!)} va en camino!',
    RequestStatus.resolved => '¡Listo! Ya atendieron tu mensaje',
    _ =>
      adultName == null
          ? 'Tu adulto vio tu mensaje'
          : '${_first(adultName!)} vio tu mensaje',
  };

  /// Lo que se lee en voz alta.
  String get spoken => '$title. $message';

  static String _first(String name) => name.trim().split(' ').first;
}

/// Decide qué cambios merecen aviso. La primera lista que llega es la base
/// (no se anuncian estados viejos al abrir la app); después, cada solicitud
/// avisa una vez por estado al pasar a vista, en camino o resuelta.
class ChildStatusWatcher {
  ChildStatusWatcher({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, RequestStatus> _known = {};
  bool _primed = false;

  /// Solo solicitudes recientes: lo de ayer no interrumpe al niño hoy.
  static const window = Duration(hours: 6);

  List<ChildStatusNotice> update(List<CommunicationRequest> requests) {
    final notices = <ChildStatusNotice>[];
    final now = _clock();
    for (final r in requests) {
      final before = _known[r.id];
      _known[r.id] = r.status;
      if (!_primed) continue;
      if (now.difference(r.createdAt) > window) continue;
      final changed = before == null
          ? r.status != RequestStatus.newRequest
          : r.status.index > before.index;
      if (!changed) continue;
      notices.add(
        ChildStatusNotice(
          requestId: r.id,
          status: r.status,
          message: r.message,
          symbol: r.emoji,
          adultName: r.statusUpdatedByName,
        ),
      );
    }
    _primed = true;
    // Si avanzó varios pasos a la vez, basta con el último de cada mensaje.
    final latest = <String, ChildStatusNotice>{};
    for (final n in notices) {
      latest[n.requestId] = n;
    }
    return latest.values.toList();
  }
}

/// Avisos pendientes de mostrar al niño (el más reciente al final).
class ChildStatusNoticesNotifier extends Notifier<List<ChildStatusNotice>> {
  ChildStatusWatcher? _watcher;

  @override
  List<ChildStatusNotice> build() {
    final childId = ref.watch(childModeProvider);
    _watcher = null;
    if (childId == null) return const [];
    _watcher = ChildStatusWatcher();
    ref.listen(childRequestsProvider(childId), (_, next) {
      final list = next.value;
      final watcher = _watcher;
      if (list == null || watcher == null) return;
      final fresh = watcher.update(list);
      if (fresh.isEmpty) return;
      state = [
        ...state.where((n) => !fresh.any((f) => f.requestId == n.requestId)),
        ...fresh,
      ].take(3).toList();
      final feedback = ref.read(childFeedbackProvider);
      feedback.success();
      feedback.speak(fresh.last.spoken);
    }, fireImmediately: true);
    return const [];
  }

  void dismiss(String requestId) =>
      state = state.where((n) => n.requestId != requestId).toList();
}

final childStatusNoticesProvider =
    NotifierProvider<ChildStatusNoticesNotifier, List<ChildStatusNotice>>(
      ChildStatusNoticesNotifier.new,
    );
