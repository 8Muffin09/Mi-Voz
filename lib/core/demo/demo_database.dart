import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../services/local_store.dart';
import 'demo_seed.dart';

/// Base de datos local del modo demostración.
///
/// Guarda tablas JSON en el dispositivo y notifica cambios para que las
/// pantallas se actualicen en tiempo real, igual que con Firestore.
class DemoDatabase {
  /// [seedSampleData]: carga los datos ficticios de `DemoSeed` cuando la base
  /// está vacía. Solo se usa en pruebas automáticas; en la app el modo local
  /// empieza vacío (sin cuentas de ejemplo).
  DemoDatabase(this._store, {this.seedSampleData = false}) {
    _load();
  }

  final bool seedSampleData;

  static const users = 'users';
  static const children = 'children';
  static const links = 'caregiver_links';
  static const invitations = 'invitations';
  static const requests = 'communication_requests';
  static const passports = 'sensory_passports';
  static const strategies = 'support_strategies';
  static const content = 'child_content';
  static const families = 'families';
  static const classes = 'classes';
  static const groupInvitations = 'group_invitations';
  static const joinRequests = 'join_requests';
  static const rateLimits = 'rate_limits';

  static const _tableNames = [
    users,
    children,
    links,
    invitations,
    requests,
    passports,
    strategies,
    content,
    families,
    classes,
    groupInvitations,
    joinRequests,
    rateLimits,
  ];

  final LocalStore _store;
  final _changes = StreamController<void>.broadcast();
  final Map<String, Map<String, Map<String, dynamic>>> _tables = {};

  void _load() {
    final raw = _store.getJson(LocalStore.keyDemoDb);
    if (raw == null) {
      _seed();
      return;
    }
    for (final name in _tableNames) {
      final table = raw[name];
      _tables[name] = {
        if (table is Map)
          for (final e in table.entries)
            if (e.value is Map)
              e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      };
    }
  }

  void _seed() {
    for (final name in _tableNames) {
      _tables[name] = {};
    }
    if (seedSampleData) DemoSeed.populate(this);
    _persist();
  }

  /// Borra todos los datos guardados en este dispositivo por el modo local.
  Future<void> reset() async {
    _seed();
    _changes.add(null);
  }

  Map<String, dynamic>? get(String table, String id) {
    final row = _tables[table]?[id];
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  List<Map<String, dynamic>> all(String table) => _tables[table]!.values
      .map((r) => Map<String, dynamic>.from(r))
      .toList(growable: false);

  List<Map<String, dynamic>> where(
    String table,
    bool Function(Map<String, dynamic> row) test,
  ) => all(table).where(test).toList(growable: false);

  /// Inserta o reemplaza una fila. Las fechas se guardan como ISO-8601.
  void put(String table, String id, Map<String, dynamic> data) {
    _tables[table]![id] = _normalize(data);
  }

  void delete(String table, String id) {
    _tables[table]!.remove(id);
  }

  void deleteWhere(String table, bool Function(Map<String, dynamic>) test) {
    _tables[table]!.removeWhere((_, row) => test(row));
  }

  /// Persiste y notifica a los observadores.
  void commit() {
    _persist();
    _changes.add(null);
  }

  /// Notifica sin modificar datos (p. ej. al cambiar la sesión).
  void notify() => _changes.add(null);

  /// Flujo que se recalcula con cada cambio de la base.
  Stream<T> watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  void _persist() {
    _store.setJson(LocalStore.keyDemoDb, {
      for (final name in _tableNames) name: _tables[name],
    });
  }

  static Map<String, dynamic> _normalize(Map<String, dynamic> data) {
    final encoded = jsonEncode(
      data,
      toEncodable: (v) =>
          v is DateTime ? v.toUtc().toIso8601String() : v.toString(),
    );
    return Map<String, dynamic>.from(jsonDecode(encoded) as Map);
  }

  static String hashPassword(String uid, String password) =>
      sha256.convert(utf8.encode('mivoz-demo:$uid:$password')).toString();

  // ---- Sesión y red simulada ----

  String? get sessionUid => _store.getString(LocalStore.keyDemoSession);

  /// Como las reglas de Firestore: el adulto de la sesión está vinculado al
  /// niño (si no, no puede leer ni escribir sus datos).
  bool sessionIsMemberOf(String childId) {
    final uid = sessionUid;
    final members = get(children, childId)?['memberUids'];
    return uid != null && members is List && members.contains(uid);
  }

  Future<void> setSession(String? uid) async {
    if (uid == null) {
      await _store.remove(LocalStore.keyDemoSession);
    } else {
      await _store.setString(LocalStore.keyDemoSession, uid);
    }
  }

  bool get simulateOffline => _store.getBool(LocalStore.keyDemoOffline);

  Future<void> setSimulateOffline(bool value) =>
      _store.setBool(LocalStore.keyDemoOffline, value);
}
