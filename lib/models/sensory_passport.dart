import '../core/utils/json_utils.dart';

enum SensitivityLevel {
  none('Sin sensibilidad', 0),
  low('Leve', 1),
  medium('Moderada', 2),
  high('Alta', 3);

  const SensitivityLevel(this.label, this.value);
  final String label;
  final int value;
}

/// Área sensorial del pasaporte.
enum SensoryArea {
  noise('Ruido'),
  light('Luz'),
  touch('Contacto físico'),
  smell('Olores'),
  texture('Texturas');

  const SensoryArea(this.label);
  final String label;
}

class Sensitivity {
  const Sensitivity({this.level = SensitivityLevel.none, this.notes = ''});

  final SensitivityLevel level;
  final String notes;

  Map<String, dynamic> toMap() => {'level': level.name, 'notes': notes};

  factory Sensitivity.fromMap(Map<String, dynamic> map) => Sensitivity(
    level: enumByName(
      SensitivityLevel.values,
      map['level'],
      SensitivityLevel.none,
    ),
    notes: readString(map['notes']) ?? '',
  );
}

/// "Mi Pasaporte Sensorial": información de apoyo comunicativo y sensorial.
/// No es un instrumento clínico ni de diagnóstico.
class SensoryPassport {
  const SensoryPassport({
    required this.childId,
    this.sensitivities = const {},
    this.personalPreferences = '',
    this.favoriteObjects = const [],
    this.calmingActivities = const [],
    this.safePlaces = const [],
    this.triggers = const [],
    this.supportStrategies = const [],
    this.communicationPreferences = '',
    this.updatedAt,
    this.updatedByName,
  });

  final String childId;
  final Map<SensoryArea, Sensitivity> sensitivities;
  final String personalPreferences;
  final List<String> favoriteObjects;
  final List<String> calmingActivities;
  final List<String> safePlaces;

  /// Situaciones que generan molestias.
  final List<String> triggers;
  final List<String> supportStrategies;
  final String communicationPreferences;
  final DateTime? updatedAt;
  final String? updatedByName;

  Sensitivity sensitivity(SensoryArea area) =>
      sensitivities[area] ?? const Sensitivity();

  bool get isEmpty =>
      sensitivities.values.every((s) => s.level == SensitivityLevel.none) &&
      personalPreferences.isEmpty &&
      favoriteObjects.isEmpty &&
      calmingActivities.isEmpty &&
      safePlaces.isEmpty &&
      triggers.isEmpty &&
      supportStrategies.isEmpty &&
      communicationPreferences.isEmpty;

  SensoryPassport copyWith({
    Map<SensoryArea, Sensitivity>? sensitivities,
    String? personalPreferences,
    List<String>? favoriteObjects,
    List<String>? calmingActivities,
    List<String>? safePlaces,
    List<String>? triggers,
    List<String>? supportStrategies,
    String? communicationPreferences,
    DateTime? updatedAt,
    String? updatedByName,
  }) => SensoryPassport(
    childId: childId,
    sensitivities: sensitivities ?? this.sensitivities,
    personalPreferences: personalPreferences ?? this.personalPreferences,
    favoriteObjects: favoriteObjects ?? this.favoriteObjects,
    calmingActivities: calmingActivities ?? this.calmingActivities,
    safePlaces: safePlaces ?? this.safePlaces,
    triggers: triggers ?? this.triggers,
    supportStrategies: supportStrategies ?? this.supportStrategies,
    communicationPreferences:
        communicationPreferences ?? this.communicationPreferences,
    updatedAt: updatedAt ?? this.updatedAt,
    updatedByName: updatedByName ?? this.updatedByName,
  );

  Map<String, dynamic> toMap() => {
    'childId': childId,
    'sensitivities': {
      for (final e in sensitivities.entries) e.key.name: e.value.toMap(),
    },
    'personalPreferences': personalPreferences,
    'favoriteObjects': favoriteObjects,
    'calmingActivities': calmingActivities,
    'safePlaces': safePlaces,
    'triggers': triggers,
    'supportStrategies': supportStrategies,
    'communicationPreferences': communicationPreferences,
    'updatedAt': updatedAt,
    'updatedByName': updatedByName,
  };

  factory SensoryPassport.fromMap(Map<String, dynamic> map) {
    final raw = readMap(map['sensitivities']);
    return SensoryPassport(
      childId: readString(map['childId']) ?? '',
      sensitivities: {
        for (final area in SensoryArea.values)
          if (raw[area.name] != null)
            area: Sensitivity.fromMap(readMap(raw[area.name])),
      },
      personalPreferences: readString(map['personalPreferences']) ?? '',
      favoriteObjects: readStringList(map['favoriteObjects']),
      calmingActivities: readStringList(map['calmingActivities']),
      safePlaces: readStringList(map['safePlaces']),
      triggers: readStringList(map['triggers']),
      supportStrategies: readStringList(map['supportStrategies']),
      communicationPreferences:
          readString(map['communicationPreferences']) ?? '',
      updatedAt: parseDate(map['updatedAt']),
      updatedByName: readString(map['updatedByName']),
    );
  }
}
