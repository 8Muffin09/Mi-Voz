import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/classroom.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../application/classes_providers.dart';
import '../../../core/widgets/visuals.dart';

/// "Mis clases": activas y archivadas, con una pantalla vacía útil.
class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(classesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mis clases')),
      floatingActionButton: (async.value ?? const []).isEmpty
          ? null
          : FloatingActionButton.extended(
              key: const Key('create-class'),
              onPressed: () => context.push(Routes.classNew),
              icon: const Icon(Icons.add),
              label: const Text('Crear clase'),
            ),
      body: AsyncValueView<List<Classroom>>(
        value: async,
        onRetry: () => ref.invalidate(classesProvider),
        data: (classes) {
          if (classes.isEmpty) return const NoClassesState();
          final active = classes.where((c) => !c.archived).toList();
          final archived = classes.where((c) => c.archived).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              const SectionHeader('Activas'),
              if (active.isEmpty)
                const Text(
                  'No tienes clases activas.',
                  style: TextStyle(color: AppColors.inkSoft),
                ),
              for (final c in active) ...[
                ClassCard(classroom: c),
                const SizedBox(height: 10),
              ],
              if (archived.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const Key('toggle-archived'),
                  onPressed: () =>
                      setState(() => _showArchived = !_showArchived),
                  icon: Icon(
                    _showArchived ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text('Clases archivadas (${archived.length})'),
                ),
                if (_showArchived)
                  for (final c in archived) ...[
                    ClassCard(classroom: c),
                    const SizedBox(height: 10),
                  ],
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Sin clases todavía: explica qué es una clase y ofrece crear la primera.
class NoClassesState extends StatelessWidget {
  const NoClassesState({super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
    art: const GroupIllustration.classroom(),
    title: 'Aún no tienes clases',
    message:
        'Una clase agrupa a tus alumnos. Las familias te autorizan a ver a '
        'cada alumno; tú los organizas en tus clases.',
    action: FilledButton.icon(
      key: const Key('create-first-class'),
      onPressed: () => context.push(Routes.classNew),
      icon: const Icon(Icons.add),
      label: const Text('Crear mi primera clase'),
    ),
  );
}

class ClassCard extends StatelessWidget {
  const ClassCard({super.key, required this.classroom});

  final Classroom classroom;

  @override
  Widget build(BuildContext context) {
    final c = classroom;
    return Card(
      key: Key('class-${c.id}'),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: c.archived
              ? Colors.black12
              : AppColors.primary.withValues(alpha: 0.12),
          child: Icon(
            c.archived ? Icons.inventory_2_outlined : Icons.groups_rounded,
            color: c.archived ? AppColors.inkSoft : AppColors.primary,
          ),
        ),
        title: Text(
          c.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            '${c.studentIds.length} alumno(s)',
            if (c.description.isNotEmpty) c.description,
            if (c.archived) 'Archivada',
          ].join(' · '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(Routes.classDetail(c.id)),
      ),
    );
  }
}
