import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';

/// PIN de adulto para salir del modo niño y entrar a funciones de adulto.
///
/// Se guarda solo un hash con sal e iteraciones (`v2:<sal>:<hash>`), nunca el
/// PIN. Tras varios intentos fallidos (PIN o contraseña) se bloquea durante
/// un tiempo creciente. Los PIN del formato anterior se aceptan y se
/// actualizan al nuevo formato la primera vez que se usan.
class ParentalPinNotifier extends Notifier<bool> {
  static const _iterations = 20000;
  static const maxFreeAttempts = 5;
  static const baseLock = Duration(seconds: 30);
  static const maxLock = Duration(minutes: 15);

  @override
  bool build() =>
      ref.watch(localStoreProvider).getString(LocalStore.keyParentPin) != null;

  LocalStore get _store => ref.read(localStoreProvider);

  static String _derive(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('mivoz-pin:$salt:$pin')).bytes;
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Url.encode(digest);
  }

  static String _legacy(String pin) =>
      sha256.convert(utf8.encode('mivoz-pin:$pin')).toString();

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
    await _store.setString(
      LocalStore.keyParentPin,
      'v2:$salt:${_derive(pin, salt)}',
    );
    await resetFailures();
    state = true;
  }

  Future<void> clear() async {
    await _store.remove(LocalStore.keyParentPin);
    state = false;
  }

  /// Comprueba el PIN sin contar intentos (ver [attempt]).
  bool verify(String pin) {
    final stored = _store.getString(LocalStore.keyParentPin);
    if (stored == null) return false;
    if (stored.startsWith('v2:')) {
      final parts = stored.split(':');
      return parts.length == 3 && _derive(pin, parts[1]) == parts[2];
    }
    return stored == _legacy(pin);
  }

  /// Intento de PIN con bloqueo por intentos. `true` si es correcto.
  Future<bool> attempt(String pin) async {
    if (lockRemaining() != null) return false;
    final stored = _store.getString(LocalStore.keyParentPin);
    if (verify(pin)) {
      if (stored != null && !stored.startsWith('v2:')) await setPin(pin);
      await resetFailures();
      return true;
    }
    await registerFailure();
    return false;
  }

  /// Tiempo de bloqueo restante, o `null` si se puede intentar.
  Duration? lockRemaining([DateTime? now]) {
    final until = DateTime.tryParse(
      _store.getString(LocalStore.keyGateLockUntil) ?? '',
    );
    if (until == null) return null;
    final left = until.difference(now ?? DateTime.now());
    return left > Duration.zero ? left : null;
  }

  int get failures =>
      int.tryParse(_store.getString(LocalStore.keyGateFailures) ?? '') ?? 0;

  /// Registra un intento fallido (también de contraseña) y bloquea si toca:
  /// 30 s tras el quinto, el doble en cada fallo siguiente, máximo 15 min.
  Future<void> registerFailure() async {
    final count = failures + 1;
    await _store.setString(LocalStore.keyGateFailures, '$count');
    if (count >= maxFreeAttempts) {
      final lock = baseLock * (1 << (count - maxFreeAttempts).clamp(0, 10));
      final until = DateTime.now().add(lock > maxLock ? maxLock : lock);
      await _store.setString(
        LocalStore.keyGateLockUntil,
        until.toIso8601String(),
      );
    }
  }

  Future<void> resetFailures() async {
    await _store.remove(LocalStore.keyGateFailures);
    await _store.remove(LocalStore.keyGateLockUntil);
  }
}

/// `true` si hay un PIN configurado.
final parentalPinProvider = NotifierProvider<ParentalPinNotifier, bool>(
  ParentalPinNotifier.new,
);
