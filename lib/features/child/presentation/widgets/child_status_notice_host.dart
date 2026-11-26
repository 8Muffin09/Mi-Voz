import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/visuals.dart';
import '../../../../models/communication_request.dart';
import '../../application/active_child.dart';
import '../../application/child_mode.dart';
import '../../application/child_status_notices.dart';

/// En modo niño, muestra sobre cualquier pantalla el aviso "¡Tu adulto va en
/// camino!" (o "vio tu mensaje", "¡Listo!"), con el pictograma de lo que
/// comunicó. Se cierra solo a los 15 s o con "Entendido".
class ChildStatusNoticeHost extends ConsumerWidget {
  const ChildStatusNoticeHost({
    super.key,
    required this.child,
    required this.onOpen,
  });

  final Widget child;
  final void Function(String requestId) onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inChildMode = ref.watch(childModeProvider) != null;
    final notices = inChildMode
        ? ref.watch(childStatusNoticesProvider)
        : const <ChildStatusNotice>[];
    return Stack(
      children: [
        child,
        if (notices.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _ChildNoticeCard(
                      key: ValueKey(
                        '${notices.last.requestId}-${notices.last.status.name}',
                      ),
                      notice: notices.last,
                      onOpen: () {
                        ref
                            .read(childStatusNoticesProvider.notifier)
                            .dismiss(notices.last.requestId);
                        onOpen(notices.last.requestId);
                      },
                      onDismiss: () => ref
                          .read(childStatusNoticesProvider.notifier)
                          .dismiss(notices.last.requestId),
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

class _ChildNoticeCard extends ConsumerStatefulWidget {
  const _ChildNoticeCard({
    super.key,
    required this.notice,
    required this.onOpen,
    required this.onDismiss,
  });

  final ChildStatusNotice notice;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  ConsumerState<_ChildNoticeCard> createState() => _ChildNoticeCardState();
}

class _ChildNoticeCardState extends ConsumerState<_ChildNoticeCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 15), widget.onDismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(activePaletteProvider);
    final n = widget.notice;
    final going = n.status == RequestStatus.attending;
    return Semantics(
      liveRegion: true,
      label: n.spoken,
      child: Material(
        key: const Key('child-status-notice'),
        elevation: 8,
        color: going ? AppColors.success : palette.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius + 4),
          onTap: widget.onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SymbolFrame(n.symbol, size: 64),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n.title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: going ? Colors.white : palette.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        n.message,
                        style: TextStyle(
                          fontSize: 17,
                          color: going ? Colors.white : palette.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  key: const Key('child-status-ok'),
                  style: TextButton.styleFrom(
                    foregroundColor: going ? Colors.white : palette.ink,
                    minimumSize: const Size(64, 56),
                  ),
                  onPressed: widget.onDismiss,
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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
