import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/theme/child_palette.dart';
import '../../../models/child_profile.dart';
import '../../../models/sensory_settings.dart';
import '../../pictograms/application/pictogram_providers.dart';
import '../../pictograms/domain/vocabulary.dart';
import '../../profiles/application/profiles_providers.dart';
import 'child_mode.dart';

/// Perfil del niño en modo niño.
final activeChildProvider = Provider<ChildProfile?>((ref) {
  final id = ref.watch(childModeProvider);
  if (id == null) return null;
  return ref.watch(childProvider(id)).value;
});

final activeSettingsProvider = Provider<SensorySettings>(
  (ref) => ref.watch(activeChildProvider)?.settings ?? const SensorySettings(),
);

final activePaletteProvider = Provider<ChildPalette>(
  (ref) => ChildPalette.from(ref.watch(activeSettingsProvider)),
);

final activeVocabularyProvider = Provider<Vocabulary?>((ref) {
  final id = ref.watch(childModeProvider);
  if (id == null) return null;
  return ref.watch(vocabularyProvider(id));
});

/// Voz y retroalimentación con las preferencias del niño activo.
class ChildFeedback {
  ChildFeedback(this._ref);

  final Ref _ref;

  SensorySettings get _settings => _ref.read(activeSettingsProvider);

  Future<bool> speak(String text) =>
      _ref.read(speechServiceProvider).speak(text, _settings);

  Future<void> tap() => _ref.read(feedbackServiceProvider).tap(_settings);

  Future<void> success() =>
      _ref.read(feedbackServiceProvider).success(_settings);

  Future<void> alert() => _ref.read(feedbackServiceProvider).alert(_settings);

  /// Al tocar un pictograma: sonido/vibración y, si está activo, leerlo.
  Future<void> select(String label) async {
    await tap();
    if (_settings.speakOnSelect) await speak(label);
  }
}

final childFeedbackProvider = Provider<ChildFeedback>(ChildFeedback.new);
