import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/stream_utils.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import '../../profiles/application/profiles_providers.dart';
import 'outbox.dart';

/// Une las solicitudes del servidor con las pendientes de este dispositivo.
List<CommunicationRequest> mergeRequests(
  Iterable<CommunicationRequest> pending,
  Iterable<CommunicationRequest> server,
) {
  final byId = <String, CommunicationRequest>{for (final r in server) r.id: r};
  for (final p in pending) {
    byId.putIfAbsent(p.id, () => p);
  }
  return byId.values.toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// Orden de la bandeja: urgentes abiertas primero, luego por fecha.
int inboxOrder(CommunicationRequest a, CommunicationRequest b) {
  final aUrgent = a.isUrgent && a.status.isOpen;
  final bUrgent = b.isUrgent && b.status.isOpen;
  if (aUrgent != bUrgent) return aUrgent ? -1 : 1;
  return b.createdAt.compareTo(a.createdAt);
}

/// Ids de los niños vinculados en una clave estable: editar un perfil (por
/// ejemplo, cambiar quién acompaña) no vuelve a abrir las suscripciones.
String _childIdsKey(Ref ref) => ref.watch(
  childrenProvider.select(
    (a) => (a.value ?? const <ChildProfile>[]).map((c) => c.id).join(','),
  ),
);

/// Una sola suscripción al servidor por niño, independiente de la cola local.
final _serverChildRequestsProvider =
    StreamProvider.family<List<CommunicationRequest>, String>((ref, childId) {
      ref.watch(sessionUidProvider);
      return ref.watch(requestsRepositoryProvider).watchChildRequests(childId);
    });

/// Solicitudes del servidor de todos los niños vinculados.
final _serverAdultRequestsProvider = StreamProvider<List<CommunicationRequest>>(
  (ref) {
    ref.watch(sessionUidProvider);
    final key = _childIdsKey(ref);
    if (key.isEmpty) return Stream.value(const []);
    final repo = ref.watch(requestsRepositoryProvider);
    return combineLatestList([
      for (final id in key.split(',')) repo.watchChildRequests(id),
    ]).map((lists) => lists.expand((l) => l).toList());
  },
);

/// Solicitudes de un niño: las del servidor más las pendientes de este
/// dispositivo. Un cambio en la cola no reabre la consulta al servidor.
final childRequestsProvider =
    FutureProvider.family<List<CommunicationRequest>, String>((
      ref,
      childId,
    ) async {
      final pending = ref
          .watch(outboxProvider)
          .where((r) => r.childId == childId)
          .toList();
      final server = await ref.watch(
        _serverChildRequestsProvider(childId).future,
      );
      return mergeRequests(pending, server);
    });

/// Todas las solicitudes de los niños vinculados al adulto.
final adultRequestsProvider = FutureProvider<List<CommunicationRequest>>((
  ref,
) async {
  final ids = _childIdsKey(ref).split(',').toSet();
  final pending = ref
      .watch(outboxProvider)
      .where((r) => ids.contains(r.childId))
      .toList();
  final server = await ref.watch(_serverAdultRequestsProvider.future);
  return mergeRequests(pending, server);
});
typedef RequestKey = ({String childId, String requestId});

/// Una solicitud concreta: pendiente local o la versión del servidor.
final trackedRequestProvider =
    StreamProvider.family<CommunicationRequest?, RequestKey>((ref, key) {
      ref.watch(sessionUidProvider);
      final pending = ref
          .watch(outboxProvider)
          .where((r) => r.id == key.requestId)
          .firstOrNull;
      if (pending != null) return Stream.value(pending);
      return ref
          .watch(requestsRepositoryProvider)
          .watchRequest(key.childId, key.requestId);
    });
