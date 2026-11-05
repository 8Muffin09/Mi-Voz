import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/dialogs.dart';
import '../application/parental_pin.dart';

/// Verificación de adulto para salir del modo niño o entrar a funciones de
/// adulto: PIN de adulto o, si no hay PIN (o se olvidó), la contraseña de la
/// cuenta. Los intentos fallidos bloquean temporalmente la verificación.
Future<bool> showParentalGate(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ParentalGateDialog(),
  );
  return result ?? false;
}

class _ParentalGateDialog extends ConsumerStatefulWidget {
  const _ParentalGateDialog();

  @override
  ConsumerState<_ParentalGateDialog> createState() =>
      _ParentalGateDialogState();
}

class _ParentalGateDialogState extends ConsumerState<_ParentalGateDialog> {
  final _controller = TextEditingController();
  late bool _usePassword = !ref.read(parentalPinProvider);
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _lockMessage() {
    final left = ref.read(parentalPinProvider.notifier).lockRemaining();
    if (left == null) return null;
    final seconds = (left.inMilliseconds / 1000).ceil();
    return 'Demasiados intentos. Espera $seconds s y vuelve a intentarlo.';
  }

  Future<void> _submit() async {
    final value = _controller.text.trim();
    if (value.isEmpty || _checking) return;
    final pin = ref.read(parentalPinProvider.notifier);
    final locked = _lockMessage();
    if (locked != null) {
      setState(() => _error = locked);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    var ok = false;
    String? error;
    if (_usePassword) {
      try {
        await ref.read(authRepositoryProvider).verifyPassword(value);
        await pin.resetFailures();
        ok = true;
      } on OfflineException {
        error = 'Sin conexión no se puede comprobar la contraseña. Usa el PIN.';
      } catch (e) {
        await pin.registerFailure();
        error = 'Contraseña incorrecta.';
      }
    } else {
      ok = await pin.attempt(value);
      if (!ok) error = 'PIN incorrecto.';
    }
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _checking = false;
      _error = _lockMessage() ?? error;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasPin = ref.watch(parentalPinProvider);
    return AlertDialog(
      icon: const Icon(Icons.lock_rounded, size: 36),
      title: const Text('Solo para adultos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _usePassword
                ? 'Escribe la contraseña de tu cuenta para continuar.'
                : 'Escribe el PIN de adulto para continuar.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          if (_usePassword)
            TextField(
              key: const Key('parental-gate-password'),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              enabled: !_checking,
              decoration: InputDecoration(
                labelText: 'Contraseña',
                errorText: _error,
                errorMaxLines: 3,
              ),
              onSubmitted: (_) => _submit(),
            )
          else
            TextField(
              key: const Key('parental-gate-input'),
              controller: _controller,
              autofocus: true,
              obscureText: true,
              enabled: !_checking,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 6),
              decoration: InputDecoration(
                counterText: '',
                errorText: _error,
                errorMaxLines: 3,
                hintText: 'PIN',
              ),
              onSubmitted: (_) => _submit(),
            ),
          if (hasPin)
            TextButton(
              key: const Key('parental-gate-switch'),
              onPressed: _checking
                  ? null
                  : () => setState(() {
                      _usePassword = !_usePassword;
                      _error = null;
                      _controller.clear();
                    }),
              child: Text(
                _usePassword
                    ? 'Usar el PIN'
                    : 'Olvidé el PIN: usar mi contraseña',
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Consejo: configura un PIN en Configuración para entrar más '
                'rápido, también sin conexión.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('parental-gate-submit'),
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Continuar'),
        ),
      ],
    );
  }
}

/// Crear o cambiar el PIN de adulto. [intro] explica por qué se pide (por
/// ejemplo, al entrar al modo infantil por primera vez). Devuelve `true` si
/// se guardó.
Future<bool> showSetPinDialog(
  BuildContext context,
  WidgetRef ref, {
  String? intro,
  String cancelLabel = 'Cancelar',
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (_) => _SetPinDialog(intro: intro, cancelLabel: cancelLabel),
  );
  if (result == null || !context.mounted) return false;
  return runGuarded(
    context,
    () => ref.read(parentalPinProvider.notifier).setPin(result),
    success: 'PIN guardado.',
  );
}

/// Diálogo con estado propio: sus campos se liberan al terminar la animación
/// de cierre (no antes).
class _SetPinDialog extends StatefulWidget {
  const _SetPinDialog({required this.intro, required this.cancelLabel});

  final String? intro;
  final String cancelLabel;

  @override
  State<_SetPinDialog> createState() => _SetPinDialogState();
}

class _SetPinDialogState extends State<_SetPinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final invalid = Validators.pin(_pin.text);
    if (invalid != null) {
      setState(() => _error = invalid);
    } else if (_pin.text != _confirm.text) {
      setState(() => _error = 'Los PIN no coinciden.');
    } else {
      Navigator.of(context).pop(_pin.text);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('PIN de adulto'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.intro != null) ...[
            Text(widget.intro!),
            const SizedBox(height: 8),
          ],
          TextField(
            key: const Key('pin-input'),
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: const InputDecoration(labelText: 'PIN (4 a 6 números)'),
          ),
          TextField(
            key: const Key('pin-confirm'),
            controller: _confirm,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: InputDecoration(
              labelText: 'Repite el PIN',
              errorText: _error,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        key: const Key('pin-cancel'),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.cancelLabel),
      ),
      FilledButton(
        key: const Key('pin-save'),
        onPressed: _save,
        child: const Text('Guardar'),
      ),
    ],
  );
}
