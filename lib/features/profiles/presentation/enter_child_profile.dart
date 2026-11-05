import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/child_profile.dart';
import '../../authentication/application/session_actions.dart';
import '../../settings/application/parental_pin.dart';
import '../../settings/presentation/parental_gate.dart';

/// "Entrar al perfil de Juan": explica cómo se sale del modo niño, activa el
/// perfil en este dispositivo y abre su comunicación con pictogramas.
Future<void> confirmAndEnterChildProfile(
  BuildContext context,
  WidgetRef ref,
  ChildProfile child,
) async {
  final hasPin = ref.read(parentalPinProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Entrar al perfil de ${child.name}'),
      content: Text(
        'La pantalla mostrará solo la comunicación con pictogramas de '
        '${child.name}. Para volver a tu panel se pedirá '
        '${hasPin ? 'el PIN de adulto' : 'la contraseña de tu cuenta'}.\n\n'
        'El perfil quedará disponible en "¿Quién utilizará Mi Voz?" de este '
        'dispositivo, sin contraseña para el niño.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-child-mode'),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Entrar'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  // Sin PIN, salir del modo infantil exigirá la contraseña de la cuenta (que
  // necesita conexión en Firebase): se ofrece crear un PIN, sin obligar.
  if (!ref.read(parentalPinProvider)) {
    await showSetPinDialog(
      context,
      ref,
      intro:
          'Recomendado: con un PIN podrás volver a tu panel rápidamente, '
          'también sin conexión. Si prefieres, se pedirá la contraseña de tu '
          'cuenta.',
      cancelLabel: 'Ahora no',
    );
  }
  await ref.read(sessionActionsProvider).enterChildProfile(child);
}
