import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/permissions/permissions.dart';
import '../../../../core/widgets/state_views.dart';
import '../../../../models/app_user.dart';
import '../../../../models/child_profile.dart';
import '../../../profiles/application/profiles_providers.dart';

/// Carga un perfil infantil y verifica que el adulto actual esté vinculado
/// antes de mostrar cualquier dato del niño.
class ChildGuard extends ConsumerWidget {
  const ChildGuard({super.key, required this.childId, required this.builder});

  final String childId;
  final Widget Function(BuildContext context, ChildProfile child, AppUser user)
  builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final async = ref.watch(childProvider(childId));
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e),
      ),
      data: (child) {
        if (user == null ||
            child == null ||
            !Permissions.canView(child, user.uid)) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'No tienes acceso a este perfil',
              message: 'Solo los adultos vinculados pueden ver su información.',
            ),
          );
        }
        return builder(context, child, user);
      },
    );
  }
}
