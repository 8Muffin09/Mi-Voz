import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../welcome/application/welcome_preferences.dart';

/// `true` cuando terminó la presentación inicial.
class SplashDoneNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void finish() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashDoneNotifier, bool>(
  SplashDoneNotifier.new,
);

/// Colores del fondo de bienvenida (celeste pastel, blanco cálido, amarillo
/// suave, verde menta y rosa muy suave).
class SplashColors {
  const SplashColors._();

  static const sky = Color(0xFFE6F3FF);
  static const warmWhite = Color(0xFFFFFBF4);
  static const softYellow = Color(0xFFFFF4D6);
  static const mint = Color(0xFFDDF4EA);
  static const blush = Color(0xFFFFE6EC);
}

/// Pantalla de carga: imagen principal de Mi Voz, fondo suave y melodía
/// opcional. Se puede omitir y nunca retrasa el acceso más de lo necesario.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Duración de la presentación completa.
  static const duration = Duration(milliseconds: 2300);

  /// Si un adulto desactivó la pantalla de bienvenida.
  static const shortDuration = Duration(milliseconds: 250);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(welcomePreferencesProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
      if (prefs.showSplash) ref.read(welcomeMelodyProvider).playOnLaunch();
    });
    _timer = Timer(
      prefs.showSplash ? SplashScreen.duration : SplashScreen.shortDuration,
      _finish,
    );
  }

  void _finish() {
    _timer?.cancel();
    if (mounted) ref.read(splashDoneProvider.notifier).finish();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: SplashColors.warmWhite,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _SoftBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Grande y centrada, sin deformarse (cuadrada), en teléfonos
                // y tablets, vertical u horizontal.
                final side = math.min(
                  math.min(
                    constraints.maxWidth * 0.82,
                    constraints.maxHeight * 0.62,
                  ),
                  460.0,
                );
                return Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton(
                          key: const Key('splash-skip'),
                          onPressed: _finish,
                          child: const Text(
                            'Omitir',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _visible ? 1 : 0,
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 700),
                          curve: Curves.easeOut,
                          child: AnimatedScale(
                            scale: _visible || reduceMotion ? 1 : 0.94,
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Semantics(
                                  label: 'Mi Voz',
                                  image: true,
                                  child: Image.asset(
                                    'assets/images/splash_mi_voz.png',
                                    key: const Key('splash-image'),
                                    width: side,
                                    height: side,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.medium,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // El nombre ya aparece en la imagen; solo se
                                // agrega el subtítulo.
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    '“Cada forma de comunicarse importa”',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF34507A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Degradado discreto con figuras redondeadas muy sutiles.
class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          SplashColors.sky,
          SplashColors.warmWhite,
          SplashColors.softYellow,
        ],
        stops: [0, 0.55, 1],
      ),
    ),
    child: CustomPaint(painter: _BubblesPainter()),
  );
}

class _BubblesPainter extends CustomPainter {
  const _BubblesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void bubble(double dx, double dy, double r, Color color) {
      canvas.drawCircle(
        Offset(size.width * dx, size.height * dy),
        size.shortestSide * r,
        Paint()..color = color.withValues(alpha: 0.55),
      );
    }

    bubble(0.08, 0.12, 0.22, SplashColors.mint);
    bubble(0.95, 0.30, 0.18, SplashColors.blush);
    bubble(0.05, 0.82, 0.20, SplashColors.blush);
    bubble(0.92, 0.92, 0.26, SplashColors.mint);
    bubble(0.55, 0.02, 0.10, SplashColors.softYellow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
