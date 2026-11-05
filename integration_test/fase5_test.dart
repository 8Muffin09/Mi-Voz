// Prueba en el dispositivo (emulador o teléfono) de la fase 5: tutorial
// interactivo con elementos resaltados, sin tocar datos, y con el texto del
// sistema al 200 %. Ejecutar con un emulador abierto:
//
//   flutter test integration_test/fase5_test.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_voz/app/app.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fases_2_3_test.dart' show tapKey, wait, waitFor;

Finder _target() => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('tour-target-'),
);

Future<void> _runTour(WidgetTester tester, String role, int steps) async {
  await tapKey(tester, 'welcome-tour');
  await tapKey(tester, 'tour-role-$role');
  for (var step = 1; step <= steps; step++) {
    debugPrint('TOUR $role paso $step');
    await waitFor(tester, find.textContaining('Paso $step de $steps'));
    var taps = 0;
    while (_target().evaluate().isNotEmpty && taps < 6) {
      await tester.ensureVisible(_target().first);
      await wait(tester, 300);
      await tester.tap(_target().first);
      await wait(tester, 400);
      taps++;
    }
    expect(taps, greaterThan(0), reason: '$role, paso $step');
    expect(find.byKey(const Key('tour-demo-done')), findsOneWidget);
    await tapKey(tester, step == steps ? 'tour-finish' : 'tour-next');
  }
  await waitFor(tester, find.text('Comenzar'));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fase 5 en el dispositivo: tutorial interactivo', (tester) async {
    await initializeDateFormatting('es');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firebaseAvailableProvider.overrideWithValue(false),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MiVozApp()),
    );
    await waitFor(tester, find.text('Comenzar'), seconds: 20);

    await _runTour(tester, 'guardian', 8);

    // Con el texto del sistema al 200 %, el recorrido sigue sin desbordes.
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await wait(tester, 800);
    await _runTour(tester, 'child', 4);
    expect(tester.takeException(), isNull);

    // El tutorial no creó cuentas ni datos.
    final db = container.read(demoDatabaseProvider);
    expect(db.all(DemoDatabase.users), isEmpty);
    expect(db.all(DemoDatabase.children), isEmpty);
    expect(db.all(DemoDatabase.requests), isEmpty);
    expect(container.read(currentUserProvider), isNull);
  });
}
