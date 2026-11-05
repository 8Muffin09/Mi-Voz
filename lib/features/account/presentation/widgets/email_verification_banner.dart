import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/dialogs.dart';

/// Aviso mientras el correo de la cuenta no esté verificado (modo Firebase).
/// Generar invitaciones exige un correo verificado (también en las reglas).
class EmailVerificationBanner extends ConsumerWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.emailVerified) return const SizedBox.shrink();
    final auth = ref.read(authRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        key: const Key('email-verification-banner'),
        color: AppColors.warning.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verifica tu correo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Te enviamos un enlace a ${user.email}. Hasta verificarlo no '
                'podrás generar códigos de invitación.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: () => runGuarded(
                      context,
                      auth.sendEmailVerification,
                      success:
                          'Correo enviado. Revisa también la carpeta de spam.',
                    ),
                    child: const Text('Reenviar'),
                  ),
                  TextButton(
                    onPressed: () async {
                      var verified = false;
                      final done = await runGuarded(context, () async {
                        verified = await auth.refreshEmailVerification();
                      });
                      if (done && !verified && context.mounted) {
                        showMessage(
                          context,
                          'Todavía no aparece verificado. Abre el enlace del '
                          'correo e inténtalo de nuevo.',
                        );
                      }
                    },
                    child: const Text('Ya lo verifiqué'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
