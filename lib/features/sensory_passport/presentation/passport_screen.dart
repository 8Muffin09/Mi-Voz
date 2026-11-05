import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_texts.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/sensory_passport.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../../profiles/application/profiles_providers.dart';
import '../../../core/widgets/visuals.dart';
import '../../../core/theme/ui_icons.dart';

final passportProvider = StreamProvider.family<SensoryPassport, String>((
  ref,
  childId,
) {
  ref.watch(sessionUidProvider);
  return ref.watch(passportRepositoryProvider).watchPassport(childId);
});

/// "Mi Pasaporte Sensorial": consulta y edición por adultos autorizados.
class PassportScreen extends ConsumerWidget {
  const PassportScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) {
        final myLink = ref
            .watch(caregiverLinksProvider(childId))
            .value
            ?.where((l) => l.adultUid == user.uid)
            .firstOrNull;
        if (!Permissions.canViewPassport(child, user.uid, myLink)) {
          return Scaffold(
            appBar: AppBar(title: Text('Pasaporte · ${child.name}')),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Sin acceso al Pasaporte Sensorial',
              message:
                  'La familia no autorizó que veas esta información. Puedes '
                  'pedírselo a su administrador.',
            ),
          );
        }
        final async = ref.watch(passportProvider(childId));
        return AsyncValueView<SensoryPassport>(
          value: async,
          data: (passport) =>
              _PassportView(child: child, user: user, passport: passport),
        );
      },
    );
  }
}

class _PassportView extends ConsumerStatefulWidget {
  const _PassportView({
    required this.child,
    required this.user,
    required this.passport,
  });

  final ChildProfile child;
  final AppUser user;
  final SensoryPassport passport;

  @override
  ConsumerState<_PassportView> createState() => _PassportViewState();
}

