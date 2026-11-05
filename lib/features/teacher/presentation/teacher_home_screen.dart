import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/visuals.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import '../../access/application/access_providers.dart';
import '../../classes/application/classes_providers.dart';
import '../../classes/presentation/classes_screen.dart';
import '../../invitations/presentation/invitation_widgets.dart';
import '../../account/presentation/widgets/email_verification_banner.dart';
import '../../adult/presentation/adult_home_screen.dart';
import '../../adult/presentation/widgets/request_tile.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../communication/application/requests_providers.dart';
import '../../profiles/presentation/enter_child_profile.dart';

/// Panel docente: alumno actual, mis alumnos, solicitudes (urgentes y
/// recientes), "Estoy acompañando", pasaportes, estrategias en el aula e
/// historial. Solo muestra alumnos vinculados mediante autorización.
class TeacherHomeScreen extends ConsumerWidget {
  const TeacherHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null) return const Scaffold(body: LoadingView());
    final demo = ref.watch(isDemoModeProvider);
    final studentsAsync = ref.watch(experienceChildrenProvider);
    final current = ref.watch(currentStudentProvider);
    final allRequests = ref.watch(adultRequestsProvider).value ?? const [];

    final schoolLine = [
      user.schoolName,
      user.groupName,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Voz · Docente'),
        actions: adultAppBarActions(context, user),
      ),
      body: !user.isTeacher
          ? ExperienceActivationCard(
              user: user,
              experience: UserExperience.teacher,
            )
          : AsyncValueView<List<ChildProfile>>(
              value: studentsAsync,
              onRetry: () => ref.invalidate(experienceChildrenProvider),
              data: (students) {
                final ids = students.map((c) => c.id).toSet();
                final requests = allRequests
                    .where((r) => ids.contains(r.childId))
                    .toList();
                final urgent =
                    requests
                        .where((r) => r.isUrgent && r.status.isOpen)
                        .toList()
                      ..sort(inboxOrder);
                final recent = [...requests]
                  ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  children: [
                    AdultGreeting(
                      user: user,
                      title: '¡Hola, ${user.teacherGreetingName}!',
                      subtitle: schoolLine.isEmpty
                          ? 'Te damos la bienvenida a Mi Voz.'
                          : schoolLine,
                    ),
                    const EmailVerificationBanner(),
                    if (demo) ...[
                      const SizedBox(height: 12),
                      const DemoBanner(),
                    ],
                    const _ClassesSection(),
                    const PendingApprovalsCard(),
                    if (students.isEmpty)
                      const _NoStudents()
                    else ...[
                      if (current != null)
                        _CurrentStudentCard(
                          student: current,
                          user: user,
                          requests: requests
                              .where((r) => r.childId == current.id)
                              .toList(),
                        ),
                      SectionHeader(
                        'Mis alumnos',
                        subtitle: '${students.length} alumno(s) autorizado(s)',
                        action: TextButton.icon(
                          onPressed: () => context.push(Routes.join),
                          icon: const Icon(Icons.key_rounded),
                          label: const Text('Vincular'),
                        ),
                      ),
                      _StudentsStrip(
                        students: students,
                        currentId: current?.id,
                      ),
                      _TeacherStats(requests: requests),
                      SectionHeader(
                        'Solicitudes urgentes',
                        subtitle: 'Prioridad alta de todos tus alumnos.',
                        action: TextButton(
                          onPressed: () => context.go(Routes.adultRequests),
                          child: const Text('Ver todas'),
                        ),
                      ),
                      if (urgent.isEmpty)
                        const NoPendingCard()
                      else
                        for (final r in urgent) ...[
                          RequestTile(request: r),
                          const SizedBox(height: 8),
                        ],
                      const SectionHeader('Solicitudes recientes'),
                      if (recent.isEmpty)
                        const NoPendingCard()
                      else
                        for (final r in recent.take(5)) ...[
                          RequestTile(request: r),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _NoStudents extends StatelessWidget {
  const _NoStudents();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Card(
      child: EmptyState(
        art: const GroupIllustration.classroom(),
        title: 'Aún no tienes alumnos vinculados',
        message:
            'Crea una clase y genera su código de invitación (o QR). Cada '
            'familia lo usa para vincular a su hijo, y tú apruebas la '
            'solicitud.',
        action: FilledButton.icon(
          key: const Key('teacher-open-classes'),
          onPressed: () => context.push(Routes.classes),
          icon: const Icon(Icons.groups_rounded),
          label: const Text('Ir a mis clases'),
        ),
      ),
    ),
  );
}

/// "Alumno actual: Juan" con "Cambiar alumno" y sus accesos.
class _CurrentStudentCard extends ConsumerWidget {
  const _CurrentStudentCard({
    required this.student,
    required this.user,
    required this.requests,
  });

  final ChildProfile student;
  final AppUser user;
  final List<CommunicationRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = requests.where((r) => r.status.isOpen).length;
    Widget action(
      IconData icon,
      String label,
      VoidCallback onTap, {
      Key? key,
    }) => ActionChip(
      key: key,
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        color: AppColors.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ChildAvatar(child: student, size: 60),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Alumno actual',
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                        Text(
                          student.name,
                          key: const Key('current-student-name'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          open == 0
                              ? 'Sin solicitudes pendientes'
                              : '$open solicitud(es) pendiente(s)',
                          style: TextStyle(
                            color: open == 0
                                ? AppColors.inkSoft
                                : AppColors.urgent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('change-student'),
                onPressed: () => context.push(Routes.students),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Cambiar alumno'),
              ),
              const SizedBox(height: 12),
              AccompanyingSwitch(child: student, user: user),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  action(
                    Icons.badge_outlined,
                    'Pasaporte Sensorial',
                    () => context.push(Routes.passport(student.id)),
                  ),
                  action(
                    Icons.lightbulb_outline,
                    'Estrategias en el aula',
                    () => context.push(Routes.strategies(student.id)),
                    key: const Key('teacher-strategies'),
                  ),
                  action(
                    Icons.history_rounded,
                    'Historial',
                    () => context.push(Routes.childHistory(student.id)),
                  ),
                  action(
                    Icons.child_care_rounded,
                    'Usar Mi Voz con ${student.name}',
                    () => confirmAndEnterChildProfile(context, ref, student),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lista horizontal de alumnos: tocar uno lo hace el alumno actual.
class _StudentsStrip extends ConsumerWidget {
  const _StudentsStrip({required this.students, required this.currentId});

  final List<ChildProfile> students;
  final String? currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 118,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(width: 10),
      itemBuilder: (context, i) {
        final s = students[i];
        final selected = s.id == currentId;
        return Semantics(
          button: true,
          selected: selected,
          label: 'Alumno ${s.name}',
          excludeSemantics: true,
          child: InkWell(
            key: Key('student-${s.id}'),
            borderRadius: BorderRadius.circular(18),
            onTap: () =>
                ref.read(currentStudentIdProvider.notifier).select(s.id),
            child: Container(
              width: 96,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.black12,
                  width: selected ? 3 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChildAvatar(child: s, size: 56),
                  const SizedBox(height: 6),
                  Text(
                    s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _TeacherStats extends StatelessWidget {
  const _TeacherStats({required this.requests});

  final List<CommunicationRequest> requests;

  @override
  Widget build(BuildContext context) {
    final newOnes = requests.where((r) => r.status == RequestStatus.newRequest);
    final attending = requests.where(
      (r) => r.status == RequestStatus.attending,
    );
    final urgent = requests.where((r) => r.isUrgent && r.status.isOpen);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          StatTile(
            label: 'Nuevas',
            value: newOnes.length,
            icon: Icons.fiber_new_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Urgentes',
            value: urgent.length,
            icon: Icons.warning_amber_rounded,
            color: AppColors.urgent,
          ),
          const SizedBox(width: 10),
          StatTile(
            label: 'Atendiendo',
            value: attending.length,
            icon: Icons.support_agent_rounded,
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

/// "Mis clases": acceso a las clases activas o, si no hay, a crear la
/// primera.
class _ClassesSection extends ConsumerWidget {
  const _ClassesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(classesProvider).value;
    if (classes == null) return const SizedBox.shrink();
    final active = classes.where((c) => !c.archived).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Mis clases',
          action: TextButton(
            key: const Key('open-classes'),
            onPressed: () => context.push(Routes.classes),
            child: Text(classes.isEmpty ? 'Administrar' : 'Ver todas'),
          ),
        ),
        if (active.isEmpty)
          const Card(child: NoClassesState())
        else
          for (final c in active.take(3)) ...[
            ClassCard(classroom: c),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}
