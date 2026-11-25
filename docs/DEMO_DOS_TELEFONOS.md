# Guion: demostración en dos teléfonos Android

**Estado: pendiente de ejecutar.** Requiere el proyecto Firebase configurado
(`docs/FIREBASE_SETUP.md`), incluidas las Cloud Functions (plan Blaze): sin
ellas no se pueden generar ni canjear códigos.

Material: teléfono **A** (docente) y teléfono **B** (familia), ambos con el
mismo APK compilado **después** de `flutterfire configure`. Dos correos
reales (pueden ser de Gmail). Anota en la tabla final el resultado de cada
paso; no marques como aprobado lo que no viste.

## Antes de empezar

1. En la PC: `flutter build apk --release` e instala el mismo APK en A y B.
2. En la consola de Firebase confirma: Authentication → Correo/contraseña
   habilitado; Firestore con las reglas publicadas; Functions desplegadas
   (`createInvitation`, `previewInvitation`, `redeemInvitation`,
   `reviewJoinRequest`, `revokeInvitation`, `notifyOnRequestCreated`).
3. En A y B: *Ajustes → Cuenta y sincronización* debe decir "Datos
   sincronizados" (si dice "Guardado en este dispositivo", el APK no tiene la
   configuración de Firebase).

## Pasos

| # | Teléfono | Acción | Resultado esperado |
|---|---|---|---|
| 1 | A | Comenzar → Crear una cuenta → Tipo de perfil: **Docente** → Continuar → registrarse | Pantalla "Revisa tu correo" |
| 2 | A | Pulsar "Ya confirmé mi correo" **sin** abrir el correo | "Todavía no aparece confirmado" |
| 3 | A | Abrir el correo (revisar spam), tocar el enlace, volver y pulsar "Ya confirmé" | Entra al panel docente |
| 4 | A | Crear clase "1.º A" → Invitar → 48 h, 1 uso, con aprobación → Generar código | Aparecen el código de 8 caracteres y su QR |
| 5 | B | Crear cuenta → **Padre, madre o tutor** → registrarse → confirmar correo | Panel de familia |
| 6 | B | Crear familia y el perfil infantil "Leo" | Leo aparece en "Niños vinculados" |
| 7 | B | En la tarjeta de Leo → Vincular con una clase → escribir mal el código | "No encontramos una invitación con ese código…" |
| 8 | B | Escanear el QR de A (o escribir el código) → revisar "1.º A" → elegir Leo → Enviar solicitud | "Solicitud enviada. Ana debe aprobarla…" |
| 9 | A | Antes de aprobar: comprobar que Leo **no** aparece en la clase | No aparece |
| 10 | A | "Solicitudes de incorporación" → Aprobar | Leo aparece en la clase y en "Mis alumnos" |
| 11 | B | Volver a usar el mismo código | "Este código ya fue utilizado" |
| 12 | B | Entrar al perfil de Leo → NECESITO → Agua → COMUNICAR (dos toques rápidos) | Una sola solicitud; estado "Enviada" |
| 13 | A | Con la app abierta: ver la solicitud en Solicitudes | Aparece sin recargar |
| 14 | A | Abrir la solicitud | B ve "Vista" |
| 15 | A | "Voy en camino" → "Marcar como resuelta" con apoyo "Le acompañé por agua" | B ve "¡Listo! Ya se resolvió" |
| 16 | B | En "¿Cómo te sientes ahora?" elegir "Me siento mejor" | A ve "El alumno dice: Me siento mejor" en el detalle y en el pasaporte |
| 17 | B | Modo avión → comunicar "Quiero ir al baño" | "Pendiente de envío" / "Sin conexión" |
| 18 | B | Cerrar la app por completo, abrirla, quitar modo avión | Se envía una sola vez; A la recibe |
| 19 | A | Cerrar la app con la pantalla apagada y que B comunique algo | Llega notificación del sistema (si no llega: anotar; depende de FCM) |
| 20 | A | Cerrar sesión, entrar con la cuenta de B | No se ve la clase de A ni sus datos |
| 21 | A | En un tercer teléfono o tras reinstalar: iniciar sesión con la cuenta docente | Recupera clase, alumno y solicitudes |
| 22 | B | En el perfil de Leo → "Adultos vinculados" → retirar a la docente | A deja de ver a Leo |

## Registro de resultados

| # | Fecha y hora | Resultado obtenido | Aprobada / fallida | Evidencia (captura, video) |
|---|---|---|---|---|
| 1 | | | | |
| … | | | | |

No incluyas en capturas o videos datos reales de menores: usa nombres de
ejemplo.
