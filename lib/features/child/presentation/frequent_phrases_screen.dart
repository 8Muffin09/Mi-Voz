import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../application/active_child.dart';
import '../application/phrase_controller.dart';
import 'widgets/child_scaffold.dart';

/// Frases frecuentes listas para escuchar o comunicar.
class FrequentPhrasesScreen extends ConsumerWidget {
  const FrequentPhrasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabulary = ref.watch(activeVocabularyProvider);
    final palette = ref.watch(activePaletteProvider);
    final phrases = vocabulary?.frequentPhrases ?? const [];
    return ChildScaffold(
      title: 'Mis frases',
      body: vocabulary == null
          ? const LoadingView()
          : phrases.isEmpty
          ? const EmptyState(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Aún no hay frases',
              message:
                  'Un adulto puede agregarlas en Administración de '
                  'pictogramas → Frases.',
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 2 : 1;
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 96,
                  ),
                  itemCount: phrases.length,
                  itemBuilder: (context, i) {
                    final phrase = phrases[i];
                    final categoryId = phrase.categoryId;
                    final category = categoryId == null
                        ? null
                        : PictogramCatalog.categoryById(categoryId);
                    return Semantics(
                      button: true,
                      label: phrase.text,
                      child: Material(
                        key: Key('phrase-${phrase.id}'),
                        color: palette.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          side: palette.border,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          onTap: () {
                            ref.read(childFeedbackProvider).select(phrase.text);
                            ref
                                .read(phraseControllerProvider.notifier)
                                .startFixed(phrase);
                            context.push(Routes.childPhrase);
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 84,
                                margin: const EdgeInsets.all(8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: palette.tint(
                                    category?.color ?? 0xFFE6ECF5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: SymbolImage(phrase.emoji, size: 64),
                              ),
                              Expanded(
                                child: Text(
                                  phrase.text,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: palette.ink,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 16),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  size: 32,
                                  color: palette.ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
