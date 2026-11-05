import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/features/authentication/application/session_actions.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/family.dart';

import 'helpers.dart';

void main() {
  group('Eliminar cuenta y datos (modo local)', () {
    test(
      'la docente: su clase se cierra y pierde el acceso a los alumnos',
      () async {
        final c = await signedInContainer(DemoSeed.ana.uid);
        addTearDown(c.dispose);
        final db = c.read(demoDatabaseProvider);

        await c
            .read(sessionActionsProvider)
            .deleteAccountAndData(DemoSeed.password);

        expect(db.get(DemoDatabase.classes, DemoSeed.class2b), isNull);
        for (final id in ['demo-juan', 'demo-mateo']) {
          final child = ChildProfile.fromMap(
            db.get(DemoDatabase.children, id)!,
          );
          expect(
            child.memberUids,
            isNot(contains(DemoSeed.ana.uid)),
            reason: id,
          );
          expect(child.classIds, isNot(contains(DemoSeed.class2b)), reason: id);
          expect(
            db.get(DemoDatabase.links, '${id}_${DemoSeed.ana.uid}'),
            isNull,
          );
        }
        // Los datos de los niños se conservan para sus familias.
        expect(
          ChildProfile.fromMap(db.get(DemoDatabase.children, 'demo-mateo')!)
              .memberUids,
          [DemoSeed.carlos.uid],
        );
        expect(db.get(DemoDatabase.users, DemoSeed.ana.uid), isNull);
      },
    );

    test(
      'la administradora: sus niños se borran y la familia pasa al otro tutor',
      () async {
        final c = await signedInContainer(DemoSeed.maria.uid);
        addTearDown(c.dispose);
        final db = c.read(demoDatabaseProvider);

        await c
            .read(sessionActionsProvider)
            .deleteAccountAndData(DemoSeed.password);

        expect(db.get(DemoDatabase.children, 'demo-juan'), isNull);
        expect(db.get(DemoDatabase.children, 'demo-sofia'), isNull);
        final family = Family.fromMap(
          db.get(DemoDatabase.families, DemoSeed.familyLopez)!,
        );
        expect(family.ownerUid, DemoSeed.luis.uid);
        expect(family.adultUids, [DemoSeed.luis.uid]);
        expect(family.adultNames.keys, isNot(contains(DemoSeed.maria.uid)));
        expect(db.get(DemoDatabase.users, DemoSeed.maria.uid), isNull);
      },
    );

    test('si era el único adulto, la familia se borra', () async {
      final c = await signedInContainer(DemoSeed.carlos.uid);
      addTearDown(c.dispose);
      final db = c.read(demoDatabaseProvider);

      await c
          .read(sessionActionsProvider)
          .deleteAccountAndData(DemoSeed.password);

      expect(db.get(DemoDatabase.families, DemoSeed.familyRuiz), isNull);
      expect(db.get(DemoDatabase.children, 'demo-mateo'), isNull);
      // La clase de Ana sigue existiendo, ya sin Mateo.
      final classRow = db.get(DemoDatabase.classes, DemoSeed.class2b)!;
      expect(classRow['studentIds'], isNot(contains('demo-mateo')));
    });
  });
}
