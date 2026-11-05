import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/status_badges.dart';
import '../../../../models/communication_request.dart';
import '../../../../core/widgets/visuals.dart';

/// Fila de solicitud para bandejas e historial.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request, this.showChild = true});

  final CommunicationRequest request;
  final bool showChild;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final urgentOpen = r.isUrgent && r.status.isOpen;
    return Card(
      color: urgentOpen ? AppColors.urgentSoft : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: () => context.push(Routes.requestDetail(r.childId, r.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SymbolImage(r.emoji, size: 36),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            showChild ? r.childName : r.categoryTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Con texto ampliado la fecha pasa a otra línea en
                        // lugar de salirse de la tarjeta.
                        Flexible(
                          child: Text(
                            formatRelative(r.createdAt),
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.message,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        RequestStatusPill(r.status),
                        if (r.priority == RequestPriority.high) PriorityPill(r),
                        if (r.delivery == DeliveryStatus.pendingSync)
                          DeliveryPill(r),
                        Pill(
                          label: 'Para: ${r.recipientLabel}',
                          color: AppColors.inkSoft,
                          icon: Icons.person_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
