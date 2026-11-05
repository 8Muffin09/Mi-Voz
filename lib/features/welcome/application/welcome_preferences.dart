import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../models/child_profile.dart';
import '../../access/application/access_providers.dart';
import '../../child/application/child_mode.dart';

/// Preferencias de la pantalla de bienvenida (por dispositivo; las cambia un
/// adulto en Configuración).
class WelcomePreferences {
  const WelcomePreferences({
    required this.melodyEnabled,
    required this.showSplash,
  });

  /// Melodía de bienvenida. Desactivada hasta que un adulto la autorice.
  final bool melodyEnabled;

  /// Pantalla de carga completa; si es `false` se omite.
  final bool showSplash;
}

class WelcomePreferencesNotifier extends Notifier<WelcomePreferences> {
  @override
  WelcomePreferences build() {
    final store = ref.watch(localStoreProvider);
    return WelcomePreferences(
      melodyEnabled: store.getBool(LocalStore.keyWelcomeMelody),
      showSplash: store.getBool(LocalStore.keyShowSplash, fallback: true),
    );
  }

  Future<void> setMelodyEnabled(bool value) async {
    await ref
        .read(localStoreProvider)
        .setBool(LocalStore.keyWelcomeMelody, value);
    state = WelcomePreferences(
      melodyEnabled: value,
      showSplash: state.showSplash,
    );
  }

  Future<void> setShowSplash(bool value) async {
    await ref.read(localStoreProvider).setBool(LocalStore.keyShowSplash, value);
    state = WelcomePreferences(
      melodyEnabled: state.melodyEnabled,
      showSplash: value,
    );
  }
}

final welcomePreferencesProvider =
    NotifierProvider<WelcomePreferencesNotifier, WelcomePreferences>(
      WelcomePreferencesNotifier.new,
    );

/// Reproduce el archivo de la melodía.
abstract class MelodyPlayer {
  Future<void> play();
  Future<void> stop();
  void dispose();
}

class AudioMelodyPlayer implements MelodyPlayer {
  static const asset = 'audio/bienvenida_mi_voz.wav';

  AudioPlayer? _player;

  @override
  Future<void> play() async {
    final player = _player ??= AudioPlayer();
    await player.stop();
    // Volumen moderado: el archivo ya tiene entrada y salida suaves.
    await player.setVolume(0.6);
    await player.play(AssetSource(asset));
  }

  @override
  Future<void> stop() async => _player?.stop();

  @override
  void dispose() => _player?.dispose();
}

final melodyPlayerProvider = Provider<MelodyPlayer>((ref) {
  final player = AudioMelodyPlayer();
  ref.onDispose(player.dispose);
  return player;
});

/// Decide si suena la melodía al abrir la app.
class WelcomeMelody {
  WelcomeMelody(this._ref);

  final Ref _ref;
  bool _playedThisLaunch = false;

  bool get playedThisLaunch => _playedThisLaunch;

  /// Modo tranquilo de un niño que usa este dispositivo (el del modo niño
  /// activo o el de los perfiles activados aquí, según la última copia local).
  bool calmModeOnDevice() {
    final store = _ref.read(localStoreProvider);
    final ids = {
      ?_ref.read(childModeProvider),
      ..._ref.read(deviceProfilesProvider).keys,
    };
    for (final id in ids) {
      final cached = store.getJson(LocalStore.childCacheKey(id));
      if (cached != null && ChildProfile.fromMap(cached).settings.calmMode) {
        return true;
      }
    }
    return false;
  }

  bool get allowed =>
      _ref.read(welcomePreferencesProvider).melodyEnabled &&
      !calmModeOnDevice();

  /// Suena una sola vez por inicio, si un adulto la activó y no hay modo
  /// tranquilo. Devuelve `true` si empezó a sonar.
  Future<bool> playOnLaunch() async {
    if (_playedThisLaunch || !allowed) return false;
    _playedThisLaunch = true;
    try {
      await _ref.read(melodyPlayerProvider).play();
      return true;
    } catch (e) {
      // Un fallo de audio nunca debe bloquear el acceso a los pictogramas.
      debugPrint('No se pudo reproducir la melodía: $e');
      return false;
    }
  }

  /// Vista previa desde Configuración.
  Future<void> preview() => _ref.read(melodyPlayerProvider).play();

  Future<void> stop() => _ref.read(melodyPlayerProvider).stop();
}

final welcomeMelodyProvider = Provider<WelcomeMelody>(WelcomeMelody.new);
