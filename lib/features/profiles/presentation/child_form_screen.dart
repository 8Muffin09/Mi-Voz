import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/visuals/avatar_catalog.dart';
import '../../../core/widgets/avatar_picker.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/child_profile.dart';
import '../../../models/sensory_settings.dart';
import '../../families/application/families_providers.dart';
import '../../families/data/demo_families_repository.dart'
    show defaultFamilyName;
import '../application/profiles_providers.dart';

/// Crear o editar un perfil infantil. Solo se pide lo necesario: nombre (o
/// nombre preferido), apellido opcional, avatar o foto opcional, concordancia
/// de las frases y preferencias de comunicación. Nunca correo ni contraseña.
class ChildFormScreen extends ConsumerWidget {
  const ChildFormScreen({super.key, this.childId});

  final String? childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = childId;
    if (id == null) return const _ChildForm(child: null);
    final async = ref.watch(childProvider(id));
    final user = ref.watch(currentUserProvider);
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e),
      ),
      data: (child) =>
          child == null || !Permissions.canEditSupport(child, user?.uid)
          ? Scaffold(
              appBar: AppBar(),
              body: const EmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'No tienes acceso a este perfil',
              ),
            )
          : _ChildForm(child: child),
    );
  }
}

class _ChildForm extends ConsumerStatefulWidget {
  const _ChildForm({required this.child});

  final ChildProfile? child;

  @override
  ConsumerState<_ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends ConsumerState<_ChildForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lastName;
  late String _avatar;
  late int _color;
  late GrammaticalGender _gender;
  late bool _speakOnSelect;
  late bool _calmMode;
  File? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  /// Familia elegida al crear (o `null` para la primera o una nueva).
  String? _familyId;
  late final TextEditingController _familyName;

