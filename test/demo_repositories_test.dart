import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/authentication/data/demo_auth_repository.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/data/demo_requests_repository.dart';
import 'package:mi_voz/features/pictograms/data/demo_content_repository.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/features/profiles/data/demo_children_repository.dart';
import 'package:mi_voz/features/strategies/data/demo_strategies_repository.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:mi_voz/models/pictogram.dart';
import 'package:mi_voz/models/support_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'phrase_builder_test.dart' show pic;

void main() {
  late DemoDatabase db;
  late DemoChildrenRepository children;
  late DemoRequestsRepository requests;
  late List<List<String>> pushes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = DemoDatabase(LocalStore(prefs), seedSampleData: true);
    children = DemoChildrenRepository(db);
    pushes = [];
    requests = DemoRequestsRepository(
      db,
      onSimulatedPush: (r, uids) => pushes.add(uids),
    );
  });

  // Lectura directa de la base (sin depender de la sesión activa).
  Future<ChildProfile> juan() async =>
      ChildProfile.fromMap(db.get(DemoDatabase.children, 'demo-juan')!);

  group('Autenticación demo', () {
    test('inicia sesión, registra y rechaza credenciales inválidas', () async {
      final auth = DemoAuthRepository(db);
      await expectLater(
        auth.signIn(email: DemoSeed.maria.email, password: 'mal'),
        throwsA(isA<AppException>()),
      );
      final user = await auth.signIn(
        email: DemoSeed.maria.email,
        password: DemoSeed.password,
      );
      expect(user.uid, DemoSeed.maria.uid);
      expect(await auth.authStateChanges().first, isNotNull);

      await auth.signOut();
      final created = await auth.register(
        email: 'nuevo@demo.mivoz',
        password: 'clave1234',
        displayName: 'Nuevo',
        role: AdultRole.cuidador,
      );
      expect(created.role, AdultRole.cuidador);
      await expectLater(
        auth.register(
          email: 'nuevo@demo.mivoz',
          password: 'clave1234',
          displayName: 'Otro',
          role: AdultRole.tutor,
        ),
        throwsA(isA<AppException>()),
      );
    });
  });

  group('Perfiles, vínculos y responsable', () {
    test('el adulto ve solo los niños a los que está vinculado', () async {
      final anaKids = await children
          .watchChildrenForAdult(DemoSeed.ana.uid)
          .first;
      expect(anaKids.map((c) => c.id), ['demo-juan', 'demo-mateo']);
      final mariaKids = await children
          .watchChildrenForAdult(DemoSeed.maria.uid)
          .first;
      expect(mariaKids.map((c) => c.id), ['demo-juan', 'demo-sofia']);
    });

    test('invitación de un solo uso vincula a un adulto nuevo', () async {
      await db.setSession(DemoSeed.maria.uid);
      final sofia = (await children.watchChild('demo-sofia').first)!;
      final inv = await children.createInvitation(
        child: sofia,
        role: AdultRole.docente,
        createdBy: DemoSeed.maria,
      );
      expect(inv.code, hasLength(8));

      final link = await children.acceptInvitation(
        code: inv.code.toLowerCase(),
        adult: DemoSeed.ana,
      );
      expect(link.role, AdultRole.docente);
      expect(link.permission, LinkPermission.caregiver);
      final updated = (await children.watchChild('demo-sofia').first)!;
      expect(updated.memberUids, contains(DemoSeed.ana.uid));

      // No se puede reutilizar.
      await expectLater(
        children.acceptInvitation(code: inv.code, adult: DemoSeed.luis),
        throwsA(isA<AppException>()),
      );
    });

    test('un adulto no administrador no puede invitar', () async {
      final child = await juan();
      await expectLater(
        children.createInvitation(
          child: child,
          role: AdultRole.tutor,
          createdBy: DemoSeed.ana,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('código inexistente o caducado se rechaza', () async {
      await expectLater(
        children.acceptInvitation(code: 'ZZZZZZZZ', adult: DemoSeed.ana),
        throwsA(isA<AppException>()),
      );
    });

    test(
      'la maestra se marca como responsable y al quitarla se libera',
      () async {
        var child = await juan();
        final anaLink = (await children.watchLinks(child.id).first).where(
          (l) => l.adultUid == DemoSeed.ana.uid,
        );
        // watchLinks requiere sesión de un adulto vinculado.
        expect(anaLink, isEmpty);

        await db.setSession(DemoSeed.ana.uid);
        final links = await children.watchLinks(child.id).first;
        final ana = links.firstWhere((l) => l.adultUid == DemoSeed.ana.uid);
        await children.setResponsible(
          child: child,
          actor: DemoSeed.ana,
          adult: ana,
        );
        child = await juan();
        expect(child.responsibleUid, DemoSeed.ana.uid);

        // Papá no puede asignar a otra persona.
        final luis = links.firstWhere((l) => l.adultUid == DemoSeed.luis.uid);
        await expectLater(
          children.setResponsible(
            child: child,
            actor: DemoSeed.ana,
            adult: luis,
          ),
          throwsA(isA<PermissionDeniedException>()),
        );

        await db.setSession(DemoSeed.maria.uid);
        await children.removeLink(
          child: child,
          actor: DemoSeed.maria,
          adultUid: DemoSeed.ana.uid,
        );
        child = await juan();
        expect(child.memberUids, isNot(contains(DemoSeed.ana.uid)));
        expect(
          child.responsibleUid,
          isNull,
          reason: 'el responsable desvinculado se libera',
        );
      },
    );

    test('solo el administrador elimina el perfil y se borra todo', () async {
      final child = await juan();
      await expectLater(
        children.deleteChild(child, actor: DemoSeed.luis),
        throwsA(isA<PermissionDeniedException>()),
      );
      await children.deleteChild(child, actor: DemoSeed.maria);
      expect(await children.watchChild(child.id).first, isNull);
      expect(
        db.where(DemoDatabase.requests, (r) => r['childId'] == child.id),
        isEmpty,
      );
      expect(
        db.where(DemoDatabase.links, (r) => r['childId'] == child.id),
        isEmpty,
      );
    });
  });

  group('Solicitudes', () {
    CommunicationRequest build(ChildProfile child, String senderUid) =>
        CommunicationService.buildRequest(
          child: child,
          draft: PhraseDraft(
            category: null,
            items: const [],
            fixedText: 'Me molesta mucho el ruido',
            fixedEmoji: '🔊',
            fixedCategoryId: 'me_molesta',
          ),
          senderUid: senderUid,
        );

    test('se dirige al responsable y la entrega es idempotente', () async {
      await db.setSession(DemoSeed.maria.uid);
      final child = await juan();
      final r = build(child, DemoSeed.maria.uid);
      expect(r.recipientUid, DemoSeed.maria.uid);

      await requests.deliver(r);
      await requests.deliver(r);
      final stored = await requests.watchChildRequests(child.id).first;
      expect(stored.where((x) => x.id == r.id), hasLength(1));
      expect(pushes, hasLength(1), reason: 'una sola notificación');
      expect(pushes.single, [DemoSeed.maria.uid]);
      final saved = stored.firstWhere((x) => x.id == r.id);
      expect(saved.delivery, DeliveryStatus.delivered);
      expect(saved.notification, NotificationStatus.simulated);
    });

    test('sin conexión lanza OfflineException y no guarda nada', () async {
      await db.setSimulateOffline(true);
      final child = await juan();
      final r = build(child, DemoSeed.maria.uid);
      await expectLater(requests.deliver(r), throwsA(isA<OfflineException>()));
      expect(db.get(DemoDatabase.requests, r.id), isNull);
    });

    test('un adulto no vinculado no puede enviar', () async {
      final child = await juan();
      final r = build(child, 'intruso');
      await expectLater(
        requests.deliver(r),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test(
      'cambios de estado: avanzan, registran tiempos y no retroceden',
      () async {
        await db.setSession(DemoSeed.ana.uid);
        final child = await juan();
        final r = build(child, DemoSeed.maria.uid);
        await requests.deliver(r);

        await requests.updateStatus(
          request: r,
          status: RequestStatus.seen,
          actor: DemoSeed.ana,
        );
        await requests.updateStatus(
          request: r,
          status: RequestStatus.attending,
          actor: DemoSeed.ana,
        );
        await requests.updateStatus(
          request: r,
          status: RequestStatus.resolved,
          actor: DemoSeed.ana,
          note: 'Le dimos audífonos',
        );
        await requests.updateStatus(
          request: r,
          status: RequestStatus.seen,
          actor: DemoSeed.ana,
        );

        final saved = (await requests.watchRequest(child.id, r.id).first)!;
        expect(saved.status, RequestStatus.resolved);
        expect(saved.seenAt, isNotNull);
        expect(saved.attendingAt, isNotNull);
        expect(saved.resolvedAt, isNotNull);
        expect(saved.statusUpdatedByName, DemoSeed.ana.displayName);
        expect(saved.note, 'Le dimos audífonos');
      },
    );
  });

  group('Favoritos y frases', () {
    test(
      'marcar y desmarcar favoritos, frases y pictogramas propios',
      () async {
        // Como en Firestore, leer el contenido exige un adulto vinculado.
        await db.setSession(DemoSeed.maria.uid);
        final content = DemoContentRepository(db);
        await content.setFavorite('demo-juan', 'tengo_frio', true);
        var c = await content.watchContent('demo-juan').first;
        expect(c.favoritePictogramIds, contains('tengo_frio'));

        await content.setFavorite('demo-juan', 'tengo_frio', false);
        c = await content.watchContent('demo-juan').first;
        expect(c.favoritePictogramIds, isNot(contains('tengo_frio')));

        await content.saveFrequentPhrase(
          'demo-juan',
          const FrequentPhrase(
            id: 'nueva',
            text: 'Quiero mi tableta',
            emoji: '📱',
          ),
        );
        c = await content.watchContent('demo-juan').first;
        expect(c.frequentPhrases.last.text, 'Quiero mi tableta');

        final custom = pic('quiero_agua').copyWith(label: 'Jugo');
        final saved = await content.saveCustomPictogram(
          'demo-juan',
          Pictogram.fromMap({
            ...custom.toMap(),
            'id': 'custom_jugo',
            'builtIn': false,
          }),
        );
        await content.setFavorite('demo-juan', saved.id, true);
        await content.deleteCustomPictogram('demo-juan', saved);
        c = await content.watchContent('demo-juan').first;
        expect(c.customPictograms, isEmpty);
        expect(c.favoritePictogramIds, isNot(contains('custom_jugo')));

        await content.deleteFrequentPhrase('demo-juan', 'nueva');
        c = await content.watchContent('demo-juan').first;
        expect(c.frequentPhrases.map((p) => p.id), isNot(contains('nueva')));
      },
    );
  });

  group('Estrategias', () {
    test('agregar, editar solo autor/administrador y eliminar', () async {
      await db.setSession(DemoSeed.ana.uid);
      final repo = DemoStrategiesRepository(db);
      final s = SupportStrategy(
        id: 'nueva',
        childId: 'demo-juan',
        title: 'Rincón tranquilo',
        place: StrategyPlace.school,
        result: StrategyResult.toTry,
        createdByUid: DemoSeed.ana.uid,
        createdByName: DemoSeed.ana.displayName,
        createdByRole: DemoSeed.ana.role,
        createdAt: DateTime.now(),
      );
      await repo.addStrategy(s);
      await expectLater(
        repo.updateStrategy(s.copyWith(title: 'x'), actor: DemoSeed.luis),
        throwsA(isA<PermissionDeniedException>()),
      );
      await repo.updateStrategy(
        s.copyWith(result: StrategyResult.worked),
        actor: DemoSeed.ana,
      );
      var list = await repo.watchStrategies('demo-juan').first;
      expect(
        list.firstWhere((e) => e.id == 'nueva').result,
        StrategyResult.worked,
      );

      await repo.deleteStrategy(s, actor: DemoSeed.maria);
      list = await repo.watchStrategies('demo-juan').first;
      expect(list.map((e) => e.id), isNot(contains('nueva')));
    });
  });
}
