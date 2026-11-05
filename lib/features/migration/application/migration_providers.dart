import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/app_exception.dart';
import 'local_data_migration.dart';

/// Historial a la nube con la función `importLocalHistory`
/// (functions/migration.js): valida en el servidor que quien llama
/// administra el perfil.
class CloudHistoryImporter implements HistoryImporter {
  CloudHistoryImporter(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<int> importHistory(
    String childId,
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) return 0;
    try {
      final result = await _functions
          .httpsCallable('importLocalHistory')
          .call<Map<String, dynamic>>({'childId': childId, 'requests': items});
      return (result.data['imported'] as num?)?.toInt() ?? 0;
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
        throw const OfflineException();
      }
      if (e.code == 'permission-denied') {
        throw const PermissionDeniedException();
      }
      throw AppException(
        'No pudimos transferir el historial. Intenta nuevamente.',
      );
    }
  }
}

final localDataMigrationProvider = Provider<LocalDataMigration>(
  (ref) => LocalDataMigration(
    source: ref.watch(demoDatabaseProvider),
    store: ref.watch(localStoreProvider),
  ),
);

/// Solo con la nube: ofrecer la transferencia si quedan perfiles locales.
final hasLocalDataToMigrateProvider = Provider<bool>((ref) {
  if (!ref.watch(isFirebaseModeProvider)) return false;
  if (ref.watch(currentUserProvider) == null) return false;
  ref.watch(migrationRefreshProvider);
  return ref.watch(localDataMigrationProvider).hasPendingData;
});

/// Se incrementa al terminar una transferencia para recalcular lo pendiente.
class MigrationRefresh extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final migrationRefreshProvider = NotifierProvider<MigrationRefresh, int>(
  MigrationRefresh.new,
);

/// Destino de la transferencia: los repositorios de la cuenta con sesión.
/// Se puede sobrescribir en pruebas.
final migrationTargetProvider = Provider<MigrationTarget>(
  (ref) => MigrationTarget(
    children: ref.watch(childrenRepositoryProvider),
    content: ref.watch(contentRepositoryProvider),
    passport: ref.watch(passportRepositoryProvider),
    strategies: ref.watch(strategiesRepositoryProvider),
    photos: ref.watch(photoStoreProvider),
    history: CloudHistoryImporter(
      FirebaseFunctions.instanceFor(region: 'us-central1'),
    ),
  ),
);
