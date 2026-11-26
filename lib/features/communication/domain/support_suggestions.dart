import '../../../models/communication_request.dart';

/// Un apoyo que ya se dio antes en una situación parecida, con lo que el
/// alumno dijo después.
class SupportSuggestion {
  const SupportSuggestion({
    required this.text,
    required this.times,
    required this.better,
    required this.same,
    required this.worse,
    required this.lastUsed,
    required this.sameMessage,
  });

  /// Apoyo tal como lo escribió el adulto la última vez.
  final String text;

  /// Veces que se usó en situaciones parecidas.
  final int times;
  final int better;
  final int same;
  final int worse;
  final DateTime lastUsed;

  /// Se usó cuando comunicó exactamente lo mismo (no solo la misma
  /// categoría).
  final bool sameMessage;

  int get rated => better + same + worse;

  /// Resumen honesto: solo cuenta lo que el alumno valoró.
  String get summary {
    final parts = <String>[
      times == 1 ? 'Usado 1 vez' : 'Usado $times veces',
      if (better > 0) 'se sintió mejor $better',
      if (same > 0) 'igual $same',
      if (worse > 0) 'peor $worse',
      if (rated == 0) 'sin valoración del alumno',
    ];
    return parts.join(' · ');
  }
}

/// "En otras ocasiones le ha servido…": busca en el historial del mismo
/// alumno los apoyos registrados para lo mismo que comunica ahora (o, si no
/// hay, para la misma categoría) y los ordena por cómo dijo sentirse.
///
/// Es una ayuda para el adulto, no una recomendación clínica: no inventa
/// apoyos ni interpreta "Resuelta" como "mejor"; los que el alumno valoró
/// solo como "peor" no se sugieren.
class SupportSuggestions {
  const SupportSuggestions._();

  static const maxResults = 3;

  static List<SupportSuggestion> forRequest(
    CommunicationRequest current,
    List<CommunicationRequest> history,
  ) {
    final groups = <String, _Group>{};
    for (final r in history) {
      final support = r.supportProvided?.trim() ?? '';
      if (r.id == current.id || support.isEmpty) continue;
      if (r.childId != current.childId) continue;
      final sameMessage = _norm(r.message) == _norm(current.message);
      final sharesPictogram = r.pictogramIds.any(current.pictogramIds.contains);
      final sameCategory = r.categoryId == current.categoryId;
      if (!sameMessage && !sharesPictogram && !sameCategory) continue;
      final key = _norm(support);
      final g = groups.putIfAbsent(key, () => _Group(support));
      g.add(r, sameMessage: sameMessage, sharesPictogram: sharesPictogram);
    }
    final list = [
      for (final g in groups.values)
        if (!(g.worse > 0 && g.better == 0 && g.same == 0)) g,
    ]..sort((a, b) => b.score.compareTo(a.score));
    return [for (final g in list.take(maxResults)) g.toSuggestion()];
  }

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N} ]', unicode: true), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _Group {
  _Group(this.text);

  String text;
  int times = 0;
  int better = 0;
  int same = 0;
  int worse = 0;
  bool sameMessage = false;
  bool sharesPictogram = false;
  DateTime lastUsed = DateTime(2000);

  void add(
    CommunicationRequest r, {
    required bool sameMessage,
    required bool sharesPictogram,
  }) {
    times++;
    this.sameMessage |= sameMessage;
    this.sharesPictogram |= sharesPictogram;
    switch (r.childFeedback) {
      case SupportFeedback.better:
        better++;
      case SupportFeedback.same:
        same++;
      case SupportFeedback.worse:
        worse++;
      case SupportFeedback.none || null:
        break;
    }
    final at = r.supportAt ?? r.resolvedAt ?? r.createdAt;
    if (at.isAfter(lastUsed)) {
      lastUsed = at;
      text = r.supportProvided!.trim();
    }
  }

  /// Primero lo que sirvió para lo mismo; luego, lo que más veces lo hizo
  /// sentir mejor; los "peor" restan; a igualdad, lo más reciente.
  double get score =>
      (sameMessage
          ? 100
          : sharesPictogram
          ? 50
          : 0) +
      better * 10 +
      same * 2 -
      worse * 8 +
      times +
      lastUsed.millisecondsSinceEpoch / 1e15;

  SupportSuggestion toSuggestion() => SupportSuggestion(
    text: text,
    times: times,
    better: better,
    same: same,
    worse: worse,
    lastUsed: lastUsed,
    sameMessage: sameMessage,
  );
}
