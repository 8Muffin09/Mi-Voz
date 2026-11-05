import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';

/// Niños vinculados al adulto actual.
final childrenProvider = StreamProvider<List<ChildProfile>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const []);
  return ref.watch(childrenRepositoryProvider).watchChildrenForAdult(user.uid);
});

/// Un perfil infantil con caché local: en modo niño sin conexión se
/// muestra la última versión conocida (incluidas sus preferencias).
final childProvider = StreamProvider.family<ChildProfile?, String>((
  ref,
  childId,
) async* {
  ref.watch(sessionUidProvider);
  final store = ref.watch(localStoreProvider);
  final repo = ref.watch(childrenRepositoryProvider);
  final key = LocalStore.childCacheKey(childId);
  final cached = store.getJson(key);
  if (cached != null) yield ChildProfile.fromMap(cached);
  await for (final child in repo.watchChild(childId)) {
    if (child != null) await store.setJson(key, child.toMap());
    yield child;
  }
});

final caregiverLinksProvider =
    StreamProvider.family<List<CaregiverLink>, String>((ref, childId) {
      ref.watch(sessionUidProvider);
      return ref.watch(childrenRepositoryProvider).watchLinks(childId);
    });

final invitationsProvider = StreamProvider.family<List<Invitation>, String>((
  ref,
  childId,
) {
  final user = ref.watch(currentUserProvider);
  final child = ref.watch(childProvider(childId)).value;
  if (user == null || child == null) return Stream.value(const []);
  return ref
      .watch(childrenRepositoryProvider)
      .watchInvitations(child, user.uid);
});
