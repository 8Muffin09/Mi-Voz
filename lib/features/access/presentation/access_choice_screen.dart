import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/mi_voz_logo.dart';
import '../../../models/app_user.dart';
import '../application/access_providers.dart';
import 'widgets/role_illustration.dart';

/// Tras "Comenzar": una sola entrada para iniciar sesión o crear un perfil.
class AccessChoiceScreen extends ConsumerWidget {
  const AccessChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ChoiceLayout(
    title: 'Comenzar',
    subtitle: '¿Ya tienes una cuenta de Mi Voz?',
    options: [
      _ChoiceOption(
        key: const Key('access-login'),
        icon: Icons.login_rounded,
        title: 'Iniciar sesión',
        subtitle:
            'Ya tengo una cuenta de adulto (docente, padre, madre o tutor).',
        onTap: () {
          ref.read(pendingStudentProfileProvider.notifier).set(false);
          context.push(Routes.login);
        },
      ),
      _ChoiceOption(
        key: const Key('access-create'),
        icon: Icons.person_add_alt_1_rounded,
        title: 'Crear una cuenta',
        subtitle: 'Es mi primera vez en Mi Voz.',
        onTap: () => context.push(Routes.createProfile),
      ),
    ],
  );
}

/// "Soy alumno": el perfil infantil no usa correo ni contraseña; lo crea y
/// vincula un adulto responsable con su propia cuenta.
class StudentProfileScreen extends ConsumerWidget {
  const StudentProfileScreen({super.key});

  Future<void> _continue(
    BuildContext context,
    WidgetRef ref,
    String route,
  ) async {
    ref.read(pendingStudentProfileProvider.notifier).set(true);
    await ref
        .read(selectedExperienceProvider.notifier)
        .select(UserExperience.guardian);
    if (context.mounted) await context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => _ChoiceLayout(
    title: 'Perfil de alumno',
    subtitle:
        'Tu perfil no necesita correo ni contraseña. Un adulto responsable '
        '(tu mamá, papá o tutor) lo crea contigo y elige tu nombre, tu avatar '
        'y tus preferencias. Después podrá vincularlo con tu clase.',
    header: const RoleIllustration(role: AccessRole.child, size: 120),
    options: [
      _ChoiceOption(
        key: const Key('student-adult-register'),
        icon: Icons.person_add_alt_1_rounded,
        title: 'El adulto crea su cuenta',
        subtitle: 'Primero se registra el adulto y luego crea el perfil.',
        onTap: () => _continue(context, ref, Routes.register),
      ),
      _ChoiceOption(
        key: const Key('student-adult-login'),
        icon: Icons.login_rounded,
        title: 'El adulto ya tiene cuenta',
        subtitle: 'Inicia sesión y crea el perfil infantil.',
        onTap: () => _continue(context, ref, Routes.login),
      ),
    ],
  );
}

class _ChoiceLayout extends StatelessWidget {
  const _ChoiceLayout({
    required this.title,
    required this.subtitle,
    required this.options,
    this.header,
  });

  final String title;
  final String subtitle;
  final List<Widget> options;
  final Widget? header;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: header ?? const MiVozLogo(size: 96)),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
                ),
                const SizedBox(height: 24),
                for (final option in options) ...[
                  option,
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opción grande: con ilustración de rol o con icono.
class _ChoiceOption extends StatelessWidget {
  const _ChoiceOption({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const background = AppColors.surface;
    const accent = AppColors.primary;
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: accent.withValues(alpha: 0.1),
                  child: Icon(icon, color: accent, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(subtitle, style: const TextStyle(fontSize: 15)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
