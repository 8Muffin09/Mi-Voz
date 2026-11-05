import 'package:flutter/material.dart';

import '../../../models/communication_request.dart';

/// Filtros del historial de solicitudes.
class HistoryFilter {
  const HistoryFilter({
    this.childId,
    this.categoryId,
    this.statuses = const {},
    this.range,
  });

  final String? childId;
  final String? categoryId;
  final Set<RequestStatus> statuses;
  final DateTimeRange? range;

  bool get isActive =>
      childId != null ||
      categoryId != null ||
      statuses.isNotEmpty ||
      range != null;

  HistoryFilter copyWith({
    String? Function()? childId,
    String? Function()? categoryId,
    Set<RequestStatus>? statuses,
    DateTimeRange? Function()? range,
  }) => HistoryFilter(
    childId: childId != null ? childId() : this.childId,
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    statuses: statuses ?? this.statuses,
    range: range != null ? range() : this.range,
  );

  bool matches(CommunicationRequest r) {
    if (childId != null && r.childId != childId) return false;
    if (categoryId != null && r.categoryId != categoryId) return false;
    if (statuses.isNotEmpty && !statuses.contains(r.status)) return false;
    final range = this.range;
    if (range != null) {
      final start = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
      );
      final end = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
      ).add(const Duration(days: 1));
      if (r.createdAt.isBefore(start) || !r.createdAt.isBefore(end)) {
        return false;
      }
    }
    return true;
  }

  List<CommunicationRequest> apply(Iterable<CommunicationRequest> requests) =>
      requests.where(matches).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Agrupa por día (más reciente primero).
  static Map<DateTime, List<CommunicationRequest>> groupByDay(
    List<CommunicationRequest> requests,
  ) {
    final groups = <DateTime, List<CommunicationRequest>>{};
    for (final r in requests) {
      final day = DateTime(
        r.createdAt.year,
        r.createdAt.month,
        r.createdAt.day,
      );
      groups.putIfAbsent(day, () => []).add(r);
    }
    return groups;
  }
}
