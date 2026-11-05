import '../core/utils/json_utils.dart';
import 'child_profile.dart';

/// Cómo se expresa la intensidad ("mucho", "un poco") en cada categoría.
enum IntensityStyle {
  /// Sin intensidad: "Quiero agua".
  none,

  /// Después del verbo: "Me duele mucho la cabeza".
  afterVerb,

  /// Adverbio antes del adjetivo: "Me siento muy feliz".
  adverb,

  /// Cuantificador con género del sustantivo: "Tengo mucha hambre".
  quantifier,
}

/// Categoría de pictogramas (QUIERO, NECESITO...).
class PictogramCategory {
  const PictogramCategory({
    required this.id,
    required this.title,
    required this.stem,
    required this.emoji,
    required this.color,
    required this.order,
    this.stemPlural,
    this.intensityStyle = IntensityStyle.none,
  });

  final String id;

  /// Texto del botón: "ME DUELE".
  final String title;

  /// Inicio de la frase: "Me duele".
  final String stem;

  /// Variante plural del verbo: "Me duelen".
  final String? stemPlural;
  final String emoji;
  final int color;
  final int order;
  final IntensityStyle intensityStyle;
}

enum NounGender { masculine, feminine }

/// Pictograma: imagen + fragmento de frase.
class Pictogram {
  const Pictogram({
    required this.id,
    required this.categoryId,
    required this.label,
    required this.fragment,
    required this.emoji,
    this.labelFeminine,
    this.fragmentFeminine,
    this.plural = false,
    this.nounGender = NounGender.masculine,
    this.imagePath,
    this.imageUrl,
    this.builtIn = true,
    this.order = 0,
  });

  final String id;
  final String categoryId;
  final String label;
  final String? labelFeminine;

  /// Parte de la frase tras el verbo: "la cabeza", "agua", "a casa".
  final String fragment;
  final String? fragmentFeminine;

  /// Pictograma ilustrado: identificador de `SymbolCatalog` (los datos
  /// anteriores pueden traer un emoji, que el catálogo traduce).
  final String emoji;

  /// Si es plural, el verbo concuerda: "Me duelen los pies".
  final bool plural;
  final NounGender nounGender;

  /// Foto local (modo demostración o caché).
  final String? imagePath;

  /// Foto en Firebase Storage.
  final String? imageUrl;
  final bool builtIn;
  final int order;

  String labelFor(GrammaticalGender gender) =>
      gender == GrammaticalGender.feminine && labelFeminine != null
      ? labelFeminine!
      : label;

  String fragmentFor(GrammaticalGender gender) =>
      gender == GrammaticalGender.feminine && fragmentFeminine != null
      ? fragmentFeminine!
      : fragment;

  bool get hasImage =>
      (imagePath?.isNotEmpty ?? false) || (imageUrl?.isNotEmpty ?? false);

  Pictogram copyWith({
    String? categoryId,
    String? label,
    String? fragment,
    String? emoji,
    bool? plural,
    NounGender? nounGender,
    String? Function()? imagePath,
    String? Function()? imageUrl,
  }) => Pictogram(
    id: id,
    categoryId: categoryId ?? this.categoryId,
    label: label ?? this.label,
    labelFeminine: labelFeminine,
    fragment: fragment ?? this.fragment,
    fragmentFeminine: fragmentFeminine,
    emoji: emoji ?? this.emoji,
    plural: plural ?? this.plural,
    nounGender: nounGender ?? this.nounGender,
    imagePath: imagePath != null ? imagePath() : this.imagePath,
    imageUrl: imageUrl != null ? imageUrl() : this.imageUrl,
    builtIn: builtIn,
    order: order,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'categoryId': categoryId,
    'label': label,
    'labelFeminine': labelFeminine,
    'fragment': fragment,
    'fragmentFeminine': fragmentFeminine,
    'emoji': emoji,
    'plural': plural,
    'nounGender': nounGender.name,
    'imagePath': imagePath,
    'imageUrl': imageUrl,
    'builtIn': builtIn,
    'order': order,
  };

  factory Pictogram.fromMap(Map<String, dynamic> map) => Pictogram(
    id: readString(map['id']) ?? '',
    categoryId: readString(map['categoryId']) ?? '',
    label: readString(map['label']) ?? '',
    labelFeminine: readString(map['labelFeminine']),
    fragment: readString(map['fragment']) ?? '',
    fragmentFeminine: readString(map['fragmentFeminine']),
    emoji: readString(map['emoji']) ?? 'pal_estrella',
    plural: readBool(map['plural'], false),
    nounGender: enumByName(
      NounGender.values,
      map['nounGender'],
      NounGender.masculine,
    ),
    imagePath: readString(map['imagePath']),
    imageUrl: readString(map['imageUrl']),
    builtIn: readBool(map['builtIn'], false),
    order: readInt(map['order'], 0),
  );
}

/// Frase frecuente configurada por el adulto ("Necesito agua").
class FrequentPhrase {
  const FrequentPhrase({
    required this.id,
    required this.text,
    required this.emoji,
    this.categoryId,
    this.order = 0,
  });

  final String id;
  final String text;
  final String emoji;
  final String? categoryId;
  final int order;

  FrequentPhrase copyWith({String? text, String? emoji, int? order}) =>
      FrequentPhrase(
        id: id,
        text: text ?? this.text,
        emoji: emoji ?? this.emoji,
        categoryId: categoryId,
        order: order ?? this.order,
      );

  Map<String, dynamic> toMap() => {
    'id': id,
    'text': text,
    'emoji': emoji,
    'categoryId': categoryId,
    'order': order,
  };

  factory FrequentPhrase.fromMap(Map<String, dynamic> map) => FrequentPhrase(
    id: readString(map['id']) ?? '',
    text: readString(map['text']) ?? '',
    emoji: readString(map['emoji']) ?? 'necesito_hablar',
    categoryId: readString(map['categoryId']),
    order: readInt(map['order'], 0),
  );
}

/// Contenido personalizable de un niño: favoritos, frases y pictogramas propios.
class ChildContent {
  const ChildContent({
    this.favoritePictogramIds = const [],
    this.frequentPhrases = const [],
    this.customPictograms = const [],
  });

  final List<String> favoritePictogramIds;
  final List<FrequentPhrase> frequentPhrases;
  final List<Pictogram> customPictograms;

  static const empty = ChildContent();

  ChildContent copyWith({
    List<String>? favoritePictogramIds,
    List<FrequentPhrase>? frequentPhrases,
    List<Pictogram>? customPictograms,
  }) => ChildContent(
    favoritePictogramIds: favoritePictogramIds ?? this.favoritePictogramIds,
    frequentPhrases: frequentPhrases ?? this.frequentPhrases,
    customPictograms: customPictograms ?? this.customPictograms,
  );

  Map<String, dynamic> toMap() => {
    'favoritePictogramIds': favoritePictogramIds,
    'frequentPhrases': frequentPhrases.map((p) => p.toMap()).toList(),
    'customPictograms': customPictograms.map((p) => p.toMap()).toList(),
  };

  factory ChildContent.fromMap(Map<String, dynamic> map) => ChildContent(
    favoritePictogramIds: readStringList(map['favoritePictogramIds']),
    frequentPhrases: readMapList(
      map['frequentPhrases'],
    ).map(FrequentPhrase.fromMap).toList()..sort((a, b) => a.order - b.order),
    customPictograms: readMapList(map['customPictograms'])
        .map(Pictogram.fromMap)
        .toList(),
  );
}
