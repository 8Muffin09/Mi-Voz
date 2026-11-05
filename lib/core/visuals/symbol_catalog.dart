part 'symbol_ids.g.dart';

/// Catálogo central de pictogramas ilustrados (comunicación).
///
/// Cada pictograma tiene un identificador estable (`quiero_agua`,
/// `cat_necesito`, `pal_pizza`...) y un archivo en
/// `assets/pictograms/<id>.png`, incluido en la app para que funcione sin
/// internet. Procedencia y licencia: `assets/pictograms/ATRIBUCION.md`.
///
/// Los datos guardan el identificador (en el campo heredado `emoji`). Los
/// datos anteriores al catálogo guardaban un emoji: [resolve] lo traduce con
/// [legacyEmoji], así las frases y favoritos existentes conservan su
/// significado con la nueva imagen. El texto y la voz nunca dependen de la
/// imagen.
class SymbolCatalog {
  const SymbolCatalog._();

  static const assetDir = 'assets/pictograms';

  /// Todos los identificadores incluidos en la app.
  static Set<String> get ids => _bundledSymbolIds;

  /// Pictogramas sugeridos al crear un pictograma propio.
  static List<String> get palette => _paletteSymbolIds;

  static bool isSymbolId(String? value) =>
      value != null && _bundledSymbolIds.contains(value);

  /// Identificador del catálogo para un valor guardado (identificador o
  /// emoji heredado). `null` si no hay ilustración equivalente.
  static String? resolve(String? value) {
    if (value == null || value.isEmpty) return null;
    if (_bundledSymbolIds.contains(value)) return value;
    final mapped = legacyEmoji[value] ?? legacyEmoji[_stripVariation(value)];
    return mapped;
  }

  /// Ruta del recurso para un valor guardado, o `null`.
  static String? assetFor(String? value) {
    final id = resolve(value);
    return id == null ? null : '$assetDir/$id.png';
  }

  /// Identificador a guardar: convierte los emojis heredados conocidos.
  static String normalize(String value) => resolve(value) ?? value;

  /// Nombre accesible de los pictogramas de la paleta.
  static const paletteLabels = <String, String>{
    'pal_pizza': 'Pizza',
    'pal_platano': 'Plátano',
    'pal_galleta': 'Galleta',
    'pal_jugo': 'Jugo',
    'pal_leche': 'Leche',
    'pal_helado': 'Helado',
    'pal_bicicleta': 'Bicicleta',
    'pal_videojuego': 'Videojuego',
    'pal_television': 'Televisión',
    'pal_tableta': 'Tableta',
    'pal_rompecabezas': 'Rompecabezas',
    'pal_pintar': 'Pintar',
    'pal_globo': 'Globo',
    'pal_perro': 'Perro',
    'pal_gato': 'Gato',
    'pal_columpio': 'Columpio',
    'pal_nadar': 'Nadar',
    'pal_mochila': 'Mochila',
    'pal_calcetines': 'Calcetines',
    'pal_zapatos': 'Zapatos',
    'pal_gorra': 'Gorra',
    'pal_banera': 'Bañera',
    'pal_medicina': 'Medicina',
    'pal_curita': 'Curita',
    'pal_cama': 'Cama',
    'pal_autobus': 'Autobús',
    'pal_hospital': 'Hospital',
    'pal_abuela': 'Abuela',
    'pal_abuelo': 'Abuelo',
    'pal_nino': 'Niño',
    'pal_nina': 'Niña',
    'pal_maestro': 'Maestro',
    'pal_pastel': 'Pastel',
    'pal_noche': 'Noche',
    'pal_estrella': 'Estrella',
    'pal_corazon': 'Corazón',
  };

  static String _stripVariation(String s) => s.replaceAll('️', '');

