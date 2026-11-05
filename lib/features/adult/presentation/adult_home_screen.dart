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
import '../../../core/widgets/visuals.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import '../../access/application/access_providers.dart';
import '../../account/presentation/widgets/email_verification_banner.dart';
import '../../access/presentation/widgets/add_experience_dialog.dart';
import '../../communication/application/requests_providers.dart';
import '../../families/application/families_providers.dart';
import '../../invitations/presentation/invitation_widgets.dart';
import '../../profiles/presentation/enter_child_profile.dart';
import 'widgets/request_tile.dart';
import 'widgets/section_header.dart';

/// Panel de la familia (padre, madre o tutor): niños vinculados, entrada a
/// su perfil, adulto responsable y solicitudes abiertas.
class AdultHomeScreen extends ConsumerWidget {
  const AdultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final demo = ref.watch(isDemoModeProvider);
    final childrenAsync = ref.watch(experienceChildrenProvider);
    // Agrupa en una familia los perfiles creados antes de existir familias.
    ref.watch(familyMigrationProvider);
    final requests = ref.watch(adultRequestsProvider).value ?? const [];

    if (user == null) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Voz · Familia'),
        actions: adultAppBarActions(context, user),
      ),
      body: !user.isGuardian
          ? ExperienceActivationCard(
              user: user,
              experience: UserExperience.guardian,
            )
          : AsyncValueView<List<ChildProfile>>(
              value: childrenAsync,
              onRetry: () => ref.invalidate(experienceChildrenProvider),
              data: (children) {
                final ids = children.map((c) => c.id).toSet();
                final mine = requests
                    .where((r) => ids.contains(r.childId))
                    .toList();
                final open = mine.where((r) => r.status.isOpen).toList()
                  ..sort(inboxOrder);
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    AdultGreeting(
                      user: user,
                      title: '¡Hola, ${user.firstName}!',
                      subtitle: 'Te damos la bienvenida a Mi Voz.',
                    ),
                    const EmailVerificationBanner(),
                    if (demo) ...[
                      const SizedBox(height: 12),
                      const DemoBanner(),
                    ],
                    _Stats(requests: mine),
                    const _FamilySection(),
                    const PendingApprovalsCard(),
                    SectionHeader(
                      'Niños vinculados',
                      action: TextButton.icon(
                        onPressed: () => context.push(Routes.kids),
                        icon: const Icon(Icons.manage_accounts_outlined),
                        label: const Text('Administrar'),
                      ),
                    ),
                    if (children.isEmpty)
                      Card(
                        child: EmptyState(
                          art: const GroupIllustration.children(),
                          title: 'Aún no tienes perfiles',
                          message:
                              'Crea el perfil de tu hijo o hija, o únete '
                              'con el código que te compartió otro adulto.',
                          action: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              FilledButton.icon(
                                key: const Key('home-create-child'),
                                onPressed: () => context.push(Routes.kidNew),
                                icon: const Icon(Icons.add),
                                label: const Text('Crear perfil infantil'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => context.push(Routes.join),
                                icon: const Icon(Icons.key_rounded),
                                label: const Text('Tengo un código'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else ...[
                      for (final child in children) ...[
                        _ChildCard(child: child, user: user, requests: mine),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        key: const Key('home-add-child'),
                        onPressed: () => context.push(Routes.kidNew),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear perfil infantil'),
                      ),
                    ],
                    SectionHeader(
                      'Solicitudes abiertas',
                      action: TextButton(
                        onPressed: () => context.go(Routes.adultRequests),
                        child: const Text('Ver todas'),
                      ),
                    ),
                    if (open.isEmpty)
                      const NoPendingCard()
                    else
                      for (final r in open.take(4)) ...[
                        RequestTile(request: r),
                        const SizedBox(height: 8),
                      ],
                  ],
                );
              },
            ),
    );
  }
}

