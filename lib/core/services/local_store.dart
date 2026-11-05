import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Envoltorio de [SharedPreferences] para guardar JSON en el dispositivo.
/// Se usa para preferencias, caché offline y la cola de envío.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const keyAppMode = 'app_mode';
  static const keyChildMode = 'child_mode';
  static const keyParentPin = 'parent_pin_hash';
  static const keyGateFailures = 'parent_gate_failures';
  static const keyGateLockUntil = 'parent_gate_lock_until';
  static const keyOutbox = 'request_outbox';
  // v2: perfiles de ejemplo de María (familia), Ana (docente), Juan, Sofía y Mateo.
  static const keyDemoDb = 'demo_db_v2';
  static const keyDemoSession = 'demo_session_uid';
  static const keyDemoOffline = 'demo_simulate_offline';
  static const keyOnboardingSeen = 'onboarding_seen';

  /// Experiencia elegida en "¿Cómo deseas ingresar?" (familia o docente).
  static const keyExperience = 'active_experience';

  /// Perfiles infantiles que un adulto activó en este dispositivo.
  static const keyDeviceChildren = 'device_child_profiles';

  /// Melodía de bienvenida: desactivada hasta que un adulto la autorice.
  static const keyWelcomeMelody = 'welcome_melody_enabled';

  /// Mostrar la pantalla de carga completa (si no, se omite).
  static const keyShowSplash = 'welcome_splash_enabled';
  static String childCacheKey(String childId) => 'child_cache_$childId';
  static String contentCacheKey(String childId) => 'content_cache_$childId';
  static String currentStudentKey(String uid) => 'current_student_$uid';

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value, toEncodable: _encodeExtra));

  List<Map<String, dynamic>> getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } on FormatException {
      return [];
    }
    return [];
  }

  Future<void> setJsonList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value, toEncodable: _encodeExtra));

  /// Elimina todas las cachés de perfiles infantiles y la cola de envío
  /// (`request_outbox_demo` / `request_outbox_firebase`).
  Future<void> clearUserData() async {
    final keys = _prefs.getKeys().where(
      (k) =>
          k.startsWith('child_cache_') ||
          k.startsWith('content_cache_') ||
          k.startsWith(keyOutbox) ||
          k == keyChildMode,
    );
    for (final k in keys.toList()) {
      await _prefs.remove(k);
    }
  }

  static Object? _encodeExtra(Object? value) {
    if (value is DateTime) return value.toUtc().toIso8601String();
    return value.toString();
  }
}
