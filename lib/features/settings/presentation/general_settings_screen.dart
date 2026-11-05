import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_texts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/mi_voz_logo.dart';
import '../../access/application/access_providers.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../authentication/application/session_actions.dart';
import '../../communication/presentation/sync_status_banner.dart';
import '../../communication/application/outbox.dart';
import '../../notifications/data/push_notification_service.dart';
import '../../welcome/application/welcome_preferences.dart';
import '../application/parental_pin.dart';
import 'parental_gate.dart';

final pushPermissionProvider = FutureProvider<PushPermission?>((ref) async {
  final push = ref.watch(pushNotificationServiceProvider);
  return push?.currentPermission();
});

/// Configuración general: cuenta, seguridad, notificaciones, sincronización,
/// privacidad y eliminación de datos.
class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final demo = ref.watch(isDemoModeProvider);
    final hasPin = ref.watch(parentalPinProvider);
    final pending = ref.watch(outboxProvider);
    if (user == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          const SectionHeader('Mi cuenta'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('settings-my-profile'),
                  leading: UserAvatar(user: user, size: 40),
                  title: Text(
                    user.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text('Mi perfil · ${user.email}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.me),
                ),
                ListTile(
                  key: const Key('settings-switch-user'),
                  leading: const Icon(Icons.switch_account_outlined),
                  title: const Text('Cambiar perfil'),
                  subtitle: const Text(
                    'Otro perfil, otro alumno u otra cuenta.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(Routes.switchUser),
                ),
              ],
            ),
          ),
          const SectionHeader('Seguridad del modo niño'),
          Card(
            child: Column(
              children: [
                ListTile(
                  key: const Key('pin-setting'),
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(
                    hasPin
                        ? 'Cambiar PIN de adulto'
                        : 'Configurar PIN de adulto',
                  ),
                  subtitle: Text(
                    hasPin ? 'Se pide para salir del modo niño.' : 'Sin PIN, se pide la contraseña de la cuenta para salir.',
                  ),
                  onTap: () => showSetPinDialog(context, ref),
                ),
                if (hasPin)
                  ListTile(
                    leading: const Icon(Icons.no_encryption_outlined),
                    title: const Text('Quitar PIN'),
                    onTap: () => runGuarded(
                      context,
                      () => ref.read(parentalPinProvider.notifier).clear(),
                      success: 'PIN eliminado.',
                    ),
                  ),
              ],
            ),
          ),
          const _WelcomeSection(),
          const SectionHeader('Notificaciones'),
          if (demo)
            const Card(
              child: ListTile(
                leading: Icon(Icons.science_outlined),
                title: Text('Avisos solo dentro de la app'),
                subtitle: Text(
                  'En esta versión los avisos aparecen dentro de la app, '
                  'marcados como "SIMULADA"; no son notificaciones del '
                  'sistema y no llegan a otros dispositivos.',
                ),
              ),
            )
          else
            const _PushCard(),
          if (pending.isNotEmpty)
            Card(
              color: AppColors.warning.withValues(alpha: 0.1),
              child: ListTile(
                leading: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppColors.warning,
                ),
                title: Text(
                  '${pending.length} solicitud(es) pendiente(s) de envío',
                ),
                subtitle: const Text('Se enviarán al recuperar la conexión.'),
                trailing: TextButton(
                  onPressed: () =>
                      ref.read(outboxProvider.notifier).sync(force: true),
                  child: const Text('Reintentar'),
                ),
              ),
            ),
          if (demo) ...[
            const SectionHeader('Datos de este dispositivo'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('simulate-offline'),
                    secondary: const Icon(Icons.wifi_off_rounded),
                    title: const Text('Simular sin conexión'),
                    subtitle: const Text(
                      'Las solicitudes quedarán "Pendientes de envío" hasta '
                      'que lo desactives.',
                    ),
                    value: ref.watch(demoOfflineProvider),
                    onChanged: (v) =>
                        ref.read(demoOfflineProvider.notifier).set(v),
                  ),
                  ListTile(
                    leading: const Icon(Icons.restart_alt_rounded),
                    key: const Key('wipe-local-data'),
                    title: const Text('Borrar todos los datos locales'),
                    subtitle: const Text(
                      'Cuentas, perfiles e historial guardados solo en este '
                      'dispositivo.',
                    ),
                    onTap: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Borrar los datos de este dispositivo',
                        message:
                            'Se eliminarán todas las cuentas y perfiles del '
                            'modo local de este dispositivo y se cerrará la '
                            'sesión. No se puede deshacer.',
                        confirmLabel: 'Borrar',
                        destructive: true,
                      );
                      if (!ok) return;
                      await ref.read(sessionActionsProvider).signOut();
                      await ref.read(demoDatabaseProvider).reset();
                    },
                  ),
                ],
              ),
            ),
          ],
          const SectionHeader('Cuenta y sincronización'),
          const Card(child: SyncStatusTile()),
          const SectionHeader('Ayuda'),
          Card(
            child: ListTile(
              key: const Key('settings-tour'),
              leading: const Icon(Icons.play_circle_outline_rounded),
              title: const Text('Conocer cómo funciona'),
              subtitle: const Text(
                'Repite el recorrido guiado (no usa datos reales).',
              ),
              trailing: const Icon(Icons.chevron_right),
              // Empieza en el recorrido del perfil que se está usando.
              onTap: () => context.push(
                Routes.tourFor(ref.read(activeExperienceProvider).name),
              ),
            ),
          ),
          const Card(
            child: ListTile(
              key: Key('settings-credits'),
              leading: Icon(Icons.collections_outlined),
              title: Text('Acerca de los pictogramas y avatares'),
              subtitle: Text(
                'Pictogramas: Sergio Palao. Origen: ARASAAC '
                '(arasaac.org). Licencia: CC BY-NC-SA 4.0. Propiedad: '
                'Gobierno de Aragón (España). Avatares: ilustraciones '
                'propias de Mi Voz.',
              ),
            ),
          ),
          const SectionHeader('Privacidad'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(AppTexts.privacySummary),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              key: const Key('delete-account'),
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: AppColors.urgent,
              ),
              title: const Text(
                'Eliminar mi cuenta y mis datos',
                style: TextStyle(
                  color: AppColors.urgent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: const Text(
                'Borra los perfiles que administras (con todo su contenido) y '
                'te desvincula de los demás.',
              ),
              onTap: () => _deleteAccount(context, ref),
            ),
          ),
          const SectionHeader('Acerca de'),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: MiVozLogo(size: 36),
                  title: Text('Mi Voz 1.0.0'),
                  subtitle: Text(AppTexts.supportDisclaimer),
                ),
                const ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('Recursos gráficos'),
                  subtitle: Text(AppTexts.pictogramAttribution),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Licencias de software'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Mi Voz',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            key: const Key('sign-out'),
            onPressed: () => ref.read(sessionActionsProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar cuenta y datos'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Esta acción es permanente. Se eliminarán los perfiles que '
              'administras con su historial, pasaporte y estrategias.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('delete-password'),
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirma con tu contraseña',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    final value = password.text;
    password.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(sessionActionsProvider).deleteAccountAndData(value);
    } catch (e) {
      if (context.mounted) showMessage(context, describeError(e), error: true);
    }
  }
}