/// Acciones comunes de la barra del adulto: "Cambiar perfil" y "Mi perfil".
List<Widget> adultAppBarActions(BuildContext context, AppUser user) => [
  IconButton(
    key: const Key('appbar-switch-user'),
    tooltip: 'Cambiar perfil',
    icon: const Icon(Icons.switch_account_rounded),
    onPressed: () => context.push(Routes.switchUser),
  ),
  Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Semantics(
      button: true,
      label: 'Mi perfil',
      excludeSemantics: true,
      child: InkWell(
        key: const Key('appbar-my-profile'),
        customBorder: const CircleBorder(),
        onTap: () => context.push(Routes.me),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: UserAvatar(user: user, size: 38),
        ),
      ),
    ),
  ),
];

/// Saludo con el avatar del adulto.
class AdultGreeting extends StatelessWidget {
  const AdultGreeting({
    super.key,
    required this.user,
    required this.title,
    required this.subtitle,
  });

  final AppUser user;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      UserAvatar(user: user, size: 56),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(subtitle, style: const TextStyle(color: AppColors.inkSoft)),
          ],
        ),
      ),
    ],
  );
}

/// La cuenta no tiene la experiencia elegida: se puede activar (misma
/// identidad) o cambiar de cuenta.
class ExperienceActivationCard extends ConsumerWidget {
  const ExperienceActivationCard({
    super.key,
    required this.user,
    required this.experience,
  });

  final AppUser user;
  final UserExperience experience;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = experience == UserExperience.teacher;
    final own = user.effectiveExperiences.first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  teacher ? '🏫' : '🏡',
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 12),
                Text(
                  teacher
                      ? 'Tu cuenta aún no tiene perfil docente'
                      : 'Tu cuenta aún no tiene perfil de familia',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Puedes activarlo con esta misma cuenta, volver a tu panel o '
                  'cambiar de cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('activate-experience'),
                  onPressed: () =>
                      showAddExperienceDialog(context, ref, experience),
                  child: Text(
                    teacher
                        ? 'Activar perfil docente'
                        : 'Activar perfil de familia',
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(selectedExperienceProvider.notifier).select(own),
                  child: Text(
                    'Volver a mi panel (${own.shortLabel.toLowerCase()})',
                  ),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.switchUser),
                  child: const Text('Cambiar cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoPendingCard extends StatelessWidget {
  const NoPendingCard({super.key});

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: AppColors.success),
          SizedBox(width: 12),
          Expanded(child: Text('No hay solicitudes pendientes.')),
        ],
      ),
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.requests});

  final List<CommunicationRequest> requests;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = requests.where(
      (r) =>
          r.createdAt.year == now.year &&
          r.createdAt.month == now.month &&
          r.createdAt.day == now.day,
    );
    final newOnes = requests.where((r) => r.status == RequestStatus.newRequest);
    final urgent = requests.where((r) => r.isUrgent && r.status.isOpen);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          StatTile(
            label: 'Nuevas',
            value: newOnes.length,
            icon: Icons.fiber_new_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Urgentes',
            value: urgent.length,
            icon: Icons.warning_amber_rounded,
            color: AppColors.urgent,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Hoy',
            value: today.length,
            icon: Icons.today_rounded,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              '$value',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
            Text(label, style: const TextStyle(color: AppColors.inkSoft)),
          ],
        ),
      ),
    ),
  );
}

/// Interruptor "Estoy acompañando a Juan" (adulto responsable actual). Solo
/// cambia con esta acción explícita del adulto.
class AccompanyingSwitch extends ConsumerWidget {
  const AccompanyingSwitch({
    super.key,
    required this.child,
    required this.user,
  });

