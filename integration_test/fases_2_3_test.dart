// Prueba de punta a punta en el dispositivo (emulador o teléfono) de las
// fases 2 y 3: clases, familias, perfiles infantiles e invitaciones con
// código, con la app real en modo "Solo en este dispositivo". Ejecutar con
// un emulador abierto:
//
//   flutter test integration_test/fases_2_3_test.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_voz/app/app.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Deja correr la app en tiempo real (E/S, animaciones) y redibuja.
Future<void> wait(WidgetTester tester, [int ms = 600]) async {
  await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Espera hasta que [finder] aparezca (máximo [seconds]).
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  int seconds = 15,
}) async {
  for (var i = 0; i < seconds * 2; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await wait(tester, 500);
  }
  fail('No apareció: $finder');
}

Finder verticalList() => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .last;

Future<void> tapKey(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(tester, 300);
  final finder = find.byKey(Key(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 250, scrollable: verticalList());
  }
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await wait(tester, 300);
  await tester.tap(finder);
  await wait(tester);
}

Future<void> type(WidgetTester tester, String key, String text) async {
  final finder = find.byKey(Key(key));
  await waitFor(tester, finder);
  await tester.ensureVisible(finder);
  await tester.enterText(finder, text);
  await wait(tester, 200);
}

/// Botón Atrás del sistema (como en Android).
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await wait(tester, 1000);
}

Future<void> register(
  WidgetTester tester, {
  required String roleKey,
  required String name,
  required String email,
}) async {
  await tapKey(tester, 'welcome-start');
  await tapKey(tester, 'access-create');
  await tapKey(tester, roleKey);
  await type(tester, 'register-name', name);
  await type(tester, 'register-email', email);
  await type(tester, 'register-password', 'clave1234');
  await type(tester, 'register-confirm', 'clave1234');
  await tapKey(tester, 'register-accept');
  await tapKey(tester, 'register-submit');
  await wait(tester, 1500);
}

Future<void> signOut(WidgetTester tester) async {
  await tapKey(tester, 'appbar-switch-user');
  await tapKey(tester, 'switch-sign-out');
  await tester.tap(find.text('Cerrar sesión').last);
  await wait(tester, 1500);
  await waitFor(tester, find.text('Comenzar'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fases 2 y 3 en el dispositivo: clases, familias e invitaciones',
    (tester) async {
      await initializeDateFormatting('es');
      final prefs = await SharedPreferences.getInstance();
      await prefs
          .clear(); // Instalación limpia, sin datos de pruebas anteriores.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            firebaseAvailableProvider.overrideWithValue(false),
          ],
          child: const MiVozApp(),
        ),
      );
      await waitFor(tester, find.text('Comenzar'), seconds: 20);

      // ---- Fase 2: docente sin clases → "Crear mi primera clase" ----
      await register(
        tester,
        roleKey: 'role-teacher',
        name: 'Laura',
        email: 'laura@ejemplo.mx',
      );
      await waitFor(tester, find.text('Aún no tienes clases'));
      await tapKey(tester, 'create-first-class');
      await type(tester, 'class-name', '1.º A');
      await type(tester, 'class-description', 'Grupo de la mañana');
      await tapKey(tester, 'save-class');
      await waitFor(tester, find.textContaining('aún no tiene alumnos'));
      expect(find.text('1.º A'), findsWidgets);

      // ---- Fase 3: la docente genera un código con QR para su clase ----
      await tapKey(tester, 'create-invitation');
      await tapKey(tester, 'invite-create');
      await waitFor(tester, find.byKey(const Key('invitation-qr')));
      final code = tester
          .widget<SelectableText>(find.byKey(const Key('invitation-code')))
          .data!;
      await tester.tap(find.text('Listo'));
      await wait(tester, 800);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byKey(Key('invitation-$code')), findsOneWidget);
      await back(tester);
      await wait(tester, 1000);
      await signOut(tester);

      // ---- Fase 2: tutor crea su familia y el perfil de su hijo ----
      await register(
        tester,
        roleKey: 'role-guardian',
        name: 'Pedro',
        email: 'pedro@ejemplo.mx',
      );
      await tapKey(tester, 'create-family');
      await type(tester, 'family-name', 'Familia Gómez');
      await tapKey(tester, 'save-family');
      await waitFor(tester, find.text('Pedro (tú)'));
      await tapKey(tester, 'family-add-child');
      await type(tester, 'child-name', 'Leo');
      await tapKey(tester, 'save-child');
      await wait(tester, 1500);
      await waitFor(tester, find.text('Leo'));
      expect(find.textContaining('Sin clase vinculada'), findsOneWidget);
      await back(tester);
      await wait(tester, 1000);

      // ---- Fase 3: el tutor canjea el código y elige a su hijo ----
      final linkAction = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('link-class-'),
      );
      await tester.scrollUntilVisible(
        linkAction,
        250,
        scrollable: verticalList(),
      );
      await tester.tap(linkAction.first);
      await wait(tester);
      await type(tester, 'join-code', code);
      await tapKey(tester, 'join-check');
      await waitFor(tester, find.byKey(const Key('join-preview')));
      expect(find.text('1.º A'), findsOneWidget);
      await tester.tap(find.text('Leo'));
      await wait(tester, 400);
      await tapKey(tester, 'join-confirm');
      await waitFor(tester, find.textContaining('Solicitud enviada'));
      await back(tester);
      await wait(tester, 1000);
      await signOut(tester);

      // ---- Fase 3: la docente aprueba y el niño aparece en su clase ----
      await tapKey(tester, 'welcome-start');
      await tapKey(tester, 'access-login');
      await type(tester, 'login-email', 'laura@ejemplo.mx');
      await type(tester, 'login-password', 'clave1234');
      await tapKey(tester, 'login-submit');
      await wait(tester, 1500);
      final approve = find.widgetWithText(FilledButton, 'Aprobar');
      await tester.scrollUntilVisible(approve, 250, scrollable: verticalList());
      expect(
        find.textContaining('quiere vincular a Leo con 1.º A'),
        findsOneWidget,
      );
      await tester.tap(approve);
      await wait(tester, 1500);
      await tapKey(tester, 'open-classes');
      await tapKey(tester, 'class-${_firstClassId(tester)}');
      await waitFor(tester, find.text('Leo'));
      expect(find.textContaining('aún no tiene alumnos'), findsNothing);
    },
  );
}

/// Id de la única clase creada (su tarjeta tiene la clave `class-<id>`).
String _firstClassId(WidgetTester tester) {
  final card = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('class-') &&
        !(w.key! as ValueKey<String>).value.startsWith('class-student'),
  );
  final key = tester.widget(card.first).key! as ValueKey<String>;
  return key.value.substring('class-'.length);
}
