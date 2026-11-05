import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/state_views.dart';
import '../application/active_child.dart';
import 'pictogram_selection_screen.dart';
import 'widgets/child_scaffold.dart';
import 'widgets/paged_pictogram_grid.dart';

/// Pictogramas favoritos (configurados por el adulto). Funciona sin
/// internet porque se guardan en el dispositivo.
class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabulary = ref.watch(activeVocabularyProvider);
    final favorites = vocabulary?.favorites ?? const [];
    return ChildScaffold(
      title: 'Favoritos',
      body: vocabulary == null
          ? const LoadingView()
          : favorites.isEmpty
          ? const EmptyState(
              icon: Icons.star_outline_rounded,
              title: 'Aún no hay favoritos',
              message:
                  'Un adulto puede marcarlos con la estrella en '
                  'Administración de pictogramas.',
            )
          : PagedPictogramGrid(
              pictograms: favorites,
              onTap: (p) => PictogramSelectionScreen.choose(context, ref, p),
            ),
    );
  }
}
