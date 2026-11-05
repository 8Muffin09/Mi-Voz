import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/app_user.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../authentication/application/session_actions.dart';
import '../application/access_providers.dart';
import 'widgets/add_experience_dialog.dart';

/// "Cambiar perfil". Distingue claramente:
/// - Cambiar de perfil infantil o de alumno (misma sesión).
/// - Volver al panel del adulto.
/// - Cambiar de contexto docente ↔ familia con la misma cuenta.
/// - Cerrar sesión.
/// - Entrar con otra cuenta.
/// Solo muestra perfiles autorizados para la cuenta de la sesión.
class SwitchUserScreen extends ConsumerWidget {
  const SwitchUserScreen({super.key});

  /// Cierra la sesión de forma segura (cachés, cola y avisos se borran). Con
  /// [otherAccount] abre después el inicio de sesión.
  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref, {
    required bool otherAccount,
  }) async {
    final actions = ref.read(sessionActionsProvider);
    final router = GoRouter.of(context);
    final pending = actions.pendingRequests;
    final ok = await showConfirmDialog(
      context,
      title: otherAccount ? 'Entrar con otra cuenta' : 'Cerrar sesión',
      message:
          'Se cerrará la sesión de forma segura en este dispositivo. Ningún '
          'dato de esta cuenta quedará visible para la siguiente.'
          '${pending > 0 ? '\n\nAtención: hay $pending solicitud(es) pendiente(s) '
                    'de envío que se descartarán.' : ''}',
      confirmLabel: otherAccount ? 'Cerrar sesión y cambiar' : 'Cerrar sesión',
      destructive: pending > 0,
    );
    if (!ok || !context.mounted) return;
    final done = await runGuarded(context, actions.switchAccount);
    if (!done) return;
    router.go(Routes.start);
    if (otherAccount) router.push(Routes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();
    final experience = ref.watch(activeExperienceProvider);
    final teacher = experience == UserExperience.teacher;
    final other = teacher ? UserExperience.guardian : UserExperience.teacher;
    final current = ref.watch(currentStudentProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Card(
            child: ListTile(
              leading: UserAvatar(user: user, size: 48),
              title: Text(
                user.displayName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('${experience.label} · ${user.email}'),
            ),
          ),

          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('switch-adult-panel'),
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Volver al panel del adulto'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(Routes.adult),
            ),
          ),

          // ------------------------------------------------ Cambiar perfil
          SectionHeader(
            teacher ? 'Cambiar alumno' : 'Cambiar perfil',
            subtitle: teacher
                ? 'Elige otro alumno autorizado sin cerrar tu sesión.'
                : 'Entra al perfil de otro de tus niños. Sus datos no se '
                      'mezclan.',
          ),
          if (teacher) ...[
            Card(
              child: ListTile(
                key: const Key('switch-student'),
                leading: current == null
                    ? const Icon(Icons.people_outline)
                    : ChildAvatar(child: current, size: 40),
                title: const Text('Cambiar alumno'),
                subtitle: Text(
                  current == null
                      ? 'Sin alumnos'
                      : 'Alumno actual: ${current.name}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.students),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Card(
            child: ListTile(
              key: const Key('switch-profile'),
              leading: const Icon(Icons.child_care_rounded),
              title: Text(
                teacher
                    ? 'Usar Mi Voz con un alumno'
                    : '¿Quién utilizará Mi Voz?',
              ),
              subtitle: const Text(
                'Abre la comunicación con pictogramas de un perfil.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push(Routes.profiles),
            ),
          ),

          // --------------------------------------------- Cambiar experiencia
          SectionHeader(
            'Familia o docente',
            subtitle: user.hasExperience(other)
                ? 'Tu cuenta tiene los dos perfiles.'
                : 'Usa la misma cuenta para ambos, sin duplicar tu identidad.',
          ),
          Card(
            child: ListTile(
              key: const Key('switch-experience'),
              leading: Icon(
                other == UserExperience.teacher
                    ? Icons.school_outlined
                    : Icons.family_restroom_outlined,
              ),
              title: Text(
                user.hasExperience(other)
                    ? 'Usar como ${other.shortLabel.toLowerCase()}'
                    : 'Activar perfil ${other == UserExperience.teacher ? 'docente' : 'de familia'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (!user.hasExperience(other)) {
                  final added = await showAddExperienceDialog(
                    context,
                    ref,
                    other,
                  );
                  if (!added || !context.mounted) return;
                } else {
                  await ref
                      .read(selectedExperienceProvider.notifier)
                      .select(other);
                }
                if (context.mounted) context.go(Routes.adult);
              },
            ),
          ),

          // ------------------------------------------------------- Sesión
          const SectionHeader(
            'Sesión',
            subtitle:
                'Para que otro adulto use este dispositivo con su propia '
                'cuenta (por ejemplo, la mamá y después el docente).',
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('switch-account'),
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Entrar con otra cuenta'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _signOut(context, ref, otherAccount: true),
                ),
                ListTile(
                  key: const Key('switch-sign-out'),
                  leading: const Icon(Icons.logout, color: AppColors.urgent),
                  title: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: AppColors.urgent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onTap: () => _signOut(context, ref, otherAccount: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