class _PushCard extends ConsumerWidget {
  const _PushCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushPermissionProvider).value;
    final text = switch (permission) {
      PushPermission.granted => 'Permitidas en este dispositivo.',
      PushPermission.denied =>
        'Bloqueadas. Actívalas en Ajustes del teléfono → Apps → Mi Voz.',
      PushPermission.notDetermined => 'Aún no se ha pedido permiso.',
      PushPermission.unsupported => 'No disponibles en este dispositivo.',
      null => 'Comprobando…',
    };
    return Card(
      child: ListTile(
        leading: Icon(
          permission == PushPermission.granted
              ? Icons.notifications_active_outlined
              : Icons.notifications_off_outlined,
        ),
        title: const Text('Notificaciones push'),
        subtitle: Text(text),
        trailing: TextButton(
          onPressed: () async {
            final user = ref.read(currentUserProvider);
            final push = ref.read(pushNotificationServiceProvider);
            if (user == null || push == null) return;
            await push.registerDevice(uid: user.uid, childModeChildId: null);
            ref.invalidate(pushPermissionProvider);
          },
          child: const Text('Registrar'),
        ),
      ),
    );
  }
}

/// Pantalla de bienvenida y melodía (preferencias del dispositivo).
class _WelcomeSection extends ConsumerWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(welcomePreferencesProvider);
    final notifier = ref.read(welcomePreferencesProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Bienvenida'),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('welcome-melody'),
                secondary: const Icon(Icons.music_note_outlined),
                title: const Text('Melodía de bienvenida'),
                subtitle: const Text(
                  'Cajita musical suave de 4 segundos. Suena una sola vez al '
                  'abrir la app y nunca si un niño tiene el modo tranquilo.',
                ),
                value: prefs.melodyEnabled,
                onChanged: notifier.setMelodyEnabled,
              ),
              ListTile(
                key: const Key('welcome-melody-preview'),
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Escuchar la melodía'),
                onTap: () => runGuarded(
                  context,
                  () => ref.read(welcomeMelodyProvider).preview(),
                ),
              ),
              SwitchListTile(
                key: const Key('show-splash'),
                secondary: const Icon(Icons.image_outlined),
                title: const Text('Mostrar pantalla de bienvenida'),
                subtitle: const Text(
                  'Si la desactivas, la app abre directamente sin la imagen '
                  'ni la melodía.',
                ),
                value: prefs.showSplash,
                onChanged: notifier.setShowSplash,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Interruptor "Simular sin conexión" del modo demostración.
class DemoOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => ref.watch(demoDatabaseProvider).simulateOffline;

  Future<void> set(bool value) async {
    await ref.read(demoDatabaseProvider).setSimulateOffline(value);
    state = value;
    // Al "volver la conexión" se envía lo pendiente.
    if (!value) await ref.read(outboxProvider.notifier).sync(force: true);
  }
}

final demoOfflineProvider = NotifierProvider<DemoOfflineNotifier, bool>(
  DemoOfflineNotifier.new,
);