  final ChildProfile child;
  final AppUser user;

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final link = CaregiverLink(
      childId: child.id,
      adultUid: user.uid,
      adultName: user.displayName,
      adultEmail: user.email,
      role: user.role,
      permission: child.ownerUid == user.uid
          ? LinkPermission.owner
          : LinkPermission.caregiver,
    );
    await runGuarded(
      context,
      () => ref
          .read(childrenRepositoryProvider)
          .setResponsible(
            child: child,
            actor: user,
            adult: value ? link : null,
          ),
      success: value
          ? 'Ahora las solicitudes de ${child.name} te llegarán a ti.'
          : 'Dejaste de acompañar a ${child.name}.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iAmResponsible = child.responsibleUid == user.uid;
    final text = !child.hasResponsible
        ? 'Sin adulto responsable: se avisa a todos'
        : iAmResponsible
        ? 'Tú estás acompañando a ${child.name}'
        : 'Acompaña: ${child.responsibleName}';
    return Material(
      color: iAmResponsible
          ? AppColors.secondary.withValues(alpha: 0.12)
          : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SwitchListTile(
        key: Key('accompany-${child.id}'),
        value: iAmResponsible,
        onChanged: (v) => _toggle(context, ref, v),
        title: Text(
          'Estoy acompañando a ${child.name}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(text),
      ),
    );
  }
}

class _ChildCard extends ConsumerWidget {
  const _ChildCard({
    required this.child,
    required this.user,
    required this.requests,
  });

  final ChildProfile child;
  final AppUser user;
  final List<CommunicationRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = requests
        .where((r) => r.childId == child.id && r.status.isOpen)
        .length;
    final isOwner = Permissions.isOwner(child, user.uid);

    Widget action(IconData icon, String label, String route, {Key? key}) =>
        ActionChip(
          key: key,
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: () => context.push(route),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ChildAvatar(child: child, size: 56),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        child.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isOwner
                            ? 'Administrador del perfil'
                            : 'Adulto autorizado',
                        style: const TextStyle(color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                if (open > 0)
                  Badge(
                    label: Text('$open'),
                    child: const Icon(Icons.inbox_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: Key('enter-profile-${child.id}'),
              onPressed: () => confirmAndEnterChildProfile(context, ref, child),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text('Entrar al perfil de ${child.name}'),
            ),
            const SizedBox(height: 12),
            AccompanyingSwitch(child: child, user: user),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Vincular con una clase: con el código o QR del docente.
                action(
                  Icons.school_outlined,
                  'Vincular con una clase',
                  Routes.join,
                  key: Key('link-class-${child.id}'),
                ),
                action(
                  Icons.badge_outlined,
                  'Pasaporte',
                  Routes.passport(child.id),
                ),
                action(
                  Icons.lightbulb_outline,
                  'Estrategias',
                  Routes.strategies(child.id),
                ),
                action(
                  Icons.history_rounded,
                  'Historial',
                  Routes.childHistory(child.id),
                ),
                action(
                  Icons.tune_rounded,
                  'Sensorial',
                  Routes.sensory(child.id),
                ),
                action(
                  Icons.grid_view_rounded,
                  'Pictogramas',
                  Routes.pictogramAdmin(child.id),
                ),
                action(
                  Icons.group_outlined,
                  'Adultos y avisos',
                  Routes.caregivers(child.id),
                  key: Key('adults-${child.id}'),
                ),
                action(
                  Icons.edit_outlined,
                  'Editar perfil',
                  Routes.kidEdit(child.id),
                ),
                action(
                  Icons.record_voice_over_outlined,
                  'Responsable',
                  Routes.responsible(child.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Mi familia": acceso a la familia o, si aún no hay, a crearla o unirse.
class _FamilySection extends ConsumerWidget {
  const _FamilySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(familiesProvider).value;
    if (families == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Mi familia'),
        if (families.isEmpty)
          Card(
            child: EmptyState(
              art: const GroupIllustration.family(),
              title: 'Crea tu familia',
              message:
                  'Agrupa los perfiles de tus hijos y a los adultos '
                  'responsables. También puedes unirte con un código.',
              action: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    key: const Key('create-family'),
                    onPressed: () => context.push(Routes.familyNew),
                    icon: const Icon(Icons.add_home_outlined),
                    label: const Text('Crear mi familia'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.join),
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Tengo un código'),
                  ),
                ],
              ),
            ),
          )
        else
          for (final f in families)
            Card(
              key: Key('family-card-${f.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const CircleAvatar(child: Text('🏡')),
                title: Text(
                  f.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${f.adultUids.length} adulto(s) responsable(s)',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(Routes.family(f.id)),
              ),
            ),
      ],
    );
  }
}
