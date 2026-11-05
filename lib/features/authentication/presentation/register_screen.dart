import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/constants/app_texts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/ui_icons.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/visuals/avatar_catalog.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/avatar_picker.dart';
import '../../../models/app_user.dart';
import '../../access/application/access_providers.dart';
import '../../access/presentation/widgets/role_illustration.dart';
import '../application/session_actions.dart';
import 'login_screen.dart' show LocalModeNotice;
import 'post_auth_navigation.dart';
import 'widgets/auth_layout.dart';

/// Registro de un adulto: familia (padre, madre o tutor) o docente, según lo
/// elegido en "¿Cómo deseas ingresar?".
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _school = TextEditingController();
  final _group = TextEditingController();
  AdultRole _relation = AdultRole.madre;
  String? _teacherTitle;
  String? _avatar;
  int _avatarColor = AppUser.colorOptions.first;
  File? _photo;
  bool _accepted = false;
  bool _loading = false;
  String? _error;

  bool get _teacher =>
      ref.read(activeExperienceProvider) == UserExperience.teacher;

  @override
  void dispose() {
    for (final c in [
      _name,
      _lastName,
      _email,
      _password,
      _confirm,
      _school,
      _group,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_accepted) {
      setState(() => _error = 'Debes aceptar el aviso de privacidad.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final teacher = _teacher;
    final lastName = _lastName.text.trim();
    final fullName = [
      _name.text.trim(),
      lastName,
    ].where((s) => s.isNotEmpty).join(' ');
    final role = teacher ? AdultRole.docente : _relation;
    try {
      final user = await ref
          .read(sessionActionsProvider)
          .register(
            email: _email.text,
            password: _password.text,
            displayName: fullName,
            role: role,
            lastName: lastName,
            avatar: _avatar ?? AvatarCatalog.defaultAdult,
            avatarColor: _avatarColor,
            schoolName: teacher ? _school.text : null,
            groupName: teacher ? _group.text : null,
            teacherTitle: teacher ? _teacherTitle : null,
            experiences: {
              teacher ? UserExperience.teacher : UserExperience.guardian,
            },
            photo: _photo,
          );
      // Se reemplaza toda la pila por el panel de la experiencia elegida.
      if (mounted) {
        await navigateAfterAuth(context, ref, user, registered: true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacher =
        ref.watch(activeExperienceProvider) == UserExperience.teacher;
    return AuthLayout(
      title: teacher ? 'Registro de docente' : 'Registro de familia',
      subtitle: teacher
          ? 'Después, la familia de cada alumno te compartirá un código de '
                'vinculación.'
          : 'Después podrás crear los perfiles de tus hijos o unirte con un '
                'código de invitación.',
      header: RoleIllustration(
        role: teacher ? AccessRole.teacher : AccessRole.guardian,
        size: 96,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ref.watch(isDemoModeProvider)) ...[
              const LocalModeNotice(),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('register-name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-last-name'),
              controller: _lastName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Apellido (opcional)',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: Validators.optionalName,
            ),
            const SizedBox(height: 14),
            if (teacher) ...[
              const Text(
                '¿Cómo te llaman tus alumnos? (opcional)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final title in AppUser.teacherTitles)
                    ChoiceChip(
                      key: Key('teacher-title-$title'),
                      label: Text(title),
                      selected: _teacherTitle == title,
                      onSelected: (v) =>
                          setState(() => _teacherTitle = v ? title : null),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register-school'),
                controller: _school,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Escuela (opcional)',
                  prefixIcon: Icon(Icons.school_outlined),
                ),
                validator: Validators.optionalText,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('register-group'),
                controller: _group,
                decoration: const InputDecoration(
                  labelText: 'Grupo o grado (opcional)',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
                validator: Validators.optionalText,
              ),
            ] else ...[
              const Text(
                'Tipo de relación',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in AdultRole.familyRoles)
                    ChoiceChip(
                      key: Key('relation-${r.name}'),
                      avatar: Icon(r.icon, size: 18),
                      label: Text(r.label),
                      selected: _relation == r,
                      onSelected: (_) => setState(() => _relation = r),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: Validators.email,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-password'),
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña (mín. 8, letras y números)',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: Validators.password,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('register-confirm'),
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Repite la contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) =>
                  v != _password.text ? 'Las contraseñas no coinciden.' : null,
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              key: const Key('register-avatar'),
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Avatar o fotografía (opcional)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [
                AvatarPicker(
                  avatar: _avatar ?? AvatarCatalog.defaultAdult,
                  color: _avatarColor,
                  options: AvatarCatalog.forAdults,
                  colorOptions: AppUser.colorOptions,
                  newPhoto: _photo,
                  onAvatar: (a) => setState(() => _avatar = a),
                  onColor: (c) => setState(() => _avatarColor = c),
                  onPickPhoto: () async {
                    final file = await pickAvatarPhoto(context);
                    if (file != null && mounted) setState(() => _photo = file);
                  },
                  onRemovePhoto: () => setState(() => _photo = null),
                ),
                const SizedBox(height: 12),
              ],
            ),
            CheckboxListTile(
              key: const Key('register-accept'),
              contentPadding: EdgeInsets.zero,
              value: _accepted,
              onChanged: (v) => setState(() => _accepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                teacher
                    ? 'Soy mayor de edad y trataré la información de mis '
                          'alumnos solo para su apoyo comunicativo.'
                    : 'Soy mayor de edad y acepto el tratamiento de datos de '
                          'los niños a mi cargo para su apoyo comunicativo.',
                style: const TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                AppTexts.privacySummary,
                style: TextStyle(fontSize: 12),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.urgent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              key: const Key('register-submit'),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Crear cuenta'),
            ),
          ],
        ),
      ),
    );
  }
}
