import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../core/widgets/state_views.dart';
import '../application/local_data_migration.dart';
import '../application/migration_providers.dart';

/// Aviso en el panel: hay perfiles guardados solo en este dispositivo. Nunca
/// se transfieren solos; "Revisar" abre la pantalla de transferencia.
class MigrationOfferBanner extends ConsumerStatefulWidget {
  const MigrationOfferBanner({super.key});

  @override
  ConsumerState<MigrationOfferBanner> createState() =>
      _MigrationOfferBannerState();
}

class _MigrationOfferBannerState extends ConsumerState<MigrationOfferBanner> {
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    if (_hidden || !ref.watch(hasLocalDataToMigrateProvider)) {
      return const SizedBox.shrink();
    }
    return Material(
      key: const Key('migration-offer'),
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.drive_file_move_outline, color: AppColors.primary),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Hay perfiles guardados solo en este dispositivo.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _hidden = true),
              child: const Text('Ahora no'),
            ),
            TextButton(
              key: const Key('migration-review'),
              onPressed: () => context.push(Routes.transfer),
              child: const Text('Revisar'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Transferir a la cuenta actual los perfiles que una cuenta anterior de
/// este dispositivo administraba: se elige la cuenta, se confirma con su
/// contraseña y se marcan los perfiles.
class MigrationScreen extends ConsumerStatefulWidget {
  const MigrationScreen({super.key});

  @override
  ConsumerState<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends ConsumerState<MigrationScreen> {
  LocalAccountSummary? _account;
  String? _password;
  List<LocalChildSummary> _children = const [];
  final Set<String> _selected = {};
  bool _busy = false;
  String? _error;
  MigrationResult? _result;

  Future<void> _unlock(LocalAccountSummary account) async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => _PasswordDialog(account: account),
    );
    if (password == null || !mounted) return;
    final migration = ref.read(localDataMigrationProvider);
    try {
      final children = migration.childrenOf(account.uid, password);
      setState(() {
        _account = account;
        _password = password;
        _children = children;
        _selected.clear();
        _error = null;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _transfer() async {
    final user = ref.read(currentUserProvider);
    final account = _account;
    if (user == null || account == null || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(localDataMigrationProvider)
          .transfer(
            localUid: account.uid,
            password: _password!,
            childIds: {..._selected},
            cloudUser: user,
            target: ref.read(migrationTargetProvider),
          );
      ref.read(migrationRefreshProvider.notifier).bump();
      if (mounted) setState(() => _result = result);
    } on OfflineException {
      if (mounted) {
        setState(
          () => _error =
              'No pudimos conectar. Intentar nuevamente: lo que ya se '
              'transfirió no se repetirá.',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de este dispositivo')),
      body: SafeArea(
        child: result != null
            ? EmptyState(
                icon: Icons.cloud_done_rounded,
                title: result.profiles == 1
                    ? 'Se transfirió 1 perfil'
                    : 'Se transfirieron ${result.profiles} perfiles',
                message:
                    'Ya puedes verlos al iniciar sesión en otros dispositivos. '
                    'La copia de este dispositivo no se borró.',
                action: FilledButton(
                  onPressed: () => context.go(Routes.adult),
                  child: const Text('Ir al inicio'),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Antes, Mi Voz guardaba algunas cuentas solo en este '
                    'dispositivo. Puedes pasar sus perfiles a tu cuenta '
                    '(${user?.email ?? ''}) para recuperarlos desde otros '
                    'dispositivos.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Por seguridad, primero confirma la contraseña de la '
                    'cuenta anterior. Solo se transfieren los perfiles que '
                    'marques, y cada perfil pasa a una sola cuenta.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 16),
                  if (_account == null) ..._accounts() else ..._childList(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        key: const Key('migration-error'),
                        style: const TextStyle(
                          color: AppColors.urgent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  List<Widget> _accounts() {
    final accounts = ref.watch(localDataMigrationProvider).pendingAccounts();
    if (accounts.isEmpty) {
      return const [
        Text('No quedan perfiles por transferir en este dispositivo.'),
      ];
    }
    return [
      for (final a in accounts)
        Card(
          child: ListTile(
            key: Key('migration-account-${a.uid}'),
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(a.displayName),
            subtitle: Text(
              '${a.maskedEmail} · ${a.pendingProfiles} '
              '${a.pendingProfiles == 1 ? 'perfil' : 'perfiles'}',
            ),
            trailing: const Icon(Icons.lock_outline_rounded),
            onTap: () => _unlock(a),
          ),
        ),
    ];
  }

  List<Widget> _childList() => [
    Text(
      'Perfiles de ${_account!.displayName}',
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
    ),
    const SizedBox(height: 8),
    for (final s in _children)
      Card(
        child: CheckboxListTile(
          key: Key('migration-child-${s.child.id}'),
          value: s.transferredTo != null || _selected.contains(s.child.id),
          onChanged: s.transferredTo != null
              ? null
              : (v) => setState(
                  () => v == true
                      ? _selected.add(s.child.id)
                      : _selected.remove(s.child.id),
                ),
          secondary: ChildAvatar(child: s.child, size: 44),
          title: Text(s.child.fullName),
          subtitle: Text(
            s.transferredTo != null
                ? 'Ya transferido'
                : '${s.favorites} favoritos · ${s.phrases} frases · '
                      '${s.customPictograms} pictogramas propios · '
                      '${s.history} en el historial',
          ),
        ),
      ),
    const SizedBox(height: 16),
    FilledButton.icon(
      key: const Key('migration-transfer'),
      onPressed: _busy || _selected.isEmpty ? null : _transfer,
      icon: _busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.drive_file_move_outline),
      label: Text(
        _selected.length == 1
            ? 'Transferir 1 perfil a mi cuenta'
            : 'Transferir ${_selected.length} perfiles a mi cuenta',
      ),
    ),
    TextButton(
      onPressed: _busy
          ? null
          : () => setState(() {
              _account = null;
              _password = null;
              _children = const [];
              _selected.clear();
            }),
      child: const Text('Elegir otra cuenta'),
    ),
  ];
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.account});

  final LocalAccountSummary account;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Contraseña de ${widget.account.displayName}'),
    content: TextField(
      key: const Key('migration-password'),
      controller: _controller,
      obscureText: true,
      autofocus: true,
      decoration: InputDecoration(
        labelText: 'Contraseña de ${widget.account.maskedEmail}',
      ),
      onSubmitted: (v) => Navigator.of(context).pop(v),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        key: const Key('migration-password-ok'),
        onPressed: () => Navigator.of(context).pop(_controller.text),
        child: const Text('Confirmar'),
      ),
    ],
  );
}
