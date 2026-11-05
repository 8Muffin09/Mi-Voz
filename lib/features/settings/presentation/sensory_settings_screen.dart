import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/child_palette.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../core/widgets/pictogram_card.dart';
import '../../../models/child_profile.dart';
import '../../../models/sensory_settings.dart';
import '../../adult/presentation/widgets/child_guard.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../pictograms/data/pictogram_catalog.dart';
import '../../../core/widgets/visuals.dart';

/// Personalización sensorial del niño: sonido, vibración, voz, tamaño y
/// cantidad de pictogramas, contraste, modo tranquilo y categorías.
class SensorySettingsScreen extends ConsumerWidget {
  const SensorySettingsScreen({super.key, required this.childId});

  final String childId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChildGuard(
      childId: childId,
      builder: (context, child, user) => _SettingsBody(child: child),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody({required this.child});

  final ChildProfile child;

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    SensorySettings settings,
  ) => runGuarded(
    context,
    () =>
        ref.read(childrenRepositoryProvider).updateSettings(child.id, settings),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = child.settings;
    void set(SensorySettings next) => _update(context, ref, next);

    return Scaffold(
      appBar: AppBar(title: Text('Personalización · ${child.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _Preview(settings: s),
          const SectionHeader('Modo tranquilo'),
          Card(
            child: SwitchListTile(
              key: const Key('calm-mode'),
              secondary: const Icon(Icons.spa_rounded),
              title: const Text('Activar modo tranquilo'),
              subtitle: const Text(
                'Colores apagados, sin animaciones ni sonidos de interfaz. '
                'La voz y la comunicación siguen disponibles.',
              ),
              value: s.calmMode,
              onChanged: (v) => set(s.copyWith(calmMode: v)),
            ),
          ),
          const SectionHeader('Sonido y vibración'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_outlined),
                  title: const Text('Sonidos de la interfaz'),
                  value: s.soundsEnabled,
                  onChanged: (v) => set(s.copyWith(soundsEnabled: v)),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration),
                  title: const Text('Vibración al tocar'),
                  value: s.vibrationEnabled,
                  onChanged: (v) => set(s.copyWith(vibrationEnabled: v)),
                ),
              ],
            ),
          ),
          const SectionHeader('Voz (texto a voz)'),
          _TtsCard(child: child, onChanged: set),
          const SectionHeader('Pictogramas'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tamaño',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PictogramSize>(
                    showSelectedIcon: false,
                    segments: [
                      for (final size in PictogramSize.values)
                        ButtonSegment(value: size, label: Text(size.label)),
                    ],
                    selected: {s.pictogramSize},
                    onSelectionChanged: (v) =>
                        set(s.copyWith(pictogramSize: v.first)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pictogramas visibles por pantalla',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final n in SensorySettings.pageSizeOptions)
                        ChoiceChip(
                          key: Key('per-page-$n'),
                          label: Text(n == 0 ? 'Todos' : '$n'),
                          selected: s.pictogramsPerPage == n,
                          onSelected: (_) =>
                              set(s.copyWith(pictogramsPerPage: n)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Menos pictogramas por pantalla reducen la carga visual.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Contraste'),
          Card(
            child: SwitchListTile(
              key: const Key('high-contrast'),
              secondary: const Icon(Icons.contrast),
              title: const Text('Alto contraste'),
              subtitle: const Text(
                'Fondo blanco, bordes negros y colores intensos.',
              ),
              value: s.highContrast,
              onChanged: (v) => set(s.copyWith(highContrast: v)),
            ),
          ),
          const SectionHeader(
            'Categorías visibles',
            subtitle: 'Oculta las que el niño no necesita.',
          ),
          Card(
            child: Column(
              children: [
                for (final c in PictogramCatalog.categories)
                  CheckboxListTile(
                    key: Key('visible-${c.id}'),
                    secondary: SymbolImage(c.emoji, size: 36),
                    title: Text(c.title),
                    value: !s.hiddenCategoryIds.contains(c.id),
                    onChanged: (visible) {
                      final hidden = {...s.hiddenCategoryIds};
                      visible == true ? hidden.remove(c.id) : hidden.add(c.id);
                      set(s.copyWith(hiddenCategoryIds: hidden.toList()));
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TtsCard extends ConsumerStatefulWidget {
  const _TtsCard({required this.child, required this.onChanged});

  final ChildProfile child;
  final ValueChanged<SensorySettings> onChanged;

  @override
  ConsumerState<_TtsCard> createState() => _TtsCardState();
}

class _TtsCardState extends ConsumerState<_TtsCard> {
  late double _rate = widget.child.settings.ttsRate;
  late double _pitch = widget.child.settings.ttsPitch;
  late double _volume = widget.child.settings.ttsVolume;

  @override
  Widget build(BuildContext context) {
    final s = widget.child.settings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Leer el pictograma al tocarlo'),
              value: s.speakOnSelect,
              onChanged: (v) => widget.onChanged(s.copyWith(speakOnSelect: v)),
            ),
            DropdownButtonFormField<String>(
              initialValue:
                  SensorySettings.languageOptions.containsKey(s.ttsLanguage)
                  ? s.ttsLanguage
                  : 'es-MX',
              decoration: const InputDecoration(labelText: 'Idioma de la voz'),
              items: [
                for (final e in SensorySettings.languageOptions.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) widget.onChanged(s.copyWith(ttsLanguage: v));
              },
            ),
            const SizedBox(height: 12),
            Text('Velocidad: ${(_rate * 100).round()}%'),
            Slider(
              value: _rate,
              min: 0.1,
              max: 1.0,
              divisions: 18,
              onChanged: (v) => setState(() => _rate = v),
              onChangeEnd: (v) => widget.onChanged(s.copyWith(ttsRate: v)),
            ),
            Text('Tono: ${_pitch.toStringAsFixed(1)}'),
            Slider(
              value: _pitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) => setState(() => _pitch = v),
              onChangeEnd: (v) => widget.onChanged(s.copyWith(ttsPitch: v)),
            ),
            Text('Volumen: ${(_volume * 100).round()}%'),
            Slider(
              value: _volume,
              min: 0,
              max: 1,
              divisions: 10,
              onChanged: (v) => setState(() => _volume = v),
              onChangeEnd: (v) => widget.onChanged(s.copyWith(ttsVolume: v)),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await ref
                    .read(speechServiceProvider)
                    .speak(
                      'Hola, soy ${widget.child.name}. Quiero agua, por favor.',
                      s.copyWith(
                        ttsRate: _rate,
                        ttsPitch: _pitch,
                        ttsVolume: _volume,
                      ),
                    );
                if (!ok && context.mounted) {
                  showMessage(
                    context,
                    'No hay una voz disponible. Instala la voz en español en '
                    'Ajustes del teléfono → Texto a voz.',
                    error: true,
                  );
                }
              },
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Probar voz'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vista previa de cómo verá el niño los pictogramas con estos ajustes.
class _Preview extends StatelessWidget {
  const _Preview({required this.settings});

  final SensorySettings settings;

  @override
  Widget build(BuildContext context) {
    final palette = ChildPalette.from(settings);
    final sample = PictogramCatalog.pictograms.take(3).toList();
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Vista previa',
            style: TextStyle(fontWeight: FontWeight.w700, color: palette.ink),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 130,
            child: Row(
              children: [
                for (final p in sample) ...[
                  Expanded(
                    child: PictogramCard(
                      pictogram: p,
                      label: p.label,
                      color: palette.tint(
                        PictogramCatalog.categories.first.color,
                      ),
                      palette: palette,
                      onTap: () {},
                    ),
                  ),
                  if (p != sample.last) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