  /// Emojis de versiones anteriores → pictograma equivalente. No se borra:
  /// los perfiles, favoritos, frases y solicitudes guardados antes del
  /// catálogo siguen mostrándose con la ilustración correcta.
  static const legacyEmoji = <String, String>{
    // Categorías y ayuda urgente
    '🙌': 'cat_quiero',
    '🙏': 'cat_necesito',
    '🌡️': 'cat_tengo',
    '🌡': 'cat_tengo',
    '😊': 'me_siento_feliz',
    '🤕': 'me_duele_cabeza',
    '😖': 'tengo_dolor',
    '🙅': 'cat_no_quiero',
    '🚶': 'cat_quiero_ir',
    '🤝': 'cat_ayudame',
    '🆘': 'urg_sos',
    '🤒': 'me_siento_enfermo',
    '😨': 'tengo_miedo',
    '😣': 'me_siento_incomodo',
    '🚪': 'quiero_salir',
    '🙋': 'necesito_ayuda',
    // Frases frecuentes
    '💧': 'quiero_agua',
    '🚻': 'necesito_bano',
    '🔊': 'me_molesta_ruido',
    '🛋️': 'necesito_descansar',
    '🛋': 'necesito_descansar',
    '🏠': 'quiero_ir_casa',
    '💬': 'necesito_hablar',
    // Pictogramas base
    '🍽️': 'quiero_comida',
    '🍽': 'quiero_comida',
    '⚽': 'quiero_jugar',
    '😴': 'quiero_dormir',
    '🤗': 'quiero_abrazo',
    '🌳': 'quiero_ir_parque',
    '🧸': 'quiero_juguetes',
    '🎵': 'quiero_musica',
    '📖': 'quiero_cuento',
    '🖍️': 'quiero_dibujar',
    '🖍': 'quiero_dibujar',
    '🚽': 'necesito_bano',
    '🧘': 'necesito_solo',
    '🎧': 'necesito_audifonos',
    '🗣️': 'necesito_hablar',
    '🗣': 'necesito_hablar',
    '🍎': 'necesito_comer',
    '🚰': 'necesito_agua',
    '🥶': 'tengo_frio',
    '🥵': 'tengo_calor',
    '😋': 'tengo_hambre',
    '🥤': 'tengo_sed',
    '😪': 'tengo_sueno',
    '😩': 'tengo_cansancio',
    '😢': 'me_siento_triste',
    '😠': 'me_siento_enojado',
    '😬': 'me_siento_nervioso',
    '😱': 'me_siento_asustado',
    '😌': 'me_siento_tranquilo',
    '😕': 'me_siento_confundido',
    '🤯': 'me_siento_saturado',
    '🤢': 'me_duele_estomago',
    '🧣': 'me_duele_garganta',
    '🦷': 'me_duele_dientes',
    '👂': 'me_duele_oidos',
    '👀': 'me_duele_ojos',
    '💪': 'me_duele_brazos',
    '✋': 'me_duele_manos',
    '🦵': 'me_duele_piernas',
    '🦶': 'me_duele_pies',
    '💡': 'me_molesta_luz',
    '👥': 'me_molesta_personas',
    '👃': 'me_molesta_olor',
    '🧶': 'me_molesta_textura',
    '🚫': 'me_molesta_contacto',
    '👕': 'me_molesta_ropa',
    '🥄': 'no_quiero_comer',
    '🛏️': 'pal_cama',
    '🛏': 'pal_cama',
    '🛁': 'no_quiero_banarme',
    '🎲': 'no_quiero_jugar',
    '🤐': 'no_quiero_hablar',
    '👉': 'no_quiero_eso',
    '🔄': 'no_quiero_cambiar',
    '☀️': 'quiero_ir_afuera',
    '☀': 'quiero_ir_afuera',
    '🏫': 'quiero_ir_escuela',
    '👩': 'quiero_ir_mama',
    '👨': 'quiero_ir_papa',
    '🌈': 'quiero_ir_tranquilo',
    '🚗': 'quiero_ir_carro',
    '📦': 'ayudame_abrir',
    '🍴': 'ayudame_comer',
    '🔍': 'ayudame_encontrar',
    '💗': 'ayudame_calmarme',
    '✏️': 'ayudame_tarea',
    '✏': 'ayudame_tarea',
    '🧼': 'ayudame_manos',
    // Paleta de pictogramas propios
    '⭐': 'pal_estrella',
    '❤️': 'pal_corazon',
    '❤': 'pal_corazon',
    '🍕': 'pal_pizza',
    '🍌': 'pal_platano',
    '🍪': 'pal_galleta',
    '🧃': 'pal_jugo',
    '🥛': 'pal_leche',
    '🍦': 'pal_helado',
    '🚲': 'pal_bicicleta',
    '🎮': 'pal_videojuego',
    '📺': 'pal_television',
    '📱': 'pal_tableta',
    '🧩': 'pal_rompecabezas',
    '🎨': 'pal_pintar',
    '🎈': 'pal_globo',
    '🐶': 'pal_perro',
    '🐱': 'pal_gato',
    '🎠': 'pal_columpio',
    '🏊': 'pal_nadar',
    '🎒': 'pal_mochila',
    '🧦': 'pal_calcetines',
    '👟': 'pal_zapatos',
    '🧢': 'pal_gorra',
    '🛀': 'pal_banera',
    '💊': 'pal_medicina',
    '🩹': 'pal_curita',
    '🛌': 'pal_cama',
    '🚌': 'pal_autobus',
    '🏥': 'pal_hospital',
    '👵': 'pal_abuela',
    '👴': 'pal_abuelo',
    '👦': 'pal_nino',
    '👧': 'pal_nina',
    '🧑‍🏫': 'pal_maestro',
    '🎂': 'pal_pastel',
    '🌙': 'pal_noche',
  };
}
