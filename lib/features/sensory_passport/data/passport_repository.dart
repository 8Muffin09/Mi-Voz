import '../../../models/sensory_passport.dart';

abstract class PassportRepository {
  Stream<SensoryPassport> watchPassport(String childId);

  Future<void> savePassport(
    SensoryPassport passport, {
    required String editorName,
  });
}