class _PassportViewState extends ConsumerState<_PassportView> {
  bool _editing = false;
  bool _saving = false;
  late SensoryPassport _draft;
  late TextEditingController _preferences;
  late TextEditingController _communication;
  final Map<SensoryArea, TextEditingController> _notes = {};

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _draft = widget.passport;
    _preferences = TextEditingController(text: _draft.personalPreferences);
    _communication = TextEditingController(
      text: _draft.communicationPreferences,
    );
    for (final area in SensoryArea.values) {
      _notes[area]?.dispose();
      _notes[area] = TextEditingController(
        text: _draft.sensitivity(area).notes,
      );
    }
  }

  @override
  void didUpdateWidget(covariant _PassportView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.passport != widget.passport) {
      _preferences.dispose();
      _communication.dispose();
      _reset();
    }
  }

  @override
  void dispose() {
    _preferences.dispose();
    _communication.dispose();
    for (final c in _notes.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final passport = _draft.copyWith(
      personalPreferences: _preferences.text.trim(),
      communicationPreferences: _communication.text.trim(),
      sensitivities: {
        for (final area in SensoryArea.values)
          area: Sensitivity(
            level: _draft.sensitivity(area).level,
            notes: _notes[area]!.text.trim(),
          ),
      },
    );
    final ok = await runGuarded(
      context,
      () => ref
          .read(passportRepositoryProvider)
          .savePassport(passport, editorName: widget.user.displayName),
      success: 'Pasaporte guardado.',
    );
    if (mounted) {
      setState(() {
        _saving = false;
        if (ok) _editing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final p = _editing ? _draft : widget.passport;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasaporte Sensorial'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _editing = false;
                      _preferences.dispose();
                      _communication.dispose();
                      _reset();
                    }),
              child: const Text('Cancelar'),
            )
          else
            IconButton(
              key: const Key('edit-passport'),
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      floatingActionButton: _editing
          ? FloatingActionButton.extended(
              key: const Key('save-passport'),
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Guardando…' : 'Guardar'),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ChildAvatar(child: child, size: 64),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mi Pasaporte Sensorial',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          child.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (p.updatedAt != null)
                          Text(
                            'Actualizado ${formatDateTime(p.updatedAt!)}'
                            '${p.updatedByName != null ? ' por ${p.updatedByName}' : ''}',
                            style: const TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar nombre y avatar',
                    icon: const Icon(Icons.face_retouching_natural),
                    onPressed: () => context.push(Routes.kidEdit(child.id)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            AppTexts.passportDisclaimer,
            style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
          _Section(title: 'Sensibilidades'),
          for (final area in SensoryArea.values)
            _SensitivityCard(
              area: area,
              value: p.sensitivity(area),
              editing: _editing,
              notesController: _notes[area]!,
              onLevel: (level) => setState(() {
                _draft = _draft.copyWith(
                  sensitivities: {
                    ..._draft.sensitivities,
                    area: Sensitivity(
                      level: level,
                      notes: _draft.sensitivity(area).notes,
                    ),
                  },
                );
              }),
            ),
          _Section(title: 'Preferencias personales'),
          _TextBlock(
            editing: _editing,
            controller: _preferences,
            value: p.personalPreferences,
            hint: 'Gustos, intereses, cosas que lo motivan…',
          ),
          _ListBlock(
            title: 'Objetos favoritos',
            icon: Icons.favorite_border_rounded,
            values: p.favoriteObjects,
            editing: _editing,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(favoriteObjects: v)),
          ),
          _ListBlock(
            title: 'Actividades tranquilizadoras',
            icon: Icons.self_improvement_rounded,
            values: p.calmingActivities,
            editing: _editing,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(calmingActivities: v)),
          ),
          _ListBlock(
            title: 'Lugares seguros',
            icon: Icons.home_outlined,
            values: p.safePlaces,
            editing: _editing,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(safePlaces: v)),
          ),
          _ListBlock(
            title: 'Situaciones que generan molestias',
            icon: Icons.warning_amber_rounded,
            values: p.triggers,
            editing: _editing,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(triggers: v)),
          ),
          _ListBlock(
            title: 'Estrategias de apoyo',
            icon: Icons.lightbulb_outline_rounded,
            values: p.supportStrategies,
            editing: _editing,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(supportStrategies: v)),
          ),
          _Section(title: 'Preferencias de comunicación'),
          _TextBlock(
            editing: _editing,
            controller: _communication,
            value: p.communicationPreferences,
            hint: 'Cómo prefiere comunicarse, cómo darle instrucciones…',
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}

class _SensitivityCard extends StatelessWidget {
  const _SensitivityCard({
    required this.area,
    required this.value,
    required this.editing,
    required this.notesController,
    required this.onLevel,
  });

  final SensoryArea area;
  final Sensitivity value;
  final bool editing;
  final TextEditingController notesController;
  final ValueChanged<SensitivityLevel> onLevel;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.success,
      AppColors.secondary,
      AppColors.warning,
      AppColors.urgent,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SymbolImage(area.symbol, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    area.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!editing)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors[value.level.value].withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      value.level.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors[value.level.value],
                      ),
                    ),
                  ),
              ],
            ),
            if (editing) ...[
              const SizedBox(height: 10),
              SegmentedButton<SensitivityLevel>(
                showSelectedIcon: false,
                segments: [
                  for (final l in SensitivityLevel.values)
                    ButtonSegment(value: l, label: Text(l.label)),
                ],
                selected: {value.level},
                onSelectionChanged: (s) => onLevel(s.first),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notas'),
              ),
            ] else if (value.notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(value.notes),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextBlock extends StatelessWidget {
  const _TextBlock({
    required this.editing,
    required this.controller,
    required this.value,
    required this.hint,
  });

  final bool editing;
  final TextEditingController controller;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: editing
          ? TextField(
              controller: controller,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(hintText: hint),
            )
          : Text(
              value.isEmpty ? 'Sin información todavía.' : value,
              style: TextStyle(color: value.isEmpty ? AppColors.inkSoft : null),
            ),
    ),
  );
}

/// Lista editable de textos cortos (objetos, lugares, actividades…).
class _ListBlock extends StatefulWidget {
  const _ListBlock({
    required this.title,
    required this.icon,
    required this.values,
    required this.editing,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final List<String> values;
  final bool editing;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_ListBlock> createState() => _ListBlockState();
}

class _ListBlockState extends State<_ListBlock> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final text = _input.text.trim();
    if (text.isEmpty || widget.values.contains(text)) return;
    widget.onChanged([...widget.values, text]);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.values.isEmpty && !widget.editing)
            const Text(
              'Sin información todavía.',
              style: TextStyle(color: AppColors.inkSoft),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in widget.values)
                widget.editing
                    ? InputChip(
                        label: Text(v),
                        onDeleted: () => widget.onChanged(
                          widget.values.where((e) => e != v).toList(),
                        ),
                      )
                    : Chip(label: Text(v)),
            ],
          ),
          if (widget.editing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      decoration: const InputDecoration(hintText: 'Agregar…'),
                      onSubmitted: (_) => _add(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Agregar',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _add,
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}
