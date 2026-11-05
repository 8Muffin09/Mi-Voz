import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../../../models/pictogram.dart';
import '../application/active_child.dart';
import 'pictogram_selection_screen.dart';
import 'widgets/category_tile.dart';
import 'widgets/child_scaffold.dart';
import 'widgets/paged_pictogram_grid.dart';

/// Explorar todas las categorías sin salir de la pantalla: lista de
/// categorías (lateral en tablets, superior en teléfonos) y sus pictogramas.
class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final vocabulary = ref.watch(activeVocabularyProvider);
    if (vocabulary == null) {
      return const ChildScaffold(title: 'Todas', body: LoadingView());
    }
    final categories = vocabulary.visibleCategories;
    if (categories.isEmpty) {
      return const ChildScaffold(
        title: 'Todas',
        body: EmptyState(
          icon: Icons.visibility_off_rounded,
          title: 'No hay categorías visibles',
        ),
      );
    }
    final selected = categories.firstWhere(
      (c) => c.id == _selectedId,
      orElse: () => categories.first,
    );
    final pictograms = vocabulary.pictogramsFor(selected.id);

    Widget categoryButton(PictogramCategory c, {required bool vertical}) =>
        SizedBox(
          width: vertical ? double.infinity : 120,
          height: vertical ? 86 : null,
          child: CategoryTile(
            key: Key('browse-${c.id}'),
            category: c,
            compact: true,
            selected: c.id == selected.id,
            onTap: () {
              ref.read(childFeedbackProvider).select(c.stem);
              setState(() => _selectedId = c.id);
            },
          ),
        );

    final grid = PagedPictogramGrid(
      key: ValueKey(selected.id),
      pictograms: pictograms,
      onTap: (p) => PictogramSelectionScreen.choose(context, ref, p),
    );

    return ChildScaffold(
      title: 'Todas las categorías',
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 700) {
            return Row(
              children: [
                SizedBox(
                  width: 170,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) =>
                        categoryButton(categories[i], vertical: true),
                  ),
                ),
                Expanded(child: grid),
              ],
            );
          }
          return Column(
            children: [
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) =>
                      categoryButton(categories[i], vertical: false),
                ),
              ),
              Expanded(child: grid),
            ],
          );
        },
      ),
    );
  }
}
