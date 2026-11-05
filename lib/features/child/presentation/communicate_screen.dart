import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/child_palette.dart';
import '../../../core/widgets/visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/communication_request.dart';
import '../../communication/application/requests_providers.dart';
import '../application/active_child.dart';
import '../application/child_mode.dart';
import 'widgets/child_scaffold.dart';

/// Confirmación y seguimiento de la solicitud enviada.
///
/// Distingue claramente el transporte (pendiente de envío → recibida en el
/// servidor → aviso enviado) de la atención (vista → atendiendo → resuelta),
/// y dice la verdad cuando el aviso no llegó a nadie o nadie lo ha visto.
class CommunicateScreen extends ConsumerStatefulWidget {
  const CommunicateScreen({super.key, required this.requestId});

  final String requestId;

  /// Tiempo tras el cual, si nadie lo vio, se sugiere buscar a un adulto.
  static const unseenWarning = Duration(minutes: 2);

  @override
  ConsumerState<CommunicateScreen> createState() => _CommunicateScreenState();
}

class _CommunicateScreenState extends ConsumerState<CommunicateScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Vuelve a evaluar "nadie lo ha visto todavía" con el paso del tiempo.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String get requestId => widget.requestId;

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(childModeProvider);
    final palette = ref.watch(activePaletteProvider);
    if (childId == null) return const SizedBox.shrink();
    final async = ref.watch(
      trackedRequestProvider((childId: childId, requestId: requestId)),
    );
    return ChildScaffold(
      title: 'Mi mensaje',
      body: AsyncValueView<CommunicationRequest?>(
        value: async,
        data: (request) {
          if (request == null) {
            return const EmptyState(
              icon: Icons.hourglass_top_rounded,
              title: 'Buscando tu mensaje…',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: SymbolFrame(request.emoji, size: 120)),
              const SizedBox(height: 12),
              Text(
                request.message,
                key: const Key('communicated-message'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
              const SizedBox(height: 24),
              ..._steps(request, palette),
            ],
          );
        },
      ),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ChildActionButton(
                label: 'ESCUCHAR',
                icon: Icons.volume_up_rounded,
                color: AppColors.listen,
                onTap: () {
                  final r = async.value;
                  if (r != null) {
                    ref.read(childFeedbackProvider).speak(r.message);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ChildActionButton(
                key: const Key('back-home'),
                label: 'INICIO',
                icon: Icons.home_rounded,
                color: AppColors.primary,
                onTap: () => context.go(Routes.child),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _steps(CommunicationRequest r, ChildPalette palette) {
    final pending = r.delivery == DeliveryStatus.pendingSync;
    final notifying = r.notification == NotificationStatus.pending;
    final who = r.notifiedNames.isNotEmpty
        ? r.notifiedNames.join(', ')
        : r.recipientName ?? 'tus adultos';
    final unseen =
        r.status == RequestStatus.newRequest &&
        DateTime.now().difference(r.createdAt) >=
            CommunicateScreen.unseenWarning;
    // Sin envío, sin destinatario o sin ver tras un rato: buscar a alguien.
    final lookForAdult =
        (pending && r.isUrgent) || r.notification.reachedNobody || unseen;
    return [
      if (pending)
        _StatusRow(
          key: const Key('status-pending'),
          icon: Icons.schedule_send_rounded,
          title: 'Todavía no se envió',
          subtitle: 'No hay conexión. Se enviará sola cuando vuelva internet.',
          palette: palette,
          highlight: true,
        )
      else if (notifying)
        _StatusRow(
          key: const Key('status-delivered'),
          icon: Icons.send_rounded,
          title: 'Mensaje recibido',
          subtitle: 'Enviando el aviso…',
          palette: palette,
          highlight: true,
        )
      else if (r.notification.reachedNobody)
        _StatusRow(
          key: const Key('status-nobody'),
          icon: Icons.warning_amber_rounded,
          title: 'El aviso no le llegó a nadie',
          subtitle: r.notification.label,
          palette: palette,
          highlight: true,
        )
      else
        _StatusRow(
          key: const Key('status-delivered'),
          icon: Icons.check_circle_rounded,
          title: 'Aviso enviado a $who',
          subtitle: r.notification == NotificationStatus.simulated
              ? r.notification.label
              : 'Todavía no sabemos si ya lo vio.',
          palette: palette,
          highlight: r.status == RequestStatus.newRequest,
        ),
      if (lookForAdult && r.status.isOpen)
        _StatusRow(
          key: const Key('status-look-for-adult'),
          icon: Icons.record_voice_over_rounded,
          title: unseen && !r.notification.reachedNobody && !pending
              ? 'Nadie lo ha visto todavía'
              : 'Busca a un adulto cerca',
          subtitle:
              'Si necesitas ayuda ya, busca a un adulto o pide ayuda en voz '
              'alta. Puedes tocar ESCUCHAR para que lo oigan.',
          palette: palette,
          highlight: true,
        ),
      if (r.status.index >= RequestStatus.seen.index)
        _StatusRow(
          icon: Icons.visibility_rounded,
          title: '${r.statusUpdatedByName ?? who} ya lo vio',
          palette: palette,
          highlight: r.status == RequestStatus.seen,
        ),
      if (r.status.index >= RequestStatus.attending.index)
        _StatusRow(
          icon: Icons.directions_walk_rounded,
          title: '${r.statusUpdatedByName ?? who} viene a ayudarte',
          palette: palette,
          highlight: r.status == RequestStatus.attending,
        ),
      if (r.status == RequestStatus.resolved)
        _StatusRow(
          icon: Icons.celebration_rounded,
          title: '¡Listo! Ya se resolvió',
          palette: palette,
          highlight: true,
        ),
    ];
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.palette,
    this.subtitle,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final ChildPalette palette;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: highlight,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: highlight ? palette.ink : palette.borderColor,
          width: highlight ? 3 : palette.borderWidth,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: palette.ink),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.ink.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
