# Compatibilidad por plataforma

Estado al 28 de octubre de 2026. "Probado" significa ejecutado en este
proyecto; "Sin probar" significa que el código existe pero no se pudo
compilar o ejecutar en el entorno de desarrollo.

| | Android | iOS | Windows |
|---|---|---|---|
| **Estado general** | Probado en emulador (debug y release) | Sin probar: requiere Mac con Xcode | Sin probar: falta Visual Studio con C++ |
| Sin nube configurada (cuentas solo en el dispositivo) | Probado | Sin probar | Sin probar |
| Cuentas y datos (Firebase Auth, Firestore, Storage) | Código listo, sin proyecto Firebase para probar | Ídem | **No apto para producción según Firebase** (ver abajo) |
| Invitaciones (Cloud Functions) | Ídem | Ídem | `cloud_functions` en Windows: por verificar al compilar |
| Texto a voz (`flutter_tts`) | Probado | Voces del sistema | Voces de Windows (SAPI) |
| Escanear QR (`mobile_scanner`) | Sí, permiso de cámara al abrir el escáner | Sí (texto de permiso incluido) | **No existe**: se escribe el código |
| Notificaciones push (FCM) | Sí, canales normal y urgente | Requiere clave APNs y cuenta de Apple | **No existe**: avisos dentro de la app mientras está abierta |
| Fotos (`image_picker`) | Galería | Fototeca (texto de permiso incluido) | Selector de archivos |
| Sonido de bienvenida (`audioplayers`) | Probado | Sí | Sí |
| Conexión (`connectivity_plus`) | Probado | Sí | Sí |
| Datos locales y PIN | `shared_preferences` (PIN con sal y hash iterado, nunca en texto) | Ídem | Ídem (archivo en la carpeta del usuario) |

## Alternativas cuando falta una función

Las integraciones que dependen del sistema se consultan en
`lib/core/platform/platform_capabilities.dart`:

- **Sin escáner** (Windows): "Tengo un código" muestra solo el campo de
  texto y lo explica.
- **Sin notificaciones push** (Windows): `requestWatcherProvider` observa
  las solicitudes mientras la app está abierta y muestra el aviso a los
  mismos adultos que elegiría la Cloud Function. **Con la app cerrada no
  llega nada**; un adulto que solo use Windows debe saberlo.
- **Sin nube configurada**: la app funciona con cuentas en el dispositivo;
  ya no hay pantalla de "Modalidad" (es un detalle interno).

## Pantallas grandes

En pantallas de 900 px o más, el panel del adulto usa navegación lateral
(`NavigationRail`) en lugar de la barra inferior. El tutorial pone la
instrucción y la simulación lado a lado desde 760 px. Hay atajos de teclado en
el tutorial (← → Esc). Pendiente de revisar en una ventana real de Windows:
foco con Tab en todas las pantallas, ratón y cambio de tamaño de ventana.

## Permisos de Android (APK de release)

| Permiso | Quién lo pide | Cuándo |
|---|---|---|
| `CAMERA` | Escáner de QR | Solo al abrir el escáner (opcional) |
| `POST_NOTIFICATIONS` | Notificaciones | Android 13+, al iniciar sesión en modo Firebase |
| `INTERNET`, `ACCESS_NETWORK_STATE` | Sincronización | Automático |
| `VIBRATE`, `WAKE_LOCK`, `c2dm.RECEIVE`, `READ_GSERVICES` | Firebase Messaging y vibración | Automático (no peligrosos) |

No se piden ubicación, contactos, micrófono ni almacenamiento.

## Windows y la nube: decisión pendiente

La documentación oficial de FlutterFire (consultada el 28/10/2026,
<https://firebase.google.com/docs/flutter/setup>) dice: *"Firebase on Windows
is not intended for production use cases, only local development
workflows."*

Estado actual (no se eliminó Windows):

- Windows compila con los mismos plugins y sirve para **desarrollo y
  pruebas**; todo lo esencial (pictogramas, frases, favoritos, voz) funciona
  sin conexión.
- **No publiques la versión de Windows con sincronización** hasta resolver
  lo siguiente.

Propuesta justificada para producción en Windows (no implementada):
un `CloudGateway` que en Windows use las **API REST oficiales** —Identity
Toolkit (`accounts:signUp`, `signInWithPassword`, `sendOobCode`,
`securetoken` para renovar), Firestore REST (`documents`, `runQuery`,
`commit`) y Storage JSON API— con el token del usuario, de modo que las
mismas reglas de seguridad protejan los datos. Las escuchas en tiempo real
se sustituirían por consultas periódicas (p. ej. cada 20 s con la app
abierta). Implica reescribir los 9 repositorios `firebase_*` sobre esa
interfaz: estimación 2–3 etapas de trabajo. Alternativa: publicar Windows
solo con cuentas locales.

## Probado en esta etapa

- `flutter analyze`: sin avisos. `flutter test`: 198 pruebas, todas pasan
  (incluye registro con cada rol, selector único, migración local→cuenta sin
  duplicar, catálogo de avatares/pictogramas y datos heredados).
- Capturas renderizadas con la fuente real en tamaño de teléfono
  (`test/visuals_preview_test.dart`, con `--dart-define=PREVIEW=true`).
- **Sin probar**: iOS (falta Mac), Windows (falta Visual Studio con C++),
  cualquier función contra un proyecto Firebase real.