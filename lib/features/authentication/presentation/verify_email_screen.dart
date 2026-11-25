import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/mi_voz_logo.dart';
import '../application/session_actions.dart';

/// Espera mínima entre reenvíos del correo de verificación. Firebase además
/// limita los envíos por su cuenta (`too-many-requests`).
const verificationResendCooldown = Duration(seconds: 60);

/// Cuándo se puede volver a enviar el correo (se recuerda por cuenta, así
/// cerrar y abrir la app no salta la espera).
class ResendCooldown {
  ResendCooldown(this._store, this._uid, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LocalStore _store;
  final String _uid;
  final DateTime Function() _clock;

  static String key(String uid) => 'verification_sent_$uid';

  DateTime? get lastSent {
    final raw = _store.getString(key(_uid));
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Duration get remaining {
    final last = lastSent;
    if (last == null) return Duration.zero;
    final left = verificationResendCooldown - _clock().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> markSent() =>
      _store.setString(key(_uid), _clock().toUtc().toIso8601String());
}

/// "Revisa tu correo": la cuenta ya existe y está guardada; confirmar el
/// correo prueba que le pertenece. Hasta entonces el servidor no deja crear
/// clases, familias, perfiles ni usar invitaciones, así que la app espera
/// aquí. "Ya confirmé" vuelve a consultar el estado real: no marca nada.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _ticker;
  bool _checking = false;
  bool _sending = false;
  String? _message;
  bool _messageIsError = false;

  ResendCooldown? get _cooldown {
    final uid = ref.read(currentUserProvider)?.uid;
    return uid == null
        ? null
        : ResendCooldown(ref.read(localStoreProvider), uid);
  }

  @override
  void initState() {
    super.initState();
    // El registro envía el primer correo: empieza la espera desde ahí.
    final cooldown = _cooldown;
    if (cooldown != null && cooldown.lastSent == null) cooldown.markSent();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _show(String text, {bool error = false}) => setState(() {
    _message = text;
    _messageIsError = error;
  });

  Future<void> _resend() async {
    final cooldown = _cooldown;
    if (cooldown == null || cooldown.remaining > Duration.zero) return;
    setState(() => _sending = true);
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      await cooldown.markSent();
      _show('Te enviamos un correo nuevo. Revisa también la carpeta de spam.');
    } on OfflineException {
      _show(
        'Sin conexión. Conéctate a internet para reenviar el correo.',
        error: true,
      );
    } catch (e) {
      _show(describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final verified = await ref
          .read(authRepositoryProvider)
          .refreshEmailVerification();
      if (!verified) {
        _show(
          'Todavía no aparece confirmado. Abre el enlace del correo y vuelve '
          'a intentarlo. Si el enlace venció, reenvía el correo.',
          error: true,
        );
      }
      // Si está verificado, la navegación continúa sola.
    } on OfflineException {
      _show(
        'Sin conexión. No pudimos comprobar el estado de tu correo.',
        error: true,
      );
    } catch (e) {
      _show(describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final remaining = _cooldown?.remaining ?? Duration.zero;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: MiVozLogo(size: 80)),
                  const SizedBox(height: 16),
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 8),
                  Semantics(
                    header: true,
                    child: Text(
                      'Revisa tu correo',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tu cuenta ya está creada. Enviamos un enlace de '
                    'confirmación a ${user?.email ?? 'tu correo'}. Ábrelo '
                    'para comprobar que el correo es tuyo.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Hasta confirmarlo no podrás crear clases, familias ni '
                    'perfiles, ni usar códigos de invitación.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('verify-check'),
                    onPressed: _checking ? null : _check,
                    child: _checking
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Ya confirmé mi correo'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('verify-resend'),
                    onPressed: _sending || remaining > Duration.zero
                        ? null
                        : _resend,
                    child: Text(
                      remaining > Duration.zero
                          ? 'Reenviar correo de verificación '
                                '(${remaining.inSeconds} s)'
                          : 'Reenviar correo de verificación',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    key: const Key('verify-sign-out'),
                    onPressed: () => ref.read(sessionActionsProvider).signOut(),
                    child: const Text('Cerrar sesión'),
                  ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _message!,
                          key: const Key('verify-message'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _messageIsError
                                ? AppColors.urgent
                                : AppColors.success,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
