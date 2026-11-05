import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/authentication/application/session_actions.dart';
import 'package:mi_voz/features/authentication/data/demo_auth_repository.dart';
import 'package:mi_voz/features/profiles/application/profiles_providers.dart';
import 'package:mi_voz/features/settings/application/parental_pin.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  group('Modo local sin cuentas de ejemplo', () {
    test('la base local empieza vacía fuera de las pruebas', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = DemoDatabase(LocalStore(prefs));
      expect(db.all(DemoDatabase.users), isEmpty);
      expect(db.all(DemoDatabase.children), isEmpty);
    });

    test('los datos locales existentes se conservan al actualizar', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = LocalStore(prefs);
      DemoDatabase(store, seedSampleData: true);
      // Una versión nueva de la app abre la misma base sin datos de ejemplo.
      final reopened = DemoDatabase(store);
      expect(reopened.get(DemoDatabase.users, DemoSeed.maria.uid), isNotNull);
    });

    test(
      'no restablece contraseñas sin poder verificar la identidad',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = DemoDatabase(LocalStore(prefs), seedSampleData: true);
        final auth = DemoAuthRepository(db);
        await expectLater(
          auth.sendPasswordReset(DemoSeed.maria.email),
          throwsA(isA<AppException>()),
        );
        // La contraseña no cambió.
        final user = await auth.signIn(
          email: DemoSeed.maria.email,
          password: DemoSeed.password,
        );
        expect(user.uid, DemoSeed.maria.uid);
      },
    );
  });

  group('PIN de adulto', () {
    test('se guarda con sal e iteraciones, nunca el PIN', () async {
      final c = await demoContainer();
      addTearDown(c.dispose);
      final pin = c.read(parentalPinProvider.notifier);
      await pin.setPin('4321');
      final stored = c
          .read(sharedPreferencesProvider)
          .getString(LocalStore.keyParentPin)!;
      expect(stored, startsWith('v2:'));
      expect(stored, isNot(contains('4321')));
      expect(pin.verify('4321'), isTrue);
      expect(pin.verify('1234'), isFalse);

      // Otra sal para el mismo PIN: el hash cambia.
      await pin.setPin('4321');
      expect(
        c.read(sharedPreferencesProvider).getString(LocalStore.keyParentPin),
        isNot(stored),
      );
    });

    test('un PIN del formato anterior se acepta y se actualiza', () async {
      final legacy = sha256.convert(utf8.encode('mivoz-pin:1234')).toString();
      final c = await demoContainer(extra: {LocalStore.keyParentPin: legacy});
      addTearDown(c.dispose);
      final pin = c.read(parentalPinProvider.notifier);
      expect(await pin.attempt('1234'), isTrue);
      expect(
        c.read(sharedPreferencesProvider).getString(LocalStore.keyParentPin),
        startsWith('v2:'),
      );
      expect(await pin.attempt('1234'), isTrue);
    });

    test('se bloquea tras 5 fallos y el bloqueo crece', () async {
      final c = await demoContainer();
      addTearDown(c.dispose);
      final pin = c.read(parentalPinProvider.notifier);
      await pin.setPin('1234');
      for (var i = 0; i < 4; i++) {
        expect(await pin.attempt('0000'), isFalse);
      }
      expect(pin.lockRemaining(), isNull, reason: 'aún sin bloqueo');
      expect(await pin.attempt('0000'), isFalse);
      final first = pin.lockRemaining()!;
      expect(first, lessThanOrEqualTo(ParentalPinNotifier.baseLock));
      // Bloqueado: ni el PIN correcto entra.
      expect(await pin.attempt('1234'), isFalse);

      await pin.registerFailure();
      expect(pin.lockRemaining()!, greaterThan(first));

      // Al terminar el bloqueo y acertar, se reinicia el contador.
      await pin.resetFailures();
      expect(await pin.attempt('1234'), isTrue);
      expect(pin.failures, 0);
    });
  });

  group('Cambio de cuenta', () {
    test('los datos de un niño no quedan en memoria para otra cuenta', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      c.listen(childProvider('demo-sofia'), (_, _) {});
      expect((await c.read(childProvider('demo-sofia').future))?.name, 'Sofía');

      await c.read(sessionActionsProvider).switchAccount();
      await c
          .read(sessionActionsProvider)
          .signIn(DemoSeed.ana.email, DemoSeed.password);
      for (var i = 0; i < 6; i++) {
        await flush();
      }
      expect(c.read(sessionUidProvider), DemoSeed.ana.uid);
      // Ana no está vinculada a Sofía: el proveedor se reconstruyó y no la ve.
      expect(c.read(childProvider('demo-sofia')).value, isNull);
    });

    test('elegir "docente" no da acceso a alumnos ajenos', () async {
      final c = await signedInContainer(null);
      addTearDown(c.dispose);
      await c
          .read(sessionActionsProvider)
          .register(
            email: 'nueva@ejemplo.mx',
            password: 'clave1234',
            displayName: 'Nueva Docente',
            role: DemoSeed.ana.role,
            experiences: DemoSeed.ana.experiences,
          );
      for (var i = 0; i < 6; i++) {
        await flush();
      }
      expect(await c.read(childrenProvider.future), isEmpty);
      final repo = c.read(childrenRepositoryProvider);
      expect(await repo.watchChild('demo-juan').first, isNull);
      expect(await repo.watchChild('demo-mateo').first, isNull);
    });
  });
}
