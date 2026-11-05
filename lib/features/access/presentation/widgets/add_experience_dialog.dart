import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/dialogs.dart';
import '../../../../models/app_user.dart';
import '../../../authentication/application/session_actions.dart';

/// Activa la experiencia de familia o de docente en la cuenta actual (misma
/// identidad, sin crear otra cuenta). No otorga acceso a ningún niño: los
/// vínculos siguen requiriendo un código de invitación.
Future<bool> showAddExperienceDialog(
  BuildContext context,
  WidgetRef ref,
  UserExperience experience,
) async {
  final school = TextEditingController();
  final group = TextEditingController();
  String? title;
  final teacher = experience == UserExperience.teacher;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          teacher ? 'Activar perfil docente' : 'Activar perfil de familia',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                teacher
                    ? 'Podrás crear clases e invitar a las familias de tus '
                          'alumnos con un código o QR.'
                    : 'Podrás crear perfiles infantiles y administrarlos.',
              ),
              if (teacher) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in AppUser.teacherTitles)
                      ChoiceChip(
                        label: Text(t),
                        selected: title == t,
                        onSelected: (v) => setState(() => title = v ? t : null),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: school,
                  decoration: const InputDecoration(
                    labelText: 'Escuela (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: group,
                  decoration: const InputDecoration(
                    labelText: 'Grupo o grado (opcional)',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirm-add-experience'),
            onPressed: () {
              if (Validators.optionalText(school.text) != null ||
                  Validators.optionalText(group.text) != null) {
                return;
              }
              Navigator.of(context).pop(true);
            },
            child: const Text('Activar'),
          ),
        ],
      ),
    ),
  );
  final schoolName = school.text;
  final groupName = group.text;
  school.dispose();
  group.dispose();
  if (ok != true || !context.mounted) return false;
  return runGuarded(
    context,
    () => ref
        .read(sessionActionsProvider)
        .addExperience(
          experience,
          schoolName: schoolName,
          groupName: groupName,
          teacherTitle: title,
        ),
    success: teacher
        ? 'Perfil docente activado.'
        : 'Perfil de familia activado.',
  );
}
