import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/demo/demo_database.dart';
import '../../../models/pictogram.dart';
import 'content_repository.dart';

/// Favoritos, frases y pictogramas propios en la base local.
/// Las fotos se copian a la carpeta privada de la app.
class DemoContentRepository implements ContentRepository {
  DemoContentRepository(this._db);

  final DemoDatabase _db;

  ChildContent _read(String childId) {
    final row = _db.get(DemoDatabase.content, childId);
    return row == null ? ChildContent.empty : ChildContent.fromMap(row);
  }

  void _write(String childId, ChildContent content) {
    _db.put(DemoDatabase.content, childId, content.toMap());
    _db.commit();
  }

  @override
  Stream<ChildContent> watchContent(String childId) => _db.watch(
    () => _db.sessionIsMemberOf(childId) ? _read(childId) : ChildContent.empty,
  );

  @override
  Future<Pictogram> saveCustomPictogram(
    String childId,
    Pictogram pictogram, {
    File? image,
  }) async {
    var saved = pictogram;
    if (image != null) {
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory('${dir.path}/pictograms');
      await folder.create(recursive: true);
      final copy = await image.copy('${folder.path}/${pictogram.id}.jpg');
      saved = pictogram.copyWith(imagePath: () => copy.path);
    }
    final content = _read(childId);
    final others = content.customPictograms.where((p) => p.id != saved.id);
    _write(childId, content.copyWith(customPictograms: [...others, saved]));
    return saved;
  }

  @override
  Future<void> deleteCustomPictogram(
    String childId,
    Pictogram pictogram,
  ) async {
    final content = _read(childId);
    final path = pictogram.imagePath;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    _write(
      childId,
      content.copyWith(
        customPictograms: content.customPictograms
            .where((p) => p.id != pictogram.id)
            .toList(),
        favoritePictogramIds: content.favoritePictogramIds
            .where((id) => id != pictogram.id)
            .toList(),
      ),
    );
  }

  @override
  Future<void> setFavorite(
    String childId,
    String pictogramId,
    bool favorite,
  ) async {
    final content = _read(childId);
    final ids = content.favoritePictogramIds.where((id) => id != pictogramId);
    _write(
      childId,
      content.copyWith(
        favoritePictogramIds: favorite ? [...ids, pictogramId] : ids.toList(),
      ),
    );
  }

  @override
  Future<void> saveFrequentPhrase(String childId, FrequentPhrase phrase) async {
    final content = _read(childId);
    final list = [...content.frequentPhrases];
    final index = list.indexWhere((p) => p.id == phrase.id);
    if (index >= 0) {
      list[index] = phrase;
    } else {
      list.add(phrase.copyWith(order: list.length));
    }
    _write(childId, content.copyWith(frequentPhrases: list));
  }

  @override
  Future<void> deleteFrequentPhrase(String childId, String phraseId) async {
    final content = _read(childId);
    _write(
      childId,
      content.copyWith(
        frequentPhrases: content.frequentPhrases
            .where((p) => p.id != phraseId)
            .toList(),
      ),
    );
  }
}
