import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/support_strategy.dart';
import '../../access/application/access_providers.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../../../core/theme/ui_icons.dart';

final strategiesProvider = StreamProvider.family<List<SupportStrategy>, String>(
  (ref, childId) {
    ref.watch(sessionUidProvider);
    return ref.watch(strategiesRepositoryProvider).watchStrategies(childId);
  },
);

/// Estrategias de apoyo compartidas entre hogar y escuela.
class StrategiesScreen extends ConsumerStatefulWidget {
  const StrategiesScreen({super.key, required this.childId});

  final String childId;

  @override
  ConsumerState<StrategiesScreen> createState() => _StrategiesScreenState();
}

class _StrategiesScreenState extends ConsumerState<StrategiesScreen> {
  StrategyPlace? _place;

  /// En la experiencia docente: "Estrategias en el aula".
  bool get _classroom =>
      ref.read(activeExperienceProvider) == UserExperience.teacher;

  @override
  void initState() {
    super.initState();
    if (_classroom) _place = StrategyPlace.school;
  }

  @override
  Widget build(BuildContext context) {
    return ChildGuard(
      childId: widget.childId,
      builder: (context, child, user) {
        final async = ref.watch(strategiesProvider(widget.childId));
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _classroom
                  ? 'Estrategias en el aula · ${child.name}'
                  : 'Estrategias · ${child.name}',
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('add-strategy'),
            onPressed: () => _openForm(context, child, user, null),
            icon: const Icon(Icons.add),
            label: const Text('Nueva estrategia'),
          ),
          body: Column(
            children: [
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Todas'),
                        selected: _place == null,
                        onSelected: (_) => setState(() => _place = null),
                      ),
                    ),
                    for (final p in StrategyPlace.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(p.icon, size: 18),
                          label: Text(p.label),
                          selected: _place == p,
                          onSelected: (_) => setState(() => _place = p),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncValueView<List<SupportStrategy>>(
                  value: async,
                  data: (all) {
                    final list = all
                        .where((s) => _place == null || s.place == _place)
                        .toList();
                    if (list.isEmpty) {
                      return const EmptyState(
                        icon: Icons.lightbulb_outline_rounded,
                        title: 'Sin estrategias registradas',
                        message:
                            'Comparte lo que funciona en casa, en la '
                            'escuela o en terapia.',
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) => _StrategyCard(
                        strategy: list[i],
                        canEdit: Permissions.canEditStrategy(
                          child,
                          list[i],
                          user.uid,
                        ),
                        onEdit: () => _openForm(context, child, user, list[i]),
                        onDelete: () => _delete(context, user, list[i]),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(
    BuildContext context,
    AppUser user,
    SupportStrategy strategy,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar estrategia',
      message: '¿Eliminar "${strategy.title}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(strategiesRepositoryProvider)
          .deleteStrategy(strategy, actor: user),
      success: 'Estrategia eliminada.',
    );
  }

  Future<void> _openForm(
    BuildContext context,
    ChildProfile child,
    AppUser user,
    SupportStrategy? existing,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _StrategyForm(child: child, user: user, existing: existing),
    );
  }
}

class _StrategyCard extends StatelessWidget {
  const _StrategyCard({
    required this.strategy,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final SupportStrategy strategy;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = strategy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    s.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canEdit)
                  PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Editar')),
                      PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                    ],
                  ),
              ],
            ),
            if (s.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(s.description),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  avatar: Icon(s.place.icon, size: 18),
                  label: Text(s.place.label),
                ),
                Chip(
                  avatar: Icon(s.result.icon, size: 18, color: s.result.color),
                  label: Text(s.result.label),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Registrado por ${s.createdByName} (${s.createdByRole.label}) · '
              '${formatDate(s.createdAt)}',
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrategyForm extends ConsumerStatefulWidget {
  const _StrategyForm({required this.child, required this.user, this.existing});

  final ChildProfile child;
  final AppUser user;
  final SupportStrategy? existing;

  @override
  ConsumerState<_StrategyForm> createState() => _StrategyFormState();
}

class _StrategyFormState extends ConsumerState<_StrategyForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late StrategyPlace _place;
  late StrategyResult _result;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    final teacher =
        ref.read(activeExperienceProvider) == UserExperience.teacher;
    _place = e?.place ?? (teacher ? StrategyPlace.school : StrategyPlace.home);
    _result = e?.result ?? StrategyResult.worked;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(strategiesRepositoryProvider);
    final existing = widget.existing;
    final ok = await runGuarded(context, () async {
      if (existing == null) {
        await repo.addStrategy(
          SupportStrategy(
            id: newId(),
            childId: widget.child.id,
            title: _title.text.trim(),
            description: _description.text.trim(),
            place: _place,
            result: _result,
            createdByUid: widget.user.uid,
            createdByName: widget.user.displayName,
            createdByRole: widget.user.role,
            createdAt: DateTime.now(),
          ),
        );
      } else {
        await repo.updateStrategy(
          existing.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            place: _place,
            result: _result,
          ),
          actor: widget.user,
        );
      }
    }, success: 'Estrategia guardada.');
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existing == null
                    ? 'Nueva estrategia'
                    : 'Editar estrategia',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('strategy-title'),
                controller: _title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Estrategia'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Describe la estrategia.' : null,
              ),
              TextFormField(
                controller: _description,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Detalles (cuándo y cómo se usa)',
                ),
              ),
              const Text(
                'Lugar',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in StrategyPlace.values)
                    ChoiceChip(
                      avatar: Icon(p.icon, size: 18),
                      label: Text(p.label),
                      selected: _place == p,
                      onSelected: (_) => setState(() => _place = p),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Resultado',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final r in StrategyResult.values)
                    ChoiceChip(
                      avatar: Icon(r.icon, size: 18, color: r.color),
                      label: Text(r.label),
                      selected: _result == r,
                      onSelected: (_) => setState(() => _result = r),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('save-strategy'),
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Guardando…' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
