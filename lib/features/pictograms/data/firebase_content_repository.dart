import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/stream_utils.dart';
import '../../../models/pictogram.dart';
import 'content_repository.dart';

/// Favoritos y frases en `children/{id}/favorites`; pictogramas propios en
/// `children/{id}/pictograms` y sus fotos en Firebase Storage.
class FirebaseContentRepository implements ContentRepository {
  FirebaseContentRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> _favorites(String childId) => _db
      .collection(FirestorePaths.childSub(childId, FirestorePaths.favorites));

  CollectionReference<Map<String, dynamic>> _pictograms(String childId) => _db
      .collection(FirestorePaths.childSub(childId, FirestorePaths.pictograms));

  @override
  Stream<ChildContent> watchContent(String childId) =>
      combineLatestList<QuerySnapshot<Map<String, dynamic>>>([
        _favorites(childId).snapshots(),
        _pictograms(childId).snapshots(),
      ]).map((snaps) {
        final favDocs = snaps[0].docs.map((d) => d.data());
        final favoriteIds = favDocs
            .where((d) => d['type'] == 'pictogram')
            .map((d) => d['pictogramId'])
            .whereType<String>()
            .toList();
        final phrases =
            favDocs
                .where((d) => d['type'] == 'phrase')
                .map(FrequentPhrase.fromMap)
                .toList()
              ..sort((a, b) => a.order - b.order);
        final custom = snaps[1].docs
            .map((d) => Pictogram.fromMap({...d.data(), 'id': d.id}))
            .toList();
        return ChildContent(
          favoritePictogramIds: favoriteIds,
          frequentPhrases: phrases,
          customPictograms: custom,
        );
      });

  @override
  Future<Pictogram> saveCustomPictogram(
    String childId,
    Pictogram pictogram, {
    File? image,
  }) async {
    var saved = pictogram;
    if (image != null) {
      final ref = _storage.ref(
        FirestorePaths.pictogramImage(childId, pictogram.id),
      );
      await ref.putFile(image, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      saved = pictogram.copyWith(imageUrl: () => url, imagePath: () => null);
    }
    await _pictograms(childId).doc(saved.id).set(saved.toMap());
    return saved;
  }

  @override
  Future<void> deleteCustomPictogram(
    String childId,
    Pictogram pictogram,
  ) async {
    if (pictogram.imageUrl != null) {
      try {
        await _storage
            .ref(FirestorePaths.pictogramImage(childId, pictogram.id))
            .delete();
      } on FirebaseException {
        // La foto ya no existe.
      }
    }
    final batch = _db.batch()
      ..delete(_pictograms(childId).doc(pictogram.id))
      ..delete(_favorites(childId).doc('pic_${pictogram.id}'));
    await batch.commit();
  }

  @override
  Future<void> setFavorite(String childId, String pictogramId, bool favorite) {
    final doc = _favorites(childId).doc('pic_$pictogramId');
    return favorite
        ? doc.set({'type': 'pictogram', 'pictogramId': pictogramId})
        : doc.delete();
  }

  @override
  Future<void> saveFrequentPhrase(String childId, FrequentPhrase phrase) =>
      _favorites(childId)
          .doc('phr_${phrase.id}')
          .set({'type': 'phrase', ...phrase.toMap()});

  @override
  Future<void> deleteFrequentPhrase(String childId, String phraseId) =>
      _favorites(childId).doc('phr_$phraseId').delete();
}
