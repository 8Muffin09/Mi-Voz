import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../models/pictogram.dart';
import '../../profiles/application/profiles_providers.dart';
import '../domain/vocabulary.dart';

/// Contenido del niño con caché local para funcionar sin internet.
final childContentProvider = StreamProvider.family<ChildContent, String>((
  ref,
  childId,
) async* {
  ref.watch(sessionUidProvider);
  final store = ref.watch(localStoreProvider);
  final repo = ref.watch(contentRepositoryProvider);
  final key = LocalStore.contentCacheKey(childId);
  final cached = store.getJson(key);
  if (cached != null) yield ChildContent.fromMap(cached);
  await for (final content in repo.watchContent(childId)) {
    await store.setJson(key, content.toMap());
    yield content;
  }
});

/// Vocabulario listo para la interfaz. `null` mientras carga.
final vocabularyProvider = Provider.family<Vocabulary?, String>((ref, childId) {
  final child = ref.watch(childProvider(childId)).value;
  if (child == null) return null;
  final content =
      ref.watch(childContentProvider(childId)).value ?? ChildContent.empty;
  return Vocabulary(child: child, content: content);
});
