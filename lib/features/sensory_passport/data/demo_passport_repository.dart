import '../../../core/demo/demo_database.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/sensory_passport.dart';
import 'passport_repository.dart';

class DemoPassportRepository implements PassportRepository {
  DemoPassportRepository(this._db);

  final DemoDatabase _db;

  /// Como las reglas de Firestore: adulto vinculado al que la familia no le
  /// retiró el permiso de ver el pasaporte.
  bool _canView(String childId) {
    if (!_db.sessionIsMemberOf(childId)) return false;
    final row = _db.get(DemoDatabase.links, '${childId}_${_db.sessionUid}');
    return row == null || CaregiverLink.fromMap(row).canViewPassport;
  }

  @override
  Stream<SensoryPassport> watchPassport(String childId) => _db.watch(() {
    if (!_canView(childId)) return SensoryPassport(childId: childId);
    final row = _db.get(DemoDatabase.passports, childId);
    return row == null
        ? SensoryPassport(childId: childId)
        : SensoryPassport.fromMap(row);
  });

  @override
  Future<void> savePassport(
    SensoryPassport passport, {
    required String editorName,
  }) async {
    if (!_canView(passport.childId)) throw const PermissionDeniedException();
    _db.put(
      DemoDatabase.passports,
      passport.childId,
      passport
          .copyWith(updatedAt: DateTime.now(), updatedByName: editorName)
          .toMap(),
    );
    _db.commit();
  }
}
