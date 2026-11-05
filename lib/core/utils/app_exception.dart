/// Error de dominio con un mensaje listo para mostrar al usuario.
class AppException implements Exception {
  const AppException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

/// No hay conexión con el servidor: la operación debe reintentarse luego.
class OfflineException extends AppException {
  const OfflineException([super.message = 'Sin conexión a internet.'])
    : super(code: 'offline');
}

/// El cambio se guardó en el dispositivo pero el servidor aún no lo confirma
/// (sin conexión). Se enviará solo al volver internet.
class SavedOfflineException extends AppException {
  const SavedOfflineException([
    super.message =
        'Sin conexión: el cambio quedó guardado en este dispositivo y se '
        'enviará al volver internet.',
  ]) : super(code: 'saved-offline');
}

/// El usuario actual no tiene permiso para la operación solicitada.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([
    super.message = 'No tienes permiso para realizar esta acción.',
  ]) : super(code: 'permission-denied');
}

/// Devuelve un mensaje legible para cualquier error.
String describeError(Object error) {
  if (error is AppException) return error.message;
  final text = error.toString();
  if (text.contains('permission-denied')) {
    return const PermissionDeniedException().message;
  }
  if (text.contains('unavailable') || text.contains('network')) {
    return const OfflineException().message;
  }
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}
