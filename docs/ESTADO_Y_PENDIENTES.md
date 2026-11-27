# Estado del trabajo (23/11/2026)

Leyenda: **Terminada** = implementada y aprobada en pruebas automáticas
(Dart y/o emuladores de Firebase). **Por verificar** = implementada, falta
probarla en teléfonos con un proyecto real. **Bloqueada** = no puede avanzar
sin una acción externa. No se indican responsables, fechas ni porcentajes.

## Terminadas

- Registro de adultos con perfil en `users/{uid}` (sin contraseña) y
  reintento sin duplicar la cuenta.
- Verificación de correo: pantalla "Revisa tu correo", reenvío con espera de
  60 s, comprobación real del estado, cierre de sesión; exigida en reglas y
  funciones.
- Recuperación de contraseña; mensajes para enlace vencido y sin conexión.
- Invitaciones: canje atómico (límite de usos, sin solicitudes ni membresías
  duplicadas), correo verificado obligatorio, normalización de código
  (`maxLength` corregido), aviso de "solo este dispositivo" en modo local.
- Solicitudes: estados solo hacia adelante validados en el servidor, firma
  con uid y hora del servidor, historial inmutable `events/`, doble toque
  sin duplicar.
- Seguimiento del apoyo: apoyo brindado (adulto) y valoración del alumno
  (mejor / igual / peor / sin respuesta) por separado, en la solicitud y en
  el pasaporte sensorial.
- Cola sin conexión por cuenta: se conserva al cerrar sesión, no la envía
  otra cuenta, migración de la cola anterior.
- Reglas endurecidas: eliminadas las ramas heredadas de unión con códigos
  antiguos.
- Pruebas: 206 de Dart y 14 recorridos contra emuladores, todas aprobadas.

## Por verificar (necesitan proyecto Firebase y dos teléfonos)

- Recorrido completo de `docs/DEMO_DOS_TELEFONOS.md`.
- Recepción real del correo de verificación y de recuperación en Gmail.
- Escaneo del QR con la cámara.
- Notificaciones push con la app cerrada o en segundo plano (FCM + función
  `notifyOnRequestCreated`). Con la app abierta, la solicitud aparece en la
  lista en tiempo real (listener de Firestore) aunque no haya push.
- Funcionamiento en modo avión en un teléfono real.

## Bloqueadas

| Actividad | Bloqueo | Acción necesaria |
|---|---|---|
| Vincular dos teléfonos | No hay proyecto Firebase (`firebase_options.dart` es un marcador) | Crear el proyecto y ejecutar `flutterfire configure` |
| Códigos de invitación | Ya no dependen de Blaze; falta desplegar las reglas | `firebase deploy --only firestore:rules,firestore:indexes --project mi-voz-fc416` |
| Avisos con la app cerrada (push) | Requieren Cloud Functions (plan Blaze) | Opcional: activar Blaze y `firebase deploy --only functions` |
| iOS | Falta Mac con Xcode y clave APNs | — |
| Windows con nube en producción | Firebase indica que en Windows es solo para desarrollo | Decidir: API REST (propuesta en `docs/PLATAFORMAS.md`) o Windows solo local |

## Limitaciones conocidas

- El alumno no tiene identidad propia en el servidor: su dispositivo
  funciona con la sesión del adulto autorizado que activó el perfil ("Entrar
  al perfil de…"). Las reglas comprueban que ese adulto esté vinculado; las
  acciones del niño quedan registradas con el uid de ese adulto. El PIN solo
  protege el panel adulto en el teléfono; no autoriza nada en el servidor.
  Para usar el perfil en otro teléfono, un adulto vinculado debe iniciar
  sesión allí y activarlo.
- Al rechazar una solicitud de unión, el uso del código ya consumido no se
  devuelve.
- El bloqueo por códigos incorrectos es por cuenta (5 en 15 minutos); no hay
  App Check, así que no hay protección por dispositivo.

## Siguiente paso exacto

1. Crear el proyecto Firebase, `flutterfire configure
   --platforms=android,ios,windows`, desplegar reglas e índices
   (`docs/FIREBASE_SETUP.md`).
2. Decidir Blaze; si se activa: `firebase deploy --only functions`.
3. Compilar el APK y seguir `docs/DEMO_DOS_TELEFONOS.md`, anotando
   resultados.

Herramientas instaladas en este equipo para las pruebas (fuera del
proyecto): Node 22 portátil en `C:\Users\Sergi\dev\tools\node-v22.23.5-win-x64`
y firebase-tools en `C:\Users\Sergi\dev\tools\fbtools`. Para usarlas en
Git Bash:
`export PATH="/c/Users/Sergi/dev/tools/node-v22.23.5-win-x64:/c/Users/Sergi/dev/tools/fbtools/node_modules/.bin:$PATH"`.
