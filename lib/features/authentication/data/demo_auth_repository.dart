import '../../../core/demo/demo_database.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
import 'auth_repository.dart';

/// Autenticación local del modo demostración. Las contraseñas se guardan
/// con hash SHA-256 y nunca salen del dispositivo.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._db);

  final DemoDatabase _db;

  AppUser? _current() {
    final uid = _db.sessionUid;
    if (uid == null) return null;
    final row = _db.get(DemoDatabase.users, uid);
    return row == null ? null : AppUser.fromMap(row);
  }

  Map<String, dynamic>? _findByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final rows = _db.where(
      DemoDatabase.users,
      (r) => (r['email'] as String?)?.toLowerCase() == normalized,
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Stream<AppUser?> authStateChanges() => _db.watch(_current);

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final row = _findByEmail(email);
    final uid = row?['uid'] as String?;
    if (row == null ||
        uid == null ||
        row['passwordHash'] != DemoDatabase.hashPassword(uid, password)) {
      throw const AppException('Correo o contraseña incorrectos.');
    }
    await _db.setSession(uid);
    _db.notify();
    return AppUser.fromMap(row);
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required AdultRole role,
    String? lastName,
    String? avatar,
    int? avatarColor,
    String? schoolName,
    String? groupName,
    String? teacherTitle,
    Set<UserExperience> experiences = const {},
  }) async {
    if (_findByEmail(email) != null) {
      throw const AppException('Ya existe una cuenta con ese correo.');
    }
    final user = AppUser(
      uid: 'demo-${newId()}',
      email: email.trim().toLowerCase(),
      displayName: displayName.trim(),
      role: role,
      lastName: _clean(lastName),
      avatar: avatar,
      avatarColor: avatarColor,
      schoolName: _clean(schoolName),
      groupName: _clean(groupName),
      teacherTitle: _clean(teacherTitle),
      experiences: experiences,
      createdAt: DateTime.now(),
    );
    _db.put(DemoDatabase.users, user.uid, {
      ...user.toMap(),
      'passwordHash': DemoDatabase.hashPassword(user.uid, password),
    });
    await _db.setSession(user.uid);
    _db.commit();
    return user;
  }

  /// El modo local no puede enviar correos ni comprobar la identidad de
  /// otra forma, así que no restablece contraseñas (hacerlo sin verificar
  /// permitiría a cualquiera entrar en otra cuenta del dispositivo).
  @override
  Future<String> sendPasswordReset(String email) async {
    throw const AppException(
      'Esta versión guarda las cuentas solo en este dispositivo y no puede '
      'enviar correos de recuperación. Si olvidaste la contraseña, pide '
      'ayuda a quien instaló la app.',
    );
  }

  /// En el modo local no hay correos: las cuentas se consideran verificadas.
  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerification() async => true;

  @override
  Future<void> updateProfile(AppUser user) async {
    // Solo el propio adulto puede editar su perfil.
    if (user.uid != _db.sessionUid) throw const PermissionDeniedException();
    final row = _db.get(DemoDatabase.users, user.uid);
    if (row == null) throw const AppException('La cuenta no existe.');
    _db.put(DemoDatabase.users, user.uid, {
      ...row,
      ...user.profileMap(),
      // El correo y el identificador no se cambian desde el perfil.
      'uid': row['uid'],
      'email': row['email'],
    });
    _db.commit();
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await verifyPassword(currentPassword);
    final uid = _db.sessionUid!;
    final row = _db.get(DemoDatabase.users, uid)!;
    _db.put(DemoDatabase.users, uid, {
      ...row,
      'passwordHash': DemoDatabase.hashPassword(uid, newPassword),
    });
    _db.commit();
  }

  static String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> signOut() async {
    await _db.setSession(null);
    _db.notify();
  }

  @override
  Future<void> verifyPassword(String password) async {
    final uid = _db.sessionUid;
    final row = uid == null ? null : _db.get(DemoDatabase.users, uid);
    if (uid == null ||
        row == null ||
        row['passwordHash'] != DemoDatabase.hashPassword(uid, password)) {
      throw const AppException('La contraseña no es correcta.');
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final uid = _db.sessionUid;
    final row = uid == null ? null : _db.get(DemoDatabase.users, uid);
    if (uid == null || row == null) {
      throw const AppException('No hay una sesión activa.');
    }
    if (row['passwordHash'] != DemoDatabase.hashPassword(uid, password)) {
      throw const AppException('La contraseña no es correcta.');
    }
    _db.delete(DemoDatabase.users, uid);
    await _db.setSession(null);
    _db.commit();
  }
}
