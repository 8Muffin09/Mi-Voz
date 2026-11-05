import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/visuals/symbol_catalog.dart';
import '../../../core/widgets/pictogram_card.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/visuals.dart';
import '../../../models/child_profile.dart';
import '../../../models/pictogram.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../application/pictogram_providers.dart';
import '../data/pictogram_catalog.dart';
import '../domain/vocabulary.dart';

/// Administración de pictogramas y frases frecuentes de un niño.
class PictogramAdminScreen extends ConsumerWidget {
  const PictogramAdminScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) {
        final vocabulary = ref.watch(vocabularyProvider(childId));
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Pictogramas · ${child.name}'),
              bottom: const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.grid_view_rounded), text: 'Pictogramas'),
                  Tab(icon: Icon(Icons.chat_bubble_outline), text: 'Frases'),
                ],
              ),
            ),
            body: vocabulary == null
                ? const LoadingView()
                : TabBarView(
                    children: [
                      _PictogramsTab(child: child, vocabulary: vocabulary),
                      _PhrasesTab(child: child, vocabulary: vocabulary),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _PictogramsTab extends ConsumerStatefulWidget {
  const _PictogramsTab({required this.child, required this.vocabulary});

  final ChildProfile child;
  final Vocabulary vocabulary;

  @override
  ConsumerState<_PictogramsTab> createState() => _PictogramsTabState();
}

class _PictogramsTabState extends ConsumerState<_PictogramsTab> {
  String _categoryId = PictogramCatalog.categories.first.id;

  Future<void> _toggleHidden(Pictogram p, bool visible) {
    final s = widget.child.settings;
    final hidden = {...s.hiddenPictogramIds};
    visible ? hidden.remove(p.id) : hidden.add(p.id);
    return runGuarded(
      context,
      () => ref
          .read(childrenRepositoryProvider)
          .updateSettings(
            widget.child.id,
            s.copyWith(hiddenPictogramIds: hidden.toList()),
          ),
    );
  }

  Future<void> _toggleFavorite(Pictogram p) => runGuarded(
    context,
    () => ref
        .read(contentRepositoryProvider)
        .setFavorite(
          widget.child.id,
          p.id,
          !widget.vocabulary.isFavorite(p.id),
        ),
  );

  Future<void> _delete(Pictogram p) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Eliminar pictograma',
      message: '¿Eliminar "${p.label}"?',
      confirmLabel: 'Eliminar',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(contentRepositoryProvider)
          .deleteCustomPictogram(widget.child.id, p),
      success: 'Pictograma eliminado.',
    );
  }

  Future<void> _edit(Pictogram? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PictogramForm(
        childId: widget.child.id,
        categoryId: existing?.categoryId ?? _categoryId,
        existing: existing,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.vocabulary;
    final pictograms = v.pictogramsFor(_categoryId, includeHidden: true);
    final category = PictogramCatalog.categoryById(_categoryId)!;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-pictogram-admin'),
        onPressed: () => _edit(null),
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Nuevo pictograma'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final c in PictogramCatalog.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: SymbolImage(c.emoji, size: 22),
                      label: Text(c.title),
                      selected: _categoryId == c.id,
                      onSelected: (_) => setState(() => _categoryId = c.id),
                    ),
                  ),
              ],
            ),
          ),
          if (v.isCategoryHidden(_categoryId))
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Esta categoría está oculta para el niño (Personalización sensorial).',
                style: TextStyle(color: AppColors.warning),
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: pictograms.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = pictograms[i];
                final hidden = v.isPictogramHidden(p.id);
                final favorite = v.isFavorite(p.id);
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Color(category.color),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: PictogramVisual(pictogram: p, size: 30),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.labelFor(widget.child.gender),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  decoration: hidden
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              Text(
                                '"${category.stem} ${p.fragmentFor(widget.child.gender)}"'
                                '${p.builtIn ? '' : ' · propio'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          key: Key('fav-${p.id}'),
                          tooltip: favorite
                              ? 'Quitar de favoritos'
                              : 'Agregar a favoritos',
                          icon: Icon(
                            favorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: favorite ? Colors.amber.shade700 : null,
                          ),
                          onPressed: () => _toggleFavorite(p),
                        ),
                        Switch(
                          value: !hidden,
                          onChanged: (visible) => _toggleHidden(p, visible),
                        ),
                        if (!p.builtIn)
                          PopupMenuButton<String>(
                            onSelected: (a) =>
                                a == 'edit' ? _edit(p) : _delete(p),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Editar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PictogramForm extends ConsumerStatefulWidget {
  const _PictogramForm({
    required this.childId,
    required this.categoryId,
    this.existing,
  });

  final String childId;
  final String categoryId;
  final Pictogram? existing;

  @override
  ConsumerState<_PictogramForm> createState() => _PictogramFormState();
}

class _PictogramFormState extends ConsumerState<_PictogramForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _fragment;
  late String _categoryId;
  late String _emoji;
  late bool _plural;
  File? _image;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label = TextEditingController(text: e?.label ?? '');
    _fragment = TextEditingController(text: e?.fragment ?? '');
    _categoryId = e?.categoryId ?? widget.categoryId;
    _emoji = SymbolCatalog.normalize(e?.emoji ?? SymbolCatalog.palette.first);
    _plural = e?.plural ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _fragment.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (file != null) setState(() => _image = File(file.path));
    } catch (_) {
      if (mounted) {
        showMessage(context, 'No se pudo abrir la galería.', error: true);
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final existing = widget.existing;
    final label = _label.text.trim();
    final fragment = _fragment.text.trim().isEmpty
        ? label.toLowerCase()
        : _fragment.text.trim();
    final pictogram = Pictogram(
      id: existing?.id ?? 'custom_${newId()}',
      categoryId: _categoryId,
      label: label,
      fragment: fragment,
      emoji: _emoji,
      plural: _plural,
      imagePath: existing?.imagePath,
      imageUrl: existing?.imageUrl,
      builtIn: false,
      order: existing?.order ?? DateTime.now().millisecondsSinceEpoch,
    );
    final ok = await runGuarded(
      context,
      () => ref
          .read(contentRepositoryProvider)
          .saveCustomPictogram(widget.childId, pictogram, image: _image),
      success: 'Pictograma guardado.',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final category = PictogramCatalog.categoryById(_categoryId)!;
    final preview = _fragment.text.trim().isEmpty
        ? _label.text.trim().toLowerCase()
        : _fragment.text.trim();
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
                    ? 'Nuevo pictograma'
                    : 'Editar pictograma',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  for (final c in PictogramCatalog.categories)
                    DropdownMenuItem(
                      value: c.id,
                      child: Row(
                        children: [
                          SymbolImage(c.emoji, size: 24),
                          const SizedBox(width: 8),
                          Text(c.title),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) =>
                    setState(() => _categoryId = v ?? _categoryId),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('pictogram-label'),
                controller: _label,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Nombre del pictograma',
                  hintText: 'Ej.: Tableta',
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
              ),
              TextFormField(
                controller: _fragment,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'Texto en la frase (opcional)',
                  hintText: 'Ej.: mi tableta',
                ),
                onChanged: (_) => setState(() {}),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Es plural'),
                subtitle: const Text('Ej.: "Me duelen los pies"'),
                value: _plural,
                onChanged: (v) => setState(() => _plural = v),
              ),
              Card(
                color: AppColors.background,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Frase: "${(_plural ? category.stemPlural : null) ?? category.stem} $preview"',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Imagen',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SymbolPickerGrid(
                selected: _emoji,
                onSelected: (e) => setState(() => _emoji = e),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (_image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        _image!,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                      ),
                    )
                  else if (widget.existing?.hasImage ?? false)
                    PictogramVisual(pictogram: widget.existing!, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Usar una foto (opcional)'),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Usa fotos de objetos o lugares. Evita fotos de personas, '
                  'especialmente de menores.',
                  style: TextStyle(fontSize: 12, color: AppColors.inkSoft),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('save-pictogram'),
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

class _PhrasesTab extends ConsumerWidget {
  const _PhrasesTab({required this.child, required this.vocabulary});

  final ChildProfile child;
  final Vocabulary vocabulary;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    FrequentPhrase? existing,
  ) async {
    final text = TextEditingController(text: existing?.text ?? '');
    var emoji = SymbolCatalog.normalize(existing?.emoji ?? 'necesito_hablar');
    final result = await showDialog<FrequentPhrase>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Nueva frase' : 'Editar frase'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const Key('phrase-input'),
                  controller: text,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'Frase',
                    hintText: 'Ej.: Necesito mis audífonos',
                  ),
                ),
                SymbolPickerGrid(
                  selected: emoji,
                  onSelected: (e) => setState(() => emoji = e),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('phrase-save'),
              onPressed: () {
                if (text.text.trim().isEmpty) return;
                Navigator.of(context).pop(
                  existing?.copyWith(text: text.text.trim(), emoji: emoji) ??
                      FrequentPhrase(
                        id: newId(),
                        text: text.text.trim(),
                        emoji: emoji,
                        order: vocabulary.frequentPhrases.length,
                      ),
                );
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    text.dispose();
    if (result == null || !context.mounted) return;
    await runGuarded(
      context,
      () => ref
          .read(contentRepositoryProvider)
          .saveFrequentPhrase(child.id, result),
      success: 'Frase guardada.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phrases = vocabulary.frequentPhrases;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('add-phrase'),
        onPressed: () => _edit(context, ref, null),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Nueva frase'),
      ),
      body: phrases.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Sin frases frecuentes',
              message: 'Agrega las expresiones que el niño usa más.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: phrases.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final p = phrases[i];
                return Card(
                  child: ListTile(
                    leading: SymbolImage(p.emoji, size: 40),
                    title: Text(
                      p.text,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(context, ref, p),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => runGuarded(
                            context,
                            () => ref
                                .read(contentRepositoryProvider)
                                .deleteFrequentPhrase(child.id, p.id),
                            success: 'Frase eliminada.',
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Galería de pictogramas ilustrados para elegir la imagen de un pictograma
/// propio o de una frase. La selección se marca con borde grueso y palomita
/// y se anuncia al lector de pantalla.
class SymbolPickerGrid extends StatelessWidget {
  const SymbolPickerGrid({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  static final List<String> options = [
    ...SymbolCatalog.palette,
    for (final p in PictogramCatalog.pictograms)
      if (!SymbolCatalog.palette.contains(p.id)) p.id,
  ];

  static String labelFor(String id) =>
      SymbolCatalog.paletteLabels[id] ??
      PictogramCatalog.pictograms.where((p) => p.id == id).firstOrNull?.label ??
      id;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 232,
    width: double.maxFinite,
    child: GridView.builder(
      key: const Key('symbol-picker'),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 64,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: options.length,
      itemBuilder: (context, i) {
        final id = options[i];
        final isSelected = id == selected;
        return Semantics(
          button: true,
          selected: isSelected,
          label: labelFor(id),
          excludeSemantics: true,
          child: InkWell(
            key: Key('symbol-option-$id'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => onSelected(id),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.ink : Colors.black12,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                    child: SymbolImage(id, size: 48),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    right: 2,
                    bottom: 2,
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: AppColors.ink,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
