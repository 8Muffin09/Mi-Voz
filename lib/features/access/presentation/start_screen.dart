import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_texts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mi_voz_logo.dart';
import '../../authentication/presentation/splash_screen.dart';

/// Bienvenida: logo, explicación breve, "Comenzar" y "Conocer cómo
/// funciona". Sin formularios ni perfiles: el acceso y el registro están en
/// el flujo que abre "Comenzar".
class StartScreen extends ConsumerWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SplashColors.warmWhite,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [SplashColors.sky, SplashColors.warmWhite],
            stops: [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: MiVozLogo(size: 168)),
                    const SizedBox(height: 16),
                    Text(
                      '¡Bienvenido a Mi Voz!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pictogramas y voz para que cada niño exprese lo que '
                      'quiere, necesita y siente, y para que su familia y su '
                      'escuela lo acompañen.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: AppColors.inkSoft, height: 1.35),
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      key: const Key('welcome-start'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(60),
                        textStyle: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onPressed: () => context.push(Routes.access),
                      child: const Text('Comenzar'),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const Key('welcome-tour'),
                      onPressed: () => context.push(Routes.tour),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: const Text(
                        'Conocer cómo funciona',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const SizedBox(height: 8),
                    const Text(
                      AppTexts.supportDisclaimer,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
