import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/visuals.dart';
import '../../../core/widgets/state_views.dart';
import '../../settings/presentation/parental_gate.dart';
import '../application/active_child.dart';
import '../application/child_mode.dart';
import 'widgets/category_tile.dart';

/// Inicio del niño: categorías grandes, ayuda urgente y accesos rápidos.
class ChildHomeScreen extends ConsumerWidget {
  const ChildHomeScreen({super.key});

  /// "Cambiar perfil": tras la verificación de adulto se sale del modo niño
  /// y se vuelve al selector de perfiles autorizados.
  Future<void> _exitChildMode(BuildContext context, WidgetRef ref) async {
    final ok = await showParentalGate(context);
    if (ok) await ref.read(childModeProvider.notifier).exit();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(activeChildProvider);
    final vocabulary = ref.watch(activeVocabularyProvider);
    final palette = ref.watch(activePaletteProvider);

    if (child == null || vocabulary == null) {
      return Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: 'Cambiar perfil (solo adultos)',
                  icon: const Icon(Icons.lock_rounded),
                  onPressed: () => _exitChildMode(context, ref),
                ),
              ),
              const Expanded(child: LoadingView(message: 'Cargando perfil…')),
            ],
          ),
        ),
      );
    }

    final categories = vocabulary.visibleCategories;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            final columns = constraints.maxWidth < 600
                ? 3
                : constraints.maxWidth < 900
                ? 4
                : 5;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      ChildAvatar(child: child, size: 52),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '¡Hola, ${child.name}!',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: palette.ink,
                              ),
                            ),
                            Text(
                              '¿Qué quieres decir hoy?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                color: palette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (child.settings.calmMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Tooltip(
                            message: 'Modo tranquilo activo',
                            child: Icon(Icons.spa_rounded, color: palette.ink),
                          ),
                        ),
                      Semantics(
                        button: true,
                        label: 'Cambiar perfil (solo adultos)',
                        excludeSemantics: true,
                        child: InkWell(
                          key: const Key('exit-child-mode'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _exitChildMode(context, ref),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 4,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.switch_account_rounded,
                                  color: palette.ink,
                                ),
                                Text(
                                  'Cambiar\nperfil',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.1,
                                    color: palette.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _UrgentButton(onTap: () => context.push(Routes.childUrgent)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: categories.isEmpty
                        ? const EmptyState(
                            icon: Icons.visibility_off_rounded,
                            title: 'No hay categorías visibles',
                            message:
                                'Un adulto puede activarlas en '
                                'Personalización sensorial.',
                          )
                        : GridView.builder(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: wide ? 1.15 : 0.95,
                                ),
                            itemCount: categories.length,
                            itemBuilder: (context, i) {
                              final c = categories[i];
                              return CategoryTile(
                                key: Key('category-${c.id}'),
                                category: c,
                                onTap: () {
                                  ref
                                      .read(childFeedbackProvider)
                                      .select(c.stem);
                                  context.push(Routes.childCategory(c.id));
                                },
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickButton(
                          key: const Key('quick-favorites'),
                          icon: Icons.star_rounded,
                          label: 'Favoritos',
                          onTap: () => context.push(Routes.childFavorites),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickButton(
                          key: const Key('quick-phrases'),
                          icon: Icons.chat_rounded,
                          label: 'Mis frases',
                          onTap: () => context.push(Routes.childPhrases),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickButton(
                          key: const Key('quick-explore'),
                          icon: Icons.grid_view_rounded,
                          label: 'Ver todo',
                          onTap: () => context.push(Routes.childCategories),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UrgentButton extends ConsumerWidget {
  const _UrgentButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    return Semantics(
      button: true,
      label: 'Necesito ayuda ya',
      child: Material(
        key: const Key('urgent-button'),
        color: palette.urgent,
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius + 4),
          onTap: () {
            ref.read(childFeedbackProvider).tap();
            onTap();
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SymbolFrame('urg_sos', size: 52),
                SizedBox(width: 14),
                Flexible(
                  child: Text(
                    'NECESITO AYUDA YA',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
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
}

class _QuickButton extends ConsumerWidget {
  const _QuickButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          side: palette.border,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius),
          onTap: () {
            ref.read(childFeedbackProvider).tap();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(icon, size: 32, color: palette.ink),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: palette.ink,
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
}
