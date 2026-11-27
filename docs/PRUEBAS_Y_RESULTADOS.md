# Pruebas y resultados

Fecha de ejecución: 23/11/2026. Entorno: Windows 11, Flutter 3.47.7,
Node 22.23.5, firebase-tools 14.27.0.

Tres niveles, que **no** se sustituyen entre sí:

| Nivel | Qué valida | Cómo se ejecuta |
|---|---|---|
| A. Pruebas de Dart (`flutter test`) | Lógica, pantallas y repositorios locales | `flutter test` |
| B. Emuladores de Firebase | Reglas de Firestore, Cloud Functions y Auth reales, con varios "dispositivos" (instancias independientes del SDK cliente) | ver abajo |
| C. Dos teléfonos con un proyecto Firebase real | Todo el recorrido de extremo a extremo | `docs/DEMO_DOS_TELEFONOS.md` |

Resultados de esta entrega: **A: 211 pruebas aprobadas** (3 omitidas a
propósito: generan capturas solo a pedido). **B: 20 de 20 aprobadas** con solo Auth y Firestore emulados, sin Cloud Functions (16 recorridos + 4 del aviso al niño)
(salida en `docs/evidencias/emuladores.txt`). **C: pendiente** (no hay
proyecto Firebase ni dos teléfonos disponibles en este entorno).

Ejecutar B:

```bash
cd functions && npm install && cd ..
cd firebase/tests && npm install && cd ../..
firebase emulators:exec --project demo-mivoz --only auth,firestore \
  "node --test --test-concurrency=1 firebase/tests/flows.test.mjs"
```

(Requiere Java 11+ y Node 22. El proyecto `demo-mivoz` es ficticio: el
emulador no se conecta a ningún servicio real.)

## Matriz de criterios

"Emulador" = aprobada en el nivel B. "Dart" = aprobada en el nivel A.
Ninguna se ha probado todavía en teléfonos físicos (nivel C).

