import '../core/utils/json_utils.dart';
import 'app_user.dart';

enum StrategyPlace {
  home('Casa'),
  school('Escuela'),
  therapy('Terapia'),
  community('Comunidad'),
  other('Otro');

  const StrategyPlace(this.label);
  final String label;
}

enum StrategyResult {
  worked('Funcionó'),
  partial('Funcionó en parte'),
  notWorked('No funcionó'),
  toTry('Por probar');

  const StrategyResult(this.label);
  final String label;
}

/// Estrategia de apoyo compartida entre hogar y escuela.
class SupportStrategy {
  const SupportStrategy({
    required this.id,
    required this.childId,
    required this.title,
    required this.place,
    required this.result,
    required this.createdByUid,
    required this.createdByName,
    required this.createdByRole,
    required this.createdAt,
    this.description = '',
    this.updatedAt,
  });

  final String id;
  final String childId;
  final String title;
  final String description;
  final StrategyPlace place;
  final StrategyResult result;
  final String createdByUid;
  final String createdByName;
  final AdultRole createdByRole;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SupportStrategy copyWith({
    String? title,
    String? description,
    StrategyPlace? place,
    StrategyResult? result,
    DateTime? updatedAt,
  }) => SupportStrategy(
    id: id,
    childId: childId,
    title: title ?? this.title,
    description: description ?? this.description,
    place: place ?? this.place,
    result: result ?? this.result,
    createdByUid: createdByUid,
    createdByName: createdByName,
    createdByRole: createdByRole,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'childId': childId,
    'title': title,
    'description': description,
    'place': place.name,
    'result': result.name,
    'createdByUid': createdByUid,
    'createdByName': createdByName,
    'createdByRole': createdByRole.name,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  factory SupportStrategy.fromMap(Map<String, dynamic> map) => SupportStrategy(
    id: readString(map['id']) ?? '',
    childId: readString(map['childId']) ?? '',
    title: readString(map['title']) ?? '',
    description: readString(map['description']) ?? '',
    place: enumByName(StrategyPlace.values, map['place'], StrategyPlace.other),
    result: enumByName(
      StrategyResult.values,
      map['result'],
      StrategyResult.toTry,
    ),
    createdByUid: readString(map['createdByUid']) ?? '',
    createdByName: readString(map['createdByName']) ?? '',
    createdByRole: enumByName(
      AdultRole.values,
      map['createdByRole'],
      AdultRole.tutor,
    ),
    createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
    updatedAt: parseDate(map['updatedAt']),
  );
}
