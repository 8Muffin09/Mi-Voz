import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Qué puede hacer la plataforma actual. Cada integración que depende del
/// sistema se consulta aquí y la app ofrece una alternativa cuando falta.
///
/// | Función                  | Android | iOS | Windows                         |
/// |--------------------------|---------|-----|---------------------------------|
/// | Notificaciones push (FCM)| Sí      | Sí  | No: avisos con la app abierta   |
/// | Escáner de QR            | Sí      | Sí  | No: se escribe el código        |
/// | Fotos                    | Galería | Galería | Selector de archivos        |
class PlatformCapabilities {
  const PlatformCapabilities._();

  static bool get _mobileOrMac =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  /// Firebase Cloud Messaging (firebase_messaging): Android, iOS y macOS.
  static bool get pushNotifications => _mobileOrMac;

  /// mobile_scanner: Android, iOS y macOS.
  static bool get qrScanner => _mobileOrMac;
}

/// Se sobrescribe en pruebas para simular otra plataforma.
final pushNotificationsSupportedProvider = Provider<bool>(
  (ref) => PlatformCapabilities.pushNotifications,
);
