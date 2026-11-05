import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/pictogram.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../../pictograms/domain/phrase_builder.dart';

/// Frase en construcción en el modo niño.
class PhraseController extends Notifier<PhraseDraft?> {
  @override
  PhraseDraft? build() => null;

  void startWithPictogram(Pictogram pictogram) {
    final category = PictogramCatalog.categoryById(pictogram.categoryId);
    state = PhraseDraft(category: category, items: [pictogram]);
  }

  void startFixed(FrequentPhrase phrase, {bool urgent = false}) {
    state = PhraseDraft.fixed(
      text: phrase.text,
      emoji: phrase.emoji,
      categoryId: urgent
          ? PictogramCatalog.urgentCategoryId
          : phrase.categoryId,
      urgent: urgent,
    );
  }

  void add(Pictogram pictogram) {
    final draft = state;
    if (draft != null) state = draft.add(pictogram);
  }

  void remove(String pictogramId) {
    final draft = state;
    if (draft != null) state = draft.remove(pictogramId);
  }

  void setIntensity(Intensity intensity) {
    final draft = state;
    if (draft != null) state = draft.copyWith(intensity: intensity);
  }

  void togglePolite() {
    final draft = state;
    if (draft != null) state = draft.copyWith(polite: !draft.polite);
  }

  void clear() => state = null;
}

final phraseControllerProvider =
    NotifierProvider<PhraseController, PhraseDraft?>(PhraseController.new);
