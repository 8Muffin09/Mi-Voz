// Archivo de marcador de posición.
//
// Mi Voz funciona en modo demostración sin Firebase. Para activar el modo
// Firebase, genera este archivo con la configuración de TU proyecto:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=<tu-id-de-proyecto>
//
// FlutterFire reemplazará este archivo por uno con tus claves públicas de
// cliente. Consulta docs/FIREBASE_SETUP.md.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => throw UnsupportedError(
    'Firebase no está configurado. Ejecuta "flutterfire configure" '
    '(ver docs/FIREBASE_SETUP.md).',
  );
}
