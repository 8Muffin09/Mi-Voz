import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../../core/demo/demo_database.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../core/services/local_store.dart';
import '../../../core/services/photo_store.dart';
import '../../../core/utils/app_exception.dart';
import '../../../core/visuals/avatar_catalog.dart';
import '../../../core/visuals/symbol_catalog.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/pictogram.dart';
import '../../../models/sensory_passport.dart';
import '../../../models/support_strategy.dart';
import '../../pictograms/data/content_repository.dart';
import '../../profiles/data/children_repository.dart';
import '../../sensory_passport/data/passport_repository.dart';
import '../../strategies/data/strategies_repository.dart';

/// Escribe el historial anterior en el servidor (las reglas no permiten que
/// el cliente cree solicitudes con fechas o estados pasados).
abstract class HistoryImporter {
  /// Devuelve cuántas se escribieron (las ya existentes no se duplican).
  Future<int> importHistory(String childId, List<Map<String, dynamic>> items);
}

/// Repositorios de la cuenta de destino (la nube, o en las pruebas otra
/// base local que la simula).
class MigrationTarget {
  const MigrationTarget({
    required this.children,
    required this.content,
    required this.passport,
    required this.strategies,
    required this.history,
    required this.photos,
  });

  final ChildrenRepository children;
  final ContentRepository content;
  final PassportRepository passport;
  final StrategiesRepository strategies;
  final HistoryImporter history;
  final PhotoStore photos;
}

/// Cuenta local (de versiones que guardaban todo en el dispositivo) que
/// administra perfiles todavía no transferidos. No expone sus perfiles hasta
/// que se confirma la contraseña de esa cuenta.
class LocalAccountSummary {
  const LocalAccountSummary({
    required this.uid,
    required this.displayName,
    required this.maskedEmail,
    required this.pendingProfiles,
  });

  final String uid;
  final String displayName;
  final String maskedEmail;
  final int pendingProfiles;
}

class LocalChildSummary {
  const LocalChildSummary({
    required this.child,
    required this.favorites,
    required this.phrases,
    required this.customPictograms,
    required this.history,
    required this.strategies,
    required this.transferredTo,
  });

  final ChildProfile child;
  final int favorites;
  final int phrases;
  final int customPictograms;
  final int history;
  final int strategies;

  /// Cuenta a la que ya se transfirió (`null` = pendiente).
  final String? transferredTo;
}

class MigrationResult {
  const MigrationResult({required this.profiles, required this.history});

  final int profiles;
  final int history;
}

/// Transfiere a la cuenta con sesión los datos que una cuenta local guardó
/// en este dispositivo.
///
/// Reglas:
/// - Nunca es automático: se elige la cuenta local, se confirma con SU
///   contraseña (así en un teléfono compartido nadie sube los perfiles de
///   otra persona) y se marcan los perfiles a transferir.
/// - Solo se ofrecen los perfiles que esa cuenta local administra.
/// - Un perfil se transfiere a una sola cuenta: queda registrado y no se
///   ofrece a otras (los demás adultos se unen con una invitación).
/// - Idempotente: el identificador del perfil en la nube se deriva del local
///   y de la cuenta, y favoritos, frases, pictogramas, estrategias e
///   historial conservan sus identificadores. Repetir tras un corte de red
///   completa lo que faltaba sin duplicar.
/// - Los datos locales no se borran.
class LocalDataMigration {
  LocalDataMigration({required DemoDatabase source, required LocalStore store})
    : _db = source,
      // ignore: prefer_initializing_formals
      _store = store;

  final DemoDatabase _db;
  final LocalStore _store;

  static const keyClaims = 'migration_claims';

  /// `childId local → uid de la cuenta en la nube` ya transferidos.
  Map<String, String> get _claims => {
    for (final e in (_store.getJson(keyClaims) ?? const {}).entries)
      if (e.value is String) e.key: e.value as String,
  };

  Future<void> _claim(String localChildId, String cloudUid) =>
      _store.setJson(keyClaims, {..._claims, localChildId: cloudUid});

