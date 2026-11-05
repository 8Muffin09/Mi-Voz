# Configurar la nube (Firebase)

Firebase es un detalle interno: el usuario **no elige modalidad**. Si
`lib/firebase_options.dart` es válido, la app usa siempre la nube; si no
(compilaciones de desarrollo), funciona con cuentas guardadas solo en el
dispositivo y la interfaz lo indica como "Guardado en este dispositivo" (sin
nombrar servicios). La pantalla "Modalidad" se eliminó.

El código está completo, pero falta **tu** proyecto: no se incluyen
credenciales ni identificadores inventados. Nada de este documento se ha
ejecutado contra un proyecto real.

## Qué servicio necesita qué plan

| Servicio | Uso en Mi Voz | Plan |
|---|---|---|
| Authentication (correo/contraseña) | Cuentas de adultos | Spark (gratis) |
| Cloud Firestore | Perfiles, solicitudes, historial, pasaporte, estrategias | Spark (gratis, con cuotas) |
| Cloud Messaging (FCM) | Entrega de notificaciones | Gratis |
| **Cloud Functions** | Invitaciones a clases y familias (validación en el servidor), envío seguro de notificaciones push (solicitudes de los niños y solicitudes por aprobar) y limpieza | **Blaze (requiere facturación)** |
| **Cloud Storage** | Fotos de pictogramas propios y fotos de perfil (opcionales) | **Blaze** para buckets nuevos |

Sin Blaze la app funciona en la nube (cuentas, datos compartidos, historial),
pero **no se pueden generar ni canjear invitaciones** (las validan las
funciones `createInvitation`, `previewInvitation`, `redeemInvitation`,
`reviewJoinRequest` y `revokeInvitation`), **no se envían notificaciones
push** (la solicitud se queda en "Notificación en proceso") y no se pueden
subir fotos de pictogramas ni de perfil (los pictogramas y avatares con emoji
sí funcionan). Blaze tiene un nivel gratuito amplio; configura una alerta de
presupuesto en Google Cloud.

> **Estado de verificación:** las reglas, los índices y las Cloud Functions
> están escritos pero **no se han desplegado ni probado** contra un proyecto
> Firebase real. Las mismas validaciones se probaron con la implementación
> local ("Solo en este dispositivo"). Antes de usar la app con familias,
> prueba los pasos de "6. Probar" y, si es posible, el emulador de Firebase.

## Pasos

### 1. Crear el proyecto
1. <https://console.firebase.google.com> → *Agregar proyecto*.
2. *Authentication → Método de acceso →* habilita **Correo electrónico/contraseña**.
3. *Firestore Database → Crear base de datos →* modo **producción**, elige región.
4. (Blaze) *Storage → Comenzar*.
5. (Blaze) *Configuración del proyecto → Uso y facturación →* cambia a Blaze.

### 2. Herramientas (una vez)
```bash
# Node.js 22 LTS: https://nodejs.org
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
```

### 3. Conectar la app
Desde la carpeta del proyecto:
```bash
flutterfire configure --project=<ID-de-tu-proyecto> --platforms=android,ios,windows
```
Esto registra las apps (Android `com.mivoz.app`, iOS `com.mivoz.app`), genera
`lib/firebase_options.dart` (reemplaza el marcador) y
`android/app/google-services.json`. Las claves de `firebase_options.dart` son
identificadores públicos de cliente; la seguridad la dan las reglas.

### 4. Publicar reglas y funciones
```bash
firebase use --add            # elige tu proyecto
firebase deploy --only firestore:rules,firestore:indexes
firebase deploy --only storage          # si activaste Storage
cd functions && npm install && cd ..
firebase deploy --only functions        # requiere Blaze
```
Las funciones de invitaciones son *callable* (v2) en `us-central1`; la app las
llama en esa región. Si las despliegas en otra, cambia la región en
`invitationsRepositoryProvider` (`lib/app/providers.dart`).

### 5. iOS (si compilas para iPhone)
1. Apple Developer → crea una **APNs Auth Key (.p8)**.
2. Firebase → *Configuración → Cloud Messaging → Apps de Apple →* sube la clave.
3. En Xcode (`ios/Runner.xcworkspace`) → *Signing & Capabilities →* agrega
   **Push Notifications** y **Background Modes → Remote notifications**.

