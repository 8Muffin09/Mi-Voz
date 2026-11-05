import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../access/application/access_providers.dart';
import '../application/profiles_providers.dart';
import '../../../core/widgets/visuals.dart';

/// Administración de perfiles infantiles.
class ChildrenAdminScreen extends ConsumerWidget {
  const ChildrenAdminScreen({super.key});

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar a ${child.name}',
      message:
          'Se eliminarán permanentemente su perfil, historial, pasaporte '
          'sensorial, estrategias y vínculos con otros adultos. Esta acción '
          'no se puede deshacer.',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(context, () async {
      await ref
          .read(childrenRepositoryProvider)
          .deleteChild(child, actor: user);
      await ref.read(photoStoreProvider).delete(child.photo);
      await ref.read(deviceProfilesProvider.notifier).revoke(child.id);
    }, success: 'Perfil eliminado.');
  }

  Future<void> _leave(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
  ) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final ok = await showConfirmDialog(
      context,
      title: 'Desvincularme de ${child.name}',
      message: 'Dejarás de recibir sus solicitudes y de ver su información.',
      confirmLabel: 'Desvincularme',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(context, () async {
      await ref
          .read(childrenRepositoryProvider)
          .removeLink(child: child, actor: user, adultUid: user.uid);
      await ref.read(deviceProfilesProvider.notifier).revoke(child.id);
    }, success: 'Te desvinculaste del perfil. Sus datos se conservan.');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(childrenProvider);
    // Crear perfiles infantiles: solo padres, madres o tutores.
    final guardian =
        ref.watch(activeExperienceProvider) == UserExperience.guardian;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfiles infantiles'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(Routes.join),
            icon: const Icon(Icons.key_rounded),
            label: const Text('Unirme'),
          ),
        ],
      ),
      floatingActionButton: guardian
          ? FloatingActionButton.extended(
              key: const Key('add-child'),
              onPressed: () => context.push(Routes.kidNew),
              icon: const Icon(Icons.add),
              label: const Text('Crear perfil infantil'),
            )
          : null,
      body: AsyncValueView<List<ChildProfile>>(
        value: async,
        data: (children) => children.isEmpty
            ? const EmptyState(
                art: GroupIllustration.children(),
                title: 'No hay perfiles',
                message: 'Crea uno nuevo o únete con un código de invitación.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final child = children[i];
                  final owner = Permissions.isOwner(child, user?.uid);
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          ListTile(
                            leading: ChildAvatar(child: child, size: 48),
                            title: Text(
                              child.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              '${owner ? 'Administrador' : 'Adulto autorizado'} · '
                              '${child.memberUids.length} adulto(s) vinculados',
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed: () =>
                                    context.push(Routes.kidEdit(child.id)),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: () =>
                                    context.push(Routes.caregivers(child.id)),
                                icon: const Icon(Icons.group_outlined),
                                label: const Text('Adultos'),
                              ),
                              if (owner)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.urgent,
                                  ),
                                  onPressed: () => _delete(context, ref, child),
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Eliminar'),
                                )
                              else
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.urgent,
                                  ),
                                  onPressed: () => _leave(context, ref, child),
                                  icon: const Icon(Icons.logout),
                                  label: const Text('Desvincularme'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
