import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/sensory_settings.dart';

/// Texto a voz. Abstracto para poder sustituirlo en las pruebas.
abstract class SpeechService {
  Future<bool> speak(String text, SensorySettings settings);
  Future<void> stop();
  Future<List<String>> availableSpanishLanguages();
  void dispose();
}

/// Implementación con `flutter_tts`, que usa el motor de voz del sistema
/// (funciona sin internet si la voz en español está instalada).
class FlutterSpeechService implements SpeechService {
  FlutterSpeechService() : _tts = FlutterTts();

  final FlutterTts _tts;
  String? _configuredLanguage;

  Future<void> _configure(SensorySettings s) async {
    if (_configuredLanguage != s.ttsLanguage) {
      final candidates = [s.ttsLanguage, 'es-MX', 'es-US', 'es-ES', 'es'];
      for (final lang in candidates) {
        final available = await _tts.isLanguageAvailable(lang);
        if (available == true) {
          await _tts.setLanguage(lang);
          break;
        }
      }
      _configuredLanguage = s.ttsLanguage;
    }
    await _tts.setSpeechRate(s.ttsRate);
    await _tts.setPitch(s.ttsPitch);
    await _tts.setVolume(s.ttsVolume);
  }

  @override
  Future<bool> speak(String text, SensorySettings settings) async {
    if (text.trim().isEmpty) return false;
    try {
      await _configure(settings);
      await _tts.stop();
      final result = await _tts.speak(text);
      return result == 1 || result == true;
    } catch (e) {
      debugPrint('TTS no disponible: $e');
      return false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {
      // El motor de voz puede no estar disponible; no es un error crítico.
    }
  }

  @override
  Future<List<String>> availableSpanishLanguages() async {
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        return langs
            .map((e) => e.toString())
            .where((l) => l.toLowerCase().startsWith('es'))
            .toList()
          ..sort();
      }
    } catch (_) {
      // Sin motor de voz.
    }
    return const [];
  }

  @override
  void dispose() {
    _tts.stop();
  }
}
