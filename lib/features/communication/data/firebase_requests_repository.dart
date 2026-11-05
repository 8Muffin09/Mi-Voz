import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/communication_request.dart';
import 'requests_repository.dart';

/// Solicitudes en Firestore. La Cloud Function `notifyOnRequestCreated`
/// envía la notificación push y escribe el resultado en `notification`.
class FirebaseRequestsRepository implements RequestsRepository {
  FirebaseRequestsRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _col(String childId) =>
      _db.collection(FirestorePaths.childSub(childId, FirestorePaths.requests));

  CommunicationRequest _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) =>
      CommunicationRequest.fromMap(
        {...?d.data(), 'id': d.id},
        // Si la escritura aún no se confirma en el servidor, no está enviada.
        delivery: d.metadata.hasPendingWrites
            ? DeliveryStatus.pendingSync
            : DeliveryStatus.delivered,
      );

  @override
  Stream<List<CommunicationRequest>> watchChildRequests(String childId) =>
      _col(childId)
          .orderBy('createdAt', descending: true)
          .limit(500)
          .snapshots()
          .map((q) => q.docs.map(_fromDoc).toList());

  @override
  Stream<CommunicationRequest?> watchRequest(
    String childId,
    String requestId,
  ) =>
      _col(childId)
          .doc(requestId)
          .snapshots()
          .map((d) => d.exists ? _fromDoc(d) : null);

  @override
  Future<void> deliver(CommunicationRequest request) async {
    final ref = _col(request.childId).doc(request.id);
    try {
      // La transacción solo se completa con confirmación del servidor, por
      // lo que nunca marcamos "Enviada" sin que la solicitud haya llegado.
      // Si el documento ya existe (reintento), no se duplica.
      await _db.runTransaction<void>((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) return;
        tx.set(ref, {
          ...request.toCreateMap(),
          'serverReceivedAt': FieldValue.serverTimestamp(),
        });
      }, timeout: const Duration(seconds: 15));
    } on TimeoutException {
      throw const OfflineException();
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const OfflineException();
      }
      if (e.code == 'permission-denied') {
        throw const PermissionDeniedException(
          'Este dispositivo ya no tiene acceso a este perfil.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> updateStatus({
    required CommunicationRequest request,
    required RequestStatus status,
    required AppUser actor,
    String? note,
  }) async {
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'status': status.key,
      'statusUpdatedAt': now,
      'statusUpdatedByUid': actor.uid,
      'statusUpdatedByName': actor.displayName,
    };
    if (request.seenAt == null) data['seenAt'] = now;
    if (status.index >= RequestStatus.attending.index &&
        request.attendingAt == null) {
      data['attendingAt'] = now;
    }
    if (status == RequestStatus.resolved) data['resolvedAt'] = now;
    if (note != null && note.trim().isNotEmpty) data['note'] = note.trim();
    // Firestore guarda el cambio en la caché local al instante y lo envía al
    // volver la conexión, pero el Future solo termina con la confirmación del
    // servidor: sin conexión se avisa en lugar de quedarse esperando.
    try {
      await _col(request.childId)
          .doc(request.id)
          .update(data)
          .timeout(const Duration(seconds: 10));
    } on TimeoutException {
      throw const SavedOfflineException();
    }
  }
}
