import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../models/family.dart';

/// Familias de la cuenta actual.
final familiesProvider = StreamProvider<List<Family>>((ref) {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(familiesRepositoryProvider).watchFamiliesForAdult(uid);
});

final familyProvider = StreamProvider.family<Family?, String>((ref, id) {
  ref.watch(sessionUidProvider);
  return ref.watch(familiesRepositoryProvider).watchFamily(id);
});

/// Actualización de datos anteriores a las familias: se ejecuta una vez por
/// sesión para los adultos con perfil de familia. Agrupa en su familia los
/// perfiles que administran y que aún no tienen familia (sin perder datos).
final familyMigrationProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(sessionUidProvider);
  final user = ref.read(currentUserProvider);
  if (uid == null || user == null || !user.isGuardian) return;
  await ref.read(familiesRepositoryProvider).adoptOrphanChildren(user);
});
