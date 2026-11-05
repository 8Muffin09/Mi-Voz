import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';

import 'access_flows_test.dart' show chooseRole, scrollTo, tapKey;
import 'widget_flows_test.dart' show launch, settle, signedInAs;

/// Registra una cuenta nueva desde la bienvenida.
Future<void> registerAs(
  WidgetTester tester, {
  required String roleKey,
  required String name,
  required String email,
}) async {
  await tapKey(tester, 'welcome-start');
  await tapKey(tester, 'access-create');
  await chooseRole(tester, roleKey.replaceFirst('role-', ''));
  await tester.enterText(find.byKey(const Key('register-name')), name);
  await tester.enterText(find.byKey(const Key('register-email')), email);
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
  // Paso "Tu clase" / "Tu familia": se deja para después.
  await tapKey(tester, 'setup-skip');
}

void main() {
  group('Clases del docente', () {
    testWidgets('sin clases muestra "Crear mi primera clase" y la crea', (
      tester,
    ) async {
      await launch(tester);
      await registerAs(
        tester,
        roleKey: 'role-teacher',
        name: 'Laura',
        email: 'laura@ejemplo.mx',
      );
      expect(find.text('Aún no tienes clases'), findsOneWidget);
      await tapKey(tester, 'create-first-class');
      await tester.enterText(find.byKey(const Key('class-name')), '1.º A');
      await tester.enterText(
        find.byKey(const Key('class-description')),
        'Grupo de la mañana',
      );
      await tapKey(tester, 'save-class');
      // Detalle de la clase recién creada, todavía sin alumnos.
      expect(find.text('1.º A'), findsWidgets);
      expect(find.textContaining('aún no tiene alumnos'), findsOneWidget);

      // Agregar alumno: sin alumnos autorizados, explica cómo incorporarlos.
      await tapKey(tester, 'add-student');
      expect(
        find.text('No hay más alumnos autorizados para agregar.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'la docente ve su clase y retira a un alumno con confirmación',
      (tester) async {
        await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
        await tapKey(tester, 'open-classes');
        expect(find.text('Mis clases'), findsOneWidget);
        await tapKey(tester, 'class-${DemoSeed.class2b}');
        expect(
          find.byKey(const Key('class-student-demo-juan')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('class-student-demo-mateo')),
          findsOneWidget,
        );

        await tapKey(tester, 'remove-student-demo-mateo');
        expect(find.text('Retirar a Mateo'), findsOneWidget);
        await tester.tap(find.text('Retirar'));
        await settle(tester);
        expect(find.byKey(const Key('class-student-demo-mateo')), findsNothing);
        expect(
          find.byKey(const Key('class-student-demo-juan')),
          findsOneWidget,
        );
      },
    );

    testWidgets('archivar una clase pide confirmación y se puede reactivar', (
      tester,
    ) async {
      await launch(tester, prefs: signedInAs(DemoSeed.ana.uid));
      await tapKey(tester, 'open-classes');
      await tapKey(tester, 'class-${DemoSeed.class2b}');
      await tapKey(tester, 'class-menu');
      await tester.tap(find.text('Archivar clase'));
      await settle(tester);
      await tester.tap(find.text('Archivar'));
      await settle(tester);
      expect(find.text('Clase archivada'), findsOneWidget);
      expect(find.byKey(const Key('add-student')), findsNothing);

      await tapKey(tester, 'class-menu');
      await tester.tap(find.text('Reactivar clase'));
      await settle(tester);
      await tester.tap(find.text('Reactivar'));
      await settle(tester);
      expect(find.text('Clase archivada'), findsNothing);
    });
  });

  group('Familia', () {
    testWidgets('un tutor nuevo crea su familia desde el panel', (
      tester,
    ) async {
      await launch(tester);
      await registerAs(
        tester,
        roleKey: 'role-guardian',
        name: 'Pedro',
        email: 'pedro@ejemplo.mx',
      );
      await scrollTo(tester, find.text('Crea tu familia'));
      await tapKey(tester, 'create-family');
      await tester.enterText(
        find.byKey(const Key('family-name')),
        'Familia Gómez',
      );
      await tapKey(tester, 'save-family');
      expect(find.text('Familia Gómez'), findsWidgets);
      expect(find.text('Pedro (tú)'), findsOneWidget);
      expect(
        find.text('Aún no hay perfiles infantiles en esta familia.'),
        findsOneWidget,
      );
    });

    testWidgets('la familia muestra a sus adultos y a sus niños', (
      tester,
    ) async {
      await launch(tester, prefs: signedInAs(DemoSeed.maria.uid));
      await scrollTo(
        tester,
        find.byKey(Key('family-card-${DemoSeed.familyLopez}')),
      );
      await tapKey(tester, 'family-card-${DemoSeed.familyLopez}');
      expect(find.byKey(const Key('family-child-demo-juan')), findsOneWidget);
      expect(find.byKey(const Key('family-child-demo-sofia')), findsOneWidget);
      await scrollTo(
        tester,
        find.byKey(Key('family-adult-${DemoSeed.luis.uid}')),
      );
      expect(find.text('María López (tú)'), findsOneWidget);
      // La administradora puede retirar a Luis, pero nadie a ella.
      expect(
        find.byKey(Key('remove-family-adult-${DemoSeed.luis.uid}')),
        findsOneWidget,
      );
      expect(
        find.byKey(Key('remove-family-adult-${DemoSeed.maria.uid}')),
        findsNothing,
      );
    });

    testWidgets('la administradora decide quién recibe solicitudes', (
      tester,
    ) async {
      await launch(tester, prefs: signedInAs(DemoSeed.maria.uid));
      await scrollTo(
        tester,
        find.byKey(Key('family-card-${DemoSeed.familyLopez}')),
      );
      await tapKey(tester, 'family-card-${DemoSeed.familyLopez}');
      await tapKey(tester, 'family-child-demo-juan');
      await tester.tap(find.text('Luis Pérez'));
      await settle(tester);
      expect(find.text('Permisos de Luis Pérez'), findsOneWidget);
      await tapKey(tester, 'perm-receives');
      await tapKey(tester, 'perm-save');
      expect(find.textContaining('No recibe solicitudes'), findsOneWidget);
    });
  });
}