### 6. Probar
1. `flutter run`. Con `firebase_options.dart` configurado, la app usa la nube
   siempre (en *Ajustes → Cuenta y sincronización* aparece "Datos
   sincronizados").
2. Teléfono 1 (docente): *Comenzar → Crear una cuenta → Tipo de perfil:
   Docente → Continuar*, regístrate y verifica el correo.
   **Crear mi primera clase** → en la clase, **Invitar** → **Generar código** → aparece
   el código de 8 caracteres y su QR.
3. Teléfono 2 (familia): *Tipo de perfil: Padre, madre o tutor*, crea **Mi familia** y el
   perfil del niño. En su tarjeta → **Vincular con una clase** → escribe o
   escanea el código → revisa el nombre de la clase → elige al niño →
   **Enviar solicitud**.
4. Teléfono 1: en "Solicitudes por aprobar" → **Aprobar**. El niño aparece en
   la clase y en "Mis alumnos". Activa "Estoy acompañando a…".
5. Comprueba también: código mal escrito, código revocado, código vencido y
   6 códigos incorrectos seguidos (bloqueo de 15 minutos).
6. Teléfono 2: **Entrar al perfil de…** y comunica una frase: el teléfono 1
   recibe "Juan necesita atención: …". El detalle muestra entrega,
   notificación, vista y atendida por separado.

## Modelo de datos

```
users/{uid}                               perfil: nombre, apellido, rol, avatar, foto,
                                          escuela, grupo, título docente, experiencias
children/{childId}                        ownerUid, memberUids[], familyId, classIds[],
                                          avatar, foto, responsable, settings,
                                          noCompanionRule, backupUids[]
  caregiver_links/{adultUid}              rol, permiso, origen (familia/clase/directo),
                                          recibe solicitudes, ve el pasaporte
  communication_requests/{requestId}      solicitud; `notification` lo escribe la función
  sensory_passports/main
  support_strategies/{id}
  favorites/{pic_<id> | phr_<id>}         favoritos y frases frecuentes
  pictograms/{id}                         pictogramas propios
families/{familyId}                       nombre, ownerUid, adultUids[], adultNames, adultRoles
classes/{classId}                         nombre, descripción, ownerUid, teacherUids[],
                                          studentIds[], archived
group_invitations/{code}                  invitación a una familia o clase: tipo, destino,
                                          ownerUid, caducidad, usos/máximo, revocada,
                                          requiere aprobación, rol (solo la escriben funciones)
join_requests/{id}                        solicitud pendiente de aprobación (solo funciones)
rate_limits/{uid}                         intentos fallidos de código (solo funciones)
invitations/{code}                        heredada: solo lectura y borrado
notification_tokens/{token}               uid del adulto, modo niño
```

Storage (privado, ver `firebase/storage.rules`):

```
children/{childId}/pictograms/{id}.jpg    solo adultos vinculados
children/{childId}/avatar/photo.jpg       solo adultos vinculados
users/{uid}/avatar/photo.jpg              solo el propio adulto
```

Las fotos de perfil se guardan como `storage:<ruta>` y la app las descarga
con el SDK (`getData`), así que siempre pasan por las reglas; no se guardan
enlaces públicos de descarga para ellas.

Las colecciones `caregiver_links`, `communication_requests`, `sensory_passports`,
`support_strategies`, `favorites` y `pictograms` son subcolecciones del niño para
que las reglas verifiquen la pertenencia en cada acceso. Las **categorías y los
pictogramas base** van incluidos en la app (no en Firestore) para garantizar que
funcionen sin internet desde la primera ejecución; lo personalizable por niño
(ocultar, favoritos, propios) sí se guarda en la nube.

## Seguridad aplicada

- Solo los adultos en `memberUids` leen o escriben datos del niño. Un docente
  solo ve a los alumnos a los que se vinculó con un código.
- `users/{uid}` solo lo lee y escribe su dueño, con campos y tamaños
  validados. Las "experiencias" (familia/docente) no dan acceso a ningún niño.
- Las invitaciones (`group_invitations`, `join_requests`, `rate_limits`) solo
  las escriben las Cloud Functions; el cliente no puede crearlas, canjearlas
  ni aprobarlas escribiendo en Firestore. Las funciones comprueban: correo
  verificado y propiedad del grupo al generar; caducidad (48 h o 7 días),
  revocación y límite de usos (1, 5 o 30) al canjear; duplicados; que solo un
  adulto de la familia del niño lo vincule con una clase; y 5 códigos
  incorrectos en 15 minutos bloquean 15 minutos.
- El QR solo contiene `mivoz://invite?code=XXXXXXXX`: ningún dato del niño ni
  credenciales, y no inicia sesión.
- Al unirse con un código, el vínculo queda siempre como `caregiver` con el
  rol de la invitación: nadie puede otorgarse permisos de administrador.
- Desvincular a un adulto conserva todos los datos del niño.
- Un niño es un solo documento aunque esté en su familia y en varias clases.
  `memberUids` es la lista de acceso que verifican las reglas.
- Crear un perfil en una familia: los miembros deben ser exactamente los
  adultos de esa familia. Ningún perfil nace vinculado a una clase.
- Un docente solo agrega a una clase alumnos a los que ya tiene acceso, y al
  retirarlos pierde el acceso que le daba esa clase.
- El administrador del perfil decide quién recibe solicitudes y quién ve el
  pasaporte; la Cloud Function y las reglas lo respetan.
- Solo el administrador invita o quita adultos y elimina el perfil.
- Cada adulto puede marcarse responsable a sí mismo; no puede asignar a otro.
- El cliente no puede escribir el resultado de la notificación ni retroceder
  estados; la Cloud Function valida al emisor y solo notifica a adultos vinculados.
- **A quién se avisa** (`notifyOnRequestCreated`, igual que
  `RecipientResolver.plan` en la app): al adulto que marcó "Estoy
  acompañando". Si nadie acompaña, o quien acompaña no tiene dispositivos,
  se aplica la regla que eligió el administrador del perfil
  (`noCompanionRule`: `admin` —por defecto—, `chosen` con `backupUids`, o
  `all`). Nunca se avisa a todos si el administrador no lo eligió, y quien
  tiene "No recibe solicitudes" nunca recibe avisos. Si no queda nadie, la
  solicitud queda como `noRecipients` y el niño ve "El aviso no le llegó a
  nadie. Busca a un adulto cerca".
- La notificación guarda `recipientUids`, `recipientNames` y `route`
  (`companion`, `rule` o `ruleAfterCompanion`). "Enviada" solo significa que
  FCM la aceptó; "Vista", "Atendiendo" y "Resuelta" son la atención real.
- Canales de Android (creados en `MainActivity.kt`): `mi_voz_requests` y
  `mi_voz_urgent` (ayuda urgente, vibración más larga).
- La app nunca contiene claves privadas: solo registra su token FCM.
- En modo niño, la salida exige PIN o una suma; el dispositivo se marca para no
  recibir los avisos del adulto.
- *Configuración → Eliminar mi cuenta y mis datos* borra los perfiles que
  administras y te desvincula de los demás.

## Novedades de esta versión (código preparado, sin desplegar)

| Pieza | Qué hace | Qué debes hacer |
|---|---|---|
| `functions/migration.js` → `importLocalHistory` | Transfiere el historial de un dispositivo al perfil en la nube. Solo el administrador del perfil; máx. 200 por llamada; idempotente; marca `imported: true` y no envía avisos. | `firebase deploy --only functions` (Blaze) |
| `notifyOnRequestCreated` | Ignora las solicitudes importadas. | Igual |
| `firestore.rules` (`users`) | `avatar` hasta 40 caracteres (identificadores del catálogo); el `email` debe coincidir con el de la sesión. | `firebase deploy --only firestore:rules` |

Sin Blaze, la transferencia de perfiles, favoritos, frases, pictogramas
propios, pasaporte y estrategias **sí** funciona (la escribe el cliente con
las reglas); solo el historial queda sin transferir y la app muestra el error.

### Servicios que se usan (y ninguno más)

Authentication (correo/contraseña), Cloud Firestore, Cloud Storage (fotos
opcionales), Cloud Messaging (avisos push en Android/iOS) y Cloud Functions
(invitaciones, avisos e importación de historial). No se usan Analytics,
Crashlytics, Remote Config ni Hosting.

### Pruebas pendientes con el proyecto real

1. Registro con cada tipo de perfil; cerrar sesión e iniciar sesión: no se
   vuelve a preguntar el rol.
2. En un segundo dispositivo, la misma cuenta ve sus perfiles, favoritos y
   frases.
3. Una cuenta B no puede leer `children/{id}` de A (consola → *Rules
   Playground* o el emulador).
4. Instalar sobre una versión anterior con cuentas locales → iniciar sesión →
   *Hay perfiles guardados solo en este dispositivo → Revisar* → contraseña
   de la cuenta local → transferir → repetir: no duplica.
5. Modo avión: enviar una frase → "Cambios pendientes" → quitar el modo avión →
   "Datos sincronizados" y una sola solicitud en el servidor.