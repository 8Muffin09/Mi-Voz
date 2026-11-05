import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../models/app_user.dart';
import '../../../models/support_strategy.dart';
import 'strategies_repository.dart';

/// Estrategias en `children/{id}/support_strategies`. Las reglas permiten
/// editar o borrar solo al autor o al administrador del perfil.
class FirebaseStrategiesRepository implements StrategiesRepository {
  FirebaseStrategiesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String childId) => _db
      .collection(FirestorePaths.childSub(childId, FirestorePaths.strategies));

  @override
  Stream<List<SupportStrategy>> watchStrategies(String childId) => _col(childId)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(
        (q) => q.docs
            .map((d) => SupportStrategy.fromMap({...d.data(), 'id': d.id}))
            .toList(),
      );

  @override
  Future<void> addStrategy(SupportStrategy strategy) =>
      _col(strategy.childId).doc(strategy.id).set(strategy.toMap());

  @override
  Future<void> updateStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  }) => _col(strategy.childId).doc(strategy.id).update({
    'title': strategy.title,
    'description': strategy.description,
    'place': strategy.place.name,
    'result': strategy.result.name,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> deleteStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  }) => _col(strategy.childId).doc(strategy.id).delete();
}