  /// Identificador estable del perfil transferido.
  static String cloudChildId(String cloudUid, String localChildId) =>
      'm${sha256.convert(utf8.encode('$cloudUid:$localChildId')).toString().substring(0, 19)}';

  List<ChildProfile> _ownedBy(String localUid) => [
    for (final row in _db.where(
      DemoDatabase.children,
      (r) => r['ownerUid'] == localUid,
    ))
      ChildProfile.fromMap(row),
  ];

  /// Cuentas locales con perfiles sin transferir.
  List<LocalAccountSummary> pendingAccounts() {
    final claims = _claims;
    return [
      for (final row in _db.all(DemoDatabase.users))
        if (_ownedBy(row['uid'] as String? ?? '')
                .where((c) => !claims.containsKey(c.id))
                .length
            case final n when n > 0)
          LocalAccountSummary(
            uid: row['uid'] as String,
            displayName: row['displayName'] as String? ?? 'Cuenta',
            maskedEmail: maskEmail(row['email'] as String? ?? ''),
            pendingProfiles: n,
          ),
    ];
  }

  bool get hasPendingData => pendingAccounts().isNotEmpty;

  static String maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email.isEmpty ? '' : '•••${email.substring(at)}';
    return '${email[0]}•••${email.substring(at)}';
  }

  /// Comprueba la contraseña de la cuenta local (hash guardado en el
  /// dispositivo; la contraseña nunca se envía a ningún servidor).
  bool verifyOwner(String localUid, String password) {
    final row = _db.get(DemoDatabase.users, localUid);
    return row != null &&
        row['passwordHash'] == DemoDatabase.hashPassword(localUid, password);
  }

  /// Perfiles de la cuenta local. Exige la contraseña confirmada.
  List<LocalChildSummary> childrenOf(String localUid, String password) {
    if (!verifyOwner(localUid, password)) {
      throw const AppException('La contraseña de esa cuenta no es correcta.');
    }
    final claims = _claims;
    return [
      for (final child in _ownedBy(localUid))
        () {
          final content = _content(child.id);
          return LocalChildSummary(
            child: child,
            favorites: content.favoritePictogramIds.length,
            phrases: content.frequentPhrases.length,
            customPictograms: content.customPictograms.length,
            history: _history(child.id).length,
            strategies: _strategies(child.id).length,
            transferredTo: claims[child.id],
          );
        }(),
    ];
  }

  ChildContent _content(String childId) {
    final row = _db.get(DemoDatabase.content, childId);
    return row == null ? ChildContent.empty : ChildContent.fromMap(row);
  }

  List<Map<String, dynamic>> _history(String childId) =>
      _db.where(DemoDatabase.requests, (r) => r['childId'] == childId);

  List<Map<String, dynamic>> _strategies(String childId) =>
      _db.where(DemoDatabase.strategies, (r) => r['childId'] == childId);

  /// Transfiere [childIds] (de la cuenta local [localUid]) a [cloudUser].
  Future<MigrationResult> transfer({
    required String localUid,
    required String password,
    required Set<String> childIds,
    required AppUser cloudUser,
    required MigrationTarget target,
  }) async {
    if (!verifyOwner(localUid, password)) {
      throw const AppException('La contraseña de esa cuenta no es correcta.');
    }
    final claims = _claims;
    var profiles = 0;
    var history = 0;
    for (final child in _ownedBy(localUid)) {
      if (!childIds.contains(child.id)) continue;
      final owner = claims[child.id];
      if (owner != null && owner != cloudUser.uid) {
        throw const AppException(
          'Ese perfil ya se transfirió a otra cuenta. Pide a esa persona que '
          'te invite.',
        );
      }
      history += await _transferChild(child, cloudUser, target);
      await _claim(child.id, cloudUser.uid);
      profiles++;
    }
    return MigrationResult(profiles: profiles, history: history);
  }

  Future<int> _transferChild(
    ChildProfile local,
    AppUser cloudUser,
    MigrationTarget target,
  ) async {
    final id = cloudChildId(cloudUser.uid, local.id);
    final avatar = AvatarCatalog.normalize(
      local.avatar,
      fallback: AvatarCatalog.defaultChild,
    );

    // 1. Perfil (si un intento anterior ya lo creó, se reutiliza).
    ChildProfile? existing;
    try {
      existing = await target.children.watchChild(id).first;
    } catch (_) {
      existing = null;
    }
    final created =
        existing ??
        await target.children.createChild(
          id: id,
          owner: cloudUser,
          name: local.name,
          lastName: local.lastName,
          avatar: avatar,
          avatarColor: local.avatarColor,
          gender: local.gender,
          settings: local.settings,
        );

    // Fotografía opcional (solo si sigue en el dispositivo).
    final photo = local.photo;
    if (photo != null && photo.startsWith('file:') && created.photo == null) {
      final file = File(photo.substring(5));
      if (file.existsSync()) {
        final ref = await target.photos.save(
          storagePath: FirestorePaths.childAvatar(id),
          file: file,
        );
        await target.children.updateChildProfile(
          created,
          name: created.name,
          lastName: created.lastName,
          avatar: avatar,
          avatarColor: created.avatarColor,
          gender: created.gender,
          photo: ref,
        );
      }
    }

    // 2. Favoritos, frases y pictogramas propios: el destino queda igual que
    // el dispositivo (también sin los favoritos iniciales que se quitaron).
    final source = _content(local.id);
    final current = await target.content.watchContent(id).first;
    final wanted = source.favoritePictogramIds.toSet();
    for (final fav in wanted.difference(current.favoritePictogramIds.toSet())) {
      await target.content.setFavorite(id, fav, true);
    }
    for (final fav in current.favoritePictogramIds.toSet().difference(wanted)) {
      await target.content.setFavorite(id, fav, false);
    }
    final phraseIds = {for (final p in source.frequentPhrases) p.id};
    for (final p in current.frequentPhrases) {
      if (!phraseIds.contains(p.id)) {
        await target.content.deleteFrequentPhrase(id, p.id);
      }
    }
    for (final p in source.frequentPhrases) {
      // La frase conserva su texto; solo la imagen pasa al catálogo nuevo.
      await target.content.saveFrequentPhrase(
        id,
        p.copyWith(emoji: SymbolCatalog.normalize(p.emoji)),
      );
    }
    final existingCustom = {for (final p in current.customPictograms) p.id};
    for (final p in source.customPictograms) {
      if (existingCustom.contains(p.id)) continue;
      final path = p.imagePath;
      final image = path != null && File(path).existsSync() ? File(path) : null;
      await target.content.saveCustomPictogram(
        id,
        p.copyWith(
          categoryId: p.categoryId,
          emoji: SymbolCatalog.normalize(p.emoji),
          imagePath: () => null,
          imageUrl: () => null,
        ),
        image: image,
      );
    }

    // 3. Pasaporte sensorial y estrategias.
    final passportRow = _db.get(DemoDatabase.passports, local.id);
    if (passportRow != null) {
      await target.passport.savePassport(
        SensoryPassport.fromMap({...passportRow, 'childId': id}),
        editorName: cloudUser.displayName,
      );
    }
    for (final row in _strategies(local.id)) {
      await target.strategies.addStrategy(
        SupportStrategy.fromMap({
          ...row,
          'childId': id,
          'createdByUid': cloudUser.uid,
        }),
      );
    }

    // 4. Historial (por lotes; los ya transferidos no se duplican).
    final items = [
      for (final row in _history(local.id))
        // Las filas locales ya guardan fechas ISO-8601 (serializables).
        {
          ...row,
          'childId': id,
          'emoji': SymbolCatalog.normalize(row['emoji'] as String? ?? ''),
        },
    ];
    var imported = 0;
    for (var i = 0; i < items.length; i += 200) {
      imported += await target.history.importHistory(
        id,
        items.sublist(i, (i + 200).clamp(0, items.length)),
      );
    }
    return imported;
  }
}