| # | Funcionalidad | Condiciones y datos | Resultado esperado | Resultado obtenido | Estado | Evidencia |
|---|---|---|---|---|---|---|
| 1 | Registro de adulto y perfil | Correo nuevo, rol `madre`; otra cuenta intenta escribir ese perfil | Cuenta en Auth + `users/{uid}` sin contraseña; otra cuenta rechazada | Igual al esperado. Reintento con el mismo correo da `email-already-in-use` y la app completa el perfil de **la misma** cuenta (mismo uid) | Aprobada (emulador) · Pendiente (teléfono) | Emulador 1 y 1b |
| 2 | Verificación de correo | Registro → "Ya confirmé" sin abrir enlace → abrir enlace → "Ya confirmé" | Se envía 1 correo; sigue sin verificar hasta abrir el enlace; sin verificar el servidor rechaza crear clases y usar invitaciones | Igual al esperado | Aprobada (emulador + Dart) · Pendiente (correo real de Gmail) | Emulador 2; `test/cloud_flows_test.dart` (pantalla, espera de 60 s, sin conexión) |
| 3 | Inicio de sesión en otro dispositivo | Cuenta con un perfil infantil; se cierra el dispositivo y se entra desde otro | Se recuperan perfil y niño autorizado | Igual al esperado | Aprobada (emulador) · Pendiente (teléfono) | Emulador 3 y 12 |
| 4 | Recuperación de contraseña | `sendPasswordResetEmail` | Se envía correo de restablecimiento | Igual al esperado | Aprobada (emulador) · Pendiente (correo real) | Emulador 4 |
| 5 | Invitación de un dispositivo a otro | Familia A genera código (5 usos, sin aprobación); B lo canjea | Código existe en el servidor antes de mostrarse; B entra a la familia; repetir no duplica | Igual al esperado | Aprobada (emulador) · Pendiente (teléfono) | Emulador 5 y 6 |
| 6 | Vinculación por QR | Código escrito como `x49x - vhga` (minúsculas, espacio, guion) | Se normaliza igual que el contenido del QR | Igual al esperado. El escaneo de la cámara en sí no se probó | Aprobada (emulador, normalización) · Pendiente (escaneo en teléfono) | Emulador 5 y 6 |
| 7 | Código incorrecto, vencido, revocado, sin usos | Código inexistente; revocado; `expiresAt` en el pasado; 1 uso consumido | Motivos `invalid`, `revoked`, `expired`, `exhausted`; 5 incorrectos bloquean 15 min | Igual al esperado. Dos canjes simultáneos del último uso: solo uno entra (`uses` = 1) | Aprobada (emulador) | Emulador 7, 7b, 7c |
| 8 | Aprobación pendiente | Código de clase con aprobación; dos toques simultáneos | Una sola solicitud; la docente no ve al alumno hasta aprobar; quien solicita no puede aprobarse | Igual al esperado | Aprobada (emulador) | Emulador 8 |
| 9 | Solicitud recibida por el adulto | Familia comunica; docente escucha con `onSnapshot` | Llega en tiempo real | Igual al esperado | Aprobada (emulador) · Pendiente (teléfono) | Emulador 9–16 |
| 10 | Estados sincronizados | Vista → En atención → Resuelta; intento de retroceder o firmar con otro uid | Avanza; retroceder y suplantar se rechazan; la familia ve "Resuelta"; historial inmutable | Igual al esperado | Aprobada (emulador + Dart) | Emulador 9–16; `cloud_flows_test.dart` |
| 11 | Sin conexión y reintento | Entrega repetida con el mismo id; `set` directo sobre la existente | Una sola solicitud; sobrescribir se rechaza | Igual al esperado. Cola por cuenta y doble toque probados en Dart | Aprobada (emulador + Dart) · Pendiente (modo avión en teléfono) | Emulador 9–16; `outbox_test.dart`; `cloud_flows_test.dart` |
| 12 | Cerrar y reabrir | Cola pendiente y reinicio del contenedor de la app | La solicitud sigue en cola y se envía al volver la red | Igual al esperado | Aprobada (Dart) · Pendiente (teléfono) | `outbox_test.dart` |
| 13 | Cambio de cuenta | Cerrar sesión e iniciar con otra en el mismo dispositivo | Sin acceso a perfiles ni solicitudes anteriores; la cola de la otra cuenta no se ve ni se envía | Igual al esperado | Aprobada (emulador + Dart) | Emulador 13; `outbox_test.dart`; `accounts_and_access_test.dart` |
| 14 | Accesos no autorizados | Docente sin vínculo: leer niño, pasaporte, solicitudes; agregarse a `memberUids`; crear vínculo propio; escribir invitaciones; invitar a clase ajena; cambiar su rol | Todo rechazado | Igual al esperado | Aprobada (emulador) | Emulador 14 |
| 15 | Revocar vinculación | Administradora retira adulto de la familia; madre retira a la docente del perfil | Pierden acceso de inmediato | Igual al esperado | Aprobada (emulador) | Emulador 15 |
| 16 | Evaluación del apoyo | Resolver con "apoyo brindado"; valoración `better`; valor inválido | Se guardan por separado; inválido rechazado; "Resuelta" no implica "mejor" | Igual al esperado | Aprobada (emulador + Dart) · Pendiente (teléfono) | Emulador 9–16; `cloud_flows_test.dart` |

## Errores encontrados y acción correctiva

| Hallazgo | Causa | Acción |
|---|---|---|
| "El código no existe" con `X49XVHGA` entre dos teléfonos | Sin `firebase_options.dart` válido la app usa la base local; el código solo existía en el teléfono que lo generó | Aviso visible en modo local en "Tengo un código" y al compartir; mensaje de error que no afirma la causa. La solución real es configurar Firebase (pendiente: requiere tu cuenta) |
| El campo del código se cortaba en 8 caracteres | `maxLength: 8` antes de normalizar: `X49X-VHGA` perdía la última letra | `maxLength: 12` y normalización |
| Solicitudes de unión duplicadas con dos toques | La comprobación de "pendiente" se hacía fuera de la transacción | Id determinista (`uid_grupo_niño`) comprobado dentro de la transacción |
| Rama heredada de reglas permitía unirse con códigos del sistema antiguo (`invitations`) | Compatibilidad con la versión anterior | Eliminada: solo las Cloud Functions agregan miembros |
| El estado de una solicitud podía retroceder o cambiarse sin dejar rastro | Reglas sin orden de estados | Orden `new < seen < attending < resolved`, firma con uid y hora del servidor, historial `events/` inmutable |
| Cerrar sesión borraba solicitudes pendientes; la cola era común a todas las cuentas | Una sola clave local | Cola por cuenta, se conserva al cerrar sesión y solo la envía esa cuenta; migración de la cola anterior |
| Mis propias pruebas listaban `join_requests` sin filtro | Error de la prueba (las reglas lo rechazan, correctamente) | La prueba usa la misma consulta filtrada que la app |
