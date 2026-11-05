import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/stream_utils.dart';
import '../../../models/app_user.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  AppUser _fallback(User u) => AppUser(
    uid: u.uid,
    email: u.email ?? '',
    displayName: u.displayName ?? u.email ?? 'Adulto',
    role: AdultRole.tutor,
  );

  @override
  Stream<AppUser?> authStateChanges() =>
      // userChanges (no solo authStateChanges) para enterarse de la
      // verificación del correo tras `reload()`.
      _auth.userChanges().switchMap<AppUser?>((u) {
        if (u == null) return Stream.value(null);
        return _userDoc(u.uid)
            .snapshots()
            .map<AppUser?>((s) {
              final data = s.data();
              final user = data == null
                  ? _fallback(u)
                  : AppUser.fromMap({...data, 'uid': u.uid});
              return user.copyWith(emailVerified: u.emailVerified);
            })
            .handleError((Object _) {}, test: (e) => e is FirebaseException);
      });

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      final snap = await _userDoc(user.uid).get();
      final data = snap.data();
      return (data == null
              ? _fallback(user)
              : AppUser.fromMap({...data, 'uid': user.uid}))
          .copyWith(emailVerified: user.emailVerified);
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
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
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());
      String? clean(String? v) =>
          (v?.trim().isEmpty ?? true) ? null : v!.trim();
      final appUser = AppUser(
        emailVerified: false,
        uid: user.uid,
        email: user.email ?? email.trim(),
        displayName: displayName.trim(),
        role: role,
        lastName: clean(lastName),
        avatar: avatar,
        avatarColor: avatarColor,
        schoolName: clean(schoolName),
        groupName: clean(groupName),
        teacherTitle: clean(teacherTitle),
        experiences: experiences,
      );
      await _userDoc(user.uid).set({
        ...appUser.profileMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      // La verificación de correo es recomendable, pero no bloquea el acceso.
      await user.sendEmailVerification().catchError((_) {});
      return appUser;
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<String> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode('es');
      await _auth.sendPasswordResetEmail(email: email.trim());
      return 'Si existe una cuenta con ese correo, recibirás un enlace para '
          'crear una nueva contraseña. Revisa también la carpeta de spam.';
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AppException('No hay una sesión activa.');
    try {
      await _auth.setLanguageCode('es');
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      // El token nuevo lleva `email_verified`, que exigen algunas reglas.
      if (refreshed?.emailVerified ?? false) await refreshed!.getIdToken(true);
      return refreshed?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') throw const OfflineException();
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<void> updateProfile(AppUser user) async {
    final current = _auth.currentUser;
    if (current == null || current.uid != user.uid) {
      throw const PermissionDeniedException();
    }
    // Las reglas de Firestore solo permiten escribir el propio documento.
    await _userDoc(user.uid).set({
      ...user.profileMap(),
      'email': current.email ?? user.email,
    }, SetOptions(merge: true));
    await current.updateDisplayName(user.displayName);
  }

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AppException('No hay una sesión activa.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> verifyPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AppException('No hay una sesión activa.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'network-request-failed') throw const OfflineException();
      throw AppException(_message(e), code: e.code);
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AppException('No hay una sesión activa.');
    }
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await _userDoc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AppException(_message(e), code: e.code);
    }
  }

  static String _message(FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => 'El correo no es válido.',
    'user-disabled' => 'Esta cuenta está deshabilitada.',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'Correo o contraseña incorrectos.',
    'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
    'weak-password' => 'La contraseña es demasiado débil.',
    'too-many-requests' =>
      'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
    'network-request-failed' => 'Sin conexión a internet.',
    'requires-recent-login' =>
      'Por seguridad, vuelve a iniciar sesión e inténtalo de nuevo.',
    'operation-not-allowed' =>
      'El inicio de sesión no está disponible por ahora. Intenta más tarde.',
    _ => 'No se pudo completar la operación (${e.code}).',
  };
}
