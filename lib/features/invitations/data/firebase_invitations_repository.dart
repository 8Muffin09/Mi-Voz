// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/firestore_paths.dart';
import '../../../core/utils/app_exception.dart';
import '../../../models/app_user.dart';
import '../../../models/group_invitation.dart';
import 'invitations_repository.dart';

/// Invitaciones en Firestore **sin Cloud Functions** (funciona en el plan
/// gratuito Spark).
///
/// Cada operación es una transacción del cliente y las reglas de
/// `firebase/firestore.rules` hacen de servidor: solo quien administra el
/// grupo (con correo verificado) crea o revoca códigos; canjear suma
/// exactamente un uso y crea una única solicitud pendiente (id
/// `uid_grupo_niño`) en el mismo lote, sin pasar del límite, vencida ni
/// revocada; y solo el responsable del grupo, al aprobar, agrega a la persona
/// o vincula al niño. Por eso toda incorporación requiere aprobación.
///
/// Diferencia con la versión con funciones: no hay bloqueo tras códigos
/// incorrectos (las reglas no pueden contar intentos). Los códigos tienen 8
/// caracteres de un alfabeto de 31 (≈ 8,5 × 10¹¹ combinaciones) y solo
/// cuentas con correo verificado pueden consultarlos.
class FirebaseInvitationsRepository implements InvitationsRepository {
  FirebaseInvitationsRepository(
    this._db, {
    FirebaseAuth? auth,
    this.uid,
    Random? random,
  }) : _auth = auth,
       _random = random ?? Random.secure();

  final FirebaseFirestore _db;
  final FirebaseAuth? _auth;
  final Random _random;

  /// Cuenta con sesión (el proveedor recrea el repositorio al cambiarla).
  final String? uid;

  static const invitationsCollection = 'group_invitations';
  static const requestsCollection = 'join_requests';

  /// Una sola solicitud por persona, grupo y niño.
  static String requestId(String uid, String targetId, String? childId) =>
      '${uid}_${targetId}_${childId ?? 'adulto'}';

  DocumentReference<Map<String, dynamic>> _inv(String code) =>
      _db.collection(invitationsCollection).doc(code);

  DocumentReference<Map<String, dynamic>> _req(String id) =>
      _db.collection(requestsCollection).doc(id);

  String _requireUid() {
    final id = uid;
    if (id == null) throw const PermissionDeniedException();
    return id;
  }

  /// El correo verificado lo exigen las reglas; se comprueba antes para dar
  /// un mensaje claro en lugar de "permiso denegado".
  void _requireVerified() {
    final user = _auth?.currentUser;
    if (user != null && !user.emailVerified) {
      throw InvitationException(InvitationError.emailNotVerified);
    }
  }

  String _newCode() => [
    for (var i = 0; i < InvitationLink.codeLength; i++)
      InvitationLink.alphabet[_random.nextInt(InvitationLink.alphabet.length)],
  ].join();

  Future<String> _myName(String id) async {
    final snap = await _db.doc(FirestorePaths.user(id)).get();
    return (snap.data()?['displayName'] as String?) ?? 'Adulto';
  }

