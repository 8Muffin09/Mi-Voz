import 'dart:async';

import 'package:flutter/services.dart';

import '../../models/sensory_settings.dart';

/// Sonidos de interfaz y vibración, respetando las preferencias del niño
/// y el modo tranquilo. Nunca bloquea la comunicación: las llamadas al
/// sistema se lanzan sin esperar su resultado.
class FeedbackService {
  const FeedbackService();

  void _fire(Future<void> Function() call) {
    unawaited(call().catchError((Object _) {}));
  }

  Future<void> tap(SensorySettings s) async {
    if (s.effectiveSounds) _fire(() => SystemSound.play(SystemSoundType.click));
    if (s.vibrationEnabled) _fire(HapticFeedback.selectionClick);
  }

  Future<void> success(SensorySettings s) async {
    if (s.effectiveSounds) _fire(() => SystemSound.play(SystemSoundType.click));
    if (s.vibrationEnabled) _fire(HapticFeedback.mediumImpact);
  }

  Future<void> alert(SensorySettings s) async {
    // La vibración de alerta se mantiene en modo tranquilo porque confirma
    // una acción importante (ayuda urgente).
    if (s.vibrationEnabled) _fire(HapticFeedback.heavyImpact);
    if (s.effectiveSounds) _fire(() => SystemSound.play(SystemSoundType.alert));
  }
}
