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
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';
import '../../../models/group_invitation.dart';
import '../../access/application/access_providers.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../invitations/presentation/invitation_widgets.dart';
import '../../profiles/application/profiles_providers.dart';
import '../application/classes_providers.dart';

/// Detalle de una clase: alumnos, alta de alumnos ya autorizados, retiro con
/// confirmación y archivo. Solo la ven sus docentes.
class ClassDetailScreen extends ConsumerWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(classProvider(classId));
    final children = ref.watch(childrenProvider).value ?? const [];
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e),
      ),
      data: (classroom) {
        if (classroom == null || user == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'No tienes acceso a esta clase',
              message: 'Solo sus docentes pueden verla.',
            ),
          );
        }
        final owner = Permissions.canManageClass(classroom, user.uid);
        final byId = {for (final c in children) c.id: c};
        final students = [for (final id in classroom.studentIds) ?byId[id]]
          ..sort((a, b) => a.name.compareTo(b.name));
        return Scaffold(
          appBar: AppBar(
            title: Text(classroom.name),
            actions: [
              if (owner)
                IconButton(
                  key: const Key('edit-class'),
                  tooltip: 'Editar clase',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push(Routes.classEdit(classroom.id)),
                ),
              if (owner)
                PopupMenuButton<String>(
                  key: const Key('class-menu'),
                  onSelected: (_) =>
                      _toggleArchive(context, ref, classroom, user),
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      key: const Key('archive-class'),
                      value: 'archive',
                      child: Text(
                        classroom.archived
                            ? 'Reactivar clase'
                            : 'Archivar clase',
                      ),
                    ),
                  ],
                ),
            ],
          ),
          floatingActionButton: owner && !classroom.archived
              ? FloatingActionButton.extended(
                  key: const Key('add-student'),
                  onPressed: () => _addStudent(context, ref, classroom, user),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Agregar alumno'),
                )
              : null,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            children: [
              if (classroom.description.isNotEmpty)
                Text(
                  classroom.description,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 16,
                  ),
                ),
              if (classroom.archived)
                Card(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  child: const ListTile(
                    leading: Icon(Icons.inventory_2_outlined),
                    title: Text('Clase archivada'),
                    subtitle: Text(
                      'Se conserva con su historial. Reactívala desde el menú '
                      'para volver a usarla.',
                    ),
                  ),
                ),
              // Invitar familias (código o QR) y aprobar sus solicitudes.
              if (owner && !classroom.archived)
                InvitationsSection(
                  type: InviteTargetType.classroom,
                  targetId: classroom.id,
                ),
              SectionHeader(
                'Alumnos',
                subtitle: '${students.length} alumno(s)',
              ),
              if (students.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Esta clase aún no tiene alumnos. Agrega a los alumnos '
                      'que sus familias ya te autorizaron.',
                    ),
                  ),
                ),
              for (final s in students)
                Card(
                  key: Key('class-student-${s.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: ChildAvatar(child: s, size: 44),
                    title: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      s.classIds.length > 1
                          ? 'También en otras ${s.classIds.length - 1} clase(s)'
                          : 'Solo en esta clase',
                    ),
                    onTap: () async {
                      await ref
                          .read(currentStudentIdProvider.notifier)
                          .select(s.id);
                      if (context.mounted) context.go(Routes.adult);
                    },
                    trailing: owner
                        ? IconButton(
                            key: Key('remove-student-${s.id}'),
                            tooltip: 'Retirar de la clase',
                            icon: const Icon(
                              Icons.person_remove_outlined,
                              color: AppColors.urgent,
                            ),
                            onPressed: () =>
                                _remove(context, ref, classroom, s, user),
                          )
                        : null,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleArchive(
    BuildContext context,
    WidgetRef ref,
    Classroom classroom,
    AppUser user,
  ) async {
    final archiving = !classroom.archived;
    final ok = await showConfirmDialog(
      context,
      title: archiving ? 'Archivar "${classroom.name}"' : 'Reactivar clase',
      message: archiving
          ? 'La clase dejará de aparecer entre las activas. Se conservan sus '
                'alumnos y su historial, y puedes reactivarla después.'
          : 'La clase volverá a aparecer entre las activas.',
      confirmLabel: archiving ? 'Archivar' : 'Reactivar',
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(classesRepositoryProvider)
          .setArchived(classroom, archiving, actor: user),
      success: archiving ? 'Clase archivada.' : 'Clase reactivada.',
    );
  }

  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    Classroom classroom,
    ChildProfile student,
    AppUser user,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Retirar a ${student.name}',
      message:
          '${student.name} dejará de estar en "${classroom.name}". Si solo lo '
          'veías por esta clase, dejarás de ver su información. Sus datos y '
          'su familia no se modifican.',
      confirmLabel: 'Retirar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(classesRepositoryProvider)
          .removeStudent(classroom, student, actor: user),
      success: '${student.name} se retiró de la clase.',
    );
  }

  Future<void> _addStudent(
    BuildContext context,
    WidgetRef ref,
    Classroom classroom,
    AppUser user,
  ) async {
    final authorized =
        (ref.read(childrenProvider).value ?? const <ChildProfile>[])
            .where((c) => !classroom.studentIds.contains(c.id))
            .toList();
    final picked = await showModalBottomSheet<ChildProfile>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            const Text(
              'Alumnos que ya te autorizaron',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Para incorporar a un alumno nuevo, genera una invitación de la '
              'clase y compártela con su familia; tú apruebas la solicitud.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            if (authorized.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No hay más alumnos autorizados para agregar.'),
              ),
            for (final c in authorized)
              ListTile(
                key: Key('pick-student-${c.id}'),
                leading: ChildAvatar(child: c, size: 40),
                title: Text(c.name),
                onTap: () => Navigator.of(sheetContext).pop(c),
              ),
            const Divider(),
            ListTile(
              key: const Key('sheet-invite-families'),
              leading: const Icon(Icons.qr_code_2_rounded),
              title: const Text('Invitar familias con código o QR'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                createAndShareInvitation(
                  context,
                  ref,
                  type: InviteTargetType.classroom,
                  targetId: classroom.id,
                );
              },
            ),
          ],
        ),
      ),
    );
    if (picked == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(classesRepositoryProvider)
          .addAuthorizedStudent(classroom, picked, actor: user),
      success: '${picked.name} se agregó a "${classroom.name}".',
    );
  }
}
