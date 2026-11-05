# Mi Voz

Aplicación Flutter de comunicación aumentativa con pictogramas para niños con
autismo. El niño forma frases tocando imágenes ("Me molesta mucho el ruido"),
las escucha con voz y las comunica al adulto que lo acompaña en ese momento.

> Mi Voz es una herramienta de apoyo a la comunicación. No realiza diagnósticos
> ni evaluaciones clínicas y no sustituye a los servicios de emergencia.

## Flujo de la aplicación

```
Pantalla de carga (imagen, fondo suave, melodía opcional, "Omitir")
        ↓
Bienvenida: logo, explicación, [Comenzar]  ·  "Conocer cómo funciona" (tutorial)
        ↓ Comenzar
Iniciar sesión (sin volver a elegir rol)  |  Crear una cuenta → Tipo de perfil ▾ → Continuar
      ├─ Docente               → registro → crear clase o unirse con código
      ├─ Padre, madre o tutor  → registro → crear familia o unirse con código
      └─ Alumno                → un adulto se registra o inicia sesión y crea
                                 el perfil infantil (sin correo del niño)
```

- Cuentas de **adulto** (correo y contraseña) y **perfiles infantiles** (sin
  correo, creados por un adulto). Elegir "docente" no da acceso a ningún
  alumno: el acceso solo llega con un vínculo verificado.
- Con sesión guardada se abre el panel del adulto. Si esa cuenta activó
  perfiles infantiles en el dispositivo, se abre "¿Quién utilizará Mi Voz?":
  el niño entra sin contraseña y el panel exige **PIN o contraseña**.
- **Cambiar perfil**: perfil infantil, volver al panel, contexto
  docente/familia, cerrar sesión o entrar con otra cuenta.