  /// Traduce los errores de Firestore sin convertirlos todos en "no existe".
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw const OfflineException(
        'Se necesita conexión para validar el código. Inténtalo cuando '
        'vuelva internet.',
      );
    } on FirebaseException catch (e) {
      switch (e.code) {
        case 'unavailable' || 'deadline-exceeded':
          throw const OfflineException(
            'Se necesita conexión para validar el código. Inténtalo cuando '
            'vuelva internet.',
          );
        case 'permission-denied':
          throw InvitationException(InvitationError.notAllowed);
        default:
          throw AppException(
            'No se pudo completar la operación. Inténtalo de nuevo.',
            code: e.code,
          );
      }
    }
  }

  @override
  Future<GroupInvitation> create({
    required InviteTargetType type,
    required String targetId,
    required Duration validity,
    required int maxUses,
    required bool requiresApproval,
    AdultRole? role,
  }) => _guard(() async {
    final me = _requireUid();
    _requireVerified();
    final target = await _db
        .doc(
          type == InviteTargetType.family
              ? FirestorePaths.family(targetId)
              : FirestorePaths.classroom(targetId),
        )
        .get();
    final data = target.data();
    if (data == null || data['ownerUid'] != me || data['archived'] == true) {
      throw InvitationException(InvitationError.notAllowed);
    }
    final name = await _myName(me);
    final hours = validity.inHours;
    // Código único: si (muy improbable) ya existe, se genera otro.
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      final ref = _inv(code);
      final created = await _db.runTransaction<bool>((tx) async {
        if ((await tx.get(ref)).exists) return false;
        tx.set(ref, {
          'code': code,
          'type': type.name,
          'targetId': targetId,
          'targetName': data['name'],
          'ownerUid': me,
          'createdBy': me,
          'createdByName': name,
          'createdAt': FieldValue.serverTimestamp(),
          'validityHours': hours,
          'maxUses': maxUses,
          'uses': 0,
          'revoked': false,
          // Sin servidor, el responsable aprueba siempre cada incorporación.
          'requiresApproval': true,
          'role': type == InviteTargetType.family
              ? (role ?? AdultRole.tutor).name
              : null,
          'lastRequestId': null,
        });
        return true;
      });
      if (created) {
        // Se devuelve lo que quedó confirmado en el servidor.
        final snap = await ref.get(const GetOptions(source: Source.server));
        return GroupInvitation.fromMap(snap.data()!);
      }
    }
    throw const AppException(
      'No se pudo generar un código. Inténtalo de nuevo.',
    );
  });

  @override
  Stream<List<GroupInvitation>> watchForTarget(
    InviteTargetType type,
    String targetId,
  ) {
    if (uid == null) return Stream.value(const []);
    // Las reglas solo dejan listar las invitaciones del responsable.
    return _db
        .collection(invitationsCollection)
        .where('ownerUid', isEqualTo: uid)
        .where('targetId', isEqualTo: targetId)
        .snapshots()
        .map(
          (q) =>
              q.docs
                  .map((d) => GroupInvitation.fromMap(d.data()))
                  .where((i) => i.type == type)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  @override
  Future<void> revoke(GroupInvitation invitation) =>
      _guard(() => _inv(invitation.code).update({'revoked': true}));

  /// Lee la invitación por su código exacto y comprueba su estado.
  Future<GroupInvitation> _activeInvitation(String raw) async {
    final code = InvitationLink.normalize(raw);
    if (!InvitationLink.isWellFormed(code)) {
      throw InvitationException(InvitationError.invalid);
    }
    final snap = await _inv(code).get(const GetOptions(source: Source.server));
    final data = snap.data();
    if (data == null) throw InvitationException(InvitationError.invalid);
    final inv = GroupInvitation.fromMap(data);
    switch (inv.status()) {
      case InvitationStatus.revoked:
        throw InvitationException(InvitationError.revoked);
      case InvitationStatus.exhausted:
        throw InvitationException(InvitationError.exhausted);
      case InvitationStatus.expired:
        throw InvitationException(InvitationError.expired);
      case InvitationStatus.active:
        return inv;
    }
  }

  @override
  Future<InvitationPreview> preview(String code) => _guard(() async {
    _requireUid();
    _requireVerified();
    final inv = await _activeInvitation(code);
    return InvitationPreview(
      code: inv.code,
      type: inv.type,
      targetName: inv.targetName,
      inviterName: inv.createdByName,
      requiresApproval: true,
      role: inv.role,
    );
  });

  @override
  Future<RedeemOutcome> redeem(String code, {String? childId}) => _guard(
    () async {
      final me = _requireUid();
      _requireVerified();
      final inv = await _activeInvitation(code);
      String? childName;
      final kidId = inv.type == InviteTargetType.classroom ? childId : null;
      if (inv.type == InviteTargetType.classroom) {
        if (kidId == null) {
          throw InvitationException(InvitationError.childRequired);
        }
        final child = (await _db.doc(FirestorePaths.child(kidId)).get()).data();
        if (child == null) {
          throw InvitationException(InvitationError.childNotAllowed);
        }
        final classIds = (child['classIds'] as List?) ?? const [];
        if (classIds.contains(inv.targetId)) {
          throw InvitationException(InvitationError.alreadyLinked);
        }
        childName = child['name'] as String?;
      }
      final name = await _myName(me);
      final reqId = requestId(me, inv.targetId, kidId);
      final invRef = _inv(inv.code);
      final reqRef = _req(reqId);
      await _db.runTransaction<void>((tx) async {
        final fresh = await tx.get(invRef);
        final existing = await tx.get(reqRef);
        final current = GroupInvitation.fromMap(fresh.data()!);
        switch (current.status()) {
          case InvitationStatus.revoked:
            throw InvitationException(InvitationError.revoked);
          case InvitationStatus.exhausted:
            throw InvitationException(InvitationError.exhausted);
          case InvitationStatus.expired:
            throw InvitationException(InvitationError.expired);
          case InvitationStatus.active:
        }
        final previous = existing.data()?['status'];
        if (previous == JoinRequestStatus.pending.name) {
          throw InvitationException(InvitationError.alreadyRequested);
        }
        if (previous == JoinRequestStatus.approved.name) {
          throw InvitationException(
            inv.type == InviteTargetType.family
                ? InvitationError.alreadyMember
                : InvitationError.alreadyLinked,
          );
        }
        tx.update(invRef, {'uses': current.uses + 1, 'lastRequestId': reqId});
        tx.set(reqRef, {
          'id': reqId,
          'code': inv.code,
          'type': inv.type.name,
          'targetId': inv.targetId,
          'targetName': inv.targetName,
          'requesterUid': me,
          'requesterName': name,
          'approverUid': fresh.data()!['ownerUid'],
          'childId': kidId,
          'childName': childName,
          'role': inv.role?.name,
          'status': JoinRequestStatus.pending.name,
          'createdAt': FieldValue.serverTimestamp(),
          'reviewedAt': null,
        });
      });
      return RedeemOutcome.pendingApproval;
    },
  );

  @override
  Stream<List<JoinRequest>> watchPendingForApprover(String uid) => _db
      .collection(requestsCollection)
      .where('approverUid', isEqualTo: uid)
      .where('status', isEqualTo: JoinRequestStatus.pending.name)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => JoinRequest.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
      );

  @override
  Stream<List<JoinRequest>> watchMyRequests(String uid) => _db
      .collection(requestsCollection)
      .where('requesterUid', isEqualTo: uid)
      .snapshots()
      .map(
        (q) =>
            q.docs.map((d) => JoinRequest.fromMap(d.data(), id: d.id)).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );

  /// Aprobar o rechazar. Al aprobar, el responsable hace la incorporación
  /// desde su dispositivo, en un solo lote que las reglas validan contra la
  /// solicitud aprobada.
  @override
  Future<void> review(JoinRequest request, {required bool approve}) =>
      _guard(() async {
        final me = _requireUid();
        _requireVerified();
        final reqRef = _req(request.id);
        final reviewed = {
          'status': approve
              ? JoinRequestStatus.approved.name
              : JoinRequestStatus.rejected.name,
          'reviewedAt': FieldValue.serverTimestamp(),
        };
        if (!approve) {
          await reqRef.update(reviewed);
          return;
        }
        if (request.type == InviteTargetType.family) {
          await _approveFamily(me, request, reqRef, reviewed);
        } else {
          await _approveClass(me, request, reqRef, reviewed);
        }
      });

  Future<void> _approveFamily(
    String me,
    JoinRequest request,
    DocumentReference<Map<String, dynamic>> reqRef,
    Map<String, dynamic> reviewed,
  ) async {
    final familyRef = _db.doc(FirestorePaths.family(request.targetId));
    // Niños de la familia (la consulta incluye memberUids para que las
    // reglas puedan comprobar el acceso).
    final kids = await _db
        .collection(FirestorePaths.children)
        .where('memberUids', arrayContains: me)
        .where('familyId', isEqualTo: request.targetId)
        .get();
    final requester = request.requesterUid;
    final role = (request.role ?? AdultRole.tutor).name;
    final batch = _db.batch()
      ..update(reqRef, reviewed)
      ..update(familyRef, {
        'adultUids': FieldValue.arrayUnion([requester]),
        'adultNames.$requester': request.requesterName,
        'adultRoles.$requester': role,
        'lastJoinRequest': request.id,
      });
    for (final kid in kids.docs) {
      batch
        ..update(kid.reference, {
          'memberUids': FieldValue.arrayUnion([requester]),
        })
        ..set(
          kid.reference
              .collection(FirestorePaths.caregiverLinks)
              .doc(requester),
          {
            'childId': kid.id,
            'adultUid': requester,
            'adultName': request.requesterName,
            'adultEmail': '',
            'role': role,
            'permission': 'caregiver',
            'source': 'family',
            'classIds': <String>[],
            'receivesRequests': true,
            'canViewPassport': true,
            'invitedByUid': me,
            'createdAt': FieldValue.serverTimestamp(),
          },
        );
    }
    await batch.commit();
  }

  Future<void> _approveClass(
    String me,
    JoinRequest request,
    DocumentReference<Map<String, dynamic>> reqRef,
    Map<String, dynamic> reviewed,
  ) async {
    final childId = request.childId;
    if (childId == null) throw InvitationException(InvitationError.notAllowed);
    final classRef = _db.doc(FirestorePaths.classroom(request.targetId));
    final childRef = _db.doc(FirestorePaths.child(childId));
    // Si la docente ya tenía acceso (el niño está en otra de sus clases),
    // solo se agrega la clase; si no, se agrega también a la lista de
    // acceso y se crea su vínculo.
    var alreadyMember = false;
    try {
      alreadyMember = (await childRef.get()).exists;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }
    final batch = _db.batch()
      ..update(reqRef, reviewed)
      ..update(classRef, {
        'studentIds': FieldValue.arrayUnion([childId]),
      });
    if (alreadyMember) {
      batch.update(childRef, {
        'classIds': FieldValue.arrayUnion([request.targetId]),
        'lastClassChange': request.targetId,
      });
      batch.update(childRef.collection(FirestorePaths.caregiverLinks).doc(me), {
        'classIds': FieldValue.arrayUnion([request.targetId]),
      });
    } else {
      final name = await _myName(me);
      batch
        ..update(childRef, {
          'classIds': FieldValue.arrayUnion([request.targetId]),
          'memberUids': FieldValue.arrayUnion([me]),
          'lastClassChange': request.targetId,
          'lastJoinRequest': request.id,
        })
        ..set(childRef.collection(FirestorePaths.caregiverLinks).doc(me), {
          'childId': childId,
          'adultUid': me,
          'adultName': name,
          'adultEmail': '',
          'role': 'docente',
          'permission': 'caregiver',
          'source': 'classroom',
          'classIds': [request.targetId],
          'receivesRequests': true,
          'canViewPassport': true,
          'invitedByUid': request.requesterUid,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
  }
}
