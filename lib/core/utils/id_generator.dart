import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();
final _random = Random.secure();

/// Identificador único generado en el cliente. Se usa como id de documento
/// para que reenviar una solicitud nunca genere duplicados.
String newId() => _uuid.v4();

/// Código de invitación de 8 caracteres sin símbolos ambiguos (0/O, 1/I/L).
String newInvitationCode() {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return List.generate(
    8,
    (_) => alphabet[_random.nextInt(alphabet.length)],
  ).join();
}
