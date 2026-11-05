import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/theme/ui_icons.dart';
import '../../../core/visuals/avatar_catalog.dart';
import '../../../core/widgets/avatar_picker.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/app_user.dart';
import '../../authentication/application/session_actions.dart';

/// Edición de "Mi perfil": nombre, apellido, avatar o fotografía y los datos
/// opcionales de cada experiencia.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AppUser _original;
  late final TextEditingController _name;
  late final TextEditingController _lastName;
  late final TextEditingController _school;
  late final TextEditingController _group;
  late AdultRole _relation;
  late String _avatar;
  late int _color;
  String? _teacherTitle;
  File? _newPhoto;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _original = ref.read(currentUserProvider)!;
    final u = _original;
    final last = u.lastName ?? '';
    final given = last.isNotEmpty && u.displayName.endsWith(' $last')
        ? u.displayName.substring(0, u.displayName.length - last.length - 1)
        : u.displayName;
    _name = TextEditingController(text: given);
    _lastName = TextEditingController(text: last);
    _school = TextEditingController(text: u.schoolName ?? '');
    _group = TextEditingController(text: u.groupName ?? '');
    _relation = u.role.isFamily ? u.role : AdultRole.tutor;
    _avatar = AvatarCatalog.normalize(
      u.avatar,
      fallback: AvatarCatalog.defaultAdult,
    );
    _color = u.avatarColorValue;
    _teacherTitle = u.teacherTitle;
  }

  @override
  void dispose() {
    for (final c in [_name, _lastName, _school, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final u = _original;
    final last = _lastName.text.trim();
    final fullName = [
      _name.text.trim(),
      last,
    ].where((s) => s.isNotEmpty).join(' ');
    String? opt(String v) => v.trim().isEmpty ? null : v.trim();
    final updated = u.copyWith(
      displayName: fullName,
      lastName: () => opt(last),
      // El rol de familia se edita aquí; el de docente se conserva.
      role: u.isGuardian && u.role.isFamily ? _relation : u.role,
      avatar: () => _avatar,
      avatarColor: () => _color,
      schoolName: () => u.isTeacher ? opt(_school.text) : u.schoolName,
      groupName: () => u.isTeacher ? opt(_group.text) : u.groupName,
      teacherTitle: () => u.isTeacher ? _teacherTitle : u.teacherTitle,
    );
    try {
      await ref
          .read(sessionActionsProvider)
          .updateProfile(
            updated,
            newPhoto: _newPhoto,
            removePhoto: _removePhoto,
          );
      if (!mounted) return;
      showMessage(context, 'Perfil actualizado.');
      context.pop();
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = _original;
    return Scaffold(
      appBar: AppBar(title: const Text('Editar mi perfil')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const Key('profile-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('profile-last-name'),
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
              options: AvatarCatalog.forAdults,
              colorOptions: AppUser.colorOptions,
              existingPhoto: _removePhoto ? null : u.photo,
              newPhoto: _newPhoto,
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
                _removePhoto = u.photo != null;
              }),
            ),
            if (u.isGuardian && u.role.isFamily) ...[
              const SizedBox(height: 16),
              const Text(
                'Tipo de relación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final r in AdultRole.familyRoles)
                    ChoiceChip(
                      avatar: Icon(r.icon, size: 18),
                      label: Text(r.label),
                      selected: _relation == r,
                      onSelected: (_) => setState(() => _relation = r),
                    ),
                ],
              ),
            ],
            if (u.isTeacher) ...[
              const SizedBox(height: 16),
              const Text(
                '¿Cómo te llaman tus alumnos?',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final t in AppUser.teacherTitles)
                    ChoiceChip(
                      label: Text(t),
                      selected: _teacherTitle == t,
                      onSelected: (v) =>
                          setState(() => _teacherTitle = v ? t : null),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _school,
                decoration: const InputDecoration(
                  labelText: 'Escuela (opcional)',
                ),
                validator: Validators.optionalText,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _group,
                decoration: const InputDecoration(
                  labelText: 'Grupo o grado (opcional)',
                ),
                validator: Validators.optionalText,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save-profile'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
