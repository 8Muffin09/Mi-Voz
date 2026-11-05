# Estado del trabajo (28/10/2026)

Leyenda: **Verificado** = probado aquí con pruebas automáticas o capturas.
**Código preparado** = escrito, compila, sin probar contra servicios reales.
**Pendiente** = no hecho.

## 1. Diagnóstico

Ya existían repositorios dobles (local / Firebase), reglas de Firestore y
Storage, Cloud Functions (invitaciones, avisos, limpieza) y cola de envío
idempotente. Faltaba el proyecto Firebase real; el usuario elegía
"Modalidad"; avatares, pictogramas e interfaz usaban emojis.

## 2. Conexión y modelo de datos

- La modalidad deja de ser una opción: `appModeProvider` usa la nube si está
  configurada. Pantalla "Modalidad" eliminada. **Verificado** (pruebas).
- Estados de sincronización para el usuario (`syncStatusProvider`,
  `SyncStatusBanner`, `SyncStatusTile`). **Verificado** (pruebas).
- Reglas: `avatar` ≤ 40 caracteres; `email` = el de la sesión.
  **Código preparado** (sin desplegar).
- Windows: Firebase no lo admite para producción; propuesta REST en
  `docs/PLATAFORMAS.md`. **Pendiente de decisión.**

## 3. Registro

`CreateAccountScreen`: logo, "Crear una cuenta", selector único "Tipo de
perfil" (panel inferior en teléfono, menú en pantallas ≥ 600 px), sin rol
preseleccionado, "Continuar", "¿Ya tienes una cuenta? Iniciar sesión".
Después del registro: `GroupSetupScreen` (crear clase/familia o unirse con
código). **Verificado** (pruebas de cada rol, selector y validación).

## 4. Recursos visuales

- 42 avatares SVG propios; 133 pictogramas ARASAAC; catálogo con
  identificadores estables y traducción de emojis anteriores.
- Selector de avatar rediseñado (vista previa, grupos, palomita); los campos
  del formulario van antes de la galería.
- Iconos Material en la interfaz; ilustraciones de grupo en pantallas vacías;
  tutorial actualizado.
- **Verificado**: pruebas de catálogo y capturas en `build/preview/`.

## 5. Migración

`LocalDataMigration` + `MigrationScreen` + `functions/migration.js`:
cuenta local → contraseña de esa cuenta → perfiles elegidos → cuenta en la
nube; idempotente; un perfil a una sola cuenta; los datos locales no se
borran. **Verificado** con una "nube" simulada; **código preparado** contra
Firebase.

## 6. Validación

`flutter analyze` sin avisos; `flutter test` 198 pruebas pasan;
`flutter build apk --debug` compila. Sin probar: iOS, Windows, Firebase real,
teclado físico/lector de pantalla en dispositivo.

## Siguiente paso exacto

1. Crear el proyecto Firebase y ejecutar `flutterfire configure` y los
   despliegues de `docs/FIREBASE_SETUP.md` (requiere tu cuenta; Blaze para
   funciones y Storage).
2. Recorrer "Pruebas pendientes con el proyecto real" de ese documento.
3. Decidir Windows (REST o solo local) — ver `docs/PLATAFORMAS.md`.
4. Revisión de pictogramas con un profesional (lista en
   `docs/RECURSOS_VISUALES.md`).

Herramientas en este equipo: `flutter` funciona; para `dart` usa
`C:\Users\Sergi\dev\flutter\bin\cache\dart-sdk\bin\dart.exe` (el `dart` de
`flutter\bin` falla porque no hay `git` en el PATH). No hay Node ni Firebase
CLI.
