import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/state_views.dart';
import '../../../models/pictogram.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../application/active_child.dart';
import '../application/phrase_controller.dart';
import 'widgets/child_scaffold.dart';
import 'widgets/paged_pictogram_grid.dart';

/// Pictogramas de una categoría. Al elegir uno se forma la frase.
class PictogramSelectionScreen extends ConsumerWidget {
  const PictogramSelectionScreen({super.key, required this.categoryId});

  final String categoryId;

  static void choose(BuildContext context, WidgetRef ref, Pictogram p) {
    final child = ref.read(activeChildProvider);
    final label = child == null ? p.label : p.labelFor(child.gender);
    ref.read(childFeedbackProvider).select(label);
    ref.read(phraseControllerProvider.notifier).startWithPictogram(p);
    context.push(Routes.childPhrase);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = PictogramCatalog.categoryById(categoryId);
    final vocabulary = ref.watch(activeVocabularyProvider);
    if (category == null) {
      return const ChildScaffold(
        body: EmptyState(
          icon: Icons.help_outline_rounded,
          title: 'Categoría no encontrada',
        ),
      );
    }
    final pictograms = vocabulary?.pictogramsFor(category.id) ?? const [];
    return ChildScaffold(
      title: '${category.title}…',
      leadingSymbol: category.emoji,
      body: vocabulary == null
          ? const LoadingView()
          : pictograms.isEmpty
          ? const EmptyState(
              icon: Icons.visibility_off_rounded,
              title: 'No hay pictogramas visibles aquí',
            )
          : PagedPictogramGrid(
              pictograms: pictograms,
              onTap: (p) => choose(context, ref, p),
            ),
    );
  }
}
