import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../models/classroom.dart';

/// Clases (activas y archivadas) en las que la cuenta actual es docente.
final classesProvider = StreamProvider<List<Classroom>>((ref) {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(classesRepositoryProvider).watchClassesForTeacher(uid);
});

final classProvider = StreamProvider.family<Classroom?, String>((ref, id) {
  ref.watch(sessionUidProvider);
  return ref.watch(classesRepositoryProvider).watchClass(id);
});
