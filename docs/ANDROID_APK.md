# Generar el APK de Android

## APK de prueba (rápido)

```bash
flutter build apk --release
```
Archivo: `build/app/outputs/flutter-apk/app-release.apk`. Sin clave propia se
firma con la clave de depuración: sirve para instalar en tus teléfonos, **no**
para Google Play.

APK más pequeños, uno por arquitectura:
```bash
flutter build apk --release --split-per-abi
```
(La mayoría de teléfonos actuales usan `app-arm64-v8a-release.apk`.)

## Instalar el APK en un teléfono

- Por cable: `adb install build/app/outputs/flutter-apk/app-release.apk`
- Sin cable: copia el archivo al teléfono, ábrelo y permite *Instalar apps de
  origen desconocido* para el administrador de archivos.

## Firma para publicar

1. Crea una clave (guárdala en un lugar seguro, fuera del repositorio):
   ```bash
   keytool -genkey -v -keystore C:\claves\mi_voz.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mivoz
   ```
2. Crea `android/key.properties` (está en `.gitignore`):
   ```properties
   storePassword=<contraseña>
   keyPassword=<contraseña>
   keyAlias=mivoz
   storeFile=C:\\claves\\mi_voz.jks
   ```
3. `flutter build apk --release` o, para Google Play, `flutter build appbundle`.

`android/app/build.gradle.kts` usa automáticamente `key.properties` si existe.

## Reglas de R8 (no borrar)

`android/app/proguard-rules.pro` conserva clases que `shared_preferences_android`
y `path_provider_android` usan vía JNI. Sin esas reglas, el APK de release se
queda en la pantalla de arranque (`NoSuchMethodError ... SharedPreferencesApiRegistrar`).

## Icono de instalación

El icono sale de `branding/imagen2_icono_app.png` (imagen 2):

- `assets/icon/app_icon_foreground.png`: primer plano del icono adaptativo,
  con la ilustración dentro de la zona segura (64 % del lienzo) para que no se
  recorte en círculos, gotas o cuadrados redondeados.
- Fondo adaptativo: color `#E3F1FF` (`android/app/src/main/res/values/colors.xml`).
- `assets/icon/app_icon.png`: versión completa sin transparencia (iOS y
  Android anteriores a 8.0).

Para regenerarlo:
```bash
dart run tool/prepare_brand_assets.dart
dart run flutter_launcher_icons
```
Si el teléfono sigue mostrando el icono anterior, desinstala la app antes de
instalar el APK nuevo (algunos lanzadores guardan el icono en caché).

## Requisitos de compilación

El paquete nativo `jni` (usado por `shared_preferences` y `path_provider`)
necesita **CMake 3.22.1** del SDK de Android. Si la compilación falla con
"Failed to install cmake;3.22.1", instálalo desde Android Studio (*SDK Manager →
SDK Tools → CMake*) o con:
```bash
"%LOCALAPPDATA%\Android\sdk\cmdline-tools\latest\bin\android.exe" sdk install "cmake;3.22.1"
```
