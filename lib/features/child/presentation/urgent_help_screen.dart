import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/constants/app_texts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/visuals.dart';
import '../../../models/pictogram.dart';
import '../../communication/application/communication_service.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../../pictograms/domain/phrase_builder.dart';
import '../application/active_child.dart';
import 'widgets/child_scaffold.dart';

/// Ayuda urgente: el niño elige una opción y la confirma en un segundo paso
/// grande y claro para evitar pulsaciones accidentales. Genera una
/// solicitud de prioridad alta.
class UrgentHelpScreen extends ConsumerStatefulWidget {
  const UrgentHelpScreen({super.key});

  @override
  ConsumerState<UrgentHelpScreen> createState() => _UrgentHelpScreenState();
}

class _UrgentHelpScreenState extends ConsumerState<UrgentHelpScreen> {
  FrequentPhrase? _selected;
  bool _sending = false;

  Future<void> _send(FrequentPhrase option) async {
    final child = ref.read(activeChildProvider);
    if (child == null) return;
    setState(() => _sending = true);
    final feedback = ref.read(childFeedbackProvider);
    try {
      final request = await ref
          .read(communicationServiceProvider)
          .send(
            child: child,
            draft: PhraseDraft.fixed(
              text: option.text,
              emoji: option.emoji,
              categoryId: PictogramCatalog.urgentCategoryId,
              urgent: true,
            ),
          );
      await feedback.alert();
      // Se lee en voz alta para que los adultos cercanos también lo oigan.
      await feedback.speak(option.text);
      if (mounted) context.go(Routes.childCommunicate(request.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(describeError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = ref.watch(activePaletteProvider);
    final selected = _selected;
    return ChildScaffold(
      title: 'Ayuda urgente',
      body: selected == null
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '¿Qué te pasa?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: palette.ink,
                  ),
                ),
                const SizedBox(height: 16),
                for (final option in PictogramCatalog.urgentOptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Semantics(
                      button: true,
                      label: option.text,
                      child: Material(
                        key: Key('urgent-${option.id}'),
                        color: palette.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          side: BorderSide(color: palette.urgent, width: 3),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radius),
                          onTap: () {
                            ref.read(childFeedbackProvider).select(option.text);
                            setState(() => _selected = option);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SymbolFrame(option.emoji, size: 64),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    option.text,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: palette.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  AppTexts.urgentDisclaimer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.ink.withValues(alpha: 0.7),
                  ),
                ),
              ],
            )
          : _ConfirmView(
              option: selected,
              sending: _sending,
              onConfirm: () => _send(selected),
              onCancel: () => setState(() => _selected = null),
            ),
    );
  }
}

class _ConfirmView extends ConsumerWidget {
  const _ConfirmView({
    required this.option,
    required this.sending,
    required this.onConfirm,
    required this.onCancel,
  });

  final FrequentPhrase option;
  final bool sending;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(activePaletteProvider);
    final offline = ref.watch(onlineProvider).value == false;
    return Semantics(
      liveRegion: true,
      label: '¿Avisar a tu adulto: ${option.text}?',
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(child: SymbolFrame(option.emoji, size: 120)),
          const SizedBox(height: 12),
          Text(
            option.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '¿Quieres avisar a tu adulto?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: palette.ink),
          ),
          if (offline)
            Container(
              key: const Key('urgent-offline'),
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppTheme.radius),
                border: Border.all(color: palette.urgent, width: 3),
              ),
              child: Text(
                'No hay internet: el aviso se enviará cuando vuelva. Si '
                'necesitas ayuda ya, busca a un adulto cerca.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                ),
              ),
            ),
          const SizedBox(height: 28),
          ChildActionButton(
            key: const Key('urgent-confirm'),
            label: 'SÍ, AVISAR',
            icon: Icons.notifications_active_rounded,
            color: palette.urgent,
            loading: sending,
            onTap: onConfirm,
          ),
          const SizedBox(height: 14),
          ChildActionButton(
            key: const Key('urgent-cancel'),
            label: 'NO, VOLVER',
            icon: Icons.undo_rounded,
            color: AppColors.inkSoft,
            onTap: sending ? null : onCancel,
          ),
        ],
      ),
    );
  }
}
