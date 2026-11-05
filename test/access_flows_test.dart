import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/app.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/app/router.dart';
import 'package:mi_voz/app/routes.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/features/access/presentation/kids_access_screen.dart';
import 'package:mi_voz/features/access/presentation/start_screen.dart';
import 'package:mi_voz/features/authentication/presentation/splash_screen.dart';
import 'package:mi_voz/features/child/presentation/child_home_screen.dart';
import 'package:mi_voz/features/teacher/presentation/teacher_home_screen.dart';

import 'helpers.dart';
import 'widget_flows_test.dart' show launch, settle, signedInAs;

/// PIN 1234 en el formato anterior (se acepta y se actualiza al usarlo).
final _pin1234 = sha256.convert(utf8.encode('mivoz-pin:1234')).toString();

/// Perfiles activados en el dispositivo por María.
final _mariaDevice = jsonEncode({
  'demo-juan': DemoSeed.maria.uid,
  'demo-sofia': DemoSeed.maria.uid,
});

/// Toca un elemento por su clave: quita el foco del teclado, lo hace visible
/// (desplazando listas perezosas si hace falta) y espera a que se acomode.
Future<void> tapKey(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(tester, steps: 3);
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      // La lista vertical de la pantalla (los campos de texto también tienen
      // un Scrollable, horizontal).
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .last,
    );
  }
  await tester.ensureVisible(finder);
  await settle(tester, steps: 3);
  await tester.tap(finder);
  await settle(tester);
}

/// Desplaza la lista vertical de la pantalla hasta que [finder] se construya.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .last,
  );
  await settle(tester, steps: 3);
}

/// "Crear una cuenta": abre el selector único, elige el tipo de perfil y
/// pulsa "Continuar".
Future<void> chooseRole(WidgetTester tester, String role) async {
  await tapKey(tester, 'role-selector');
  await tapKey(tester, 'role-option-$role');
  await tapKey(tester, 'role-continue');
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.byKey(const Key('parental-gate-input')), pin);
  await tapKey(tester, 'parental-gate-submit');
}

/// "Comenzar → Iniciar sesión" con correo y contraseña.
Future<void> login(WidgetTester tester, String email, String password) async {
  await tapKey(tester, 'welcome-start');
  await tapKey(tester, 'access-login');
  await tester.enterText(find.byKey(const Key('login-email')), email);
  await tester.enterText(find.byKey(const Key('login-password')), password);
  await tapKey(tester, 'login-submit');
}

Future<ProviderContainer> launchFresh(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeMelodyPlayer? melody,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final sp = await demoPrefs(extra: prefs);
  final container = ProviderContainer(
    overrides: testOverrides(sp, melody: melody),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MiVozApp()),
  );
  return container;
}

