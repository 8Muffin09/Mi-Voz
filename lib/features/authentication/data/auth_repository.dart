import '../../../models/app_user.dart';

/// Autenticación de adultos.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();

  Future<AppUser> signIn({required String email, required String password});

  /// Crea la cuenta con su perfil básico. Los datos opcionales (apellido,
  /// avatar, escuela, grupo...) pueden completarse después en "Mi perfil".
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
  });

  /// Devuelve el mensaje que se mostrará al usuario.
  Future<String> sendPasswordReset(String email);

  /// Reenvía el correo de verificación de la cuenta actual.
  Future<void> sendEmailVerification();

  /// Vuelve a consultar si el correo ya se verificó. Devuelve el estado.
  Future<bool> refreshEmailVerification();

  /// Guarda los datos editables del perfil del adulto actual.
  Future<void> updateProfile(AppUser user);

  /// Cambia la contraseña tras confirmar la actual.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> signOut();

  /// Confirma la identidad antes de acciones sensibles (borrar datos).
  Future<void> verifyPassword(String password);

  /// Elimina la cuenta de autenticación y el documento de usuario.
  /// Los datos de los niños se eliminan antes con `AccountDeletionService`.
  Future<void> deleteAccount({required String password});
}
