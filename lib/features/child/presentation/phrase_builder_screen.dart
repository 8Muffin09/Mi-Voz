import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/child_palette.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/pictogram_card.dart';
import '../../../core/widgets/visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/child_profile.dart';
import '../../../models/pictogram.dart';
import '../../communication/application/communication_service.dart';
import '../../pictograms/domain/phrase_builder.dart';
import '../application/active_child.dart';
import '../application/phrase_controller.dart';
import 'widgets/child_scaffold.dart';

/// Construcción y modificación de la frase, con los botones
/// ESCUCHAR — COMUNICAR — CAMBIAR.
class PhraseBuilderScreen extends ConsumerStatefulWidget {
  const PhraseBuilderScreen({super.key});

  @override
  ConsumerState<PhraseBuilderScreen> createState() =>
      _PhraseBuilderScreenState();
}

class _PhraseBuilderScreenState extends ConsumerState<PhraseBuilderScreen> {
  bool _sending = false;

  Future<void> _communicate(ChildProfile child, PhraseDraft draft) async {
    setState(() => _sending = true);
    try {
      final request = await ref
          .read(communicationServiceProvider)
          .send(child: child, draft: draft);
      await ref.read(childFeedbackProvider).success();
      if (!mounted) return;
      ref.read(phraseControllerProvider.notifier).clear();
      context.go(Routes.childCommunicate(request.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _addMore(PhraseDraft draft) async {
    final vocabulary = ref.read(activeVocabularyProvider);
    final category = draft.category;
    if (vocabulary == null || category == null) return;
    final chosen = draft.items.map((i) => i.id).toSet();
    final options = vocabulary
        .pictogramsFor(category.id)
        .where((p) => !chosen.contains(p.id))
        .toList();
    final picked = await showModalBottomSheet<Pictogram>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddPictogramSheet(options: options),
    );
    if (picked != null) {
      ref.read(phraseControllerProvider.notifier).add(picked);
      ref.read(childFeedbackProvider).select(picked.label);
    }
  }

  void _change(PhraseDraft draft) {
    ref.read(childFeedbackProvider).tap();
    if (context.canPop()) {
      context.pop();
    } else if (draft.category != null) {
      context.go(Routes.childCategory(draft.category!.id));
    } else {
      context.go(Routes.child);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(phraseControllerProvider);
    final child = ref.watch(activeChildProvider);
    final palette = ref.watch(activePaletteProvider);
    final controller = ref.read(phraseControllerProvider.notifier);

    if (draft == null || child == null) {
      return ChildScaffold(
        title: 'Mi frase',
        body: EmptyState(
          icon: Icons.extension_rounded,
          title: 'Elige un pictograma para formar tu frase',
          action: FilledButton(
            onPressed: () => context.go(Routes.child),
            child: const Text('Ir al inicio'),
          ),
        ),
      );
    }

    final phrase = PhraseBuilder.build(draft, gender: child.gender);
    final categoryColor = palette.tint(draft.category?.color ?? 0xFFE6ECF5);

    return ChildScaffold(
      title: 'Mi frase',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _SentenceStrip(
            draft: draft,
            gender: child.gender,
            palette: palette,
            color: categoryColor,
            onRemove: draft.items.length > 1 ? controller.remove : null,
            onAdd: draft.canAddMore ? () => _addMore(draft) : null,
          ),
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            label: 'Frase: $phrase',
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius + 4),
                border: Border.fromBorderSide(palette.border),
              ),
              child: Text(
                phrase,
                key: const Key('phrase-text'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  height: 1.2,
                ),
              ),
            ),
          ),
          if (draft.supportsIntensity) ...[
            const SizedBox(height: 20),
            Text(
              '¿Cuánto?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.ink,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final level in Intensity.values) ...[
                  Expanded(
                    child: _ChoiceButton(
                      key: Key('intensity-${level.name}'),
                      leading: IntensityBars(
                        level: level.index + 1,
                        color: draft.intensity == level
                            ? palette.surface
                            : palette.ink,
                      ),
                      label: level.label,
                      selected: draft.intensity == level,
                      palette: palette,
                      onTap: () {
                        ref.read(childFeedbackProvider).tap();
                        controller.setIntensity(level);
                      },
                    ),
                  ),
                  if (level != Intensity.values.last) const SizedBox(width: 10),
                ],
              ],
            ),
          ],
          if (!draft.isFixed) ...[
            const SizedBox(height: 14),
            _ChoiceButton(
              key: const Key('toggle-polite'),
              leading: Icon(
                Icons.favorite_rounded,
                size: 24,
                color: draft.polite ? palette.surface : palette.ink,
              ),
              label: 'Por favor',
              selected: draft.polite,
              palette: palette,
              onTap: () {
                ref.read(childFeedbackProvider).tap();
                controller.togglePolite();
              },
            ),
          ],
        ],
      ),
      bottom: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: ChildActionButton(
                key: const Key('action-listen'),
                label: 'ESCUCHAR',
                icon: Icons.volume_up_rounded,
                color: AppColors.listen,
                onTap: () => ref.read(childFeedbackProvider).speak(phrase),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChildActionButton(
                key: const Key('action-communicate'),
                label: 'COMUNICAR',
                icon: Icons.campaign_rounded,
                color: AppColors.communicate,
                loading: _sending,
                onTap: () => _communicate(child, draft),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ChildActionButton(
                key: const Key('action-change'),
                label: 'CAMBIAR',
                icon: Icons.swap_horiz_rounded,
                color: AppColors.change,
                onTap: () => _change(draft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tira visual de la frase: verbo + pictogramas elegidos + botón "agregar".
class _SentenceStrip extends StatelessWidget {
  const _SentenceStrip({
    required this.draft,
    required this.gender,
    required this.palette,
    required this.color,
    required this.onRemove,
    required this.onAdd,
  });

  final PhraseDraft draft;
  final GrammaticalGender gender;
  final ChildPalette palette;
  final Color color;
  final ValueChanged<String>? onRemove;
  final VoidCallback? onAdd;

  Widget _caption(String text) => Text(
    text,
    textAlign: TextAlign.center,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontWeight: FontWeight.w700,
      color: palette.ink,
      fontSize: 14,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    if (draft.isFixed) {
      cards.add(
        _StripCard(
          color: color,
          palette: palette,
          child: SymbolImage(draft.emoji, size: 64),
        ),
      );
    } else {
      final category = draft.category;
      if (category != null) {
        cards.add(
          _StripCard(
            color: color,
            palette: palette,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SymbolImage(category.emoji, size: 44),
                const SizedBox(height: 4),
                _caption(category.title),
              ],
            ),
          ),
        );
      }
      for (final item in draft.items) {
        cards.add(
          Stack(
            clipBehavior: Clip.none,
            children: [
              _StripCard(
                color: palette.surface,
                palette: palette,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PictogramVisual(pictogram: item, size: 40),
                    const SizedBox(height: 4),
                    _caption(item.labelFor(gender)),
                  ],
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: -8,
                  right: -8,
                  child: Semantics(
                    button: true,
                    label: 'Quitar ${item.label}',
                    child: Material(
                      color: palette.ink,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: Key('remove-${item.id}'),
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove!(item.id),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }
      if (onAdd != null) {
        cards.add(
          Semantics(
            button: true,
            label: 'Agregar otro pictograma',
            child: InkWell(
              key: const Key('add-pictogram'),
              borderRadius: BorderRadius.circular(AppTheme.radius),
              onTap: onAdd,
              child: _StripCard(
                color: palette.background,
                palette: palette,
                dashed: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 40, color: palette.ink),
                    _caption('Agregar'),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: cards,
    );
  }
}

class _StripCard extends StatelessWidget {
  const _StripCard({
    required this.color,
    required this.palette,
    required this.child,
    this.dashed = false,
  });

  final Color color;
  final ChildPalette palette;
  final Widget child;
  final bool dashed;

  @override
  // Ancho fijo y alto mínimo: con texto ampliado la tarjeta crece hacia
  // abajo en lugar de recortar el nombre del pictograma.
  Widget build(BuildContext context) => Container(
    width: 108,
    constraints: const BoxConstraints(minHeight: 108),
    padding: const EdgeInsets.all(8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      border: Border.all(
        color: dashed
            ? palette.ink.withValues(alpha: 0.4)
            : palette.borderColor,
        width: dashed ? 2 : palette.borderWidth,
      ),
    ),
    child: child,
  );
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.leading,
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final bool selected;
  final ChildPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: selected ? palette.ink : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: palette.border,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              leading,
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: selected ? palette.surface : palette.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AddPictogramSheet extends ConsumerWidget {
  const _AddPictogramSheet({required this.options});

  final List<Pictogram> options;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final child = ref.watch(activeChildProvider);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: options.isEmpty
            ? const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'Ya elegiste todos',
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 150,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.86,
                ),
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final p = options[i];
                  return PictogramCard(
                    key: Key('add-option-${p.id}'),
                    pictogram: p,
                    label: child == null ? p.label : p.labelFor(child.gender),
                    color: palette.tint(0xFFEFF3F8),
                    palette: palette,
                    onTap: () => Navigator.of(context).pop(p),
                  );
                },
              ),
      ),
    );
  }
}
