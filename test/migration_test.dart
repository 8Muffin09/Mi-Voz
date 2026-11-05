import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/demo/demo_database.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/core/visuals/avatar_catalog.dart';
import 'package:mi_voz/core/visuals/symbol_catalog.dart';
import 'package:mi_voz/features/authentication/data/demo_auth_repository.dart';
import 'package:mi_voz/features/migration/application/local_data_migration.dart';
import 'package:mi_voz/features/pictograms/data/demo_content_repository.dart';
import 'package:mi_voz/features/profiles/data/demo_children_repository.dart';
import 'package:mi_voz/features/sensory_passport/data/demo_passport_repository.dart';
import 'package:mi_voz/features/strategies/data/demo_strategies_repository.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/pictogram.dart';

import 'helpers.dart';

/// Simula la función del servidor: escribe el historial sin duplicar.
class _FakeHistory implements HistoryImporter {
  _FakeHistory(this.db);

  final DemoDatabase db;

  @override
  Future<int> importHistory(
    String childId,
    List<Map<String, dynamic>> items,
  ) async {
    var n = 0;
    for (final r in items) {
      if (db.get(DemoDatabase.requests, r['id'] as String) != null) continue;
      db.put(DemoDatabase.requests, r['id'] as String, {
        ...r,
        'imported': true,
      });
      n++;
    }
    db.commit();
    return n;
  }
}

void main() {
  late DemoDatabase local;
  late DemoDatabase cloud;
  late LocalStore store;
  late LocalDataMigration migration;
  late MigrationTarget target;

  Future<AppUser> cloudAccount(String email) => DemoAuthRepository(cloud)
      .register(
        email: email,
        password: 'clave1234',
        displayName: 'Cuenta nube',
        role: AdultRole.madre,
      );

  setUp(() async {
    final prefs = await demoPrefs();
    store = LocalStore(prefs);
    // Base del dispositivo con cuentas locales anteriores (María, Ana...).
    local = DemoDatabase(store, seedSampleData: true);
    // "Nube" simulada: otra base vacía en memoria.
    cloud = DemoDatabase(store);
    await cloud.reset();
    migration = LocalDataMigration(source: local, store: store);
    target = MigrationTarget(
      children: DemoChildrenRepository(cloud),
      content: DemoContentRepository(cloud),
      passport: DemoPassportRepository(cloud),
      strategies: DemoStrategiesRepository(cloud),
      history: _FakeHistory(cloud),
      photos: FakePhotoStore(),
    );
  });

  List<ChildProfile> owned(DemoDatabase db, String uid) => [
    for (final r in db.where(
      DemoDatabase.children,
      (r) => r['ownerUid'] == uid,
    ))
      ChildProfile.fromMap(r),
  ];

  test('lista las cuentas locales sin mostrar sus perfiles ni el correo', () {
    final accounts = migration.pendingAccounts();
    final maria = accounts.firstWhere((a) => a.uid == DemoSeed.maria.uid);
    expect(maria.pendingProfiles, owned(local, DemoSeed.maria.uid).length);
    expect(maria.maskedEmail, isNot(DemoSeed.maria.email));
    expect(maria.maskedEmail, endsWith('@demo.mivoz'));
  });

  test(
    'sin la contraseña de la cuenta local no se ven ni se transfieren',
    () async {
      expect(
        () => migration.childrenOf(DemoSeed.maria.uid, 'otra'),
        throwsA(isA<AppException>()),
      );
      final user = await cloudAccount('nueva@ejemplo.mx');
      expect(
        () => migration.transfer(
          localUid: DemoSeed.maria.uid,
          password: 'otra',
          childIds: {owned(local, DemoSeed.maria.uid).first.id},
          cloudUser: user,
          target: target,
        ),
        throwsA(isA<AppException>()),
      );
      expect(cloud.all(DemoDatabase.children), isEmpty);
    },
  );

  test('transfiere solo lo elegido, conserva contenido e historial y no '
      'duplica al repetir', () async {
    final user = await cloudAccount('nueva@ejemplo.mx');
    final source = owned(local, DemoSeed.maria.uid).first;
    final summary = migration
        .childrenOf(DemoSeed.maria.uid, DemoSeed.password)
        .firstWhere((s) => s.child.id == source.id);

    Future<void> run() => migration.transfer(
      localUid: DemoSeed.maria.uid,
      password: DemoSeed.password,
      childIds: {source.id},
      cloudUser: user,
      target: target,
    );
    await run();

    final id = LocalDataMigration.cloudChildId(user.uid, source.id);
    final copy = ChildProfile.fromMap(cloud.get(DemoDatabase.children, id)!);
    // Un único perfil, administrado por la cuenta de la nube.
    expect(cloud.all(DemoDatabase.children), hasLength(1));
    expect(copy.ownerUid, user.uid);
    expect(copy.memberUids, [user.uid]);
    expect(copy.name, source.name);
    // El avatar se guarda con el identificador del catálogo.
    expect(AvatarCatalog.byId(copy.avatar), isNotNull);
    expect(copy.avatar, AvatarCatalog.normalize(source.avatar, fallback: ''));

    final sourceContent = ChildContent.fromMap(
      local.get(DemoDatabase.content, source.id) ?? const {},
    );
    final copyContent = ChildContent.fromMap(
      cloud.get(DemoDatabase.content, id)!,
    );
    expect(
      copyContent.favoritePictogramIds.toSet(),
      sourceContent.favoritePictogramIds.toSet(),
    );
    // Las frases dicen lo mismo; solo cambia la imagen al catálogo nuevo.
    expect(
      [for (final p in copyContent.frequentPhrases) p.text],
      [for (final p in sourceContent.frequentPhrases) p.text],
    );
    for (final p in copyContent.frequentPhrases) {
      expect(SymbolCatalog.resolve(p.emoji), isNotNull, reason: p.text);
    }
    final history = cloud.where(
      DemoDatabase.requests,
      (r) => r['childId'] == id,
    );
    expect(history, hasLength(summary.history));

    // Repetir (p. ej. tras un corte de red) no duplica nada.
    await run();
    expect(cloud.all(DemoDatabase.children), hasLength(1));
    expect(
      cloud.where(DemoDatabase.requests, (r) => r['childId'] == id),
      hasLength(summary.history),
    );
    expect(
      ChildContent.fromMap(cloud.get(DemoDatabase.content, id)!)
          .frequentPhrases
          .length,
      sourceContent.frequentPhrases.length,
    );

    // Los datos locales no se borran.
    expect(local.get(DemoDatabase.children, source.id), isNotNull);
  });

  test(
    'un perfil transferido no se ofrece a otra cuenta del dispositivo',
    () async {
      final first = await cloudAccount('primera@ejemplo.mx');
      final source = owned(local, DemoSeed.maria.uid).first;
      final before = migration
          .pendingAccounts()
          .firstWhere((a) => a.uid == DemoSeed.maria.uid)
          .pendingProfiles;
      await migration.transfer(
        localUid: DemoSeed.maria.uid,
        password: DemoSeed.password,
        childIds: {source.id},
        cloudUser: first,
        target: target,
      );
      final after = migration
          .pendingAccounts()
          .where((a) => a.uid == DemoSeed.maria.uid)
          .firstOrNull
          ?.pendingProfiles;
      expect(after ?? 0, before - 1);

      final second = await cloudAccount('segunda@ejemplo.mx');
      expect(
        () => migration.transfer(
          localUid: DemoSeed.maria.uid,
          password: DemoSeed.password,
          childIds: {source.id},
          cloudUser: second,
          target: target,
        ),
        throwsA(isA<AppException>()),
      );
    },
  );
}
