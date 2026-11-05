import '../../../core/demo/demo_database.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/support_strategy.dart';
import 'strategies_repository.dart';

class DemoStrategiesRepository implements StrategiesRepository {
  DemoStrategiesRepository(this._db);

  final DemoDatabase _db;

  ChildProfile _child(String id) {
    final row = _db.get(DemoDatabase.children, id);
    if (row == null) throw const AppException('El perfil ya no existe.');
    return ChildProfile.fromMap(row);
  }

  @override
  Stream<List<SupportStrategy>> watchStrategies(String childId) => _db.watch(
    () =>
        !_db.sessionIsMemberOf(childId)
              ? <SupportStrategy>[]
              : _db
                    .where(
                      DemoDatabase.strategies,
                      (r) => r['childId'] == childId,
                    )
                    .map(SupportStrategy.fromMap)
                    .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );

  @override
  Future<void> addStrategy(SupportStrategy strategy) async {
    if (!Permissions.canEditSupport(
      _child(strategy.childId),
      strategy.createdByUid,
    )) {
      throw const PermissionDeniedException();
    }
    _db.put(DemoDatabase.strategies, strategy.id, strategy.toMap());
    _db.commit();
  }

  @override
  Future<void> updateStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  }) async {
    final row = _db.get(DemoDatabase.strategies, strategy.id);
    if (row == null) throw const AppException('La estrategia ya no existe.');
    final original = SupportStrategy.fromMap(row);
    if (!Permissions.canEditStrategy(
      _child(strategy.childId),
      original,
      actor.uid,
    )) {
      throw const PermissionDeniedException(
        'Solo quien registró la estrategia o el administrador puede editarla.',
      );
    }
    _db.put(
      DemoDatabase.strategies,
      strategy.id,
      strategy.copyWith(updatedAt: DateTime.now()).toMap(),
    );
    _db.commit();
  }

  @override
  Future<void> deleteStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  }) async {
    if (!Permissions.canEditStrategy(
      _child(strategy.childId),
      strategy,
      actor.uid,
    )) {
      throw const PermissionDeniedException(
        'Solo quien registró la estrategia o el administrador puede eliminarla.',
      );
    }
    _db.delete(DemoDatabase.strategies, strategy.id);
    _db.commit();
  }
}
