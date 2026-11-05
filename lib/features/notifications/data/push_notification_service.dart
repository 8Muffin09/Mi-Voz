import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/firestore_paths.dart';

enum PushPermission { granted, denied, notDetermined, unsupported }

/// Registro del dispositivo en Firebase Cloud Messaging.
///
/// El cliente **solo** guarda su token en `notification_tokens/{token}`. El
/// envío lo hace la Cloud Function con credenciales de servidor; la app
/// nunca contiene claves privadas.
class PushNotificationService {
  PushNotificationService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  StreamSubscription<String>? _refreshSub;
  String? _token;

  Future<PushPermission> requestPermission() async {
    try {
      final settings = await _messaging.requestPermission();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };
    } catch (e) {
      debugPrint('FCM no disponible: $e');
      return PushPermission.unsupported;
    }
  }

  Future<PushPermission> currentPermission() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      return switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };
    } catch (_) {
      return PushPermission.unsupported;
    }
  }

  /// Guarda el token del dispositivo asociado al adulto.
  /// En modo niño, la función no envía avisos a este dispositivo.
  Future<PushPermission> registerDevice({
    required String uid,
    required String? childModeChildId,
  }) async {
    final permission = await requestPermission();
    if (permission != PushPermission.granted) return permission;
    try {
      // Se usan tokens de registro (compatibles con sendEachForMulticast del
      // Admin SDK en la Cloud Function) en lugar del nuevo registro por FID.
      // ignore: deprecated_member_use
      final token = await _messaging.getToken();
      if (token == null) return PushPermission.unsupported;
      _token = token;
      await _saveToken(token, uid, childModeChildId);
      await _refreshSub?.cancel();
      // ignore: deprecated_member_use
      _refreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        final old = _token;
        _token = newToken;
        if (old != null && old != newToken) await _deleteToken(old);
        await _saveToken(newToken, uid, childModeChildId);
      });
    } catch (e) {
      debugPrint('No se pudo registrar el token FCM: $e');
      return PushPermission.unsupported;
    }
    return permission;
  }

  Future<void> _saveToken(String token, String uid, String? childId) =>
      _db.collection(FirestorePaths.notificationTokens).doc(token).set({
        'uid': uid,
        'platform': defaultTargetPlatform.name,
        'childMode': childId != null,
        'childId': childId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> _deleteToken(String token) async {
    try {
      await _db
          .collection(FirestorePaths.notificationTokens)
          .doc(token)
          .delete();
    } catch (_) {
      // Sin conexión o el documento ya no existe.
    }
  }

  /// Al cerrar sesión: este dispositivo deja de recibir avisos del adulto.
  Future<void> unregister() async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    final token =
        _token ??
        // ignore: deprecated_member_use
        await _messaging.getToken().catchError((_) => null);
    if (token != null) await _deleteToken(token);
    _token = null;
  }

  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  Stream<RemoteMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp;

  Future<RemoteMessage?> initialMessage() => _messaging.getInitialMessage();

  void dispose() {
    _refreshSub?.cancel();
  }
}
