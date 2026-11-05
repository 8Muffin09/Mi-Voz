import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/validators.dart';
import '../../access/application/access_providers.dart';
import '../application/session_actions.dart';
import 'post_auth_navigation.dart';
import 'widgets/auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await ref
          .read(sessionActionsProvider)
          .signIn(_email.text, _password.text);
      if (mounted) await navigateAfterAuth(context, ref, user);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final demo = ref.watch(isDemoModeProvider);
    final forStudent = ref.watch(pendingStudentProfileProvider);
    return AuthLayout(
      title: 'Iniciar sesión',
      subtitle: forStudent
          ? 'Inicia sesión con la cuenta del adulto responsable para crear el '
                'perfil del alumno.'
          : 'Cuenta de adulto: docente, padre, madre o tutor. El mismo acceso '
                'sirve para todos tus perfiles.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (demo) ...[
                const LocalModeNotice(),
                const SizedBox(height: 16),
              ],
              TextFormField(
                key: const Key('login-email'),
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('login-password'),
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _signIn(),
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: _obscure
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v ?? '').isEmpty ? 'Escribe tu contraseña.' : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: const Text('¿Olvidaste tu contraseña?'),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.urgent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              FilledButton(
                key: const Key('login-submit'),
                onPressed: _loading ? null : _signIn,
                child: _loading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Entrar'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('login-register'),
                onPressed: _loading
                    ? null
                    : () => context.push(Routes.createProfile),
                child: const Text('No tengo cuenta: crear una cuenta'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Solo en versiones sin nube configurada: avisa que la cuenta no se podrá
/// recuperar desde otro dispositivo (sin nombrar servicios técnicos).
class LocalModeNotice extends StatelessWidget {
  const LocalModeNotice({super.key});

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.primary.withValues(alpha: 0.06),
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.phone_android_rounded, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Esta versión guarda la cuenta y sus datos solo en este '
              'dispositivo: no se podrán abrir desde otro teléfono ni '
              'recuperar por correo.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    ),
  );
}
