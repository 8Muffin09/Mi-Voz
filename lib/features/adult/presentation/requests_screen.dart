import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/communication_request.dart';
import '../../communication/application/requests_providers.dart';
import 'widgets/request_tile.dart';

enum _InboxFilter {
  open('Pendientes'),
  newOnes('Nuevas'),
  seen('Vistas'),
  attending('Atendiendo'),
  urgent('Urgentes');

  const _InboxFilter(this.label);
  final String label;

  bool matches(CommunicationRequest r) => switch (this) {
    _InboxFilter.open => r.status.isOpen,
    _InboxFilter.newOnes => r.status == RequestStatus.newRequest,
    _InboxFilter.seen => r.status == RequestStatus.seen,
    _InboxFilter.attending => r.status == RequestStatus.attending,
    _InboxFilter.urgent => r.isUrgent && r.status.isOpen,
  };
}

/// Solicitudes recibidas (pendientes de atender).
class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen> {
  _InboxFilter _filter = _InboxFilter.open;
  bool _onlyMine = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(adultRequestsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitudes recibidas')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in _InboxFilter.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          SwitchListTile(
            dense: true,
            value: _onlyMine,
            onChanged: (v) => setState(() => _onlyMine = v),
            title: const Text('Solo las dirigidas a mí'),
          ),
          Expanded(
            child: AsyncValueView<List<CommunicationRequest>>(
              value: async,
              onRetry: () => ref.invalidate(adultRequestsProvider),
              data: (all) {
                final list =
                    all
                        .where(_filter.matches)
                        .where(
                          (r) =>
                              !_onlyMine ||
                              r.recipientUid == user?.uid ||
                              r.recipientUid == null,
                        )
                        .toList()
                      ..sort(inboxOrder);
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'No hay solicitudes aquí',
                    message: 'Cuando un niño comunique algo, aparecerá en esta lista.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => RequestTile(request: list[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
