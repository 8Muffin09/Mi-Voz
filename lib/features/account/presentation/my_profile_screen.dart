import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../authentication/application/session_actions.dart';

/// "Mi perfil" del adulto: datos, avatar y opciones de cuenta.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold();
    final types = [
      if (user.isGuardian)
        'Familia${user.role.isFamily ? ' (${user.role.label})' : ''}',
      if (user.isTeacher) 'Docente',
    ].join(' · ');

    Widget info(String label, String? value) => value == null || value.isEmpty
        ? const SizedBox.shrink()
        : ListTile(
            dense: true,
            title: Text(
              label,
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            subtitle: Text(
              value,
              style: const TextStyle(fontSize: 16, color: AppColors.ink),
            ),
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Mi perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Center(child: UserAvatar(user: user, size: 112)),
          const SizedBox(height: 12),
          Text(
            user.displayName,
            key: const Key('my-profile-name'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            types,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                info('Correo electrónico', user.email),
                info('Tipo de usuario', types),
                if (user.isTeacher) ...[
                  info('Mis alumnos me llaman', user.teacherTitle),
                  info('Escuela', user.schoolName),
                  info('Grupo o grado', user.groupName),
                ],
              ],
            ),
          ),
          const SectionHeader('Opciones'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('edit-my-profile'),
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Editar nombre, avatar y datos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.meEdit),
                ),
                ListTile(
                  key: const Key('change-password'),
                  leading: const Icon(Icons.password_rounded),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePassword(context, ref),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Administrar configuraciones'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.go(Routes.adultSettings),
                ),
                ListTile(
                  key: const Key('profile-switch-user'),
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Cambiar perfil'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.switchUser),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('profile-sign-out'),
            onPressed: () => ref.read(sessionActionsProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  /// Flujo seguro: pide la contraseña actual antes de cambiarla.
  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final formKey = GlobalKey<FormState>();
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    String? error;
    var saving = false;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Cambiar contraseña'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    key: const Key('password-current'),
                    controller: current,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña actual',
                    ),
                    validator: (v) => (v ?? '').isEmpty
                        ? 'Escribe tu contraseña actual.'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('password-new'),
                    controller: next,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const Key('password-confirm'),
                    controller: confirm,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Repite la nueva contraseña',
                      errorText: error,
                    ),
                    validator: (v) =>
                        v != next.text ? 'Las contraseñas no coinciden.' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('password-save'),
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await ref
                            .read(sessionActionsProvider)
                            .changePassword(current.text, next.text);
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (e) {
                        setState(() {
                          saving = false;
                          error = describeError(e);
                        });
                      }
                    },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (changed == true && context.mounted) {
      showMessage(context, 'Contraseña actualizada.');
    }
  }
}
