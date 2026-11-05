import 'package:flutter/material.dart';

import '../../models/sensory_settings.dart';
import 'app_theme.dart';

/// Colores y comportamiento visual de la experiencia infantil, calculados a
/// partir de las preferencias sensoriales del niño.
class ChildPalette {
  const ChildPalette._({
    required this.background,
    required this.surface,
    required this.ink,
    required this.borderColor,
    required this.borderWidth,
    required this.animationDuration,
    required this.calm,
    required this.highContrast,
  });

  factory ChildPalette.from(SensorySettings s) {
    if (s.highContrast) {
      return ChildPalette._(
        background: Colors.white,
        surface: Colors.white,
        ink: Colors.black,
        borderColor: Colors.black,
        borderWidth: 3,
        animationDuration: s.calmMode
            ? Duration.zero
            : const Duration(milliseconds: 180),
        calm: s.calmMode,
        highContrast: true,
      );
    }
    if (s.calmMode) {
      return const ChildPalette._(
        background: Color(0xFFF1F3F4),
        surface: Color(0xFFFAFAFA),
        ink: Color(0xFF2E3440),
        borderColor: Color(0x1F000000),
        borderWidth: 1,
        animationDuration: Duration.zero,
        calm: true,
        highContrast: false,
      );
    }
    return const ChildPalette._(
      background: Color(0xFFFBF7F0),
      surface: Colors.white,
      ink: AppColors.ink,
      borderColor: Color(0x14000000),
      borderWidth: 1,
      animationDuration: Duration(milliseconds: 220),
      calm: false,
      highContrast: false,
    );
  }

  final Color background;
  final Color surface;
  final Color ink;
  final Color borderColor;
  final double borderWidth;
  final Duration animationDuration;

  /// Duración real de las animaciones: también se suprimen si el sistema
  /// pide reducir el movimiento (Android "Quitar animaciones", iOS "Reducir
  /// movimiento", Windows "Efectos de animación").
  Duration animationFor(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
      ? Duration.zero
      : animationDuration;
  final bool calm;
  final bool highContrast;

  /// Adapta el color de una categoría: apagado en modo tranquilo y más
  /// saturado (con texto negro) en alto contraste.
  Color tint(int argb) {
    final color = Color(argb);
    if (highContrast) {
      final hsl = HSLColor.fromColor(color);
      return hsl
          .withSaturation((hsl.saturation + 0.25).clamp(0.0, 1.0))
          .withLightness(0.72)
          .toColor();
    }
    if (calm) {
      final hsl = HSLColor.fromColor(color);
      return hsl
          .withSaturation(hsl.saturation * 0.3)
          .withLightness((hsl.lightness + 0.05).clamp(0.0, 0.94))
          .toColor();
    }
    return color;
  }

  Color get urgent => highContrast
      ? const Color(0xFFB00020)
      : calm
      ? const Color(0xFFC98A7B)
      : AppColors.urgent;

  BorderSide get border => BorderSide(color: borderColor, width: borderWidth);
}
