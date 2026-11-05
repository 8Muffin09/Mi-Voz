# Política de privacidad de Mi Voz (borrador)

> Borrador técnico basado en lo que hace la app. **No es asesoría legal.**
> Antes de publicarlo, complétalo con los datos del responsable y revísalo
> con alguien que conozca la ley aplicable (por ejemplo, la LFPDPPP en
> México, el RGPD en Europa o COPPA en EE. UU.), sobre todo por tratarse de
> datos de menores.

**Responsable:** [nombre de la persona u organización que publica la app]
**Contacto de privacidad:** [correo]
**Última actualización:** [fecha]

## Qué datos se tratan

| Dato | De quién | Para qué |
|---|---|---|
| Nombre, correo y contraseña | Adultos | Cuenta y acceso. La contraseña la gestiona Firebase Authentication; Mi Voz nunca la guarda. |
| Rol, escuela, grupo y foto (opcionales) | Adultos | Mostrarlos a los adultos vinculados |
| Nombre, avatar o foto opcional, preferencias sensoriales | Niños (los crea un adulto) | Personalizar la comunicación |
| Mensajes comunicados, fecha y estado | Niños | Avisar al adulto y llevar el historial |
| Pasaporte Sensorial y estrategias | Niños | Compartirlos entre familia y escuela |
| Token de notificaciones | Dispositivos de adultos | Enviar los avisos |

Los niños no tienen cuenta, correo ni contraseña. No se recogen ubicación,
contactos, audio ni identificadores publicitarios, y no hay publicidad.

## Quién ve los datos de un niño

Solo los adultos vinculados: su familia y los docentes de las clases a las
que la familia lo vinculó con un código. El administrador del perfil decide
quién recibe solicitudes y quién ve el Pasaporte Sensorial. Las reglas del
servidor imponen estos permisos.

## Dónde se guardan

- **"Solo en este dispositivo"**: únicamente en el dispositivo.
- **Con cuenta**: en Google Firebase (Authentication, Firestore, Storage,
  Cloud Functions y Cloud Messaging), en la región [región del proyecto].
  Google actúa como encargado del tratamiento.

## Conservación y eliminación

- *Configuración → Eliminar mi cuenta y mis datos* borra la cuenta, los
  perfiles infantiles que administra la persona (con sus mensajes, pasaporte,
  estrategias y fotos), sus vínculos con otros perfiles y sus clases. Las
  familias que compartía pasan a otro adulto.
- Quitar a un adulto de un perfil conserva los datos del niño para los demás.
- Solicitudes por correo: [correo de contacto].

## Permisos del dispositivo

Cámara (solo para escanear el QR de invitación, al abrir el escáner),
notificaciones y fotos (solo si se elige una foto). Todos son opcionales.

## Menores

El adulto que crea un perfil infantil declara ser su madre, padre, tutor o
contar con su autorización. [Completar según la ley aplicable.]
