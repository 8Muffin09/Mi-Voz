import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/dialogs.dart';
import '../../../models/app_user.dart';
import '../../../models/group_invitation.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../application/invitations_providers.dart';
import '../../../core/theme/ui_icons.dart';

/// Opciones de una invitación nueva.
class _InviteOptions {
  const _InviteOptions(
    this.validity,
    this.maxUses,
    this.requiresApproval,
    this.role,
  );

  final Duration validity;
  final int maxUses;
  final bool requiresApproval;
  final AdultRole? role;
}

/// Crea una invitación (validada por el servidor) y la muestra para compartir.
Future<void> createAndShareInvitation(
  BuildContext context,
  WidgetRef ref, {
  required InviteTargetType type,
  required String targetId,
}) async {
  final user = ref.read(currentUserProvider);
  if (user != null && !user.emailVerified) {
    showMessage(
      context,
      'Verifica tu correo antes de generar códigos de invitación.',
      error: true,
    );
    return;
  }
  final options = await showModalBottomSheet<_InviteOptions>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CreateInvitationSheet(type: type),
  );
  if (options == null || !context.mounted) return;
  try {
    final invitation = await ref
        .read(invitationsRepositoryProvider)
        .create(
          type: type,
          targetId: targetId,
          validity: options.validity,
          maxUses: options.maxUses,
          requiresApproval: options.requiresApproval,
          role: options.role,
        );
    if (context.mounted) await showInvitationShare(context, ref, invitation);
  } catch (e) {
    if (context.mounted) showMessage(context, describeError(e), error: true);
  }
}

class _CreateInvitationSheet extends StatefulWidget {
  const _CreateInvitationSheet({required this.type});

  final InviteTargetType type;

  @override
  State<_CreateInvitationSheet> createState() => _CreateInvitationSheetState();
}

class _CreateInvitationSheetState extends State<_CreateInvitationSheet> {
  Duration _validity = GroupInvitation.allowedValidity.first;
  late int _maxUses = widget.type == InviteTargetType.family ? 1 : 30;
  bool _approval = true;
  AdultRole _role = AdultRole.tutor;

