import '../../../models/child_profile.dart';
import '../../../models/pictogram.dart';

enum Intensity {
  little('Un poco'),
  normal('Normal'),
  much('Mucho');

  const Intensity(this.label);
  final String label;
}

/// Borrador de la frase que el niño está construyendo.
///
/// Puede venir de pictogramas (categoría + elementos) o ser una frase
/// completa ya hecha ([fixedText]: frases frecuentes y ayuda urgente).
class PhraseDraft {
  const PhraseDraft({
    this.category,
    this.items = const [],
    this.intensity = Intensity.normal,
    this.polite = false,
    this.fixedText,
    this.fixedEmoji,
    this.fixedCategoryId,
    this.urgent = false,
  });

  /// Frase completa sin construir (frecuente o urgente).
  const PhraseDraft.fixed({
    required String text,
    required String emoji,
    String? categoryId,
    bool urgent = false,
  }) : this(
         fixedText: text,
         fixedEmoji: emoji,
         fixedCategoryId: categoryId,
         urgent: urgent,
       );

  static const maxItems = 3;

  final PictogramCategory? category;
  final List<Pictogram> items;
  final Intensity intensity;
  final bool polite;
  final String? fixedText;
  final String? fixedEmoji;
  final String? fixedCategoryId;
  final bool urgent;

  bool get isFixed => fixedText != null;
  bool get isEmpty => !isFixed && items.isEmpty;
  bool get canAddMore => !isFixed && items.length < maxItems;
  bool get supportsIntensity =>
      !isFixed &&
      category != null &&
      category!.intensityStyle != IntensityStyle.none;

  String get emoji =>
      fixedEmoji ??
      (items.isNotEmpty
          ? items.first.emoji
          : category?.emoji ?? 'necesito_hablar');

  String get categoryId => fixedCategoryId ?? category?.id ?? 'frase';

  PhraseDraft copyWith({
    PictogramCategory? category,
    List<Pictogram>? items,
    Intensity? intensity,
    bool? polite,
  }) => PhraseDraft(
    category: category ?? this.category,
    items: items ?? this.items,
    intensity: intensity ?? this.intensity,
    polite: polite ?? this.polite,
    fixedText: fixedText,
    fixedEmoji: fixedEmoji,
    fixedCategoryId: fixedCategoryId,
    urgent: urgent,
  );

  /// Agrega un pictograma de la misma categoría (sin repetir, máx. 3).
  PhraseDraft add(Pictogram p) {
    if (isFixed || items.any((i) => i.id == p.id) || !canAddMore) return this;
    if (category != null && p.categoryId != category!.id) return this;
    return copyWith(items: [...items, p]);
  }

  PhraseDraft remove(String pictogramId) =>
      copyWith(items: items.where((i) => i.id != pictogramId).toList());

  /// Reemplaza todos los elementos por uno nuevo ("cambiar").
  PhraseDraft replaceWith(Pictogram p) => copyWith(items: [p]);
}

/// Construye frases en español con concordancia de número y género.
class PhraseBuilder {
  const PhraseBuilder._();

  static String build(
    PhraseDraft draft, {
    GrammaticalGender gender = GrammaticalGender.masculine,
  }) {
    if (draft.isFixed) return draft.fixedText!;
    final category = draft.category;
    if (category == null || draft.items.isEmpty) {
      return category?.stem ?? '';
    }

    final usePlural =
        category.stemPlural != null &&
        (draft.items.length > 1 || draft.items.any((i) => i.plural));
    final verb = usePlural ? category.stemPlural! : category.stem;
    final intensity = draft.intensity;

    late final String body;
    switch (category.intensityStyle) {
      case IntensityStyle.none:
        body = '$verb ${_join(draft.items.map((i) => i.fragmentFor(gender)))}';
      case IntensityStyle.afterVerb:
        final adverb = switch (intensity) {
          Intensity.little => ' un poco',
          Intensity.normal => '',
          Intensity.much => ' mucho',
        };
        body =
            '$verb$adverb ${_join(draft.items.map((i) => i.fragmentFor(gender)))}';
      case IntensityStyle.adverb:
        final adverb = switch (intensity) {
          Intensity.little => 'un poco ',
          Intensity.normal => '',
          Intensity.much => 'muy ',
        };
        body =
            '$verb $adverb${_join(draft.items.map((i) => i.fragmentFor(gender)))}';
      case IntensityStyle.quantifier:
        body =
            '$verb ${_join(draft.items.map((i) => _quantify(i, intensity, gender)))}';
    }
    return draft.polite ? '$body, por favor' : body;
  }

  static String _quantify(
    Pictogram p,
    Intensity intensity,
    GrammaticalGender gender,
  ) {
    final noun = p.fragmentFor(gender);
    return switch (intensity) {
      Intensity.little => 'un poco de $noun',
      Intensity.normal => noun,
      Intensity.much =>
        '${p.nounGender == NounGender.feminine ? 'mucha' : 'mucho'} $noun',
    };
  }

  /// "a", "a y b", "a, b y c". Usa "e" ante sonido /i/: "tranquilo e incómodo".
  static String _join(Iterable<String> parts) {
    final list = parts.toList();
    if (list.isEmpty) return '';
    if (list.length == 1) return list.first;
    final last = list.last.toLowerCase();
    final useE =
        RegExp(r'^h?[ií]').hasMatch(last) &&
        !RegExp(r'^h?i[aeoáéó]').hasMatch(last);
    final conjunction = useE ? 'e' : 'y';
    return '${list.sublist(0, list.length - 1).join(', ')} $conjunction ${list.last}';
  }
}
