import 'package:intl/intl.dart';

final _date = DateFormat('d MMM yyyy', 'es');
final _time = DateFormat('HH:mm', 'es');
final _dayHeader = DateFormat("EEEE d 'de' MMMM", 'es');

String formatDate(DateTime d) => _date.format(d);
String formatTime(DateTime d) => _time.format(d);
String formatDateTime(DateTime d) => '${formatDate(d)} · ${formatTime(d)}';

String formatDayHeader(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Hoy';
  if (diff == 1) return 'Ayer';
  final text = _dayHeader.format(d);
  return text[0].toUpperCase() + text.substring(1);
}

/// "hace 5 min", "hace 2 h"... para listas de solicitudes.
String formatRelative(DateTime d, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final diff = reference.difference(d);
  if (diff.inSeconds < 60) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  return formatDateTime(d);
}

String capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