- PIN con hash, sal e iteraciones; bloqueo progresivo tras 5 intentos.
- **Familias**: el tutor crea su familia ("Mi familia"); sus adultos ven a
  todos sus niños. **Clases**: el docente crea varias clases ("Crear mi
  primera clase"), agrega alumnos que ya le autorizaron, los retira con
  confirmación y archiva clases. Un mismo niño está en su familia y en varias
  clases sin duplicar sus datos.
- **Invitaciones**: el administrador de la familia o el docente de la clase
  genera un código de 8 caracteres con QR (vigencia de 48 h o 7 días, 1, 5 o
  30 usos, aprobación opcional) y puede revocarlo. Quien lo recibe lo escribe
  o lo escanea en "Tengo un código", ve a qué clase o familia corresponde,
  confirma y, si hace falta, espera la aprobación. El QR no contiene datos del
  niño ni sirve para iniciar sesión; la cámara solo se pide al escanear.
- El administrador del perfil decide qué adultos reciben solicitudes y cuáles
  ven el Pasaporte Sensorial.
- **Avisos**: llegan a quien marcó "Estoy acompañando". Si nadie acompaña, se
  aplica la regla del perfil (*Adultos y avisos*): solo al administrador
  (por defecto), a los adultos que él elija o a todos (solo si lo elige).
- **Envío y atención por separado**: pendiente de envío → recibida en el
  servidor → aviso enviado; y aparte vista → atendiendo → resuelta. Si el
  aviso no llegó a nadie, no hay internet o nadie lo ha visto en 2 minutos,
  el niño ve "Busca a un adulto cerca". El botón de ayuda urgente no
  sustituye a los servicios de emergencia.
- **Conocer cómo funciona** (bienvenida y *Configuración → Ayuda*): recorrido
  por rol con pantallas simuladas y el elemento que hay que tocar resaltado;
  progreso, "Anterior", "Siguiente", "Omitir" y "Finalizar"; también con
  teclado (← → y Esc). Usa solo datos ficticios: no crea cuentas ni envía
  avisos. Desde Ayuda empieza en el rol de la cuenta.
- **Accesibilidad**: se respetan el texto ampliado del sistema, "Quitar
  animaciones" / "Reducir movimiento" y el modo tranquilo de cada niño.
- **Sin conexión**: las solicitudes se guardan en el dispositivo y se envían
  solas (reintentos de 15 s a 5 min, al volver la red y al abrir la app); el
  panel muestra lo pendiente con "Reintentar".

## Cuentas y sincronización

El usuario no elige modalidad. Con la nube configurada
([docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)) las cuentas se
sincronizan entre dispositivos; sin ella (desarrollo) todo se guarda en el
dispositivo. La app solo muestra estados: *Sin conexión*, *Cambios
pendientes*, *Datos sincronizados*, *No pudimos conectar. Intentar
nuevamente*. Los perfiles de cuentas locales anteriores se transfieren a la
cuenta solo tras confirmar la contraseña de esa cuenta local
(`lib/features/migration/`).

Avatares, pictogramas e iconos: [docs/RECURSOS_VISUALES.md](docs/RECURSOS_VISUALES.md).

Las personas ficticias de `lib/core/demo/demo_seed.dart` (María, Ana, Luis,
Carlos, Juan, Sofía, Mateo) solo se cargan en las pruebas automáticas.
## Ejecutar en Visual Studio Code

1. Requisitos: Flutter 3.47+ (Dart 3.13+), Android SDK y la extensión *Flutter* de VS Code.
2. Abre la carpeta `mi_voz` en VS Code.
3. En una terminal: `flutter pub get`.
4. Elige el dispositivo en la barra inferior (emulador o teléfono) y pulsa **F5**
   (o `flutter run`).

Plataformas: **Android**, **iOS** y **Windows**. Para compilar la versión de
Windows se necesitan Visual Studio 2022 con "Desarrollo de escritorio con C++"
y el modo de desarrollador activado (*Configuración → Sistema → Para
desarrolladores*). Qué funciona en cada plataforma y qué alternativa se usa
cuando falta algo: [docs/PLATAFORMAS.md](docs/PLATAFORMAS.md).

## Probar en un teléfono Android

1. En el teléfono: *Ajustes → Acerca del teléfono →* toca 7 veces *Número de compilación*.
2. *Opciones de desarrollador →* activa **Depuración USB**.
3. Conecta por USB y acepta la huella del equipo.
4. `flutter devices` debe listarlo; luego `flutter run` (o F5 en VS Code).
5. Para la voz: *Ajustes → Sistema → Idioma → Texto a voz* e instala la voz en español.

Para instalar sin cable, genera el APK (abajo) y cópialo al teléfono.

## Generar el APK

```bash
flutter build apk --release
# Resultado: build/app/outputs/flutter-apk/app-release.apk
```

Detalles de firma para publicar y APK por arquitectura: [docs/ANDROID_APK.md](docs/ANDROID_APK.md).

## Publicar

Android (AAB para Google Play y APK firmado), Windows (instalador y
Microsoft Store) e iOS (TestFlight): [docs/DISTRIBUCION.md](docs/DISTRIBUCION.md).
Borrador de política de privacidad: [docs/PRIVACIDAD.md](docs/PRIVACIDAD.md).

## Pruebas

```bash
flutter analyze
flutter test
```

182 pruebas: construcción de frases, vocabulario y favoritos, permisos y roles,
destinatario responsable, modelos, repositorios demo, cola sin conexión,
historial, registro de familia y docente, creación y edición de perfiles y
avatares, selección y cambio de perfil, cambio de cuenta y cierre de sesión,
panel docente, familias y clases, invitaciones (caducidad, revocación, usos,
duplicados, aprobación, bloqueo por intentos, sin conexión), regla de avisos
sin acompañante, estados honestos del envío, cola con reintentos, tutorial
interactivo sin efectos en los datos, pautas de accesibilidad (tamaño de
zonas táctiles, etiquetas, contraste), texto al 200 %, suscripciones que no
se reabren e historial por bloques, eliminación de la cuenta (clases, familias y
vínculos), avisos sin notificaciones push, protección de
alumnos no autorizados y de la administración, pantalla de carga y
preferencias de sonido.

Prueba de punta a punta en un emulador o teléfono (modo local):

```bash
flutter test integration_test/fases_2_3_test.dart -d <dispositivo>
flutter test integration_test/fase4_test.dart -d <dispositivo>
flutter test integration_test/fase5_test.dart -d <dispositivo>
```

Estas pruebas borran los datos de Mi Voz del dispositivo: úsalas en un
emulador, no en un teléfono con datos reales.

Las reglas de Firestore y las Cloud Functions no tienen pruebas automáticas
todavía: requieren Node.js y el emulador de Firebase.

## Imagen, icono y melodía

| Recurso | Origen | Uso |
|---|---|---|
| `branding/imagen1_pantalla_de_carga.png` | Imagen 1 del proyecto (sin modificar) | Se procesa a `assets/images/splash_mi_voz.png` (exterior del círculo transparente) |
| `branding/imagen2_icono_app.png` | Imagen 2 del proyecto (sin modificar) | Icono de instalación (Android adaptativo + iOS) y logotipo `assets/images/logo_mi_voz.png` |
| `assets/audio/bienvenida_mi_voz.wav` | Compuesta y sintetizada en `tool/generate_welcome_melody.dart` (obra original del proyecto) | Melodía de bienvenida de 4,6 s, cajita musical |

Regenerar tras cambiar una imagen original:

```bash
dart run tool/prepare_brand_assets.dart
dart run flutter_launcher_icons
dart run tool/generate_welcome_melody.dart   # solo si cambias la melodía
```

La melodía está **desactivada** hasta que un adulto la active en
Configuración → Bienvenida; suena una sola vez por inicio, nunca si un niño del
dispositivo tiene el modo tranquilo, y la pantalla de carga se puede omitir
("Omitir" o "Mostrar pantalla de bienvenida").

## Arquitectura

```
lib/
├── main.dart                  Arranque (Firebase opcional + Riverpod)
├── firebase_options.dart      Marcador: lo reemplaza `flutterfire configure`
├── app/                       App, router (GoRouter + guardas), proveedores, rutas
├── core/
│   ├── constants/             Textos legales
│   ├── demo/                  Base local del modo demo y datos de ejemplo
│   ├── permissions/           Reglas de roles (espejo de firestore.rules)
│   ├── services/              Almacenamiento local, fotos, TTS, vibración, red
│   ├── theme/                 Tema adulto y paleta infantil (tranquilo/contraste)
│   ├── utils/                 Errores, formatos, validadores, flujos
│   └── widgets/               Componentes reutilizables (avatar, selector de avatar…)
├── features/
│   ├── access/                ¿Cómo deseas ingresar?, Soy niño, Cambiar usuario, experiencias
│   ├── account/               Mi perfil y su edición
│   ├── authentication/        Pantalla de carga, acceso, registro
│   ├── welcome/               Preferencias de bienvenida y melodía
│   ├── teacher/               Panel docente
│   ├── profiles/              Perfiles, selector, vínculos con invitación, responsable
│   ├── child/                 Experiencia del niño (pictogramas, frase, urgente)
│   ├── adult/                 Panel de familia, solicitudes, detalle
│   ├── communication/         Solicitudes, cola offline, servicio de envío
│   ├── pictograms/            Catálogo, gramática, vocabulario, administración
│   ├── notifications/         FCM, avisos internos
│   ├── sensory_passport/      Mi Pasaporte Sensorial
│   ├── strategies/            Estrategias hogar–escuela (y en el aula)
│   ├── history/               Historial y filtros
│   └── settings/              Personalización sensorial, configuración, PIN
└── models/                    Modelos con serialización
branding/                      Imágenes originales (no se empaquetan)
tool/                          Generación de recursos (imágenes y melodía)
firebase/                      firestore.rules, storage.rules, índices
functions/                     Cloud Functions (envío de push, limpieza)
```

Cada repositorio tiene una interfaz y dos implementaciones (demo y Firebase); el
proveedor elige según la modalidad, así que las pantallas son las mismas.

## Recursos gráficos y licencias

- Imagen de la pantalla de carga e icono/logotipo: imágenes proporcionadas para
  el proyecto (`branding/`).
- Melodía de bienvenida: original, generada por código en este proyecto.
- Pictogramas y avatares: emojis del sistema (en Android, Noto Color Emoji,
  SIL OFL 1.1) sobre fichas de diseño propio; los adultos pueden añadir fotos.
- Tipografía: Atkinson Hyperlegible (SIL OFL 1.1, `assets/fonts/OFL.txt`).
