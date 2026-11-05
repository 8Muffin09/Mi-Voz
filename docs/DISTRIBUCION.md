# Publicar Mi Voz

Este proyecto **no incluye** claves de firma, certificados, cuentas de
desarrollador ni identidades de tienda: cada uno debe ser tuyo.

## Android

### Clave de firma (una sola vez)

```powershell
powershell -ExecutionPolicy Bypass -File tool\crear_clave_android.ps1
```

Crea tu clave de subida (`.jks`) fuera del proyecto y `android/key.properties`
(en `.gitignore`). Guarda una copia del `.jks` y su contraseña: sin ellos no
podrás actualizar la app. Detalles: [ANDROID_APK.md](ANDROID_APK.md).

Sin `key.properties`, la compilación de release usa la clave de depuración:
sirve para probar, **no para publicar**.

### Compilar

```bash
flutter build appbundle --release          # Google Play (.aab)
flutter build apk --release --split-per-abi # instalación directa, un APK por arquitectura
```

Comprobado el 28 de octubre de 2026, firmado con la clave de depuración: el
AAB (72.9 MB) y el APK universal (79.8 MB) compilan, y el APK de release abre
en el emulador sin errores. Con `--split-per-abi` cada APK pesa mucho menos.

### Google Play

1. Cuenta de desarrollador de Google Play (pago único).
2. Crea la app, sube el `.aab` a pruebas internas y activa la firma de apps
   de Google Play.
3. **Seguridad de los datos**: declara nombre y correo (cuentas de adultos),
   datos de niños (nombre, avatar, mensajes, preferencias), fotos opcionales
   y token de notificaciones; cifrados en tránsito; el usuario puede pedir
   su eliminación.
4. **Eliminación de la cuenta**: Play pide un enlace web además de la opción
   dentro de la app (*Configuración → Eliminar mi cuenta y mis datos*).
   Publica una página con los pasos o un formulario.
5. **Política de privacidad**: completa [PRIVACIDAD.md](PRIVACIDAD.md) y
   publícala en una URL.
6. **Público objetivo**: si la app se dirige a niños, aplica la política de
   Familias de Google Play.

## Windows

### Requisitos del equipo de compilación

1. Visual Studio 2022 con "Desarrollo de escritorio con C++".
2. Modo de desarrollador activado: *Configuración → Sistema → Para
   desarrolladores* (Flutter usa enlaces simbólicos para los plugins).
3. Para Firebase en Windows: `flutterfire configure --platforms=windows`.

```bash
flutter build windows --release
# Resultado: build\windows\x64\runner\Release\
```

**Estado**: el proyecto ya tiene la plataforma Windows (`windows/`, icono y
nombre "Mi Voz"), pero **no se ha compilado**: en este equipo falta Visual
Studio.

### Instalador clásico (.exe)

Abre `windows/installer/mi_voz.iss` con
[Inno Setup 6](https://jrsoftware.org/isinfo.php) y compílalo. Copia la app
y las bibliotecas de Visual C++ que necesita. El resultado queda en
`build\installer\`.

Para evitar la advertencia de SmartScreen, firma el instalador y `mi_voz.exe`
con **tu** certificado de firma de código (`signtool sign /fd SHA256 ...`).

### Microsoft Store (MSIX)

1. Cuenta de desarrollador en el Centro de partners de Microsoft y reserva
   el nombre "Mi Voz".
2. Copia `identity_name`, `publisher` y `publisher_display_name` en
   `msix_config` (en `pubspec.yaml`).
3. `flutter build windows --release` y luego
   `dart run msix:create --build-windows false`.
4. Sube el `.msix` al Centro de partners (la Store lo firma).

## iOS (requiere Mac)

Desde Windows no se puede compilar ni firmar una app de iOS.

1. Mac con Xcode actualizado y CocoaPods; cuenta de Apple Developer (pago anual).
2. `flutterfire configure --platforms=ios` (crea `GoogleService-Info.plist`).
3. `cd ios && pod install`.
4. Abre `ios/Runner.xcworkspace` → *Signing & Capabilities*: elige tu equipo,
   bundle id `com.mivoz.app` (o el tuyo), y agrega **Push Notifications** y
   **Background Modes → Remote notifications** (ya declarado en `Info.plist`).
5. Clave APNs (.p8) de Apple Developer → súbela a Firebase (*Cloud
   Messaging → Apps de Apple*).
6. `flutter build ipa` → sube con Xcode u otra herramienta a App Store
   Connect → TestFlight.

Ya preparado: versión mínima iOS 15.0 (la que exige Firebase), textos de
permiso de cámara y fotos en `Info.plist`, e icono.

## Antes de publicar en cualquier tienda

- [ ] Proyecto Firebase propio con plan Blaze; reglas, índices y funciones
      desplegados y probados (ver [FIREBASE_SETUP.md](FIREBASE_SETUP.md)).
- [ ] Prueba con dos teléfonos reales: invitación, solicitud y notificación.
- [ ] Política de privacidad publicada y enlace de eliminación de datos.
- [ ] Revisión con TalkBack/VoiceOver y en una ventana real de Windows.
