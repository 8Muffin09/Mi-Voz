import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../models/app_user.dart';
import '../../access/application/access_providers.dart';

/// Después de iniciar sesión o registrarse: abre el panel que corresponde a
/// la cuenta (reemplazando toda la pila: Atrás no vuelve al formulario) y, si
/// se eligió "Alumno", continúa con la creación del perfil infantil.
///
/// Al iniciar sesión no se vuelve a preguntar el rol: se abre la experiencia
/// que la cuenta ya tiene (la última usada si tiene varias). Tras un registro
/// nuevo ([registered]) se ofrece crear o unirse a la clase o familia.
Future<void> navigateAfterAuth(
  BuildContext context,
  WidgetRef ref,
  AppUser user, {
  bool registered = false,
}) async {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final experience = ref.read(activeExperienceProvider);
  final wantsStudent = ref.read(pendingStudentProfileProvider);
  ref.read(pendingStudentProfileProvider.notifier).set(false);

  if (!user.hasExperience(experience)) {
    // La cuenta no tiene la experiencia elegida: se abre la suya (puede
    // activar la otra desde "Cambiar perfil" sin crear otra cuenta).
    await ref
        .read(selectedExperienceProvider.notifier)
        .select(user.effectiveExperiences.first);
  }

  router.go(Routes.adult);
  if (!wantsStudent) {
    if (registered) {
      final teacher =
          ref.read(activeExperienceProvider) == UserExperience.teacher;
      router.push(teacher ? Routes.setupClass : Routes.setupFamily);
    }
    return;
  }
  if (user.isGuardian) {
    await ref
        .read(selectedExperienceProvider.notifier)
        .select(UserExperience.guardian);
    router.push(Routes.kidNew);
  } else {
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Los perfiles infantiles los crea la familia del alumno. Después la '
          'familia usa el código de tu clase para vincularlo.',
        ),
      ),
    );
  }
}
