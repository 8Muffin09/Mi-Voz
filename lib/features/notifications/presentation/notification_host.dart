import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../child/application/child_mode.dart';
import '../application/in_app_notifications.dart';

/// Muestra los avisos internos sobre cualquier pantalla de adulto.
/// En modo niño no se muestran (el niño ve el estado en su pantalla).
class NotificationHost extends ConsumerWidget {
  const NotificationHost({
    super.key,
    required this.child,
    required this.onOpen,
  });

  final Widget child;
  final void Function(InAppNotice notice) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(inAppNotificationsProvider);
    final inChildMode = ref.watch(childModeProvider) != null;
    return Stack(
      children: [
        child,
        if (!inChildMode && notices.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _NoticeBanner(
                      key: ValueKey(notices.last.id),
                      notice: notices.last,
                      pendingCount: notices.length - 1,
                      onOpen: () {
                        ref
                            .read(inAppNotificationsProvider.notifier)
                            .dismiss(notices.last.id);
                        onOpen(notices.last);
                      },
                      onDismiss: () => ref
                          .read(inAppNotificationsProvider.notifier)
                          .dismiss(notices.last.id),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NoticeBanner extends StatefulWidget {
  const _NoticeBanner({
    super.key,
    required this.notice,
    required this.pendingCount,
    required this.onOpen,
    required this.onDismiss,
  });

  final InAppNotice notice;
  final int pendingCount;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  State<_NoticeBanner> createState() => _NoticeBannerState();
}

class _NoticeBannerState extends State<_NoticeBanner> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Los urgentes permanecen hasta que el adulto los cierre.
    if (!widget.notice.urgent) {
      _timer = Timer(const Duration(seconds: 8), widget.onDismiss);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notice;
    final accent = n.urgent ? AppColors.urgent : AppColors.primary;
    return Semantics(
      liveRegion: true,
      label:
          '${n.simulated ? 'Notificación simulada. ' : ''}${n.title}. ${n.body}',
      child: Material(
        elevation: 8,
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: n.requestId != null ? widget.onOpen : null,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border(left: BorderSide(color: accent, width: 6)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  n.urgent
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_active_rounded,
                  color: accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (n.simulated)
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            n.recipientLabel == null
                                ? 'NOTIFICACIÓN SIMULADA (DEMO)'
                                : 'NOTIFICACIÓN SIMULADA · para ${n.recipientLabel}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      Text(
                        n.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(n.body),
                      if (widget.pendingCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '+${widget.pendingCount} aviso(s) más',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Sin tooltip: el aviso está por encima del Navigator y no
                // hay Overlay donde mostrarlo (fallaría al construirse).
                Semantics(
                  button: true,
                  label: 'Cerrar aviso',
                  excludeSemantics: true,
                  child: IconButton(
                    key: const Key('notice-close'),
                    icon: const Icon(Icons.close_rounded),
                    onPressed: widget.onDismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
