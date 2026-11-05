import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../models/sensory_passport.dart';
import 'passport_repository.dart';

class FirebasePassportRepository implements PassportRepository {
  FirebasePassportRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String childId) => _db
      .collection(FirestorePaths.childSub(childId, FirestorePaths.passports))
      .doc(FirestorePaths.passportDocId);

  @override
  Stream<SensoryPassport> watchPassport(String childId) =>
      _doc(childId).snapshots().map((s) {
        final data = s.data();
        return data == null
            ? SensoryPassport(childId: childId)
            : SensoryPassport.fromMap({...data, 'childId': childId});
      });

  @override
  Future<void> savePassport(
    SensoryPassport passport, {
    required String editorName,
  }) => _doc(passport.childId).set({
    ...passport.toMap(),
    'updatedAt': FieldValue.serverTimestamp(),
    'updatedByName': editorName,
  });
}
