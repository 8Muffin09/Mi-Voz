import 'dart:io';

import '../../../models/pictogram.dart';

/// Favoritos, frases frecuentes y pictogramas personalizados de un niño.
abstract class ContentRepository {
  Stream<ChildContent> watchContent(String childId);

  /// Crea o actualiza un pictograma propio. [image] es opcional.
  Future<Pictogram> saveCustomPictogram(
    String childId,
    Pictogram pictogram, {
    File? image,
  });

  Future<void> deleteCustomPictogram(String childId, Pictogram pictogram);

  Future<void> setFavorite(String childId, String pictogramId, bool favorite);

  Future<void> saveFrequentPhrase(String childId, FrequentPhrase phrase);

  Future<void> deleteFrequentPhrase(String childId, String phraseId);
}
