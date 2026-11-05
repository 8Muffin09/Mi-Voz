import '../../../models/app_user.dart';
import '../../../models/communication_request.dart';

/// Solicitudes de comunicación del niño hacia sus adultos.
abstract class RequestsRepository {
  Stream<List<CommunicationRequest>> watchChildRequests(String childId);

  Stream<CommunicationRequest?> watchRequest(String childId, String requestId);

  /// Entrega idempotente al servidor. Si la solicitud ya existe no la
  /// duplica. Lanza [OfflineException] si no hay conexión.
  Future<void> deliver(CommunicationRequest request);

  Future<void> updateStatus({
    required CommunicationRequest request,
    required RequestStatus status,
    required AppUser actor,
    String? note,
  });
}
