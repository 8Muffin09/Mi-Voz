import '../../../models/app_user.dart';
import '../../../models/communication_request.dart';

/// Solicitudes de comunicación del niño hacia sus adultos.
abstract class RequestsRepository {
  Stream<List<CommunicationRequest>> watchChildRequests(String childId);

  Stream<CommunicationRequest?> watchRequest(String childId, String requestId);

  /// Entrega idempotente al servidor. Si la solicitud ya existe no la
  /// duplica. Lanza [OfflineException] si no hay conexión.
  Future<void> deliver(CommunicationRequest request);

  /// Cambia el estado (solo hacia adelante) y lo deja en el historial.
  /// [support] registra el apoyo brindado (al resolver, por ejemplo).
  Future<void> updateStatus({
    required CommunicationRequest request,
    required RequestStatus status,
    required AppUser actor,
    String? note,
    String? support,
  });

  /// Apoyo brindado por el adulto (después de atender).
  Future<void> saveSupport({
    required CommunicationRequest request,
    required AppUser actor,
    required String support,
  });

  /// Valoración del alumno ("Me siento mejor", "igual", "peor" o sin
  /// respuesta). [actor] es la cuenta del adulto con la que funciona el
  /// dispositivo del niño.
  Future<void> setChildFeedback({
    required CommunicationRequest request,
    required AppUser actor,
    required SupportFeedback feedback,
  });

  /// Historial de cambios de una solicitud (más antiguo primero).
  Stream<List<RequestEvent>> watchEvents(String childId, String requestId);
}