  @override
  void initState() {
    super.initState();
    final c = widget.child;
    _name = TextEditingController(text: c?.name ?? '');
    _lastName = TextEditingController(text: c?.lastName ?? '');
    // Los emojis de versiones anteriores se guardan ya como identificador.
    _avatar = AvatarCatalog.normalize(
      c?.avatar,
      fallback: AvatarCatalog.defaultChild,
    );
    _color = c?.avatarColor ?? ChildProfile.colorOptions.first;
    _gender = c?.gender ?? GrammaticalGender.masculine;
    _speakOnSelect = c?.settings.speakOnSelect ?? true;
    _calmMode = c?.settings.calmMode ?? false;
    final user = ref.read(currentUserProvider);
    _familyName = TextEditingController(
      text: user == null ? 'Mi familia' : defaultFamilyName(user),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _lastName.dispose();
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    final repo = ref.read(childrenRepositoryProvider);
    final photos = ref.read(photoStoreProvider);
    try {
      final existing = widget.child;
      var target = existing;
      if (target == null) {
        // Todo perfil nuevo pertenece a una familia: la elegida o una nueva.
        final families = ref.read(familiesProvider).value ?? const [];
        var familyId = _familyId ?? families.firstOrNull?.id;
        familyId ??=
            (await ref
                    .read(familiesRepositoryProvider)
                    .createFamily(owner: user, name: _familyName.text))
                .id;
        target = await repo.createChild(
          owner: user,
          familyId: familyId,
          name: _name.text,
          lastName: _lastName.text,
          avatar: _avatar,
          avatarColor: _color,
          gender: _gender,
          settings: SensorySettings(
            speakOnSelect: _speakOnSelect,
            calmMode: _calmMode,
          ),
        );
      } else {
        final settings = existing!.settings;
        if (settings.speakOnSelect != _speakOnSelect ||
            settings.calmMode != _calmMode) {
          await repo.updateSettings(
            existing.id,
            settings.copyWith(
              speakOnSelect: _speakOnSelect,
              calmMode: _calmMode,
            ),
          );
        }
      }
      // Foto opcional: se guarda con el identificador del perfil.
      var photo = existing?.photo;
      if (_newPhoto != null) {
        photo = await photos.save(
          storagePath: FirestorePaths.childAvatar(target.id),
          file: _newPhoto!,
        );
        if (existing?.photo != null && existing!.photo!.startsWith('file:')) {
          await photos.delete(existing.photo);
        }
      } else if (_removePhoto) {
        await photos.delete(existing?.photo);
        photo = null;
      }
      if (existing != null || photo != null) {
        await repo.updateChildProfile(
          target,
          name: _name.text,
          lastName: _lastName.text,
          avatar: _avatar,
          avatarColor: _color,
          gender: _gender,
          photo: photo,
        );
      }
      if (!mounted) return;
      showMessage(
        context,
        existing == null
            ? 'Perfil de ${_name.text.trim()} creado.'
            : 'Cambios guardados.',
      );
      context.pop();
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final editing = child != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          editing ? 'Editar a ${child.name}' : 'Nuevo perfil infantil',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const Key('child-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre o nombre preferido',
                helperText: 'Basta con el nombre o un apodo.',
              ),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('child-last-name'),
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Apellido (opcional)',
              ),
              validator: Validators.optionalName,
            ),
            const SizedBox(height: 20),
            const Text(
              'Avatar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),
            AvatarPicker(
              avatar: _avatar,
              color: _color,
              options: AvatarCatalog.forChildren,
              colorOptions: ChildProfile.colorOptions,
              existingPhoto: _removePhoto ? null : child?.photo,
              newPhoto: _newPhoto,
              photoHelp:
                  'No es necesario subir fotografías reales de los niños: '
                  'un avatar es suficiente.',
              onAvatar: (a) => setState(() => _avatar = a),
              onColor: (c) => setState(() => _color = c),
              onPickPhoto: () async {
                final file = await pickAvatarPhoto(context);
                if (file != null && mounted) {
                  setState(() {
                    _newPhoto = file;
                    _removePhoto = false;
                  });
                }
              },
              onRemovePhoto: () => setState(() {
                _newPhoto = null;
                _removePhoto = child?.photo != null;
              }),
            ),
            const SizedBox(height: 20),
            if (!editing) ...[
              _FamilyPicker(
                familyId: _familyId,
                nameController: _familyName,
                onChanged: (id) => setState(() => _familyId = id),
              ),
              const SizedBox(height: 20),
            ],
            const Text(
              'Concordancia de las frases',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text(
              'Define si la app dice "Me siento cansado" o "cansada".',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            RadioGroup<GrammaticalGender>(
              groupValue: _gender,
              onChanged: (v) => setState(() => _gender = v ?? _gender),
              child: Column(
                children: [
                  for (final g in GrammaticalGender.values)
                    RadioListTile<GrammaticalGender>(
                      value: g,
                      title: Text(g.label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Preferencias de comunicación',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SwitchListTile(
              key: const Key('child-speak-on-select'),
              contentPadding: EdgeInsets.zero,
              value: _speakOnSelect,
              onChanged: (v) => setState(() => _speakOnSelect = v),
              title: const Text('Leer en voz alta cada pictograma al tocarlo'),
            ),
            SwitchListTile(
              key: const Key('child-calm-mode'),
              contentPadding: EdgeInsets.zero,
              value: _calmMode,
              onChanged: (v) => setState(() => _calmMode = v),
              title: const Text('Modo tranquilo'),
              subtitle: const Text(
                'Colores suaves, sin sonidos ni animaciones.',
              ),
            ),
            if (editing)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push(Routes.sensory(child.id)),
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text(
                    'Más opciones de personalización sensorial',
                  ),
                ),
              )
            else
              const Text(
                'Después podrás ajustar la voz, el tamaño de los pictogramas y '
                'más en "Personalización sensorial".',
                style: TextStyle(color: AppColors.inkSoft),
              ),
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save-child'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Familia del perfil nuevo: la única, una a elegir o el nombre de una nueva.
class _FamilyPicker extends ConsumerWidget {
  const _FamilyPicker({
    required this.familyId,
    required this.nameController,
    required this.onChanged,
  });

  final String? familyId;
  final TextEditingController nameController;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final families = ref.watch(familiesProvider).value ?? const [];
    if (families.isEmpty) {
      return TextFormField(
        key: const Key('child-family-name'),
        controller: nameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Nombre de tu familia',
          helperText: 'Se creará tu familia con este perfil.',
        ),
        validator: (v) {
          final text = v?.trim() ?? '';
          if (text.isEmpty) return 'Escribe un nombre.';
          if (text.length > 60) return 'Máximo 60 caracteres.';
          return null;
        },
      );
    }
    if (families.length == 1) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Text('🏡', style: TextStyle(fontSize: 26)),
        title: Text('Familia: ${families.first.name}'),
        subtitle: const Text('Sus adultos responsables verán este perfil.'),
      );
    }
    return DropdownButtonFormField<String>(
      key: const Key('child-family'),
      initialValue: familyId ?? families.first.id,
      decoration: const InputDecoration(labelText: 'Familia'),
      items: [
        for (final f in families)
          DropdownMenuItem(value: f.id, child: Text(f.name)),
      ],
      onChanged: onChanged,
    );
  }
}
