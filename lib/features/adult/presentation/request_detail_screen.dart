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
import '../../communication/domain/support_suggestions.dart';
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

  Future<void> _update(RequestStatus status, {String? suggested}) async {
    String? support;
    if (status == RequestStatus.resolved) {
      support = await _askSupport(
        title: 'Marcar como resuelta',
        initial: suggested,
      );
      if (support == null) return;
    }
    setState(() => _busy = true);
    if (!mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(communicationServiceProvider)
          .updateStatus(widget.request, status, support: support),
      success: 'Estado actualizado: ${status.label}',
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _registerSupport() async {
    final support = await _askSupport(title: 'Apoyo brindado');
    if (support == null || support.trim().isEmpty || !mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(communicationServiceProvider)
          .saveSupport(widget.request, support),
      success: 'Apoyo registrado.',
    );
  }

  /// Apoyo brindado: es la observación del adulto. La valoración del alumno
  /// se registra aparte (y nunca se deduce de "Resuelta").
  Future<String?> _askSupport({required String title, String? initial}) {
    final controller = TextEditingController(
      text: initial ?? widget.request.supportProvided ?? '',
    );
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('support-input'),
          controller: controller,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Apoyo brindado (opcional)',
            helperText: 'Qué hiciste para ayudar. Es tu observación.',
            helperMaxLines: 2,
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
        else ...[
          const SizedBox(height: 8),
          _SupportFollowUp(
            request: r,
            onRegister: r.status.index >= RequestStatus.attending.index
                ? _registerSupport
                : null,
          ),
        ],
        if (!pending && r.status.isOpen)
          _PastSupportSuggestions(
            request: r,
            onUse: _busy
                ? null
                : (text) => _update(RequestStatus.resolved, suggested: text),
          ),
        if (!pending && r.status.isOpen) ...[
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

/// Seguimiento del apoyo: lo que hizo el adulto, cómo dijo sentirse el
/// alumno (por separado) y el historial de cambios. No es una evaluación
/// clínica.
class _SupportFollowUp extends ConsumerWidget {
  const _SupportFollowUp({required this.request, required this.onRegister});

  final CommunicationRequest request;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final events =
        ref.watch(requestEventsProvider((r.childId, r.id))).value ??
        const <RequestEvent>[];
    final feedback = r.childFeedback;
    return Card(
      key: const Key('support-follow-up'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Seguimiento del apoyo',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _InfoRow(
              'Apoyo brindado',
              r.supportProvided == null
                  ? 'Sin registrar'
                  : '${r.supportProvided} · ${r.supportByName ?? ''}'
                        '${r.supportAt == null ? '' : ' · ${formatDateTime(r.supportAt!)}'}',
            ),
            Row(
              children: [
                if (feedback != null && feedback != SupportFeedback.none) ...[
                  SymbolImage(feedback.symbol, size: 32),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _InfoRow(
                    'El alumno dice',
                    feedback?.label ?? 'Aún sin valoración',
                  ),
                ),
              ],
            ),
            if (onRegister != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('register-support'),
                  onPressed: onRegister,
                  icon: const Icon(Icons.edit_note_rounded),
                  label: Text(
                    r.supportProvided == null
                        ? 'Registrar apoyo brindado'
                        : 'Editar apoyo brindado',
                  ),
                ),
              ),
            if (events.isNotEmpty) ...[
              const Divider(),
              const Text(
                'Historial',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              for (final e in events)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${formatDateTime(e.at)} · ${e.label} · ${e.byName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "En otras ocasiones le ha servido": apoyos registrados antes para lo
/// mismo (o la misma categoría), con lo que el alumno dijo después. Ayuda a
/// decidir; no es una recomendación clínica.
class _PastSupportSuggestions extends ConsumerWidget {
  const _PastSupportSuggestions({required this.request, required this.onUse});

  final CommunicationRequest request;
  final ValueChanged<String>? onUse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history =
        ref.watch(childRequestsProvider(request.childId)).value ??
        const <CommunicationRequest>[];
    final suggestions = SupportSuggestions.forRequest(request, history);
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Card(
      key: const Key('past-support-suggestions'),
      color: AppColors.primary.withValues(alpha: 0.06),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En otras ocasiones le ha servido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Apoyos que se registraron antes cuando comunicó algo parecido, '
              'y cómo dijo sentirse después.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            for (final s in suggestions)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, right: 8),
                      child: s.better > 0
                          ? SymbolImage(SupportFeedback.better.symbol, size: 28)
                          : const Icon(
                              Icons.history_rounded,
                              size: 28,
                              color: AppColors.inkSoft,
                            ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.text,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            [
                              if (!s.sameMessage) 'En una situación parecida',
                              s.summary,
                              'última vez ${formatDate(s.lastUsed)}',
                            ].join(' · '),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (onUse != null)
                      TextButton(
                        key: Key('use-suggestion-${suggestions.indexOf(s)}'),
                        onPressed: () => onUse!(s.text),
                        child: const Text('Usar'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
