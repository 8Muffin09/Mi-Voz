import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/pictogram.dart';
import '../theme/app_theme.dart';
import '../theme/child_palette.dart';
import 'visuals.dart';

/// Imagen del pictograma: foto propia si existe, si no la ilustración del
/// catálogo (`SymbolCatalog`).
class PictogramVisual extends StatelessWidget {
  const PictogramVisual({super.key, required this.pictogram, this.size = 56});

  final Pictogram pictogram;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emoji = SymbolImage(pictogram.emoji, size: size * 1.25);
    final path = pictogram.imagePath;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return _framed(
        Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => emoji,
        ),
      );
    }
    final url = pictogram.imageUrl;
    if (url != null && url.isNotEmpty) {
      return _framed(
        Image.network(url, fit: BoxFit.cover, errorBuilder: (_, _, _) => emoji),
      );
    }
    return emoji;
  }

  Widget _framed(Widget image) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.2),
    child: SizedBox.square(dimension: size * 1.25, child: image),
  );
}

/// Emoji sin escalado del texto del sistema. Solo se usa para contenido
/// heredado que no tiene ilustración equivalente (nunca para la interfaz).
class EmojiGlyph extends StatelessWidget {
  const EmojiGlyph(this.emoji, {super.key, this.size = 48});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Text(
      emoji,
      textScaler: TextScaler.noScaling,
      style: TextStyle(fontSize: size, height: 1.15),
    ),
  );
}

/// Ficha táctil de pictograma para la experiencia infantil.
class PictogramCard extends StatelessWidget {
  const PictogramCard({
    super.key,
    required this.pictogram,
    required this.label,
    required this.color,
    required this.palette,
    required this.onTap,
    this.selected = false,
    this.trailing,
  });

  final Pictogram pictogram;
  final String label;
  final Color color;
  final ChildPalette palette;
  final VoidCallback onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final side = constraints.biggest.shortestSide;
          return AnimatedContainer(
            duration: palette.animationFor(context),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius + 4),
              border: Border.fromBorderSide(
                selected
                    ? BorderSide(color: palette.ink, width: 4)
                    : palette.border,
              ),
              boxShadow: palette.calm || palette.highContrast
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTheme.radius + 4),
                onTap: onTap,
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: PictogramVisual(
                              pictogram: pictogram,
                              size: side * 0.36,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w700,
                              fontSize: (side * 0.11).clamp(14.0, 24.0),
                              color: palette.ink,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (trailing != null)
                      Positioned(top: 4, right: 4, child: trailing!),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
