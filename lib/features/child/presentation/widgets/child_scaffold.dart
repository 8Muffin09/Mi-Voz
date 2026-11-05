import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/visuals.dart';
import '../../application/active_child.dart';

/// Estructura común de las pantallas del niño: botones grandes de
/// "atrás" e "inicio", título claro y fondo suave.
class ChildScaffold extends ConsumerWidget {
  const ChildScaffold({
    super.key,
    required this.body,
    this.title,
    this.leadingSymbol,
    this.showHome = true,
    this.bottom,
  });

  final Widget body;
  final String? title;

  /// Pictograma junto al título (p. ej. el de la categoría).
  final String? leadingSymbol;
  final bool showHome;
  final Widget? bottom;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final canPop = context.canPop();
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  if (canPop)
                    ChildRoundButton(
                      icon: Icons.arrow_back_rounded,
                      label: 'Atrás',
                      onTap: () => context.pop(),
                    ),
                  const SizedBox(width: 12),
                  if (leadingSymbol != null) ...[
                    SymbolFrame(leadingSymbol, size: 44),
                    const SizedBox(width: 10),
                  ],
                  if (title != null)
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: palette.ink,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (showHome)
                    ChildRoundButton(
                      icon: Icons.home_rounded,
                      label: 'Inicio',
                      onTap: () => context.go(Routes.child),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Botón circular grande con etiqueta accesible.
class ChildRoundButton extends ConsumerWidget {
  const ChildRoundButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        shape: CircleBorder(side: palette.border),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            ref.read(childFeedbackProvider).tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(icon, size: 32, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

/// Botón de acción grande (ESCUCHAR, COMUNICAR, CAMBIAR...).
class ChildActionButton extends ConsumerWidget {
  const ChildActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final background = palette.highContrast
        ? Colors.black
        : palette.calm
        ? Color.lerp(color, Colors.grey, 0.45)!
        : color;
    return Semantics(
      button: true,
      label: label,
      child: SizedBox(
        height: 92,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radius + 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius + 4),
            onTap: loading ? null : onTap,
            child: Center(
              child: loading
                  ? const SizedBox.square(
                      dimension: 32,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: Colors.white, size: 34),
                        const SizedBox(height: 4),
                        FittedBox(
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
