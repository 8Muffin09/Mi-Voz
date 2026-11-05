import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pictogram_card.dart';
import '../../../../models/pictogram.dart';
import '../../../pictograms/data/pictogram_catalog.dart';
import '../../application/active_child.dart';

/// Cuadrícula de pictogramas que respeta el tamaño y la cantidad visible
/// configurados. Con paginación usa botones grandes en lugar de scroll.
class PagedPictogramGrid extends ConsumerStatefulWidget {
  const PagedPictogramGrid({
    super.key,
    required this.pictograms,
    required this.onTap,
    this.selectedIds = const {},
  });

  final List<Pictogram> pictograms;
  final ValueChanged<Pictogram> onTap;
  final Set<String> selectedIds;

  @override
  ConsumerState<PagedPictogramGrid> createState() => _PagedPictogramGridState();
}

class _PagedPictogramGridState extends ConsumerState<PagedPictogramGrid> {
  int _page = 0;

  @override
  void didUpdateWidget(covariant PagedPictogramGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pictograms.length != widget.pictograms.length) _page = 0;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(activeSettingsProvider);
    final palette = ref.watch(activePaletteProvider);
    final child = ref.watch(activeChildProvider);
    final perPage = settings.pictogramsPerPage;
    final total = widget.pictograms.length;
    final pages = perPage == 0 ? 1 : (total / perPage).ceil().clamp(1, 999);
    final page = _page.clamp(0, pages - 1);
    final visible = perPage == 0
        ? widget.pictograms
        : widget.pictograms.skip(page * perPage).take(perPage).toList();

    final grid = GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: settings.pictogramSize.tileExtent,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.86,
      ),
      itemCount: visible.length,
      itemBuilder: (context, i) {
        final p = visible[i];
        final category = PictogramCatalog.categoryById(p.categoryId);
        final label = child == null ? p.label : p.labelFor(child.gender);
        return PictogramCard(
          key: Key('pictogram-${p.id}'),
          pictogram: p,
          label: label,
          color: palette.tint(category?.color ?? 0xFFE0E0E0),
          palette: palette,
          selected: widget.selectedIds.contains(p.id),
          onTap: () => widget.onTap(p),
        );
      },
    );

    if (pages <= 1) return grid;
    return Column(
      children: [
        Expanded(child: grid),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            children: [
              _PageButton(
                icon: Icons.chevron_left_rounded,
                label: 'Anterior',
                onTap: page > 0 ? () => setState(() => _page = page - 1) : null,
              ),
              Expanded(
                child: Text(
                  '${page + 1} de $pages',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
              ),
              _PageButton(
                icon: Icons.chevron_right_rounded,
                label: 'Siguiente',
                onTap: page < pages - 1
                    ? () => setState(() => _page = page + 1)
                    : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageButton extends ConsumerWidget {
  const _PageButton({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    return Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: palette.border,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap == null
              ? null
              : () {
                  ref.read(childFeedbackProvider).tap();
                  onTap!();
                },
          child: Semantics(
            button: true,
            label: label,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Icon(icon, size: 40, color: palette.ink),
            ),
          ),
        ),
      ),
    );
  }
}
