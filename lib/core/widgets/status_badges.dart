import 'package:flutter/material.dart';

import '../../models/communication_request.dart';
import '../theme/app_theme.dart';

class Pill extends StatelessWidget {
  const Pill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.foreground,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? _darken(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _darken(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * 0.55).clamp(0.0, 1.0)).toColor();
  }
}

Color statusColor(RequestStatus s) => switch (s) {
  RequestStatus.newRequest => AppColors.urgent,
  RequestStatus.seen => AppColors.primary,
  RequestStatus.attending => AppColors.warning,
  RequestStatus.resolved => AppColors.success,
};

IconData statusIcon(RequestStatus s) => switch (s) {
  RequestStatus.newRequest => Icons.fiber_new_rounded,
  RequestStatus.seen => Icons.visibility_rounded,
  RequestStatus.attending => Icons.directions_run_rounded,
  RequestStatus.resolved => Icons.check_circle_rounded,
};

class RequestStatusPill extends StatelessWidget {
  const RequestStatusPill(this.status, {super.key});

  final RequestStatus status;

  @override
  Widget build(BuildContext context) => Pill(
    label: status.label,
    color: statusColor(status),
    icon: statusIcon(status),
  );
}

class PriorityPill extends StatelessWidget {
  const PriorityPill(this.request, {super.key});

  final CommunicationRequest request;

  @override
  Widget build(BuildContext context) => request.priority == RequestPriority.high
      ? const Pill(
          label: 'Prioridad alta',
          color: AppColors.urgent,
          icon: Icons.priority_high_rounded,
        )
      : const Pill(label: 'Prioridad normal', color: AppColors.inkSoft);
}

/// Entrega al servidor: "Pendiente de envío" o "Enviada".
class DeliveryPill extends StatelessWidget {
  const DeliveryPill(this.request, {super.key});

  final CommunicationRequest request;

  @override
  Widget build(BuildContext context) =>
      request.delivery == DeliveryStatus.pendingSync
      ? const Pill(
          label: 'Pendiente de envío',
          color: AppColors.warning,
          icon: Icons.cloud_off_rounded,
        )
      : const Pill(
          label: 'Enviada',
          color: AppColors.success,
          icon: Icons.cloud_done_rounded,
        );
}

/// Resultado de la notificación push (distinto de "vista" o "atendida").
class NotificationPill extends StatelessWidget {
  const NotificationPill(this.request, {super.key});

  final CommunicationRequest request;

  @override
  Widget build(BuildContext context) {
    if (request.delivery == DeliveryStatus.pendingSync) {
      return const SizedBox.shrink();
    }
    final (color, icon) = switch (request.notification) {
      NotificationStatus.pending => (AppColors.inkSoft, Icons.schedule_rounded),
      NotificationStatus.sent => (
        AppColors.success,
        Icons.notifications_active_rounded,
      ),
      NotificationStatus.simulated => (
        AppColors.primary,
        Icons.science_rounded,
      ),
      NotificationStatus.noRecipients => (
        AppColors.urgent,
        Icons.person_off_rounded,
      ),
      NotificationStatus.noDevices => (
        AppColors.warning,
        Icons.phonelink_off_rounded,
      ),
      NotificationStatus.failed => (
        AppColors.urgent,
        Icons.error_outline_rounded,
      ),
    };
    return Pill(label: request.notification.label, color: color, icon: icon);
  }
}
