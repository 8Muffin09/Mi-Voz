import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/access/application/access_providers.dart';
import 'package:mi_voz/features/authentication/application/session_actions.dart';
import 'package:mi_voz/features/child/application/active_child.dart';
import 'package:mi_voz/features/child/application/child_mode.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/application/requests_providers.dart';
import 'package:mi_voz/features/history/domain/history_filter.dart';
import 'package:mi_voz/features/pictograms/application/pictogram_providers.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/features/profiles/application/profiles_providers.dart';
import 'package:mi_voz/features/welcome/application/welcome_preferences.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/sensory_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Deja que los flujos de sesión y perfiles reflejen el último cambio.
Future<void> settleProviders() async {
  for (var i = 0; i < 6; i++) {
    await flush();
  }
}

ChildProfile seedChild(ProviderContainer c, String id) => ChildProfile.fromMap(
  c.read(demoDatabaseProvider).get(DemoDatabase.children, id)!,
);

void main() {
  group('Registro de adultos', () {
    test('padre/tutor: nombre, apellido, relación y avatar', () async {
      final c = await signedInContainer(null);
      addTearDown(c.dispose);
      final user = await c
          .read(sessionActionsProvider)
          .register(
            email: 'pedro@demo.mivoz',
            password: 'clave1234',
            displayName: 'Pedro Gómez',
            role: AdultRole.padre,
            lastName: 'Gómez',
            avatar: '👨‍🦱',
            avatarColor: AppUser.colorOptions[2],
            experiences: {UserExperience.guardian},
          );
      await settleProviders();

      final current = c.read(currentUserProvider)!;
      expect(current.uid, user.uid);
      expect(current.firstName, 'Pedro');
      expect(current.lastName, 'Gómez');
      expect(current.role, AdultRole.padre);
      expect(current.avatarRef, '👨‍🦱');
      expect(current.isGuardian, isTrue);
      expect(current.isTeacher, isFalse);
    });

    test('docente: escuela, grupo y cómo lo llaman sus alumnos', () async {
      final c = await signedInContainer(null);
      addTearDown(c.dispose);
      await c
          .read(sessionActionsProvider)
          .register(
            email: 'jorge@demo.mivoz',
            password: 'clave1234',
            displayName: 'Jorge Díaz',
            role: AdultRole.docente,
            lastName: 'Díaz',
            schoolName: 'Escuela Primaria Sol',
            groupName: '3.º A',
            teacherTitle: 'Maestro',
            experiences: {UserExperience.teacher},
          );
      await settleProviders();

      final teacher = c.read(currentUserProvider)!;
      expect(teacher.isTeacher, isTrue);
      expect(teacher.isGuardian, isFalse);
      expect(teacher.teacherGreetingName, 'Maestro Jorge');
      expect(teacher.schoolName, 'Escuela Primaria Sol');
      expect(teacher.groupName, '3.º A');
      // Un docente recién registrado no ve a ningún niño.
      expect(await c.read(childrenProvider.future), isEmpty);
    });

    test('la fotografía opcional del registro queda en el perfil', () async {
      final photos = FakePhotoStore();
      final c = await signedInContainer(null, photos: photos);
      addTearDown(c.dispose);
      final user = await c
          .read(sessionActionsProvider)
          .register(
            email: 'foto@demo.mivoz',
            password: 'clave1234',
            displayName: 'Rita',
            role: AdultRole.tutor,
            photo: File('galeria/rita.jpg'),
          );
      expect(photos.saved.keys, ['users/${user.uid}/avatar/photo.jpg']);
      expect(user.photo, startsWith('file:'));
      await settleProviders();
      expect(c.read(currentUserProvider)!.photo, user.photo);
    });
  });

  group('Perfiles infantiles', () {
    test('crear perfil: solo lo necesario y datos propios del niño', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final child = await c
          .read(childrenRepositoryProvider)
          .createChild(
            owner: DemoSeed.maria,
            name: 'Lucía',
            lastName: 'López',
            avatar: '🐰',
            avatarColor: ChildProfile.colorOptions[3],
            gender: GrammaticalGender.feminine,
            settings: const SensorySettings(
              calmMode: true,
              speakOnSelect: false,
            ),
          );
      await settleProviders();

      final mine = await c.read(childrenProvider.future);
      expect(mine.map((k) => k.name), contains('Lucía'));
      final saved = mine.firstWhere((k) => k.id == child.id);
      expect(saved.fullName, 'Lucía López');
      expect(saved.memberUids, [DemoSeed.maria.uid]);
      expect(saved.settings.calmMode, isTrue);
      expect(saved.settings.speakOnSelect, isFalse);
      // Otro adulto no lo ve.
      final anaKids = await c
          .read(childrenRepositoryProvider)
          .watchChildrenForAdult(DemoSeed.ana.uid)
          .first;
      expect(anaKids.map((k) => k.id), isNot(contains(child.id)));
    });

    test('no se puede crear un perfil a nombre de otro adulto', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      await expectLater(
        c
            .read(childrenRepositoryProvider)
            .createChild(
              owner: DemoSeed.maria,
              name: 'Intruso',
              avatar: '🦊',
              avatarColor: ChildProfile.colorOptions.first,
              gender: GrammaticalGender.masculine,
            ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('editar nombre y avatar del niño (incluida la foto)', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final juan = seedChild(c, 'demo-juan');
      await c
          .read(childrenRepositoryProvider)
          .updateChildProfile(
            juan,
            name: 'Juanito',
            lastName: 'López',
            avatar: '🐼',
            avatarColor: ChildProfile.colorOptions[4],
            gender: juan.gender,
            photo: 'file:/memoria/children/demo-juan/avatar/photo.jpg',
          );
      final updated = seedChild(c, 'demo-juan');
      expect(updated.name, 'Juanito');
      expect(updated.fullName, 'Juanito López');
      expect(updated.avatar, '🐼');
      expect(updated.photo, endsWith('photo.jpg'));
      // Los ajustes y vínculos no cambian al editar el perfil.
      expect(updated.memberUids, juan.memberUids);
      expect(updated.responsibleUid, DemoSeed.maria.uid);
    });

    test('editar "Mi perfil" actualiza el nombre en sus vínculos', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final maria = c.read(currentUserProvider)!;
      await c
          .read(sessionActionsProvider)
          .updateProfile(
            maria.copyWith(
              displayName: 'María José López',
              avatar: () => '🌻',
              avatarColor: () => AppUser.colorOptions[3],
            ),
          );
      await settleProviders();

      final current = c.read(currentUserProvider)!;
      expect(current.displayName, 'María José López');
      expect(current.firstName, 'María');
      expect(current.avatarRef, '🌻');
      final db = c.read(demoDatabaseProvider);
      final link = CaregiverLink.fromMap(
        db.get(DemoDatabase.links, 'demo-juan_demo-maria')!,
      );
      expect(link.adultName, 'María José López');
      expect(seedChild(c, 'demo-juan').responsibleName, 'María José López');
    });

    test('un adulto no puede editar el perfil de otro adulto', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      await expectLater(
        c
            .read(authRepositoryProvider)
            .updateProfile(DemoSeed.maria.copyWith(displayName: 'Otra')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('cambiar la contraseña exige la actual', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final actions = c.read(sessionActionsProvider);
      await expectLater(
        actions.changePassword('incorrecta', 'nueva1234'),
        throwsA(isA<AppException>()),
      );
      await actions.changePassword(DemoSeed.password, 'nueva1234');
      final auth = c.read(authRepositoryProvider);
      await auth.signOut();
      await expectLater(
        auth.signIn(email: DemoSeed.maria.email, password: DemoSeed.password),
        throwsA(isA<AppException>()),
      );
      final user = await auth.signIn(
        email: DemoSeed.maria.email,
        password: 'nueva1234',
      );
      expect(user.uid, DemoSeed.maria.uid);
    });
  });

  group('Selección y cambio de perfil', () {
    test(
      'entrar al perfil activa el modo niño y lo deja en el dispositivo',
      () async {
        final c = await signedInContainer(DemoSeed.maria.uid);
        addTearDown(c.dispose);
        c.listen(deviceChildrenProvider, (_, _) {});
        await c
            .read(sessionActionsProvider)
            .enterChildProfile(seedChild(c, 'demo-juan'));

        expect(c.read(childModeProvider), 'demo-juan');
        expect(c.read(deviceProfilesProvider), {
          'demo-juan': DemoSeed.maria.uid,
        });
        expect(c.read(deviceChildrenProvider).value!.map((k) => k.id), [
          'demo-juan',
        ]);
        expect(c.read(adultGateRequiredProvider), isTrue);
      },
    );

    test('un adulto no vinculado no puede activar un perfil', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      await c
          .read(sessionActionsProvider)
          .enterChildProfile(seedChild(c, 'demo-sofia'));
      expect(c.read(childModeProvider), isNull);
      expect(c.read(deviceProfilesProvider), isEmpty);
    });

    test('cambiar entre varios niños no mezcla sus datos', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      for (final id in ['demo-juan', 'demo-sofia']) {
        c
          ..listen(childProvider(id), (_, _) {})
          ..listen(childContentProvider(id), (_, _) {})
          ..listen(childRequestsProvider(id), (_, _) {});
        await c.read(childProvider(id).future);
        await c.read(childContentProvider(id).future);
      }
      final actions = c.read(sessionActionsProvider);

      await actions.enterChildProfile(seedChild(c, 'demo-juan'));
      await settleProviders();
      expect(c.read(activeChildProvider)!.name, 'Juan');
      final juanFavorites = c
          .read(activeVocabularyProvider)!
          .favorites
          .map((p) => p.id)
          .toList();
      final juanSettings = c.read(activeSettingsProvider);

      await c.read(childModeProvider.notifier).exit();
      await actions.enterChildProfile(seedChild(c, 'demo-sofia'));
      await settleProviders();
      expect(c.read(activeChildProvider)!.name, 'Sofía');
      final sofiaFavorites = c
          .read(activeVocabularyProvider)!
          .favorites
          .map((p) => p.id)
          .toList();
      expect(sofiaFavorites, isNot(equals(juanFavorites)));
      expect(sofiaFavorites, contains('quiero_dibujar'));
      expect(c.read(activeSettingsProvider).pictogramSize, PictogramSize.large);
      expect(juanSettings.pictogramSize, PictogramSize.medium);
    });

    test('separación de historial y favoritos entre niños', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final content = c.read(contentRepositoryProvider);
      await content.setFavorite('demo-juan', 'tengo_frio', true);
      final juan = await content.watchContent('demo-juan').first;
      final sofia = await content.watchContent('demo-sofia').first;
      expect(juan.favoritePictogramIds, contains('tengo_frio'));
      expect(sofia.favoritePictogramIds, isNot(contains('tengo_frio')));

      // Una solicitud de Sofía no aparece en el historial de Juan.
      final request = CommunicationService.buildRequest(
        child: seedChild(c, 'demo-sofia'),
        draft: PhraseDraft(
          category: null,
          items: const [],
          fixedText: 'Quiero un cuento',
          fixedEmoji: '📖',
          fixedCategoryId: 'quiero',
        ),
        senderUid: DemoSeed.maria.uid,
      );
      await c.read(requestsRepositoryProvider).deliver(request);
      c.listen(adultRequestsProvider, (_, _) {});
      final all = await c.read(adultRequestsProvider.future);
      final juanHistory = HistoryFilter(childId: 'demo-juan').apply(all);
      final sofiaHistory = HistoryFilter(childId: 'demo-sofia').apply(all);
      expect(juanHistory.every((r) => r.childId == 'demo-juan'), isTrue);
      expect(juanHistory.map((r) => r.id), isNot(contains(request.id)));
      expect(sofiaHistory.map((r) => r.id), contains(request.id));
    });
  });

  group('Cambio de cuenta y cierre de sesión', () {
    test('cerrar sesión borra modo niño, cachés y la cola de envío', () async {
      final c = await signedInContainer(
        DemoSeed.maria.uid,
        extra: {
          LocalStore.keyChildMode: 'demo-juan',
          LocalStore.childCacheKey('demo-juan'): '{}',
          '${LocalStore.keyOutbox}_demo': '[]',
        },
      );
      addTearDown(c.dispose);
      await c.read(sessionActionsProvider).signOut();
      await settleProviders();

      final prefs = c.read(sharedPreferencesProvider);
      expect(c.read(currentUserProvider), isNull);
      expect(c.read(childModeProvider), isNull);
      expect(prefs.getString(LocalStore.childCacheKey('demo-juan')), isNull);
      expect(prefs.getString('${LocalStore.keyOutbox}_demo'), isNull);
    });

    test('cambiar de cuenta: la siguiente no ve lo de la anterior', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      c.listen(deviceChildrenProvider, (_, _) {});
      final actions = c.read(sessionActionsProvider);
      await actions.enterChildProfile(seedChild(c, 'demo-juan'));
      await c.read(childModeProvider.notifier).exit();

      await actions.switchAccount(to: UserExperience.teacher);
      await settleProviders();
      expect(c.read(currentUserProvider), isNull);
      expect(c.read(activeExperienceProvider), UserExperience.teacher);

      await actions.signIn(DemoSeed.ana.email, DemoSeed.password);
      await settleProviders();
      await c.read(childrenProvider.future);
      await settleProviders();
      expect(c.read(currentUserProvider)!.uid, DemoSeed.ana.uid);
      // Ana también es docente de Juan, pero el perfil lo activó María en
      // este dispositivo: no aparece para Ana ni exige su verificación.
      expect(c.read(deviceChildrenProvider).value, isEmpty);
      expect(c.read(adultGateRequiredProvider), isFalse);
      expect(c.read(experienceChildrenProvider).value!.map((k) => k.id), [
        'demo-juan',
        'demo-mateo',
      ]);
    });
  });

  group('Panel docente y vinculación', () {
    test('el docente solo ve y usa alumnos autorizados', () async {
      final c = await signedInContainer(DemoSeed.ana.uid);
      addTearDown(c.dispose);
      final students = c.read(experienceChildrenProvider).value!;
      expect(students.map((k) => k.name), ['Juan', 'Mateo']);
      expect(c.read(currentStudentProvider)!.id, 'demo-juan');

      await c.read(currentStudentIdProvider.notifier).select('demo-mateo');
      expect(c.read(currentStudentProvider)!.name, 'Mateo');
      // Un alumno no autorizado no puede ser el alumno actual.
      await c.read(currentStudentIdProvider.notifier).select('demo-sofia');
      expect(c.read(currentStudentProvider)!.id, 'demo-juan');

      // Sofía no está vinculada: ni perfil, ni contenido, ni solicitudes.
      final repo = c.read(childrenRepositoryProvider);
      expect(await repo.watchChild('demo-sofia').first, isNull);
      final content = await c
          .read(contentRepositoryProvider)
          .watchContent('demo-sofia')
          .first;
      expect(content.favoritePictogramIds, isEmpty);
      final passport = await c
          .read(passportRepositoryProvider)
          .watchPassport('demo-sofia')
          .first;
      expect(passport.personalPreferences, isEmpty);
      final strategies = await c
          .read(strategiesRepositoryProvider)
          .watchStrategies('demo-sofia')
          .first;
      expect(strategies, isEmpty);
      expect(
        await c
            .read(requestsRepositoryProvider)
            .watchChildRequests('demo-sofia')
            .first,
        isEmpty,
      );
    });

    test('vinculación de docente con código de un solo uso', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      final repo = c.read(childrenRepositoryProvider);
      final sofia = seedChild(c, 'demo-sofia');
      final invitation = await repo.createInvitation(
        child: sofia,
        role: AdultRole.docente,
        createdBy: DemoSeed.maria,
      );
      expect(
        invitation.expiresAt.difference(invitation.createdAt),
        const Duration(hours: 48),
      );

      final link = await repo.acceptInvitation(
        code: invitation.code,
        adult: DemoSeed.ana,
      );
      expect(link.role, AdultRole.docente);
      expect(
        link.permission,
        LinkPermission.caregiver,
        reason: 'nunca administrador',
      );
      expect(seedChild(c, 'demo-sofia').memberUids, contains(DemoSeed.ana.uid));
      await expectLater(
        repo.acceptInvitation(code: invitation.code, adult: DemoSeed.carlos),
        throwsA(isA<AppException>()),
      );
      // El docente no puede invitar a otros (no administra el perfil).
      await expectLater(
        repo.createInvitation(
          child: seedChild(c, 'demo-sofia'),
          role: AdultRole.tutor,
          createdBy: DemoSeed.ana,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      // Desvincular al docente conserva los datos de Sofía.
      final db = c.read(demoDatabaseProvider);
      final before = db.get(DemoDatabase.content, 'demo-sofia');
      await repo.removeLink(
        child: seedChild(c, 'demo-sofia'),
        actor: DemoSeed.maria,
        adultUid: DemoSeed.ana.uid,
      );
      expect(
        seedChild(c, 'demo-sofia').memberUids,
        isNot(contains(DemoSeed.ana.uid)),
      );
      expect(db.get(DemoDatabase.content, 'demo-sofia'), before);
      expect(
        db.where(DemoDatabase.requests, (r) => r['childId'] == 'demo-sofia'),
        isNotEmpty,
      );
    });

    test('una cuenta con ambas experiencias separa hijos y alumnos', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      c.listen(linkedChildrenProvider, (_, _) {});
      final repo = c.read(childrenRepositoryProvider);
      // Carlos (papá de Mateo) invita a María como docente de Mateo.
      final invitation = await repo.createInvitation(
        child: seedChild(c, 'demo-mateo'),
        role: AdultRole.docente,
        createdBy: DemoSeed.carlos,
      );
      await repo.acceptInvitation(code: invitation.code, adult: DemoSeed.maria);
      await c
          .read(sessionActionsProvider)
          .addExperience(UserExperience.teacher, schoolName: 'Escuela Sol');
      await settleProviders();
      await c.read(linkedChildrenProvider.future);
      await settleProviders();

      final maria = c.read(currentUserProvider)!;
      expect(maria.isGuardian && maria.isTeacher, isTrue);
      expect(c.read(activeExperienceProvider), UserExperience.teacher);
      expect(c.read(experienceChildrenProvider).value!.map((k) => k.id), [
        'demo-mateo',
      ]);

      await c
          .read(selectedExperienceProvider.notifier)
          .select(UserExperience.guardian);
      expect(c.read(experienceChildrenProvider).value!.map((k) => k.id), [
        'demo-juan',
        'demo-sofia',
      ]);
    });
  });

  group('Preferencias de la bienvenida', () {
    test('la melodía viene desactivada y su preferencia persiste', () async {
      final c = await demoContainer();
      addTearDown(c.dispose);
      final initial = c.read(welcomePreferencesProvider);
      expect(
        initial.melodyEnabled,
        isFalse,
        reason: 'desactivada hasta autorizarla',
      );
      expect(initial.showSplash, isTrue);

      await c.read(welcomePreferencesProvider.notifier).setMelodyEnabled(true);
      await c.read(welcomePreferencesProvider.notifier).setShowSplash(false);

      // Un nuevo arranque de la app lee lo guardado.
      final prefs = await SharedPreferences.getInstance();
      final restarted = ProviderContainer(overrides: testOverrides(prefs));
      addTearDown(restarted.dispose);
      final restored = restarted.read(welcomePreferencesProvider);
      expect(restored.melodyEnabled, isTrue);
      expect(restored.showSplash, isFalse);
    });

    test('suena una sola vez por inicio y nunca en modo tranquilo', () async {
      final melody = FakeMelodyPlayer();
      final c = await demoContainer(
        melody: melody,
        extra: {LocalStore.keyWelcomeMelody: true},
      );
      addTearDown(c.dispose);
      final welcome = c.read(welcomeMelodyProvider);
      expect(await welcome.playOnLaunch(), isTrue);
      expect(await welcome.playOnLaunch(), isFalse);
      expect(melody.plays, 1);

      // Mateo tiene el modo tranquilo y está en modo niño en el dispositivo.
      final calmMelody = FakeMelodyPlayer();
      final mateo = ChildProfile(
        id: 'demo-mateo',
        name: 'Mateo',
        avatar: '🐢',
        avatarColor: ChildProfile.colorOptions.first,
        gender: GrammaticalGender.masculine,
        ownerUid: DemoSeed.carlos.uid,
        memberUids: [DemoSeed.carlos.uid],
        settings: const SensorySettings(calmMode: true),
      );
      final calm = await demoContainer(
        melody: calmMelody,
        extra: {
          LocalStore.keyWelcomeMelody: true,
          LocalStore.keyChildMode: 'demo-mateo',
          LocalStore.childCacheKey('demo-mateo'): jsonEncode(mateo.toMap()),
        },
      );
      addTearDown(calm.dispose);
      expect(calm.read(welcomeMelodyProvider).calmModeOnDevice(), isTrue);
      expect(await calm.read(welcomeMelodyProvider).playOnLaunch(), isFalse);
      expect(calmMelody.plays, 0);
    });
  });
}
