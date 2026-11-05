import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/classroom.dart';
import '../application/classes_providers.dart';

/// Crear o editar una clase: nombre y descripción opcional.
class ClassFormScreen extends ConsumerWidget {
  const ClassFormScreen({super.key, this.classId});

  final String? classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = classId;
    if (id == null) return const _ClassForm(existing: null);
    return ref
        .watch(classProvider(id))
        .when(
          loading: () => const Scaffold(body: LoadingView()),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(error: e),
          ),
          data: (c) => c == null
              ? Scaffold(
                  appBar: AppBar(),
                  body: const EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'No tienes acceso a esta clase',
                  ),
                )
              : _ClassForm(existing: c),
        );
  }
}

class _ClassForm extends ConsumerStatefulWidget {
  const _ClassForm({required this.existing});

  final Classroom? existing;

  @override
  ConsumerState<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends ConsumerState<_ClassForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _description = TextEditingController(
    text: widget.existing?.description ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _saving = true);
    final repo = ref.read(classesRepositoryProvider);
    try {
      final existing = widget.existing;
      if (existing == null) {
        final created = await repo.createClass(
          owner: user,
          name: _name.text,
          description: _description.text,
        );
        if (!mounted) return;
        showMessage(context, 'Clase "${created.name}" creada.');
        context.pushReplacement(Routes.classDetail(created.id));
      } else {
        await repo.updateClass(
          existing,
          name: _name.text,
          description: _description.text,
          actor: user,
        );
        if (!mounted) return;
        showMessage(context, 'Cambios guardados.');
        context.pop();
      }
    } catch (e) {
      if (mounted) showMessage(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? 'Editar clase' : 'Nueva clase')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextFormField(
              key: const Key('class-name'),
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre de la clase',
                hintText: 'Por ejemplo: 2.º B',
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Escribe un nombre.';
                if (text.length > 60) return 'Máximo 60 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('class-description'),
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                hintText: 'Por ejemplo: grupo de la mañana',
              ),
              validator: (v) => (v?.trim().length ?? 0) > 200
                  ? 'Máximo 200 caracteres.'
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('save-class'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Guardando…' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
