import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../application/profiles_providers.dart';
import '../../../core/theme/ui_icons.dart';

/// Vinculación de tutores, docentes y cuidadores mediante invitaciones de
/// un solo uso con caducidad.
class CaregiversScreen extends ConsumerWidget {
  const CaregiversScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) {
        final links = ref.watch(caregiverLinksProvider(childId));
        final canManage = Permissions.canManageCaregivers(child, user.uid);
        final familyId = child.familyId;
        return Scaffold(
          appBar: AppBar(title: Text('Adultos de ${child.name}')),
          // Los adultos se invitan a la familia (código o QR) y los docentes
          // llegan con el código de su clase: ya no hay códigos por niño.
          floatingActionButton: canManage && familyId != null
              ? FloatingActionButton.extended(
                  key: const Key('invite-adult'),
                  onPressed: () => context.push(Routes.family(familyId)),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Invitar a la familia'),
                )
              : null,
          body: AsyncValueView<List<CaregiverLink>>(
            value: links,
            data: (list) => ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              children: [
                const Text(
                  'Solo los adultos de esta lista pueden ver la información '
                  'de este perfil y recibir sus solicitudes.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
                const SectionHeader('Avisos'),
                _NoCompanionCard(
                  child: child,
                  links: list,
                  canEdit: Permissions.canManageLinkPermissions(
                    child,
                    user.uid,
                  ),
                  onEdit: () => _editRule(context, ref, child, user, list),
                ),
                const SectionHeader('Adultos vinculados'),
                for (final link in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.background,
                        child: Icon(link.role.icon, size: 20),
                      ),
                      title: Text(
                        link.adultUid == user.uid
                            ? '${link.adultName} (tú)'
                            : link.adultName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        [
                          link.role.label,
                          link.permission.label,
                          link.source.label,
                          if (child.responsibleUid == link.adultUid)
                            'Acompañando ahora',
                          if (!link.receivesRequests) 'No recibe solicitudes',
                          if (!link.canViewPassport) 'Sin acceso al pasaporte',
                        ].join(' · '),
                      ),
                      onTap: canManage && !link.isOwner
                          ? () => _editPermissions(
                              context,
                              ref,
                              child,
                              user,
                              link,
                            )
                          : null,
                      trailing:
                          Permissions.canRemoveLink(
                            child,
                            actorUid: user.uid,
                            targetUid: link.adultUid,
                          )
                          ? IconButton(
                              tooltip: link.adultUid == user.uid
                                  ? 'Desvincularme'
                                  : 'Quitar acceso',
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: AppColors.urgent,
                              ),
                              onPressed: () =>
                                  _remove(context, ref, child, user, link),
                            )
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Quién recibe solicitudes y quién ve el Pasaporte Sensorial.
  Future<void> _editPermissions(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
    AppUser user,
    CaregiverLink link,
  ) async {
    final result = await showModalBottomSheet<(bool, bool)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PermissionsSheet(link: link),
    );
    if (result == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(childrenRepositoryProvider)
          .setLinkPermissions(
            child: child,
            actor: user,
            adultUid: link.adultUid,
            receivesRequests: result.$1,
            canViewPassport: result.$2,
          ),
      success: 'Permisos actualizados.',
    );
  }

  /// A quién avisar cuando nadie marcó "Estoy acompañando".
  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
    AppUser user,
    List<CaregiverLink> links,
  ) async {
    final result = await showModalBottomSheet<(NoCompanionRule, List<String>)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _NoCompanionSheet(child: child, links: links),
    );
    if (result == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(childrenRepositoryProvider)
          .setNoCompanionRule(
            child: child,
            actor: user,
            rule: result.$1,
            backupUids: result.$2,
          ),
      success: 'Regla de avisos guardada.',
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    ChildProfile child,
    AppUser user,
    CaregiverLink link,
  ) async {
    final self = link.adultUid == user.uid;
    final ok = await showConfirmDialog(
      context,
      title: self ? 'Desvincularme' : 'Quitar acceso a ${link.adultName}',
      message: self
          ? 'Dejarás de ver la información de ${child.name}.'
          : '${link.adultName} dejará de ver la información de ${child.name} '
                'y de recibir sus solicitudes. Los datos de ${child.name} se '
                'conservan.',
      confirmLabel: self ? 'Desvincularme' : 'Quitar acceso',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runGuarded(
      context,
      () => ref
          .read(childrenRepositoryProvider)
          .removeLink(child: child, actor: user, adultUid: link.adultUid),
      success: 'Acceso retirado.',
    );
    if (done && self && context.mounted) context.pop();
  }
}

class _PermissionsSheet extends StatefulWidget {
  const _PermissionsSheet({required this.link});

  final CaregiverLink link;

  @override
  State<_PermissionsSheet> createState() => _PermissionsSheetState();
}

class _PermissionsSheetState extends State<_PermissionsSheet> {
  late bool _receives = widget.link.receivesRequests;
  late bool _passport = widget.link.canViewPassport;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Permisos de ${widget.link.adultName}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SwitchListTile(
            key: const Key('perm-receives'),
            value: _receives,
            onChanged: (v) => setState(() => _receives = v),
            title: const Text('Recibe las solicitudes del niño'),
            subtitle: const Text(
              'Si lo desactivas, no le llegarán avisos aunque esté vinculado.',
            ),
          ),
          SwitchListTile(
            key: const Key('perm-passport'),
            value: _passport,
            onChanged: (v) => setState(() => _passport = v),
            title: const Text('Puede ver el Pasaporte Sensorial'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('perm-save'),
            onPressed: () => Navigator.of(context).pop((_receives, _passport)),
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}

/// Resumen de quién recibe los avisos ahora mismo.
class _NoCompanionCard extends StatelessWidget {
  const _NoCompanionCard({
    required this.child,
    required this.links,
    required this.canEdit,
    required this.onEdit,
  });

  final ChildProfile child;
  final List<CaregiverLink> links;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final plan = RecipientResolver.plan(child, links: links);
    String nameOf(String uid) => links
        .firstWhere(
          (l) => l.adultUid == uid,
          orElse: () => CaregiverLink(
            childId: child.id,
            adultUid: uid,
            adultName: 'Adulto',
            adultEmail: '',
            role: AdultRole.tutor,
            permission: LinkPermission.caregiver,
          ),
        )
        .adultName;
    final ruleNames = plan.byRule.map(nameOf).join(', ');
    return Card(
      key: const Key('no-companion-rule'),
      child: ListTile(
        leading: const Icon(Icons.notifications_active_outlined),
        title: Text(
          plan.companion == null
              ? 'Nadie acompaña a ${child.name} ahora'
              : 'Acompaña ahora: ${nameOf(plan.companion!)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          'Si nadie acompaña: ${child.noCompanionRule.label.toLowerCase()}'
          '${plan.byRule.isEmpty ? '. Ahora mismo nadie recibiría el aviso.' : ' ($ruleNames).'}',
          style: TextStyle(
            color: plan.primary.isEmpty ? AppColors.urgent : null,
          ),
        ),
        trailing: canEdit ? const Icon(Icons.edit_outlined) : null,
        onTap: canEdit ? onEdit : null,
      ),
    );
  }
}

class _NoCompanionSheet extends StatefulWidget {
  const _NoCompanionSheet({required this.child, required this.links});

  final ChildProfile child;
  final List<CaregiverLink> links;

  @override
  State<_NoCompanionSheet> createState() => _NoCompanionSheetState();
}

class _NoCompanionSheetState extends State<_NoCompanionSheet> {
  late NoCompanionRule _rule = widget.child.noCompanionRule;
  late final Set<String> _chosen = widget.child.backupUids.toSet();

  @override
  Widget build(BuildContext context) {
    final candidates = widget.links.where((l) => l.receivesRequests).toList();
    final invalid = _rule == NoCompanionRule.chosen && _chosen.isEmpty;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Si nadie está acompañando',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Cuando ${widget.child.name} comunica algo y nadie marcó "Estoy '
              'acompañando" (o quien acompaña no puede recibir avisos), ¿a '
              'quién le llega?',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            RadioGroup<NoCompanionRule>(
              groupValue: _rule,
              onChanged: (v) => setState(() => _rule = v ?? _rule),
              child: Column(
                children: [
                  for (final rule in NoCompanionRule.values)
                    RadioListTile<NoCompanionRule>(
                      key: Key('rule-${rule.name}'),
                      value: rule,
                      title: Text(rule.label),
                      subtitle: Text(rule.description),
                    ),
                ],
              ),
            ),
            if (_rule == NoCompanionRule.chosen)
              for (final link in candidates)
                CheckboxListTile(
                  key: Key('backup-${link.adultUid}'),
                  value: _chosen.contains(link.adultUid),
                  onChanged: (v) => setState(
                    () => v == true
                        ? _chosen.add(link.adultUid)
                        : _chosen.remove(link.adultUid),
                  ),
                  title: Text(link.adultName),
                  subtitle: Text(link.role.label),
                ),
            if (invalid)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Elige al menos un adulto.',
                  style: TextStyle(color: AppColors.urgent),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Los adultos con "No recibe solicitudes" nunca reciben avisos.',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('rule-save'),
              onPressed: invalid
                  ? null
                  : () => Navigator.of(context).pop((
                      _rule,
                      _rule == NoCompanionRule.chosen
                          ? _chosen.toList()
                          : const <String>[],
                    )),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
