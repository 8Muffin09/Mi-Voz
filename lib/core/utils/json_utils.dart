import 'package:cloud_firestore/cloud_firestore.dart';

/// Convierte cualquier representación de fecha (Timestamp de Firestore,
/// ISO-8601, milisegundos o DateTime) a [DateTime] local.
DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  if (value is Timestamp) return value.toDate().toLocal();
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
  return null;
}

String? readString(Object? value) => value is String ? value : null;

List<String> readStringList(Object? value) {
  if (value is Iterable) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}

Map<String, dynamic> readMap(Object? value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> readMapList(Object? value) {
  if (value is Iterable) {
    return value.whereType<Map>().map(readMap).toList(growable: false);
  }
  return const [];
}

double readDouble(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  return fallback;
}

int readInt(Object? value, int fallback) {
  if (value is num) return value.toInt();
  return fallback;
}

bool readBool(Object? value, bool fallback) => value is bool ? value : fallback;

/// Busca un valor de enum por su nombre, con valor por defecto.
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is String) {
    for (final v in values) {
      if (v.name == name) return v;
    }
  }
  return fallback;
}
