import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/visuals.dart';

/// Paso posterior al registro: crear el grupo propio (clase o familia) o
/// unirse a uno existente con un código. Unirse siempre pasa por la
/// validación del código en el servidor; elegir el rol no da acceso.
class GroupSetupScreen extends StatelessWidget {
  const GroupSetupScreen({super.key, required this.teacher});

  /// `true`: clase (docente). `false`: familia (padre, madre o tutor).
  final bool teacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(teacher ? 'Tu clase' : 'Tu familia'),
        actions: [
          TextButton(
            key: const Key('setup-skip'),
            onPressed: () => context.go(Routes.adult),
            child: const Text('Más tarde'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: teacher
                        ? const GroupIllustration.classroom()
                        : const GroupIllustration.family(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    teacher
                        ? '¿Creas una clase o te unes a una?'
                        : '¿Creas tu familia o te unes a una?',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    teacher
                        ? 'En tu clase agruparás a tus alumnos. Las familias '
                              'vinculan a cada niño con el código de la clase.'
                        : 'En tu familia agruparás los perfiles de tus hijos y '
                              'a los adultos responsables.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('setup-create'),
                    onPressed: () => context.pushReplacement(
                      teacher ? Routes.classNew : Routes.familyNew,
                    ),
                    icon: Icon(
                      teacher
                          ? Icons.add_business_rounded
                          : Icons.add_home_rounded,
                    ),
                    label: Text(
                      teacher ? 'Crear mi clase' : 'Crear mi familia',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('setup-join'),
                    onPressed: () => context.pushReplacement(Routes.join),
                    icon: const Icon(Icons.key_rounded),
                    label: const Text('Tengo un código de invitación'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
