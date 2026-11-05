import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/child_profile.dart';
import '../../authentication/presentation/splash_screen.dart';
import '../../child/application/child_mode.dart';
import '../../settings/presentation/parental_gate.dart';
import '../application/access_providers.dart';
import 'widgets/role_illustration.dart';

/// Con una sesión guardada en un dispositivo compartido: muestra solo los
/// perfiles infantiles que esta cuenta activó aquí. El niño entra tocando su
/// tarjeta, sin contraseña; el panel del adulto exige PIN o contraseña.
class KidsAccessScreen extends ConsumerWidget {
  const KidsAccessScreen({super.key});

  Future<void> _openAdult(BuildContext context) async {
    final ok = await showParentalGate(context);
    if (ok && context.mounted) context.go(Routes.adult);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(deviceChildrenProvider);
    final body = AsyncValueView<List<ChildProfile>>(
      value: profiles,
      data: (children) {
        if (children.isEmpty) {
          return _Help(
            title: 'Aún no hay perfiles aquí',
            message:
                'Un adulto puede activar un perfil desde su panel con '
                '"Entrar al perfil de…". Así aparecerá en esta pantalla.',
            actionLabel: 'Soy el adulto',
            onAction: () => _openAdult(context),
          );
        }
        return _KidsGrid(children: children);
      },
    );

    return Scaffold(
      backgroundColor: SplashColors.warmWhite,
      appBar: AppBar(
        backgroundColor: AccessRole.child.background,
        automaticallyImplyLeading: false,
        title: const Text('¿Quién utilizará Mi Voz?'),
        actions: [
          TextButton.icon(
            key: const Key('kids-adult-panel'),
            onPressed: () => _openAdult(context),
            icon: const Icon(Icons.lock_rounded),
            label: const Text('Soy el adulto'),
          ),
        ],
      ),
      body: ColoredBox(
        color: AccessRole.child.background.withValues(alpha: 0.35),
        child: body,
      ),
    );
  }
}

class _KidsGrid extends ConsumerWidget {
  const _KidsGrid({required this.children});

  final List<ChildProfile> children;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GridView.builder(
    padding: const EdgeInsets.all(20),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 260,
      mainAxisSpacing: 18,
      crossAxisSpacing: 18,
      // Altura fija: no depende del ancho de la pantalla.
      mainAxisExtent: 252,
    ),
    itemCount: children.length,
    itemBuilder: (context, i) {
      final child = children[i];
      return Semantics(
        button: true,
        label: 'Entrar como ${child.name}',
        excludeSemantics: true,
        child: Material(
          key: Key('kid-enter-${child.id}'),
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            // Sin contraseña: el perfil ya fue autorizado por un adulto.
            onTap: () => ref.read(childModeProvider.notifier).enter(child.id),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChildAvatar(child: child, size: 84),
                  const SizedBox(height: 8),
                  FittedBox(
                    child: Text(
                      child.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AccessRole.child.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Entrar',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Help extends StatelessWidget {
  const _Help({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const RoleIllustration(role: AccessRole.child, size: 130),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('kids-help-action'),
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