  bool get _family => widget.type == InviteTargetType.family;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _family ? 'Invitar a un adulto responsable' : 'Invitar familias',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _family
                ? 'La persona que use el código verá a todos los niños de la '
                      'familia.'
                : 'Cada familia elige con el código cuál de sus niños vincula '
                      'con esta clase.',
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          if (_family) ...[
            const SizedBox(height: 14),
            const Text('Rol', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 8,
              children: [
                for (final r in [...AdultRole.familyRoles, AdultRole.cuidador])
                  ChoiceChip(
                    key: Key('invite-role-${r.name}'),
                    avatar: Icon(r.icon, size: 18),
                    label: Text(r.label),
                    selected: _role == r,
                    onSelected: (_) => setState(() => _role = r),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          const Text('Vigencia', style: TextStyle(fontWeight: FontWeight.w700)),
          Wrap(
            spacing: 8,
            children: [
              for (final v in GroupInvitation.allowedValidity)
                ChoiceChip(
                  label: Text(v.inHours == 48 ? '48 horas' : '7 días'),
                  selected: _validity == v,
                  onSelected: (_) => setState(() => _validity = v),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Cuántas veces se puede usar',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final n in GroupInvitation.allowedMaxUses)
                ChoiceChip(
                  key: Key('invite-uses-$n'),
                  label: Text(n == 1 ? 'Una vez' : '$n veces'),
                  selected: _maxUses == n,
                  onSelected: (_) => setState(() => _maxUses = n),
                ),
            ],
          ),
          SwitchListTile(
            key: const Key('invite-approval'),
            contentPadding: EdgeInsets.zero,
            value: _approval,
            onChanged: (v) => setState(() => _approval = v),
            title: const Text('Aprobar cada solicitud'),
            subtitle: const Text(
              'Recomendado: nadie se incorpora hasta que tú lo apruebes.',
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('invite-create'),
            onPressed: () => Navigator.of(context).pop(
              _InviteOptions(
                _validity,
                _maxUses,
                _approval,
                _family ? _role : null,
              ),
            ),
            child: const Text('Generar código'),
          ),
        ],
      ),
    ),
  );
}

/// Código grande, QR (solo el código: sin datos del niño) y opción de copiar.
Future<void> showInvitationShare(
  BuildContext context,
  WidgetRef ref,
  GroupInvitation invitation,
) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Código para ${invitation.targetName}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('invitation-qr'),
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            // Tamaño fijo: AlertDialog mide el contenido con dimensiones
            // intrínsecas y QrImageView usa un LayoutBuilder, que no las da.
            child: SizedBox.square(
              dimension: 200,
              child: QrImageView(
                data: invitation.link,
                size: 200,
                semanticsLabel: 'Código QR de la invitación',
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            invitation.code,
            key: const Key('invitation-code'),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Válido hasta ${formatDateTime(invitation.expiresAt)} · '
            '${invitation.maxUses == 1 ? 'un solo uso' : '${invitation.maxUses} usos'}'
            '${invitation.requiresApproval ? ' · requiere tu aprobación' : ''}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 8),
          const Text(
            'Se escribe o se escanea en Mi Voz con "Tengo un código". El QR '
            'no sirve para iniciar sesión.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    ),
    actions: [
      TextButton.icon(
        onPressed: () {
          Clipboard.setData(
            ClipboardData(
              text:
                  'Te invito a "${invitation.targetName}" en Mi Voz. '
                  'Código: ${invitation.code}',
            ),
          );
          showMessage(context, 'Mensaje copiado.');
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copiar'),
      ),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Listo'),
      ),
    ],
  ),
);

/// "Invitaciones" de una familia o clase: generar, ver, revocar y aprobar.
class InvitationsSection extends ConsumerWidget {
  const InvitationsSection({
    super.key,
    required this.type,
    required this.targetId,
  });

  final InviteTargetType type;
  final String targetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitations =
        ref
            .watch(
              invitationsForTargetProvider((type: type, targetId: targetId)),
            )
            .value ??
        const <GroupInvitation>[];
    final pending = (ref.watch(pendingApprovalsProvider).value ?? const [])
        .where((r) => r.targetId == targetId)
        .toList();
    final now = DateTime.now();
    final active = invitations.where((i) => i.isActive(now)).toList();
    final inactive = invitations.where((i) => !i.isActive(now)).take(3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (pending.isNotEmpty) ...[
          SectionHeader(
            'Solicitudes de incorporación',
            subtitle: '${pending.length} pendiente(s) de tu aprobación',
          ),
          JoinRequestsList(requests: pending),
        ],
        SectionHeader(
          'Invitaciones',
          subtitle:
              'Códigos con caducidad y límite de usos. Puedes revocarlos.',
          action: TextButton.icon(
            key: const Key('create-invitation'),
            onPressed: () => createAndShareInvitation(
              context,
              ref,
              type: type,
              targetId: targetId,
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            label: const Text('Invitar'),
          ),
        ),
        if (invitations.isEmpty)
          const Text(
            'Aún no has generado códigos.',
            style: TextStyle(color: AppColors.inkSoft),
          ),
        for (final inv in [...active, ...inactive])
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              key: Key('invitation-${inv.code}'),
              leading: Icon(
                inv.isActive(now)
                    ? Icons.vpn_key_outlined
                    : Icons.key_off_outlined,
                color: inv.isActive(now)
                    ? AppColors.primary
                    : AppColors.inkSoft,
              ),
              title: Text(
                inv.code,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              subtitle: Text(
                '${inv.status(now).label} · ${inv.uses}/${inv.maxUses} usos · '
                'vence ${formatDateTime(inv.expiresAt)}',
              ),
              onTap: inv.isActive(now)
                  ? () => showInvitationShare(context, ref, inv)
                  : null,
              trailing: inv.isActive(now)
                  ? IconButton(
                      key: Key('revoke-${inv.code}'),
                      tooltip: 'Revocar',
                      icon: const Icon(Icons.block, color: AppColors.urgent),
                      onPressed: () => _revoke(context, ref, inv),
                    )
                  : null,
            ),
          ),
      ],
    );
  }

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    GroupInvitation invitation,
  ) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Revocar ${invitation.code}',
      message:
          'El código dejará de funcionar. Las incorporaciones ya hechas '
          'no cambian.',
      confirmLabel: 'Revocar',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    await runGuarded(
      context,
      () => ref.read(invitationsRepositoryProvider).revoke(invitation),
      success: 'Código revocado.',
    );
  }
}

/// Solicitudes pendientes con "Aprobar" y "Rechazar".
class JoinRequestsList extends ConsumerWidget {
  const JoinRequestsList({super.key, required this.requests});

  final List<JoinRequest> requests;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      for (final r in requests)
        Card(
          key: Key('join-request-${r.id}'),
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  r.type == InviteTargetType.classroom
                      ? '${r.requesterName} quiere vincular a '
                            '${r.childName ?? 'un niño'} con ${r.targetName}'
                      : '${r.requesterName} quiere unirse a ${r.targetName}'
                            '${r.role == null ? '' : ' como ${r.role!.label.toLowerCase()}'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Solicitado ${formatDateTime(r.createdAt)} con el código ${r.code}',
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton(
                      key: Key('reject-${r.id}'),
                      onPressed: () => _review(context, ref, r, false),
                      child: const Text('Rechazar'),
                    ),
                    FilledButton(
                      key: Key('approve-${r.id}'),
                      onPressed: () => _review(context, ref, r, true),
                      child: const Text('Aprobar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ],
  );

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    JoinRequest request,
    bool approve,
  ) => runGuarded(
    context,
    () => ref
        .read(invitationsRepositoryProvider)
        .review(request, approve: approve),
    success: approve ? 'Solicitud aprobada.' : 'Solicitud rechazada.',
  );
}

/// Aviso en el panel cuando hay solicitudes por aprobar.
class PendingApprovalsCard extends ConsumerWidget {
  const PendingApprovalsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingApprovalsProvider).value ?? const [];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          'Solicitudes de incorporación',
          subtitle: '${pending.length} pendiente(s) de tu aprobación',
        ),
        JoinRequestsList(requests: pending),
      ],
    );
  }
}
