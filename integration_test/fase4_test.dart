// Prueba en el dispositivo (emulador o teléfono) de la fase 4: regla "si
// nadie acompaña" y estados honestos del envío, con la app real en modo
// "Solo en este dispositivo". Ejecutar con un emulador abierto:
//
//   flutter test integration_test/fase4_test.dart -d emulator-5554
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_voz/app/app.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fases_2_3_test.dart'
    show back, register, tapKey, type, verticalList, wait, waitFor;

/// Id del niño a partir de la clave `adults-<id>` de su tarjeta.
String _childId(WidgetTester tester) {
  final chip = find.byWidgetPredicate(
    (w) =>
        w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('adults-'),
  );
  final key = tester.widget(chip.first).key! as ValueKey<String>;
  return key.value.substring('adults-'.length);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('fase 4 en el dispositivo: a quién se avisa y qué ve el niño', (
    tester,
  ) async {
    await initializeDateFormatting('es');
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
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

    // Familia con un niño; nadie marcó "Estoy acompañando".
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
    await back(tester);

    // Regla por defecto: solo el administrador (no "todos").
    final adults = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('adults-'),
    );
    await tester.scrollUntilVisible(adults, 250, scrollable: verticalList());
    final childId = _childId(tester);
    await tapKey(tester, 'adults-$childId');
    await waitFor(tester, find.byKey(const Key('no-companion-rule')));
    expect(find.text('Nadie acompaña a Leo ahora'), findsOneWidget);
    expect(
      find.textContaining('solo al administrador del perfil (Pedro'),
      findsOneWidget,
    );

    // El administrador la cambia a "todos" de forma explícita.
    await tapKey(tester, 'no-companion-rule');
    await tapKey(tester, 'rule-all');
    await tapKey(tester, 'rule-save');
    await wait(tester, 800);
    expect(
      find.textContaining('a todos los adultos autorizados'),
      findsOneWidget,
    );
    await back(tester);

    // El niño comunica algo: ve a quién se avisó y que aún nadie lo vio.
    await tapKey(tester, 'enter-profile-$childId');
    await tapKey(tester, 'confirm-child-mode');
    await tapKey(tester, 'pin-cancel');
    await wait(tester, 1500);
    await tapKey(tester, 'quick-phrases');
    await tapKey(tester, 'phrase-fp_agua');
    await tapKey(tester, 'action-communicate');
    await waitFor(tester, find.byKey(const Key('status-delivered')));
    expect(find.textContaining('Aviso enviado a Pedro'), findsOneWidget);
    // En este modo el aviso es simulado y así se indica.
    expect(find.textContaining('Aviso simulado'), findsOneWidget);
    expect(find.textContaining('ya lo vio'), findsNothing);

    // Ayuda urgente: confirmación y el mismo seguimiento honesto.
    await tapKey(tester, 'back-home');
    await wait(tester, 1000);
    await tapKey(tester, 'urgent-button');
    await tapKey(tester, 'urgent-urg_miedo');
    await tapKey(tester, 'urgent-confirm');
    await waitFor(tester, find.byKey(const Key('status-delivered')));
    expect(find.textContaining('Aviso enviado a Pedro'), findsOneWidget);
  });
}
