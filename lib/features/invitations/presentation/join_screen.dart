import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/child_avatar.dart';
import '../../../models/child_profile.dart';
import '../../../models/group_invitation.dart';
import '../../adult/presentation/widgets/section_header.dart';
import '../../families/application/families_providers.dart';
import '../../profiles/application/profiles_providers.dart';
import '../application/invitations_providers.dart';
import 'scan_invitation_screen.dart';

/// "Tengo un código": escribir o escanear el código, ver a qué clase o
/// familia corresponde, elegir el niño (en una clase) y confirmar. La
/// validación y el registro del vínculo los hace el servidor; sin conexión
/// no se puede validar.
class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  late final _code = TextEditingController(text: widget.initialCode ?? '');
  InvitationPreview? _preview;
  String? _childId;
  bool _loading = false;
  String? _error;
  String? _result;

  @override
  void initState() {
    super.initState();
    if ((widget.initialCode ?? '').isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanInvitationScreen()),
    );
    if (code == null || !mounted) return;
    _code.text = code;
    await _check();
  }

  Future<void> _check() async {
    final code = InvitationLink.parse(_code.text);
    if (code == null) {
      setState(() {
        _error = 'El código tiene 8 letras o números.';
        _preview = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _preview = null;
      _childId = null;
    });
    try {
      final preview = await ref
          .read(invitationsRepositoryProvider)
          .preview(code);
      if (mounted) setState(() => _preview = preview);
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    if (preview == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(invitationsRepositoryProvider)
          .redeem(preview.code, childId: _childId);
      ref.invalidate(childrenProvider);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _code.clear();
        _result = switch ((outcome, preview.type)) {
          (RedeemOutcome.pendingApproval, _) =>
            'Solicitud enviada. ${preview.inviterName} debe aprobarla; te '
                'avisaremos aquí cuando lo haga.',
          (RedeemOutcome.joined, InviteTargetType.family) =>
            'Listo: ya formas parte de ${preview.targetName}.',
          (RedeemOutcome.joined, InviteTargetType.classroom) =>
            'Listo: el niño quedó vinculado con ${preview.targetName}.',
        };
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(qrScannerAvailableProvider);
    final preview = _preview;
    final requests = ref.watch(myJoinRequestsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Tengo un código')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Escribe o escanea el código que te compartió el docente o la '
            'familia. Se necesita conexión para validarlo.',
            style: TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('join-code'),
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              letterSpacing: 6,
              fontWeight: FontWeight.w700,
            ),
            decoration: const InputDecoration(
              labelText: 'Código de 8 caracteres',
              counterText: '',
            ),
            onSubmitted: (_) => _check(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  key: const Key('join-check'),
                  onPressed: _loading ? null : _check,
                  child: Text(
                    _loading && preview == null ? 'Comprobando…' : 'Comprobar',
                  ),
                ),
              ),
              if (scanner) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  key: const Key('join-scan'),
                  onPressed: _loading ? null : _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Escanear QR'),
                ),
              ],
            ],
          ),
          if (!scanner)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'En este dispositivo no hay escáner: escribe el código.',
                style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _error!,
                key: const Key('join-error'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.urgent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (_result != null)
            Card(
              key: const Key('join-result'),
              color: AppColors.success.withValues(alpha: 0.1),
              margin: const EdgeInsets.only(top: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_result!, style: const TextStyle(fontSize: 16)),
              ),
            ),
          if (preview != null) ...[
            const SizedBox(height: 16),
            _PreviewCard(preview: preview),
            if (preview.type == InviteTargetType.classroom)
              _ChildPicker(
                selected: _childId,
                onChanged: (id) => setState(() => _childId = id),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('join-confirm'),
              onPressed:
                  _loading ||
                      (preview.type == InviteTargetType.classroom &&
                          _childId == null)
                  ? null
                  : _confirm,
              child: Text(
                preview.requiresApproval ? 'Enviar solicitud' : 'Confirmar',
              ),
            ),
          ],
          if (requests.isNotEmpty) ...[
            const SectionHeader('Mis solicitudes'),
            for (final r in requests.take(10))
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  key: Key('my-request-${r.id}'),
                  leading: Icon(switch (r.status) {
                    JoinRequestStatus.pending => Icons.hourglass_top_rounded,
                    JoinRequestStatus.approved => Icons.check_circle_outline,
                    JoinRequestStatus.rejected => Icons.cancel_outlined,
                  }),
                  title: Text(
                    r.childName == null
                        ? r.targetName
                        : '${r.childName} → ${r.targetName}',
                  ),
                  subtitle: Text(
                    '${r.status.label} · ${formatDateTime(r.createdAt)}',
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final InvitationPreview preview;

  @override
  Widget build(BuildContext context) {
    final classroom = preview.type == InviteTargetType.classroom;
    return Card(
      key: const Key('join-preview'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              classroom ? 'Clase' : 'Familia',
              style: const TextStyle(color: AppColors.inkSoft),
            ),
            Text(
              preview.targetName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            Text('Invitación de ${preview.inviterName}'),
            const SizedBox(height: 8),
            Text(
              classroom
                  ? 'Elige qué niño de tu familia quieres vincular. El docente '
                        'verá su información y podrá recibir sus solicitudes.'
                  : 'Verás a los niños de esta familia'
                        '${preview.role == null ? '' : ' como ${preview.role!.label.toLowerCase()}'}.',
            ),
            if (preview.requiresApproval)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Necesita la aprobación del responsable.',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Niños de las familias del adulto (solo estos se pueden vincular).
class _ChildPicker extends ConsumerWidget {
  const _ChildPicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(sessionUidProvider);
    final familyIds = {
      for (final f in ref.watch(familiesProvider).value ?? const [])
        if (f.isAdult(uid)) f.id,
    };
    final children =
        (ref.watch(childrenProvider).value ?? const <ChildProfile>[])
            .where(
              (c) => c.familyId == null
                  ? c.ownerUid == uid
                  : familyIds.contains(c.familyId),
            )
            .toList();
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            const Text(
              'Para vincular a un niño con una clase, primero crea su perfil en '
              'tu familia.',
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: () => context.push(Routes.kidNew),
              child: const Text('Crear perfil infantil'),
            ),
          ],
        ),
      );
    }
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: onChanged,
      child: Column(
        children: [
          for (final c in children)
            RadioListTile<String>(
              key: Key('join-child-${c.id}'),
              value: c.id,
              secondary: ChildAvatar(child: c, size: 40),
              title: Text(c.name),
            ),
        ],
      ),
    );
  }
}
