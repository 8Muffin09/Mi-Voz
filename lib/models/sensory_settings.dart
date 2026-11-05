import '../core/utils/json_utils.dart';

enum PictogramSize {
  small('Pequeño', 110),
  medium('Mediano', 140),
  large('Grande', 180),
  extraLarge('Muy grande', 230);

  const PictogramSize(this.label, this.tileExtent);
  final String label;

  /// Ancho máximo aproximado de cada pictograma en la cuadrícula.
  final double tileExtent;
}

/// Preferencias sensoriales y de accesibilidad de un niño.
/// Se guardan dentro del perfil infantil y también en caché local.
class SensorySettings {
  const SensorySettings({
    this.soundsEnabled = true,
    this.vibrationEnabled = true,
    this.speakOnSelect = true,
    this.ttsRate = 0.45,
    this.ttsPitch = 1.0,
    this.ttsVolume = 1.0,
    this.ttsLanguage = 'es-MX',
    this.pictogramSize = PictogramSize.medium,
    this.pictogramsPerPage = 9,
    this.highContrast = false,
    this.calmMode = false,
    this.hiddenCategoryIds = const [],
    this.hiddenPictogramIds = const [],
  });

  final bool soundsEnabled;
  final bool vibrationEnabled;

  /// Leer en voz alta el nombre del pictograma al tocarlo.
  final bool speakOnSelect;
  final double ttsRate;
  final double ttsPitch;
  final double ttsVolume;
  final String ttsLanguage;
  final PictogramSize pictogramSize;

  /// 0 = mostrar todos (con desplazamiento).
  final int pictogramsPerPage;
  final bool highContrast;
  final bool calmMode;
  final List<String> hiddenCategoryIds;
  final List<String> hiddenPictogramIds;

  static const pageSizeOptions = [4, 6, 9, 12, 0];
  static const languageOptions = {
    'es-MX': 'Español (México)',
    'es-ES': 'Español (España)',
    'es-US': 'Español (EE. UU.)',
  };

  /// En modo tranquilo se suprimen sonidos de interfaz y animaciones,
  /// pero la voz (comunicación esencial) sigue disponible.
  bool get effectiveSounds => soundsEnabled && !calmMode;
  bool get animationsEnabled => !calmMode;

  SensorySettings copyWith({
    bool? soundsEnabled,
    bool? vibrationEnabled,
    bool? speakOnSelect,
    double? ttsRate,
    double? ttsPitch,
    double? ttsVolume,
    String? ttsLanguage,
    PictogramSize? pictogramSize,
    int? pictogramsPerPage,
    bool? highContrast,
    bool? calmMode,
    List<String>? hiddenCategoryIds,
    List<String>? hiddenPictogramIds,
  }) => SensorySettings(
    soundsEnabled: soundsEnabled ?? this.soundsEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    speakOnSelect: speakOnSelect ?? this.speakOnSelect,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsPitch: ttsPitch ?? this.ttsPitch,
    ttsVolume: ttsVolume ?? this.ttsVolume,
    ttsLanguage: ttsLanguage ?? this.ttsLanguage,
    pictogramSize: pictogramSize ?? this.pictogramSize,
    pictogramsPerPage: pictogramsPerPage ?? this.pictogramsPerPage,
    highContrast: highContrast ?? this.highContrast,
    calmMode: calmMode ?? this.calmMode,
    hiddenCategoryIds: hiddenCategoryIds ?? this.hiddenCategoryIds,
    hiddenPictogramIds: hiddenPictogramIds ?? this.hiddenPictogramIds,
  );

  Map<String, dynamic> toMap() => {
    'soundsEnabled': soundsEnabled,
    'vibrationEnabled': vibrationEnabled,
    'speakOnSelect': speakOnSelect,
    'ttsRate': ttsRate,
    'ttsPitch': ttsPitch,
    'ttsVolume': ttsVolume,
    'ttsLanguage': ttsLanguage,
    'pictogramSize': pictogramSize.name,
    'pictogramsPerPage': pictogramsPerPage,
    'highContrast': highContrast,
    'calmMode': calmMode,
    'hiddenCategoryIds': hiddenCategoryIds,
    'hiddenPictogramIds': hiddenPictogramIds,
  };

  factory SensorySettings.fromMap(Map<String, dynamic> map) {
    const d = SensorySettings();
    final perPage = readInt(map['pictogramsPerPage'], d.pictogramsPerPage);
    return SensorySettings(
      soundsEnabled: readBool(map['soundsEnabled'], d.soundsEnabled),
      vibrationEnabled: readBool(map['vibrationEnabled'], d.vibrationEnabled),
      speakOnSelect: readBool(map['speakOnSelect'], d.speakOnSelect),
      ttsRate: readDouble(map['ttsRate'], d.ttsRate).clamp(0.1, 1.0),
      ttsPitch: readDouble(map['ttsPitch'], d.ttsPitch).clamp(0.5, 2.0),
      ttsVolume: readDouble(map['ttsVolume'], d.ttsVolume).clamp(0.0, 1.0),
      ttsLanguage: readString(map['ttsLanguage']) ?? d.ttsLanguage,
      pictogramSize: enumByName(
        PictogramSize.values,
        map['pictogramSize'],
        d.pictogramSize,
      ),
      pictogramsPerPage: pageSizeOptions.contains(perPage)
          ? perPage
          : d.pictogramsPerPage,
      highContrast: readBool(map['highContrast'], d.highContrast),
      calmMode: readBool(map['calmMode'], d.calmMode),
      hiddenCategoryIds: readStringList(map['hiddenCategoryIds']),
      hiddenPictogramIds: readStringList(map['hiddenPictogramIds']),
    );
  }
}
