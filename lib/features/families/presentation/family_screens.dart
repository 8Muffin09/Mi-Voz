import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/family.dart';
import '../../../models/group_invitation.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../invitations/presentation/invitation_widgets.dart';
import '../../profiles/application/profiles_providers.dart';
import '../application/families_providers.dart';
import '../../../core/theme/ui_icons.dart';
import '../data/demo_families_repository.dart' show defaultFamilyName;

String? _validFamilyName(String? v) {
  final text = v?.trim() ?? '';
  if (text.isEmpty) return 'Escribe un nombre.';
  if (text.length > 60) return 'Máximo 60 caracteres.';
  return null;
}

/// Crear una familia: el adulto queda como administrador.
class FamilyFormScreen extends ConsumerStatefulWidget {
  const FamilyFormScreen({super.key});

  @override
  ConsumerState<FamilyFormScreen> createState() => _FamilyFormScreenState();
}

class _FamilyFormScreenState extends ConsumerState<FamilyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: defaultFamilyName(ref.read(currentUserProvider)!),
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    try {
      final family = await ref
          .read(familiesRepositoryProvider)
          .createFamily(owner: user, name: _name.text);
      if (!mounted) return;
      showMessage(context, '"${family.name}" creada.');
      context.pushReplacement(Routes.family(family.id));
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Crear mi familia')),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'En tu familia estarán los perfiles de tus hijos y los adultos '
            'responsables que invites. Tú serás su administrador.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 16),
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('family-name'),
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre de la familia',
            ),
            validator: _validFamilyName,
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('save-family'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Creando…' : 'Crear familia'),
          ),
        ],
      ),
    ),
  );
}

/// Detalle de una familia: adultos, niños y administración.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key, required this.familyId});

  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(familyProvider(familyId));
    final children = (ref.watch(childrenProvider).value ?? const [])
        .where((c) => c.familyId == familyId)
        .toList();
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e),
      ),
      data: (family) {
        if (family == null || user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'No perteneces a esta familia',
            ),
          );
        }
        final owner = Permissions.canManageFamily(family, user.uid);
        return Scaffold(
          appBar: AppBar(
            title: Text(family.name),
            actions: [
              if (owner)
                IconButton(
                  key: const Key('rename-family'),
                  tooltip: 'Cambiar nombre',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _rename(context, ref, family, user),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              SectionHeader(
                'Niños',
                subtitle:
                    'Un perfil por niño: sus datos no se duplican aunque esté '
                    'también en una o varias clases.',
                action: TextButton.icon(
                  key: const Key('family-add-child'),
                  onPressed: () => context.push(Routes.kidNew),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear'),
                ),
              ),
              if (children.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Aún no hay perfiles infantiles en esta familia.',
                    ),
                  ),
                ),
              for (final c in children)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: Key('family-child-${c.id}'),
                    leading: ChildAvatar(child: c, size: 44),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      c.classIds.isEmpty
                          ? 'Sin clase vinculada'
                          : 'Vinculado a ${c.classIds.length} clase(s)',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    // Adultos con acceso y sus permisos.
                    onTap: () => context.push(Routes.caregivers(c.id)),
                  ),
                ),
              const SectionHeader(
                'Adultos responsables',
                subtitle: 'Tienen acceso a todos los niños de la familia.',
              ),
              for (final uid in family.adultUids)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    key: Key('family-adult-$uid'),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.background,
                      child: Icon(family.adultRole(uid).icon, size: 20),
                    ),
                    title: Text(
                      uid == user.uid
                          ? '${family.adultName(uid)} (tú)'
                          : family.adultName(uid),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      '${family.adultRole(uid).label}'
                      '${uid == family.ownerUid ? ' · Administrador' : ''}',
                    ),
                    trailing:
                        Permissions.canRemoveFamilyAdult(
                          family,
                          actorUid: user.uid,
                          targetUid: uid,
                        )
                        ? IconButton(
                            key: Key('remove-family-adult-$uid'),
                            tooltip: uid == user.uid
                                ? 'Salir de la familia'
                                : 'Retirar de la familia',
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: AppColors.urgent,
                            ),
                            onPressed: () =>
                                _removeAdult(context, ref, family, user, uid),
                          )
                        : null,
                  ),
                ),
              // Invitar a otros adultos responsables (código o QR) y aprobar
              // sus solicitudes: solo el administrador.
              if (owner)
                InvitationsSection(
                  type: InviteTargetType.family,
                  targetId: family.id,
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    Family family,
    AppUser user,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: family.name),
    );
    if (name == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(familiesRepositoryProvider)
          .renameFamily(family, name, actor: user),
      success: 'Nombre actualizado.',
    );
  }

  Future<void> _removeAdult(
    BuildContext context,
    WidgetRef ref,
    Family family,
    AppUser user,
    String uid,
  ) async {
    final self = uid == user.uid;
    final name = family.adultName(uid);
    final ok = await showConfirmDialog(
      context,
      title: self ? 'Salir de ${family.name}' : 'Retirar a $name',
      message:
          '${self ? 'Dejarás' : '$name dejará'} de ver a los niños de la '
          'familia y de recibir sus solicitudes. Los datos de los niños se '
          'conservan.',
      confirmLabel: self ? 'Salir' : 'Retirar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final done = await runGuarded(
      context,
      () => ref
          .read(familiesRepositoryProvider)
          .removeAdult(family, actor: user, adultUid: uid),
      success: self
          ? 'Saliste de la familia.'
          : '$name ya no está en la familia.',
    );
    if (done && self && context.mounted) context.go(Routes.adult);
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nombre de la familia'),
    content: TextField(
      key: const Key('rename-family-input'),
      controller: _controller,
      autofocus: true,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(errorText: _error),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('rename-family-save'),
        onPressed: () {
          final error = _validFamilyName(_controller.text);
          if (error != null) {
            setState(() => _error = error);
          } else {
            Navigator.of(context).pop(_controller.text.trim());
          }
        },
        child: const Text('Guardar'),
      ),
    ],
  );
}
