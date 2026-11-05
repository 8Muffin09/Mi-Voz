import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/classroom.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:mi_voz/models/family.dart';

import 'helpers.dart';

ChildProfile child(ProviderContainer c, String id) => ChildProfile.fromMap(
  c.read(demoDatabaseProvider).get(DemoDatabase.children, id)!,
);

Family family(ProviderContainer c, String id) => Family.fromMap(
  c.read(demoDatabaseProvider).get(DemoDatabase.families, id)!,
);

Classroom classroom(ProviderContainer c, String id) => Classroom.fromMap(
  c.read(demoDatabaseProvider).get(DemoDatabase.classes, id)!,
);

CaregiverLink? link(ProviderContainer c, String childId, String uid) {
  final row = c
      .read(demoDatabaseProvider)
      .get(DemoDatabase.links, '${childId}_$uid');
  return row == null ? null : CaregiverLink.fromMap(row);
}

void main() {
  group('Familias', () {
    test('cada adulto ve solo sus familias', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final repo = c.read(familiesRepositoryProvider);
      final maria = await repo.watchFamiliesForAdult(DemoSeed.maria.uid).first;
      expect(maria.map((f) => f.name), ['Familia López']);
      expect(await repo.watchFamiliesForAdult(DemoSeed.ana.uid).first, isEmpty);
      // Una familia ajena no se puede leer.
      expect(await repo.watchFamily(DemoSeed.familyRuiz).first, isNull);
    });

    test(
      'el mismo niño está en su familia y en su clase sin duplicarse',
      () async {
        final c = await signedInContainer(DemoSeed.maria.uid);
        addTearDown(c.dispose);
        final juan = child(c, 'demo-juan');
        expect(juan.familyId, DemoSeed.familyLopez);
        expect(juan.classIds, [DemoSeed.class2b]);
        final db = c.read(demoDatabaseProvider);
        expect(
          db.where(DemoDatabase.children, (r) => r['name'] == 'Juan'),
          hasLength(1),
        );
      },
    );

    test(
      'crear un perfil en la familia da acceso a todos sus adultos',
      () async {
        final c = await signedInContainer(DemoSeed.maria.uid);
        addTearDown(c.dispose);
        final created = await c
            .read(childrenRepositoryProvider)
            .createChild(
              owner: DemoSeed.maria,
              familyId: DemoSeed.familyLopez,
              name: 'Lía',
              avatar: '🐰',
              avatarColor: ChildProfile.colorOptions.first,
              gender: GrammaticalGender.feminine,
            );
        expect(created.familyId, DemoSeed.familyLopez);
        expect(created.memberUids, [DemoSeed.maria.uid, DemoSeed.luis.uid]);
        expect(created.classIds, isEmpty);
        final luisLink = link(c, created.id, DemoSeed.luis.uid)!;
        expect(luisLink.permission, LinkPermission.caregiver);
        expect(luisLink.source, LinkSource.family);
        expect(luisLink.role, AdultRole.padre);
        expect(link(c, created.id, DemoSeed.maria.uid)!.isOwner, isTrue);
      },
    );

    test('no se crean perfiles en una familia ajena', () async {
      final c = await signedInContainer(DemoSeed.carlos.uid);
      addTearDown(c.dispose);
      await expectLater(
        c
            .read(childrenRepositoryProvider)
            .createChild(
              owner: DemoSeed.carlos,
              familyId: DemoSeed.familyLopez,
              name: 'Intruso',
              avatar: '🦊',
              avatarColor: ChildProfile.colorOptions.first,
              gender: GrammaticalGender.masculine,
            ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('solo el administrador renombra; un adulto puede salir', () async {
      final c = await signedInContainer(DemoSeed.luis.uid);
      addTearDown(c.dispose);
      final repo = c.read(familiesRepositoryProvider);
      final lopez = family(c, DemoSeed.familyLopez);
      await expectLater(
        repo.renameFamily(lopez, 'Otra', actor: DemoSeed.luis),
        throwsA(isA<PermissionDeniedException>()),
      );
      // Luis no puede retirar al administrador.
      await expectLater(
        repo.removeAdult(
          lopez,
          actor: DemoSeed.luis,
          adultUid: DemoSeed.maria.uid,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      await repo.removeAdult(
        lopez,
        actor: DemoSeed.luis,
        adultUid: DemoSeed.luis.uid,
      );
      expect(family(c, DemoSeed.familyLopez).adultUids, [DemoSeed.maria.uid]);
      // Pierde el acceso a los niños; sus datos se conservan.
      for (final id in ['demo-juan', 'demo-sofia']) {
        final kid = child(c, id);
        expect(kid.memberUids, isNot(contains(DemoSeed.luis.uid)));
        expect(link(c, id, DemoSeed.luis.uid), isNull);
      }
      expect(child(c, 'demo-juan').memberUids, contains(DemoSeed.ana.uid));
      final db = c.read(demoDatabaseProvider);
      expect(db.get(DemoDatabase.content, 'demo-sofia'), isNotNull);
    });

    test('el administrador retira a un adulto (y la docente sigue)', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      await c
          .read(familiesRepositoryProvider)
          .removeAdult(
            family(c, DemoSeed.familyLopez),
            actor: DemoSeed.maria,
            adultUid: DemoSeed.luis.uid,
          );
      final juan = child(c, 'demo-juan');
      expect(juan.memberUids, [DemoSeed.maria.uid, DemoSeed.ana.uid]);
    });

    test(
      'actualización: los perfiles sin familia se agrupan sin perder datos',
      () async {
        final c = await signedInContainer(DemoSeed.maria.uid);
        addTearDown(c.dispose);
        final db = c.read(demoDatabaseProvider);
        // Perfil creado con una versión anterior (sin familia).
        final legacy = child(c, 'demo-sofia').copyWith(familyId: () => null);
        db.put(DemoDatabase.children, 'demo-legacy', {
          ...legacy.toMap(),
          'id': 'demo-legacy',
          'name': 'Antiguo',
        });
        db.commit();
        final adopted = await c
            .read(familiesRepositoryProvider)
            .adoptOrphanChildren(DemoSeed.maria);
        expect(adopted!.id, DemoSeed.familyLopez, reason: 'usa su familia');
        expect(child(c, 'demo-legacy').familyId, DemoSeed.familyLopez);
        expect(child(c, 'demo-legacy').name, 'Antiguo');
        // Nada más que agrupar.
        expect(
          await c
              .read(familiesRepositoryProvider)
              .adoptOrphanChildren(DemoSeed.maria),
          isNull,
        );
      },
    );
  });

  group('Clases', () {
    test(
      'el docente ve sus clases y una docente nueva empieza sin ninguna',
      () async {
        final c = await signedInContainer(DemoSeed.ana.uid);
        addTearDown(c.dispose);
        final repo = c.read(classesRepositoryProvider);
        final ana = await repo.watchClassesForTeacher(DemoSeed.ana.uid).first;
        expect(ana.map((k) => k.name), ['2.º B']);
        expect(
          await repo.watchClassesForTeacher(DemoSeed.maria.uid).first,
          isEmpty,
        );
      },
    );

    test('crear varias clases, editar, archivar y reactivar', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      final repo = c.read(classesRepositoryProvider);
      final created = await repo.createClass(
        owner: DemoSeed.ana,
        name: '3.º A',
        description: 'Tarde',
      );
      expect(created.teacherUids, [DemoSeed.ana.uid]);
      expect(created.studentIds, isEmpty);
      await repo.updateClass(
        created,
        name: '3.º A (tarde)',
        description: '',
        actor: DemoSeed.ana,
      );
      await repo.setArchived(
        classroom(c, created.id),
        true,
        actor: DemoSeed.ana,
      );
      expect(classroom(c, created.id).archived, isTrue);
      expect(classroom(c, created.id).name, '3.º A (tarde)');
      await repo.setArchived(
        classroom(c, created.id),
        false,
        actor: DemoSeed.ana,
      );
      expect(classroom(c, created.id).archived, isFalse);
    });

    test('otro adulto no administra la clase', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final repo = c.read(classesRepositoryProvider);
      final b2 = classroom(c, DemoSeed.class2b);
      expect(await repo.watchClass(DemoSeed.class2b).first, isNull);
      await expectLater(
        repo.setArchived(b2, true, actor: DemoSeed.maria),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        repo.removeStudent(b2, child(c, 'demo-juan'), actor: DemoSeed.maria),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('solo se agregan alumnos ya autorizados', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      final repo = c.read(classesRepositoryProvider);
      final b2 = classroom(c, DemoSeed.class2b);
      await expectLater(
        repo.addAuthorizedStudent(
          b2,
          child(c, 'demo-sofia'),
          actor: DemoSeed.ana,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(
        child(c, 'demo-sofia').memberUids,
        isNot(contains(DemoSeed.ana.uid)),
      );
    });

    test(
      'un alumno en varias clases: retirarlo de una conserva el acceso',
      () async {
        final c = await signedInContainer(DemoSeed.ana.uid);
        addTearDown(c.dispose);
        final repo = c.read(classesRepositoryProvider);
        final otra = await repo.createClass(
          owner: DemoSeed.ana,
          name: 'Taller',
        );
        await repo.addAuthorizedStudent(
          otra,
          child(c, 'demo-juan'),
          actor: DemoSeed.ana,
        );
        expect(child(c, 'demo-juan').classIds, {DemoSeed.class2b, otra.id});
        expect(link(c, 'demo-juan', DemoSeed.ana.uid)!.classIds, {
          DemoSeed.class2b,
          otra.id,
        });

        await repo.removeStudent(
          classroom(c, DemoSeed.class2b),
          child(c, 'demo-juan'),
          actor: DemoSeed.ana,
        );
        expect(child(c, 'demo-juan').memberUids, contains(DemoSeed.ana.uid));
        expect(child(c, 'demo-juan').classIds, [otra.id]);

        // Al retirarlo de la última clase, la docente pierde el acceso; los
        // datos del niño y su familia se conservan.
        await repo.removeStudent(
          classroom(c, otra.id),
          child(c, 'demo-juan'),
          actor: DemoSeed.ana,
        );
        final juan = child(c, 'demo-juan');
        expect(juan.memberUids, isNot(contains(DemoSeed.ana.uid)));
        expect(juan.classIds, isEmpty);
        expect(juan.familyId, DemoSeed.familyLopez);
        expect(link(c, 'demo-juan', DemoSeed.ana.uid), isNull);
        expect(classroom(c, DemoSeed.class2b).studentIds, ['demo-mateo']);
      },
    );
  });

  group('Permisos de cada adulto', () {
    test('la familia decide quién recibe solicitudes', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final children = c.read(childrenRepositoryProvider);
      // Nadie acompaña a Juan: se aplica la lista de autorizados.
      final links = await children.watchLinks('demo-juan').first;
      await children.setResponsible(
        child: child(c, 'demo-juan'),
        actor: DemoSeed.maria,
        adult: null,
      );
      expect(links, isNotEmpty);
      await children.setLinkPermissions(
        child: child(c, 'demo-juan'),
        actor: DemoSeed.maria,
        adultUid: DemoSeed.luis.uid,
        receivesRequests: false,
        canViewPassport: true,
      );
      final requests = c.read(requestsRepositoryProvider);
      // Captura los destinatarios reales del "backend" local.
      final db = c.read(demoDatabaseProvider);
      final request = CommunicationService.buildRequest(
        child: child(c, 'demo-juan'),
        draft: PhraseDraft(
          category: null,
          items: const [],
          fixedText: 'Tengo sed',
          fixedEmoji: '🥤',
          fixedCategoryId: 'tengo',
        ),
        senderUid: DemoSeed.maria.uid,
      );
      await requests.deliver(request);
      final saved = db.get(DemoDatabase.requests, request.id)!;
      final names = CommunicationRequest.fromMap(saved).notifiedNames;
      expect(names, isNot(contains(DemoSeed.luis.displayName)));
      expect(names, contains(DemoSeed.maria.displayName));
    });

    test('la familia puede retirar el acceso al pasaporte', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      await c
          .read(childrenRepositoryProvider)
          .setLinkPermissions(
            child: child(c, 'demo-juan'),
            actor: DemoSeed.maria,
            adultUid: DemoSeed.ana.uid,
            receivesRequests: true,
            canViewPassport: false,
          );
      await c.read(demoDatabaseProvider).setSession(DemoSeed.ana.uid);
      final passport = await c
          .read(passportRepositoryProvider)
          .watchPassport('demo-juan')
          .first;
      expect(passport.personalPreferences, isEmpty);
    });

    test('solo el administrador del perfil cambia permisos', () async {
      final c = await signedInContainer(DemoSeed.luis.uid);
      addTearDown(c.dispose);
      await expectLater(
        c
            .read(childrenRepositoryProvider)
            .setLinkPermissions(
              child: child(c, 'demo-juan'),
              actor: DemoSeed.luis,
              adultUid: DemoSeed.ana.uid,
              receivesRequests: false,
              canViewPassport: false,
            ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