void main() {
  group('Pantalla de carga y bienvenida', () {
    testWidgets('muestra la imagen y después la bienvenida con "Comenzar"', (
      tester,
    ) async {
      await launchFresh(tester);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.byKey(const Key('splash-image')), findsOneWidget);
      expect(find.text('“Cada forma de comunicarse importa”'), findsOneWidget);
      expect(find.byKey(const Key('splash-skip')), findsOneWidget);

      await settle(tester, steps: 25);
      expect(find.byType(StartScreen), findsOneWidget);
      expect(find.text('¡Bienvenido a Mi Voz!'), findsOneWidget);
      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.text('Conocer cómo funciona'), findsOneWidget);
      // Sin formularios, perfiles ni cuentas de ejemplo en la bienvenida.
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('demostración'), findsNothing);
      expect(find.textContaining('demo1234'), findsNothing);
    });

    testWidgets('"Omitir" abre la bienvenida al momento', (tester) async {
      await launchFresh(tester);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('splash-skip')));
      await settle(tester, steps: 5);
      expect(find.byType(StartScreen), findsOneWidget);
    });

    testWidgets('sin pantalla de bienvenida no suena la melodía ni se espera', (
      tester,
    ) async {
      final melody = FakeMelodyPlayer();
      await launchFresh(
        tester,
        melody: melody,
        prefs: {
          LocalStore.keyShowSplash: false,
          LocalStore.keyWelcomeMelody: true,
        },
      );
      await settle(tester, steps: 5);
      expect(find.byType(StartScreen), findsOneWidget);
      expect(melody.plays, 0);
    });

    testWidgets('con la melodía autorizada suena una vez al iniciar', (
      tester,
    ) async {
      final melody = FakeMelodyPlayer();
      await launchFresh(
        tester,
        melody: melody,
        prefs: {LocalStore.keyWelcomeMelody: true},
      );
      await settle(tester, steps: 25);
      expect(melody.plays, 1);
    });
  });

  group('Acceso unificado', () {
    testWidgets(
      '"Comenzar" ofrece iniciar sesión o crear una cuenta con un selector',
      (tester) async {
        await launch(tester);
        await tapKey(tester, 'welcome-start');
        expect(find.text('Iniciar sesión'), findsOneWidget);
        expect(find.text('Crear una cuenta'), findsWidgets);
        await tapKey(tester, 'access-create');
        expect(find.text('Selecciona cómo utilizarás Mi Voz'), findsOneWidget);
        expect(find.text('Tipo de perfil'), findsWidgets);
        // Ningún rol viene elegido: "Continuar" pide elegir uno.
        expect(find.text('Selecciona una opción'), findsOneWidget);
        await tapKey(tester, 'role-continue');
        expect(
          find.text('Selecciona un tipo de perfil para continuar.'),
          findsOneWidget,
        );
        // La lista muestra las tres opciones y se cierra al elegir.
        await tapKey(tester, 'role-selector');
        expect(find.text('Docente'), findsWidgets);
        expect(find.text('Padre, madre o tutor'), findsWidgets);
        expect(find.text('Alumno'), findsWidgets);
        await tapKey(tester, 'role-option-guardian');
        expect(find.byKey(const Key('role-option-teacher')), findsNothing);
        final value = tester.widget<Text>(
          find.byKey(const Key('role-selector-value')),
        );
        expect(value.data, 'Padre, madre o tutor');
        expect(find.byKey(const Key('role-login')), findsOneWidget);
      },
    );

    testWidgets('iniciar sesión sin cuentas de ejemplo lleva al panel', (
      tester,
    ) async {
      await launch(tester);
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'access-login');
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      expect(find.textContaining('Cuentas de demostración'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        DemoSeed.maria.email,
      );
      await tester.enterText(find.byKey(const Key('login-password')), 'mala');
      await tapKey(tester, 'login-submit');
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('login-password')),
        DemoSeed.password,
      );
      await tapKey(tester, 'login-submit');
      expect(find.text('¡Hola, María!'), findsOneWidget);
    });

    testWidgets('"Soy alumno": un adulto crea su cuenta y luego el perfil', (
      tester,
    ) async {
      await launch(tester);
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'access-create');
      await chooseRole(tester, 'child');
      expect(
        find.textContaining('no necesita correo ni contraseña'),
        findsOneWidget,
      );
      await tapKey(tester, 'student-adult-register');
      await tester.enterText(find.byKey(const Key('register-name')), 'Rosa');
      await tester.enterText(
        find.byKey(const Key('register-email')),
        'rosa@ejemplo.mx',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'clave1234',
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm')),
        'clave1234',
      );
      await tapKey(tester, 'register-accept');
      await tapKey(tester, 'register-submit');
      // Pasa directamente a crear el perfil infantil (sin correo ni contraseña).
      expect(find.text('Nuevo perfil infantil'), findsOneWidget);
      expect(find.textContaining('Correo'), findsNothing);
      await tester.enterText(find.byKey(const Key('child-name')), 'Tito');
      await tapKey(tester, 'save-child');
      await scrollTo(tester, find.text('Entrar al perfil de Tito'));
      expect(find.text('Entrar al perfil de Tito'), findsOneWidget);
    });

    testWidgets('"Conocer cómo funciona" recorre pasos sin tocar los datos', (
      tester,
    ) async {
      final container = await launch(tester);
      final db = container.read(demoDatabaseProvider);
      final usersBefore = db.all(DemoDatabase.users).length;
      final requestsBefore = db.all(DemoDatabase.requests).length;

      await tapKey(tester, 'welcome-tour');
      expect(find.text('¿Qué perfil quieres conocer?'), findsOneWidget);
      await tapKey(tester, 'tour-role-teacher');
      expect(find.textContaining('Paso 1 de'), findsOneWidget);
      await tapKey(tester, 'tour-next');
      expect(find.textContaining('Paso 2 de'), findsOneWidget);
      await tapKey(tester, 'tour-previous');
      expect(find.textContaining('Paso 1 de'), findsOneWidget);
      while (find.byKey(const Key('tour-next')).evaluate().isNotEmpty) {
        await tapKey(tester, 'tour-next');
      }
      await tapKey(tester, 'tour-finish');
      expect(find.byType(StartScreen), findsOneWidget);

      expect(db.all(DemoDatabase.users).length, usersBefore);
      expect(db.all(DemoDatabase.requests).length, requestsBefore);
      expect(container.read(currentUserProvider), isNull);
    });
  });

  group('Sesión guardada en un dispositivo compartido', () {
    testWidgets('el niño elige su perfil activado y entra sin contraseña', (
      tester,
    ) async {
      await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyDeviceChildren: _mariaDevice,
        },
      );
      expect(find.byType(KidsAccessScreen), findsOneWidget);
      expect(find.byKey(const Key('kid-enter-demo-juan')), findsOneWidget);
      await tapKey(tester, 'kid-enter-demo-sofia');
      expect(find.byType(ChildHomeScreen), findsOneWidget);
      expect(find.text('¡Hola, Sofía!'), findsOneWidget);
    });

    testWidgets('el panel del adulto pide el PIN', (tester) async {
      await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyDeviceChildren: _mariaDevice,
          LocalStore.keyParentPin: _pin1234,
        },
      );
      await tapKey(tester, 'kids-adult-panel');
      expect(find.text('Solo para adultos'), findsOneWidget);
      await enterPin(tester, '9999');
      expect(find.text('PIN incorrecto.'), findsOneWidget);
      await enterPin(tester, '1234');
      expect(find.text('¡Hola, María!'), findsOneWidget);
    });

    testWidgets('sin PIN se pide la contraseña de la cuenta (no una suma)', (
      tester,
    ) async {
      await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyDeviceChildren: _mariaDevice,
        },
      );
      await tapKey(tester, 'kids-adult-panel');
      expect(find.byKey(const Key('parental-gate-password')), findsOneWidget);
      expect(find.textContaining('¿Cuánto es'), findsNothing);
      await tester.enterText(
        find.byKey(const Key('parental-gate-password')),
        'incorrecta',
      );
      await tapKey(tester, 'parental-gate-submit');
      expect(find.text('Contraseña incorrecta.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('parental-gate-password')),
        DemoSeed.password,
      );
      await tapKey(tester, 'parental-gate-submit');
      expect(find.text('¡Hola, María!'), findsOneWidget);
    });

    testWidgets('tras varios intentos fallidos se bloquea la verificación', (
      tester,
    ) async {
      await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyDeviceChildren: _mariaDevice,
          LocalStore.keyParentPin: _pin1234,
        },
      );
      await tapKey(tester, 'kids-adult-panel');
      for (var i = 0; i < 5; i++) {
        await enterPin(tester, '0000');
      }
      expect(find.textContaining('Demasiados intentos'), findsOneWidget);
      // Incluso el PIN correcto se rechaza mientras dura el bloqueo.
      await enterPin(tester, '1234');
      expect(find.textContaining('Demasiados intentos'), findsOneWidget);
      expect(find.text('¡Hola, María!'), findsNothing);
    });

    testWidgets('el botón Atrás no saca al niño del modo niño', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
      );
      await tapKey(tester, 'category-quiero');
      final router = container.read(routerProvider);
      router.pop();
      await settle(tester);
      router.go(Routes.start);
      await settle(tester);
      expect(find.byType(ChildHomeScreen), findsOneWidget);
    });
  });

  group('Permisos del docente', () {
    testWidgets('no puede crear perfiles infantiles', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.ana.uid),
      );
      container.read(routerProvider).go(Routes.kidNew);
      await settle(tester);
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
      expect(find.text('Nuevo perfil infantil'), findsNothing);
    });

    testWidgets('muestra sus alumnos y permite cambiar de alumno', (
      tester,
    ) async {
      await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
      expect(find.text('¡Hola, Maestra Ana!'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('current-student-name'))).data,
        'Juan',
      );
      await tapKey(tester, 'change-student');
      expect(find.text('Selecciona un alumno'), findsOneWidget);
      expect(find.byKey(const Key('select-child-demo-mateo')), findsOneWidget);
      expect(find.byKey(const Key('select-child-demo-sofia')), findsNothing);
      await tapKey(tester, 'select-child-demo-mateo');
      expect(
        tester.widget<Text>(find.byKey(const Key('current-student-name'))).data,
        'Mateo',
      );
    });

    testWidgets('no muestra información de alumnos no autorizados', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.ana.uid),
      );
      container.read(routerProvider).push(Routes.passport('demo-sofia'));
      await settle(tester);
      expect(find.text('No tienes acceso a este perfil'), findsOneWidget);
    });
  });

  group('Cambiar perfil', () {
    testWidgets('el padre cambia del perfil de Juan al de Sofía con PIN', (
      tester,
    ) async {
      await launch(
        tester,
        prefs: {
          ...signedInAs(DemoSeed.maria.uid),
          LocalStore.keyParentPin: _pin1234,
        },
      );
      await tapKey(tester, 'enter-profile-demo-juan');
      await tapKey(tester, 'confirm-child-mode');
      expect(find.text('¡Hola, Juan!'), findsOneWidget);

      await tapKey(tester, 'exit-child-mode');
      await enterPin(tester, '1234');
      expect(find.text('¿Quién utilizará Mi Voz?'), findsOneWidget);
      await tapKey(tester, 'select-child-demo-sofia');
      await tapKey(tester, 'confirm-child-mode');
      expect(find.text('¡Hola, Sofía!'), findsOneWidget);
    });

    testWidgets('sin PIN, entrar al modo infantil ofrece crearlo', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await tapKey(tester, 'enter-profile-demo-juan');
      await tapKey(tester, 'confirm-child-mode');
      expect(find.text('PIN de adulto'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('pin-input')), '2468');
      await tester.enterText(find.byKey(const Key('pin-confirm')), '2468');
      await tapKey(tester, 'pin-save');
      expect(find.text('¡Hola, Juan!'), findsOneWidget);
      final stored = container
          .read(sharedPreferencesProvider)
          .getString(LocalStore.keyParentPin)!;
      expect(stored, startsWith('v2:'), reason: 'hash con sal, nunca el PIN');
      expect(stored, isNot(contains('2468')));
    });

    testWidgets('entrar con otra cuenta cierra la sesión y abre el acceso', (
      tester,
    ) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await tapKey(tester, 'appbar-switch-user');
      expect(find.byKey(const Key('switch-adult-panel')), findsOneWidget);
      await tapKey(tester, 'switch-account');
      await tester.tap(find.text('Cerrar sesión y cambiar'));
      await settle(tester);

      expect(container.read(currentUserProvider), isNull);
      expect(find.byKey(const Key('login-email')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('login-email')),
        DemoSeed.ana.email,
      );
      await tester.enterText(
        find.byKey(const Key('login-password')),
        DemoSeed.password,
      );
      await tapKey(tester, 'login-submit');
      expect(find.text('¡Hola, Maestra Ana!'), findsOneWidget);
      expect(find.text('¡Hola, María!'), findsNothing);
    });

    testWidgets('cerrar sesión vuelve a la bienvenida', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await tapKey(tester, 'appbar-switch-user');
      await tapKey(tester, 'switch-sign-out');
      await tester.tap(find.text('Cerrar sesión').last);
      await settle(tester);
      expect(container.read(currentUserProvider), isNull);
      expect(find.byType(StartScreen), findsOneWidget);
    });
  });

  group('Registro y perfiles', () {
    testWidgets('registro de docente con sus datos opcionales', (tester) async {
      await launch(tester);
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'access-create');
      await chooseRole(tester, 'teacher');
      expect(find.text('Registro de docente'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register-name')), 'Laura');
      await tester.enterText(
        find.byKey(const Key('register-last-name')),
        'Ríos',
      );
      await tapKey(tester, 'teacher-title-Maestra');
      await tester.enterText(
        find.byKey(const Key('register-school')),
        'Escuela Sol',
      );
      await tester.enterText(
        find.byKey(const Key('register-email')),
        'laura@ejemplo.mx',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'clave1234',
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm')),
        'clave1234',
      );
      await tapKey(tester, 'register-accept');
      await tapKey(tester, 'register-submit');

      // Después del registro: crear la clase o unirse con un código.
      expect(find.text('¿Creas una clase o te unes a una?'), findsOneWidget);
      expect(find.byKey(const Key('setup-create')), findsOneWidget);
      expect(find.byKey(const Key('setup-join')), findsOneWidget);
      await tapKey(tester, 'setup-skip');
      expect(find.byType(TeacherHomeScreen), findsOneWidget);
      expect(find.text('¡Hola, Maestra Laura!'), findsOneWidget);
      await scrollTo(tester, find.text('Aún no tienes alumnos vinculados'));
      expect(find.text('Aún no tienes alumnos vinculados'), findsOneWidget);
    });

    testWidgets('registro de familia y creación de un perfil infantil', (
      tester,
    ) async {
      await launch(tester);
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'access-create');
      await chooseRole(tester, 'guardian');
      expect(find.text('Registro de familia'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('register-name')), 'Pedro');
      await tapKey(tester, 'relation-padre');
      await tester.enterText(
        find.byKey(const Key('register-email')),
        'pedro@ejemplo.mx',
      );
      await tester.enterText(
        find.byKey(const Key('register-password')),
        'clave1234',
      );
      await tester.enterText(
        find.byKey(const Key('register-confirm')),
        'clave1234',
      );
      await tapKey(tester, 'register-accept');
      await tapKey(tester, 'register-submit');
      expect(find.text('¿Creas tu familia o te unes a una?'), findsOneWidget);
      await tapKey(tester, 'setup-skip');
      expect(find.text('¡Hola, Pedro!'), findsOneWidget);

      await tapKey(tester, 'home-create-child');
      expect(find.text('Nuevo perfil infantil'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('child-name')), 'Leo');
      await tapKey(tester, 'avatar-option-animal_panda');
      await tapKey(tester, 'save-child');
      await scrollTo(tester, find.text('Entrar al perfil de Leo'));
      expect(find.text('Entrar al perfil de Leo'), findsOneWidget);
    });

    testWidgets('editar nombre y avatar en "Mi perfil"', (tester) async {
      final container = await launch(
        tester,
        prefs: signedInAs(DemoSeed.maria.uid),
      );
      await tapKey(tester, 'appbar-my-profile');
      expect(find.text('maria@demo.mivoz'), findsOneWidget);
      await tapKey(tester, 'edit-my-profile');
      await tester.enterText(find.byKey(const Key('profile-name')), 'Mariana');
      await tapKey(tester, 'avatar-option-character_flower');
      await tapKey(tester, 'save-profile');
      // Se guarda el identificador del avatar, no su posición ni un emoji.
      expect(container.read(currentUserProvider)?.avatar, 'character_flower');
      expect(
        tester.widget<Text>(find.byKey(const Key('my-profile-name'))).data,
        'Mariana López',
      );
    });
  });
}
