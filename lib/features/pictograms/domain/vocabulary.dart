import '../../../models/child_profile.dart';
import '../../../models/pictogram.dart';
import '../data/pictogram_catalog.dart';

/// Vocabulario disponible para un niño: catálogo base + pictogramas propios,
/// aplicando categorías y pictogramas ocultos por el adulto.
class Vocabulary {
  Vocabulary({required this.child, required this.content});

  final ChildProfile child;
  final ChildContent content;

  late final List<Pictogram> _all = [
    ...PictogramCatalog.pictograms,
    ...content.customPictograms,
  ];

  late final Map<String, Pictogram> _byId = {for (final p in _all) p.id: p};

  Set<String> get _hiddenCategories => child.settings.hiddenCategoryIds.toSet();
  Set<String> get _hiddenPictograms =>
      child.settings.hiddenPictogramIds.toSet();

  List<PictogramCategory> get allCategories => PictogramCatalog.categories;

  List<PictogramCategory> get visibleCategories => PictogramCatalog.categories
      .where((c) => !_hiddenCategories.contains(c.id))
      .toList(growable: false);

  bool isCategoryHidden(String id) => _hiddenCategories.contains(id);
  bool isPictogramHidden(String id) => _hiddenPictograms.contains(id);
  bool isFavorite(String id) => content.favoritePictogramIds.contains(id);

  Pictogram? byId(String id) => _byId[id];

  /// Pictogramas de una categoría (base primero, luego los propios).
  List<Pictogram> pictogramsFor(
    String categoryId, {
    bool includeHidden = false,
  }) => _all
      .where(
        (p) =>
            p.categoryId == categoryId &&
            (includeHidden || !_hiddenPictograms.contains(p.id)),
      )
      .toList(growable: false);

  /// Favoritos visibles, en el orden en que se marcaron.
  List<Pictogram> get favorites => content.favoritePictogramIds
      .map(byId)
      .nonNulls
      .where(
        (p) =>
            !_hiddenPictograms.contains(p.id) &&
            !_hiddenCategories.contains(p.categoryId),
      )
      .toList(growable: false);

  List<FrequentPhrase> get frequentPhrases => content.frequentPhrases;
}
