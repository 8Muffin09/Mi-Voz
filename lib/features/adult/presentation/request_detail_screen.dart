import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_badges.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import '../../communication/application/communication_service.dart';
import '../../communication/application/requests_providers.dart';
import '../../../core/widgets/visuals.dart';
import 'widgets/child_guard.dart';

/// Detalle de una solicitud con su línea de tiempo y acciones de atención.
class RequestDetailScreen extends ConsumerWidget {
  const RequestDetailScreen({
    super.key,
    required this.childId,
    required this.requestId,
  });

  final String childId;
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) {
        final async = ref.watch(
          trackedRequestProvider((childId: childId, requestId: requestId)),
        );
        return Scaffold(
          appBar: AppBar(title: const Text('Detalle de solicitud')),
          body: AsyncValueView<CommunicationRequest?>(
            value: async,
            data: (r) => r == null
                ? const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Solicitud no encontrada',
                  )
                : _DetailBody(request: r, child: child),
          ),
        );
      },
    );
  }
}

class _DetailBody extends ConsumerStatefulWidget {
  const _DetailBody({required this.request, required this.child});

  final CommunicationRequest request;
  final ChildProfile child;

  @override
  ConsumerState<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends ConsumerState<_DetailBody> {
  bool _busy = false;
  bool _markedSeen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen());
  }

  @override
  void didUpdateWidget(covariant _DetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _markSeen();
  }

  /// Abrir el detalle marca la solicitud como "Vista".
  Future<void> _markSeen() async {
    final r = widget.request;
    if (_markedSeen ||
        r.status != RequestStatus.newRequest ||
        r.delivery == DeliveryStatus.pendingSync) {
      return;
    }
    _markedSeen = true;
    try {
      await ref
          .read(communicationServiceProvider)
          .updateStatus(r, RequestStatus.seen);
    } catch (_) {
      _markedSeen = false;
    }
  }

  Future<void> _update(RequestStatus status) async {
    String? note;
    if (status == RequestStatus.resolved) {
      note = await _askNote();
      if (note == null) return;
    }
    setState(() => _busy = true);
    if (!mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(communicationServiceProvider)
          .updateStatus(widget.request, status, note: note),
      success: 'Estado actualizado: ${status.label}',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<String?> _askNote() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como resuelta'),
        content: TextField(
          controller: controller,
          maxLength: 200,
          decoration: const InputDecoration(
            labelText: 'Nota opcional (qué se hizo)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-resolve'),
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Resolver'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final pending = r.delivery == DeliveryStatus.pendingSync;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        Card(
          color: r.isUrgent ? AppColors.urgentSoft : null,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                SymbolFrame(r.emoji, size: 72),
                const SizedBox(height: 8),
                Text(
                  r.message,
                  key: const Key('detail-message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.childName} · ${r.categoryTitle}',
                  style: const TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    RequestStatusPill(r.status),
                    PriorityPill(r),
                    DeliveryPill(r),
                    NotificationPill(r),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(speechServiceProvider)
                      .speak(r.message, widget.child.settings),
                  icon: const Icon(Icons.volume_up_rounded),
                  label: const Text('Escuchar mensaje'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _InfoRow('Niño', r.childName),
                _InfoRow('Categoría', r.categoryTitle),
                _InfoRow('Fecha', formatDate(r.createdAt)),
                _InfoRow('Hora', formatTime(r.createdAt)),
                _InfoRow('Destinatario', r.recipientLabel),
                _InfoRow('Prioridad', r.priority.label),
                _InfoRow('Estado', r.status.label),
                if (r.notifiedNames.isNotEmpty)
                  _InfoRow('Avisados', r.notifiedNames.join(', ')),
                if (r.route != null) _InfoRow('Motivo', r.route!.label),
                if (r.note != null && r.note!.isNotEmpty)
                  _InfoRow('Nota', r.note!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Envío',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 8),
                _TimelineItem(
                  done: true,
                  title: 'Creada en el dispositivo del niño',
                  time: r.createdAt,
                ),
                _TimelineItem(
                  done: !pending,
                  title: pending
                      ? 'Pendiente de envío'
                      : 'Recibida en el servidor',
                  time: r.deliveredAt,
                ),
                _TimelineItem(
                  key: const Key('timeline-notification'),
                  done:
                      r.notification == NotificationStatus.sent ||
                      r.notification == NotificationStatus.simulated,
                  failed: r.notification.reachedNobody,
                  title: pending ? 'Aviso (en espera)' : r.notification.label,
                  time: r.notifiedAt,
                  last: true,
                ),
                if (r.notification == NotificationStatus.sent)
                  const Text(
                    '"Aviso enviado" significa que el servicio de '
                    'notificaciones lo aceptó; no confirma que alguien lo '
                    'haya leído.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Atención',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                const SizedBox(height: 8),
                _TimelineItem(
                  done: r.seenAt != null,
                  title: 'Vista',
                  time: r.seenAt,
                ),
                _TimelineItem(
                  done: r.attendingAt != null,
                  title: 'Atendiendo',
                  time: r.attendingAt,
                ),
                _TimelineItem(
                  done: r.resolvedAt != null,
                  title: 'Resuelta',
                  time: r.resolvedAt,
                  last: true,
                ),
                if (r.statusUpdatedByName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Último cambio por ${r.statusUpdatedByName}',
                      style: const TextStyle(color: AppColors.inkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (pending)
          const Text(
            'Esta solicitud se creó sin conexión en este dispositivo y se '
            'enviará automáticamente cuando vuelva internet.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.warning),
          )
        else if (r.status.isOpen) ...[
          if (r.status.index < RequestStatus.attending.index)
            FilledButton.icon(
              key: const Key('mark-attending'),
              onPressed: _busy ? null : () => _update(RequestStatus.attending),
              icon: const Icon(Icons.directions_run_rounded),
              label: const Text('Voy en camino (Atendiendo)'),
            ),
          const SizedBox(height: 10),
          FilledButton.icon(
            key: const Key('mark-resolved'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: _busy ? null : () => _update(RequestStatus.resolved),
            icon: const Icon(Icons.check_circle_rounded),
            label: const Text('Marcar como resuelta'),
          ),
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: AppColors.inkSoft)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    super.key,
    required this.done,
    required this.title,
    this.time,
    this.last = false,
    this.failed = false,
  });

  final bool done;
  final bool failed;
  final String title;
  final DateTime? time;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: [
            Icon(
              failed
                  ? Icons.error_rounded
                  : done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 20,
              color: failed
                  ? AppColors.urgent
                  : done
                  ? AppColors.success
                  : AppColors.inkSoft,
            ),
            if (!last)
              Expanded(
                child: Container(
                  width: 2,
                  color: done ? AppColors.success : Colors.black12,
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: done || failed
                          ? FontWeight.w700
                          : FontWeight.normal,
                      color: failed
                          ? AppColors.urgent
                          : done
                          ? AppColors.ink
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
                if (time != null)
                  Text(
                    formatDateTime(time!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.inkSoft,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
