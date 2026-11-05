import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../models/group_invitation.dart';

typedef InviteTarget = ({InviteTargetType type, String targetId});

/// Invitaciones de un grupo (solo las ve su responsable).
final invitationsForTargetProvider =
    StreamProvider.family<List<GroupInvitation>, InviteTarget>((ref, target) {
      ref.watch(sessionUidProvider);
      return ref
          .watch(invitationsRepositoryProvider)
          .watchForTarget(target.type, target.targetId);
    });

/// Solicitudes de incorporación que la cuenta actual debe aprobar.
final pendingApprovalsProvider = StreamProvider<List<JoinRequest>>((ref) {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(invitationsRepositoryProvider).watchPendingForApprover(uid);
});

/// Solicitudes enviadas por la cuenta actual.
final myJoinRequestsProvider = StreamProvider<List<JoinRequest>>((ref) {
  final uid = ref.watch(sessionUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(invitationsRepositoryProvider).watchMyRequests(uid);
});

/// El escáner de QR (mobile_scanner) existe en Android, iOS y macOS. En
/// Windows y en la web se escribe el código.
final qrScannerAvailableProvider = Provider<bool>(
  (ref) => PlatformCapabilities.qrScanner,
);
