import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/child_profile.dart';
import '../../../models/communication_request.dart';
import '../../pictograms/domain/phrase_builder.dart';
import 'outbox.dart';

/// Crea solicitudes a partir de las frases del niño y gestiona sus estados.
class CommunicationService {
  CommunicationService(this._ref);

  final Ref _ref;

  static const urgentCategoryTitle = 'AYUDA URGENTE';
  static const frequentCategoryTitle = 'FRASE FRECUENTE';

  /// Construye la solicitud (sin enviarla). Útil también para pruebas.
  static CommunicationRequest buildRequest({
    required ChildProfile child,
    required PhraseDraft draft,
    required String senderUid,
    DateTime? now,
    String? id,
  }) {
    final message = PhraseBuilder.build(draft, gender: child.gender);
    return CommunicationRequest(
      id: id ?? newId(),
      childId: child.id,
      childName: child.name,
      categoryId: draft.categoryId,
      categoryTitle: draft.urgent
          ? urgentCategoryTitle
          : draft.category?.title ?? frequentCategoryTitle,
      message: message,
      emoji: draft.emoji,
      pictogramIds: draft.items.map((p) => p.id).toList(),
      priority: draft.urgent ? RequestPriority.high : RequestPriority.normal,
      isUrgent: draft.urgent,
      recipientUid: RecipientResolver.recipientUid(child),
      recipientName: RecipientResolver.recipientName(child),
      createdByUid: senderUid,
      createdAt: now ?? DateTime.now(),
    );
  }

  /// "COMUNICAR": registra la solicitud y la entrega (o la deja pendiente).
  Future<CommunicationRequest> send({
    required ChildProfile child,
    required PhraseDraft draft,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw const AppException('La sesión no está disponible.');
    if (!Permissions.canCreateRequest(child, user.uid)) {
      throw const PermissionDeniedException();
    }
    final request = buildRequest(
      child: child,
      draft: draft,
      senderUid: user.uid,
    );
    return _ref.read(outboxProvider.notifier).submit(request);
  }

  Future<void> updateStatus(
    CommunicationRequest request,
    RequestStatus status, {
    String? note,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw const AppException('La sesión no está disponible.');
    if (request.delivery == DeliveryStatus.pendingSync) {
      throw const AppException(
        'Esta solicitud aún no llega al servidor (pendiente de envío).',
      );
    }
    await _ref
        .read(requestsRepositoryProvider)
        .updateStatus(
          request: request,
          status: status,
          actor: user,
          note: note,
        );
  }
}

final communicationServiceProvider = Provider<CommunicationService>(
  CommunicationService.new,
);
