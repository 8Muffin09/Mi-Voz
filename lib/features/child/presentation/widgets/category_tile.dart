import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/visuals.dart';
import '../../../../models/pictogram.dart';
import '../../application/active_child.dart';

/// Botón grande de categoría (QUIERO, NECESITO...).
class CategoryTile extends ConsumerWidget {
  const CategoryTile({
    super.key,
    required this.category,
    required this.onTap,
    this.selected = false,
    this.compact = false,
  });

  final PictogramCategory category;
  final VoidCallback onTap;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final color = palette.tint(category.color);
    return Semantics(
      button: true,
      selected: selected,
      label: category.title,
      child: AnimatedContainer(
        duration: palette.animationFor(context),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppTheme.radius + 2),
          border: Border.fromBorderSide(
            selected
                ? BorderSide(color: palette.ink, width: 4)
                : palette.border,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radius + 2),
            onTap: onTap,
            child: LayoutBuilder(
              builder: (context, c) {
                final side = c.biggest.shortestSide;
                return Padding(
                  padding: EdgeInsets.all(compact ? 8 : 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SymbolFrame(
                        category.emoji,
                        size: compact ? 34 : (side * 0.54).clamp(34.0, 120.0),
                      ),
                      SizedBox(height: compact ? 2 : 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          category.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700,
                            fontSize: compact
                                ? 14
                                : (side * 0.14).clamp(14.0, 26.0),
                            color: palette.highContrast
                                ? Colors.black
                                : palette.ink,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
