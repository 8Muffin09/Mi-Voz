import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../application/profiles_providers.dart';
import '../../../core/theme/ui_icons.dart';

/// Selección del adulto responsable actual: quien acompaña al niño recibe
/// sus solicitudes de forma prioritaria.
class ResponsibleAdultScreen extends ConsumerWidget {
  const ResponsibleAdultScreen({super.key, required this.childId});

  final String childId;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
    AppUser user,
    CaregiverLink? link,
  ) => runGuarded(
    context,
    () => ref
        .read(childrenRepositoryProvider)
        .setResponsible(child: child, actor: user, adult: link),
    success: link == null
        ? 'Sin responsable: se avisará a todos los adultos vinculados.'
        : 'Ahora acompaña ${link.adultName}.',
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) {
        final links = ref.watch(caregiverLinksProvider(childId));
        return Scaffold(
          appBar: AppBar(title: const Text('Adulto responsable')),
          body: AsyncValueView<List<CaregiverLink>>(
            value: links,
            data: (list) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.secondary.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      child.hasResponsible
                          ? '${child.responsibleName} acompaña a ${child.name}'
                                '${child.responsibleSince != null ? ' desde ${formatDateTime(child.responsibleSince!)}' : ''}. '
                                'Sus solicitudes le llegarán primero.'
                          : '${child.name} no tiene adulto responsable: las '
                                'solicitudes se envían a todos los adultos vinculados.',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Cada adulto puede marcarse a sí mismo. El administrador del '
                  'perfil puede asignar a cualquier adulto vinculado.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 12),
                for (final link in list)
                  _Option(
                    key: Key('responsible-${link.adultUid}'),
                    title: link.adultUid == user.uid
                        ? 'Yo (${link.adultName})'
                        : link.adultName,
                    subtitle: link.role.label,
                    icon: link.role.icon,
                    selected: child.responsibleUid == link.adultUid,
                    enabled: Permissions.canSetResponsible(
                      child,
                      actorUid: user.uid,
                      targetUid: link.adultUid,
                    ),
                    onTap: () => _set(context, ref, child, user, link),
                  ),
                _Option(
                  key: const Key('responsible-none'),
                  title: 'Nadie en particular',
                  subtitle: 'Avisar a todos los adultos vinculados',
                  icon: Icons.groups_rounded,
                  selected: !child.hasResponsible,
                  enabled:
                      child.hasResponsible &&
                      Permissions.canSetResponsible(
                        child,
                        actorUid: user.uid,
                        targetUid: null,
                      ),
                  onTap: () => _set(context, ref, child, user, null),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      side: BorderSide(
        color: selected ? AppColors.secondary : Colors.black12,
        width: selected ? 2.5 : 1,
      ),
    ),
    child: ListTile(
      enabled: enabled || selected,
      leading: Icon(icon, size: 28, color: AppColors.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.secondary)
          : enabled
          ? const Icon(Icons.radio_button_unchecked)
          : const Icon(Icons.lock_outline, size: 18),
      onTap: enabled && !selected ? onTap : null,
    ),
  );
}
