import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/permissions/permissions.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/utils/id_generator.dart';
import '../../../models/app_user.dart';
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

  /// Un segundo toque con la misma frase dentro de este intervalo devuelve
  /// la solicitud ya creada en lugar de crear otra.
  static const doubleTapWindow = Duration(seconds: 8);

  CommunicationRequest? _last;
  Future<CommunicationRequest>? _inFlight;

  /// "COMUNICAR": registra la solicitud y la entrega (o la deja pendiente).
  /// El identificador se crea aquí, una sola vez: los reintentos de la cola
  /// usan el mismo y el servidor nunca duplica.
  Future<CommunicationRequest> send({
    required ChildProfile child,
    required PhraseDraft draft,
    DateTime? now,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw const AppException('La sesión no está disponible.');
    if (!Permissions.canCreateRequest(child, user.uid)) {
      throw const PermissionDeniedException();
    }
    final at = now ?? DateTime.now();
    final message = PhraseBuilder.build(draft, gender: child.gender);
    final last = _last;
    if (last != null &&
        last.childId == child.id &&
        last.createdByUid == user.uid &&
        last.message == message &&
        at.difference(last.createdAt) < doubleTapWindow) {
      return _inFlight ?? Future.value(last);
    }
    final request = buildRequest(
      child: child,
      draft: draft,
      senderUid: user.uid,
      now: at,
    );
    _last = request;
    final future = _ref.read(outboxProvider.notifier).submit(request);
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<void> updateStatus(
    CommunicationRequest request,
    RequestStatus status, {
    String? note,
    String? support,
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
          support: support,
        );
  }

  /// Apoyo brindado por el adulto (su observación, no la del alumno).
  Future<void> saveSupport(CommunicationRequest request, String support) {
    final user = _requireUser();
    return _ref
        .read(requestsRepositoryProvider)
        .saveSupport(request: request, actor: user, support: support);
  }

  /// Cómo dice sentirse el alumno. Opcional: nunca bloquea la app.
  Future<void> setChildFeedback(
    CommunicationRequest request,
    SupportFeedback feedback,
  ) {
    final user = _requireUser();
    return _ref
        .read(requestsRepositoryProvider)
        .setChildFeedback(request: request, actor: user, feedback: feedback);
  }

  AppUser _requireUser() {
    final user = _ref.read(currentUserProvider);
    if (user == null) throw const AppException('La sesión no está disponible.');
    return user;
  }
}

final communicationServiceProvider = Provider<CommunicationService>(
  CommunicationService.new,
);
