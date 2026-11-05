import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../access/application/access_providers.dart';
import '../../../core/widgets/visuals.dart';
import 'enter_child_profile.dart';

/// "¿Quién utilizará Mi Voz?" (familia) o "Selecciona un alumno" (docente).
///
/// Solo muestra perfiles autorizados para la cuenta. Con [selectStudent]
/// cambia el alumno actual del panel docente; si no, abre el modo niño.
class ProfileSelectionScreen extends ConsumerWidget {
  const ProfileSelectionScreen({super.key, this.selectStudent = false});

  final bool selectStudent;

  Future<void> _enter(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
  ) async {
    if (selectStudent) {
      await ref.read(currentStudentIdProvider.notifier).select(child.id);
      if (context.mounted) context.go(Routes.adult);
      return;
    }
    await confirmAndEnterChildProfile(context, ref, child);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher =
        ref.watch(activeExperienceProvider) == UserExperience.teacher;
    final async = ref.watch(experienceChildrenProvider);
    final currentId = ref.watch(currentStudentProvider)?.id;
    final title = teacher ? 'Selecciona un alumno' : '¿Quién utilizará Mi Voz?';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!selectStudent)
            TextButton.icon(
              key: const Key('go-adult-panel'),
              onPressed: () => context.go(Routes.adult),
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Mi panel'),
            ),
        ],
      ),
      body: AsyncValueView<List<ChildProfile>>(
        value: async,
        data: (children) {
          if (children.isEmpty && teacher) {
            return EmptyState(
              art: const GroupIllustration.classroom(),
              title: 'Aún no tienes alumnos vinculados',
              message:
                  'Invita a las familias desde tus clases con un código o QR '
                  'y aprueba sus solicitudes.',
              action: FilledButton.icon(
                onPressed: () => context.push(Routes.classes),
                icon: const Icon(Icons.groups_rounded),
                label: const Text('Ir a mis clases'),
              ),
            );
          }
          final canCreate = !teacher && !selectStudent;
          return GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 230,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              // Altura fija: no depende del ancho de la pantalla.
              mainAxisExtent: 236,
            ),
            itemCount: children.length + (canCreate ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == children.length) return const _CreateCard();
              final child = children[i];
              return _ProfileCard(
                child: child,
                actionLabel: selectStudent ? 'Seleccionar' : 'Entrar',
                current: selectStudent && child.id == currentId,
                onTap: () => _enter(context, ref, child),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.child,
    required this.actionLabel,
    required this.current,
    required this.onTap,
  });

  final ChildProfile child;
  final String actionLabel;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    key: Key('select-child-${child.id}'),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      side: BorderSide(
        color: current
            ? AppColors.primary
            : Colors.black.withValues(alpha: 0.06),
        width: current ? 3 : 1,
      ),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChildAvatar(child: child, size: 72),
            const SizedBox(height: 10),
            FittedBox(
              child: Text(
                child.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (current)
              const Text(
                'Alumno actual',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: onTap,
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    ),
  );
}

/// "+ Crear perfil infantil" (solo familia).
class _CreateCard extends StatelessWidget {
  const _CreateCard();

  @override
  Widget build(BuildContext context) => Card(
    key: const Key('create-child-card'),
    color: AppColors.primary.withValues(alpha: 0.06),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      onTap: () => context.push(Routes.kidNew),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.add_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 12),
            Text(
              '+ Crear perfil infantil',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
