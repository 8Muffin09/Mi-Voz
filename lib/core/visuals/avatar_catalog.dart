/// Colección de avatares ilustrados (identidad del perfil).
///
/// Diseño original de Mi Voz generado con `tool/avatars/generate_avatars.dart`
/// (`assets/avatars/<id>.svg`): mismo lienzo, encuadre de busto, trazo y
/// paleta en toda la colección. El fondo es transparente y lo pinta el color
/// que elige cada perfil.
///
/// Los perfiles guardan el identificador ([AvatarArt.id]); nunca la posición
/// en la galería. Los valores anteriores (emojis) se traducen con
/// [AvatarCatalog.resolve].
enum AvatarGroup {
  animals('Animales'),
  characters('Personajes'),
  portraits('Retratos');

  const AvatarGroup(this.label);
  final String label;
}

class AvatarArt {
  const AvatarArt(this.id, this.label, this.group);

  final String id;

  /// Descripción accesible ("León", "Persona de cabello rizado").
  final String label;
  final AvatarGroup group;

  String get asset => '${AvatarCatalog.assetDir}/$id.svg';
}

class AvatarCatalog {
  const AvatarCatalog._();

  static const assetDir = 'assets/avatars';

  static const animals = <AvatarArt>[
    AvatarArt('animal_lion', 'León', AvatarGroup.animals),
    AvatarArt('animal_bear', 'Oso', AvatarGroup.animals),
    AvatarArt('animal_panda', 'Panda', AvatarGroup.animals),
    AvatarArt('animal_koala', 'Koala', AvatarGroup.animals),
    AvatarArt('animal_fox', 'Zorro', AvatarGroup.animals),
    AvatarArt('animal_tiger', 'Tigre', AvatarGroup.animals),
    AvatarArt('animal_frog', 'Rana', AvatarGroup.animals),
    AvatarArt('animal_monkey', 'Mono', AvatarGroup.animals),
    AvatarArt('animal_dog', 'Perro', AvatarGroup.animals),
    AvatarArt('animal_cat', 'Gato', AvatarGroup.animals),
    AvatarArt('animal_rabbit', 'Conejo', AvatarGroup.animals),
    AvatarArt('animal_unicorn', 'Unicornio', AvatarGroup.animals),
    AvatarArt('animal_turtle', 'Tortuga', AvatarGroup.animals),
    AvatarArt('animal_owl', 'Búho', AvatarGroup.animals),
    AvatarArt('animal_penguin', 'Pingüino', AvatarGroup.animals),
    AvatarArt('animal_elephant', 'Elefante', AvatarGroup.animals),
    AvatarArt('animal_mouse', 'Ratón', AvatarGroup.animals),
    AvatarArt('animal_chick', 'Pollito', AvatarGroup.animals),
  ];

  static const characters = <AvatarArt>[
    AvatarArt('character_robot', 'Robot', AvatarGroup.characters),
    AvatarArt('character_star', 'Estrella', AvatarGroup.characters),
    AvatarArt('character_cloud', 'Nube', AvatarGroup.characters),
    AvatarArt('character_flower', 'Flor', AvatarGroup.characters),
    AvatarArt('character_sun', 'Sol', AvatarGroup.characters),
    AvatarArt('character_leaf', 'Hoja', AvatarGroup.characters),
  ];

  static const portraits = <AvatarArt>[
    AvatarArt(
      'adult_long_brown',
      'Persona de cabello largo castaño',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_short_brown',
      'Persona de cabello corto castaño',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_short_black',
      'Persona de cabello corto negro',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_curly_black',
      'Persona de cabello rizado',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_shortcurly_beard',
      'Persona de cabello rizado corto y barba',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_bob_auburn',
      'Persona de melena pelirroja',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_gray_beard',
      'Persona de cabello gris y barba',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_bun_gray',
      'Persona de cabello gris recogido con lentes',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_bald_glasses',
      'Persona calva con lentes',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_long_black_glasses',
      'Persona de cabello largo negro con lentes',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_sidepart_glasses',
      'Persona de cabello peinado de lado con lentes',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_buzz_glasses',
      'Persona de cabello muy corto con lentes',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_ponytail_blond',
      'Persona de cabello rubio con coleta',
      AvatarGroup.portraits,
    ),
    AvatarArt('adult_locs', 'Persona con rastas', AvatarGroup.portraits),
    AvatarArt(
      'adult_headscarf',
      'Persona con pañuelo en la cabeza',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_wavy_brown',
      'Persona de cabello ondulado',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_short_blond_beard',
      'Persona de cabello rubio y barba',
      AvatarGroup.portraits,
    ),
    AvatarArt(
      'adult_curly_brown',
      'Persona de cabello rizado castaño',
      AvatarGroup.portraits,
    ),
  ];

  /// Galería de los perfiles infantiles.
  static const forChildren = [...animals, ...characters];

  /// Galería de los adultos: retratos y personajes neutros. Ningún rol tiene
  /// una apariencia asignada.
  static const forAdults = [...portraits, ...characters];

  static const all = [...animals, ...characters, ...portraits];

  static const defaultChild = 'animal_lion';

  /// Neutro: no supone ninguna apariencia.
  static const defaultAdult = 'character_leaf';

  static final Map<String, AvatarArt> _byId = {for (final a in all) a.id: a};

  static AvatarArt? byId(String? id) => id == null ? null : _byId[id];

  /// Avatar para un valor guardado (identificador o emoji heredado).
  static AvatarArt? resolve(String? value) {
    if (value == null || value.isEmpty) return null;
    return _byId[value] ?? _byId[legacyEmoji[value] ?? ''];
  }

  /// Identificador a guardar (traduce los emojis heredados conocidos).
  static String normalize(String? value, {required String fallback}) =>
      resolve(value)?.id ?? fallback;

  /// Emojis de versiones anteriores → avatar ilustrado equivalente.
  static const legacyEmoji = <String, String>{
    // Niños
    '🦁': 'animal_lion',
    '🐻': 'animal_bear',
    '🐼': 'animal_panda',
    '🐨': 'animal_koala',
    '🦊': 'animal_fox',
    '🐯': 'animal_tiger',
    '🐸': 'animal_frog',
    '🐵': 'animal_monkey',
    '🐶': 'animal_dog',
    '🐱': 'animal_cat',
    '🐰': 'animal_rabbit',
    '🦄': 'animal_unicorn',
    '🐢': 'animal_turtle',
    '🐬': 'animal_penguin',
    '🦋': 'animal_owl',
    '🐝': 'animal_chick',
    '🚀': 'character_robot',
    '⭐': 'character_star',
    '🌈': 'character_cloud',
    '🌻': 'character_flower',
    '🍀': 'character_leaf',
    // Adultos
    '👩': 'adult_long_brown',
    '👨': 'adult_short_brown',
    '🧑': 'adult_short_black',
    '👩‍🦱': 'adult_curly_black',
    '👨‍🦱': 'adult_shortcurly_beard',
    '👩‍🦰': 'adult_bob_auburn',
    '👨‍🦳': 'adult_gray_beard',
    '👵': 'adult_bun_gray',
    '👴': 'adult_bald_glasses',
    '👩‍🏫': 'adult_long_black_glasses',
    '👨‍🏫': 'adult_sidepart_glasses',
    '🧑‍🏫': 'adult_buzz_glasses',
    '🤝': 'character_leaf',
  };
}
