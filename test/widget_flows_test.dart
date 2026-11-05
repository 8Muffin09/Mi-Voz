import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/app.dart';
import 'package:mi_voz/app/router.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/features/child/presentation/child_home_screen.dart';
import 'package:mi_voz/features/communication/application/outbox.dart';
import 'package:mi_voz/features/settings/presentation/general_settings_screen.dart';

import 'helpers.dart';

/// Avanza el reloj de prueba en pasos (evita esperar animaciones infinitas).
Future<void> settle(WidgetTester tester, {int steps = 20}) async {
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<ProviderContainer> launch(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
  FakeSpeechService? speech,
  FakeConnectivity? connectivity,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final sp = await demoPrefs(extra: prefs);
  final container = ProviderContainer(
    overrides: testOverrides(sp, speech: speech, connectivity: connectivity),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MiVozApp()),
  );
  await settle(tester, steps: 25); // splash
  return container;
}

Map<String, Object> signedInAs(String uid, {String? childMode}) => {
  LocalStore.keyDemoSession: uid,
  LocalStore.keyChildMode: ?childMode,
};

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}

void main() {
  testWidgets('inicio de sesión de un adulto lleva a su panel', (tester) async {
    await launch(tester);
    // Bienvenida → "Comenzar" → "Iniciar sesión".
    await tapKey(tester, 'welcome-start');
    await tapKey(tester, 'access-login');
    await tester.enterText(
      find.byKey(const Key('login-email')),
      DemoSeed.maria.email,
    );
    await tester.enterText(
      find.byKey(const Key('login-password')),
      DemoSeed.password,
    );
    await tapKey(tester, 'login-submit');
    expect(find.text('¡Hola, María!'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Juan'), 300);
    expect(find.text('Juan'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Sofía'), 300);
    expect(find.text('Sofía'), findsWidgets);
  });

  testWidgets('el niño forma "Quiero agua", la escucha y la comunica', (
    tester,
  ) async {
    final speech = FakeSpeechService();
    await launch(
      tester,
      speech: speech,
      prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
    );
    expect(find.byType(ChildHomeScreen), findsOneWidget);
    expect(find.text('¡Hola, Juan!'), findsOneWidget);

    await tapKey(tester, 'category-quiero');
    await tapKey(tester, 'pictogram-quiero_agua');
    expect(find.byKey(const Key('phrase-text')), findsOneWidget);
    expect(find.text('Quiero agua'), findsOneWidget);

    // Modificar sin escribir: agregar "por favor".
    await tapKey(tester, 'toggle-polite');
    expect(find.text('Quiero agua, por favor'), findsOneWidget);

    await tapKey(tester, 'action-listen');
    expect(speech.spoken.last, 'Quiero agua, por favor');

    await tapKey(tester, 'action-communicate');
    expect(find.byKey(const Key('communicated-message')), findsOneWidget);
    expect(find.byKey(const Key('status-delivered')), findsOneWidget);
    expect(find.textContaining('Aviso enviado a María López'), findsOneWidget);
    // Enviar no es lo mismo que ser visto: no se dice que alguien lo vio.
    expect(find.textContaining('ya lo vio'), findsNothing);
  });

  testWidgets('sin conexión la solicitud se muestra "Pendiente de envío"', (
    tester,
  ) async {
    final container = await launch(
      tester,
      prefs: {
        ...signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
        LocalStore.keyDemoOffline: true,
      },
    );
    await tapKey(tester, 'quick-phrases');
    await tapKey(tester, 'phrase-fp_agua');
    expect(find.text('Necesito agua'), findsWidgets);
    await tapKey(tester, 'action-communicate');
    expect(find.byKey(const Key('status-pending')), findsOneWidget);
    expect(find.text('Todavía no se envió'), findsOneWidget);
    expect(find.byKey(const Key('status-delivered')), findsNothing);

    // Vuelve la conexión: la misma pantalla pasa a "Enviada".
    await container.read(demoOfflineProvider.notifier).set(false);
    await settle(tester);
    expect(find.byKey(const Key('status-delivered')), findsOneWidget);
    expect(container.read(outboxProvider), isEmpty);
  });

  testWidgets('ayuda urgente pide confirmación y envía prioridad alta', (
    tester,
  ) async {
    final speech = FakeSpeechService();
    await launch(
      tester,
      speech: speech,
      prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
    );
    await tapKey(tester, 'urgent-button');
    await tapKey(tester, 'urgent-urg_miedo');
    expect(find.text('¿Quieres avisar a tu adulto?'), findsOneWidget);

    // "No" vuelve a las opciones sin enviar.
    await tapKey(tester, 'urgent-cancel');
    expect(find.text('¿Qué te pasa?'), findsOneWidget);

    await tapKey(tester, 'urgent-urg_miedo');
    await tapKey(tester, 'urgent-confirm');
    expect(find.text('Tengo miedo'), findsWidgets);
    expect(find.byKey(const Key('status-delivered')), findsOneWidget);
    expect(speech.spoken, contains('Tengo miedo'));
  });

  testWidgets('el modo niño no permite abrir herramientas de adulto', (
    tester,
  ) async {
    final container = await launch(
      tester,
      prefs: signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
    );
    container.read(routerProvider).go('/adult/settings');
    await settle(tester);
    expect(find.byType(ChildHomeScreen), findsOneWidget);
    expect(find.text('Configuración'), findsNothing);
  });

  testWidgets('salir del modo niño exige el PIN de adulto', (tester) async {
    final pinHash = sha256.convert(utf8.encode('mivoz-pin:1234')).toString();
    await launch(
      tester,
      prefs: {
        ...signedInAs(DemoSeed.maria.uid, childMode: 'demo-juan'),
        LocalStore.keyParentPin: pinHash,
      },
    );
    await tapKey(tester, 'exit-child-mode');
    await tester.enterText(
      find.byKey(const Key('parental-gate-input')),
      '0000',
    );
    await tapKey(tester, 'parental-gate-submit');
    expect(find.text('PIN incorrecto.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('parental-gate-input')),
      '1234',
    );
    await tapKey(tester, 'parental-gate-submit');
    expect(find.byType(ChildHomeScreen), findsNothing);
    // "Cambiar usuario" vuelve al selector de perfiles autorizados.
    expect(find.text('¿Quién utilizará Mi Voz?'), findsOneWidget);
  });

  testWidgets('la maestra activa "Estoy acompañando a Juan"', (tester) async {
    await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
    // Con la sesión guardada no se pide la contraseña: abre su panel.
    expect(find.text('¡Hola, Maestra Ana!'), findsOneWidget);
    expect(find.text('Acompaña: María López'), findsOneWidget);

    await tapKey(tester, 'accompany-demo-juan');
    expect(find.text('Tú estás acompañando a Juan'), findsOneWidget);
  });
}
