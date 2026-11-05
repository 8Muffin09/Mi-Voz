import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/communication_request.dart';
import '../../adult/presentation/widgets/request_tile.dart';
import '../../communication/application/communication_service.dart';
import '../../communication/application/requests_providers.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../../profiles/application/profiles_providers.dart';
import '../domain/history_filter.dart';

/// Historial de expresiones comunicadas, con filtros por niño, fecha,
/// categoría y estado. Con [childId] abre ya filtrado por ese niño (solo si
/// el adulto está vinculado a él).
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.childId});

  final String? childId;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  /// Solicitudes por bloque en la lista.
  static const pageSize = 50;

  late HistoryFilter _currentFilter = HistoryFilter(childId: widget.childId);
  int _visible = pageSize;

  HistoryFilter get _filter => _currentFilter;

  /// Con otro filtro se vuelve al primer bloque.
  set _filter(HistoryFilter value) {
    _currentFilter = value;
    _visible = pageSize;
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _filter.range,
      helpText: 'Filtrar por fechas',
    );
    if (range != null) {
      setState(() => _filter = _filter.copyWith(range: () => range));
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(adultRequestsProvider);
    final children = ref.watch(childrenProvider).value ?? const [];
    final categories = {
      for (final c in PictogramCatalog.categories) c.id: c.title,
      PictogramCatalog.urgentCategoryId:
          CommunicationService.urgentCategoryTitle,
    };

    final focused = children.where((c) => c.id == widget.childId).firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          focused == null ? 'Historial' : 'Historial · ${focused.name}',
        ),
        actions: [
          if (_filter.isActive)
            TextButton(
              onPressed: () => setState(() => _filter = const HistoryFilter()),
              child: const Text('Limpiar'),
            ),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (children.length > 1) ...[
                  _DropdownChip(
                    icon: Icons.child_care_rounded,
                    label: 'Niño',
                    value: _filter.childId,
                    options: {for (final c in children) c.id: c.name},
                    onChanged: (v) => setState(
                      () => _filter = _filter.copyWith(childId: () => v),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    _filter.range == null
                        ? 'Fechas'
                        : '${formatDate(_filter.range!.start)} – ${formatDate(_filter.range!.end)}',
                  ),
                  onPressed: _pickRange,
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  icon: Icons.category_outlined,
                  label: 'Categoría',
                  value: _filter.categoryId,
                  options: categories,
                  onChanged: (v) => setState(
                    () => _filter = _filter.copyWith(categoryId: () => v),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                for (final s in RequestStatus.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      key: Key('history-status-${s.name}'),
                      label: Text(s.label),
                      selected: _filter.statuses.contains(s),
                      onSelected: (selected) => setState(() {
                        final next = {..._filter.statuses};
                        selected ? next.add(s) : next.remove(s);
                        _filter = _filter.copyWith(statuses: next);
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<CommunicationRequest>>(
              value: async,
              onRetry: () => ref.invalidate(adultRequestsProvider),
              data: (all) {
                final list = _filter.apply(all);
                if (list.isEmpty) {
                  return EmptyState(
                    icon: Icons.history_rounded,
                    title: _filter.isActive
                        ? 'Ninguna solicitud coincide con los filtros'
                        : 'Todavía no hay solicitudes',
                  );
                }
                // Se muestran por bloques y la lista se construye a medida
                // que se desplaza: un historial largo no crea todas las
                // tarjetas de una vez.
                final shown = list.take(_visible).toList();
                final groups = HistoryFilter.groupByDay(shown);
                final rows = <Object>[
                  for (final entry in groups.entries) ...[
                    entry.key,
                    ...entry.value,
                  ],
                ];
                final hasMore = list.length > shown.length;
                return ListView.builder(
                  key: const Key('history-list'),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: rows.length + (hasMore ? 2 : 1),
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Text(
                        hasMore
                            ? 'Mostrando ${shown.length} de ${list.length} '
                                  'solicitudes'
                            : '${list.length} solicitud(es)',
                        style: const TextStyle(color: AppColors.inkSoft),
                      );
                    }
                    if (i == rows.length + 1) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton(
                          key: const Key('history-more'),
                          onPressed: () => setState(() => _visible += pageSize),
                          child: const Text('Mostrar más'),
                        ),
                      );
                    }
                    final row = rows[i - 1];
                    if (row is DateTime) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Semantics(
                          header: true,
                          child: Text(
                            formatDayHeader(row),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: RequestTile(request: row as CommunicationRequest),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownChip extends StatelessWidget {
  const _DropdownChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  /// Valor del menú para "sin filtro" (un `null` equivale a cancelar).
  static const _all = '__all__';

  final IconData icon;
  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: (v) => onChanged(v == _all ? null : v),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: _all,
          child: Text('Sin filtro de ${label.toLowerCase()}'),
        ),
        for (final e in options.entries)
          PopupMenuItem<String>(value: e.key, child: Text(e.value)),
      ],
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(value == null ? label : options[value] ?? label),
        backgroundColor: value == null
            ? null
            : AppColors.primary.withValues(alpha: 0.12),
      ),
    );
  }
}
