/// Validadores de formularios. Devuelven `null` si el valor es válido.
class Validators {
  const Validators._();

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe tu correo electrónico.';
    if (!_emailRegex.hasMatch(v)) return 'El correo no es válido.';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Escribe una contraseña.';
    if (v.length < 8) return 'Debe tener al menos 8 caracteres.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Usa letras y números.';
    }
    return null;
  }

  static String? required(String? value, {String field = 'Este campo'}) {
    if ((value?.trim() ?? '').isEmpty) return '$field es obligatorio.';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Escribe un nombre.';
    if (v.length > 40) return 'Máximo 40 caracteres.';
    return null;
  }

  /// Apellido u otro nombre opcional.
  static String? optionalName(String? value) {
    if ((value?.trim().length ?? 0) > 40) return 'Máximo 40 caracteres.';
    return null;
  }

  /// Texto corto opcional (escuela, grupo).
  static String? optionalText(String? value) {
    if ((value?.trim().length ?? 0) > 80) return 'Máximo 80 caracteres.';
    return null;
  }

  static String? pin(String? value) {
    final v = value ?? '';
    if (!RegExp(r'^\d{4,6}$').hasMatch(v)) {
      return 'El PIN debe tener 4 a 6 números.';
    }
    return null;
  }

  static String? invitationCode(String? value) {
    final v = (value ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(v)) {
      return 'El código tiene 8 letras o números.';
    }
    return null;
  }
}
