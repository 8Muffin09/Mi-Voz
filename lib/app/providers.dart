import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/demo/demo_database.dart';
import '../core/platform/platform_capabilities.dart';
import '../core/services/connectivity_service.dart';
import '../core/services/feedback_service.dart';
import '../core/services/local_store.dart';
import '../core/services/photo_store.dart';
import '../core/services/speech_service.dart';
import '../features/authentication/data/auth_repository.dart';
import '../features/authentication/data/demo_auth_repository.dart';
import '../features/authentication/data/firebase_auth_repository.dart';
import '../features/classes/data/classes_repository.dart';
import '../features/classes/data/demo_classes_repository.dart';
import '../features/classes/data/firebase_classes_repository.dart';
import '../features/communication/data/demo_requests_repository.dart';
import '../features/communication/data/firebase_requests_repository.dart';
import '../features/communication/data/requests_repository.dart';
import '../features/families/data/demo_families_repository.dart';
import '../features/families/data/families_repository.dart';
import '../features/families/data/firebase_families_repository.dart';
import '../features/invitations/data/demo_invitations_repository.dart';
import '../features/invitations/data/firebase_invitations_repository.dart';
import '../features/invitations/data/invitations_repository.dart';
import '../features/notifications/application/in_app_notifications.dart';
import '../features/notifications/data/push_notification_service.dart';
import '../features/pictograms/data/content_repository.dart';
import '../features/pictograms/data/demo_content_repository.dart';
import '../features/pictograms/data/firebase_content_repository.dart';
import '../features/profiles/data/children_repository.dart';
import '../features/profiles/data/demo_children_repository.dart';
import '../features/profiles/data/firebase_children_repository.dart';
import '../features/sensory_passport/data/demo_passport_repository.dart';
import '../features/sensory_passport/data/firebase_passport_repository.dart';
import '../features/sensory_passport/data/passport_repository.dart';
import '../features/strategies/data/demo_strategies_repository.dart';
import '../features/strategies/data/firebase_strategies_repository.dart';
import '../features/strategies/data/strategies_repository.dart';
import '../models/app_user.dart';

/// Backend interno (no es una opción del usuario).
enum AppMode {
  /// Cuentas y datos solo en este dispositivo (sin nube configurada).
  /// También es la base aislada de pruebas automáticas.
  demo,

  /// Cuentas en la nube: sincronización entre dispositivos y avisos push.
  firebase,
}

// ---------------------------------------------------------------------------
// Infraestructura (se sobrescriben en main.dart y en las pruebas)
// ---------------------------------------------------------------------------

final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Se inicializa en main.dart'),
);

/// `true` si `Firebase.initializeApp` funcionó (configuración válida).
final firebaseAvailableProvider = Provider<bool>((ref) => false);

final localStoreProvider = Provider<LocalStore>(
  (ref) => LocalStore(ref.watch(sharedPreferencesProvider)),
);

final speechServiceProvider = Provider<SpeechService>((ref) {
  final service = FlutterSpeechService();
  ref.onDispose(service.dispose);
  return service;
});

final feedbackServiceProvider = Provider<FeedbackService>(
  (ref) => const FeedbackService(),
);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => PlusConnectivityService(),
);

/// Hay red (según el sistema). No garantiza que el servidor responda: la
/// entrega real la confirma la cola de envío.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityServiceProvider);
  yield await connectivity.isOnline();
  yield* connectivity.onlineChanges;
});

// ---------------------------------------------------------------------------
// Modo de la app
// ---------------------------------------------------------------------------

/// Backend de cuentas y datos. No lo elige el usuario: si el proyecto tiene
/// la nube configurada (`firebase_options.dart` válido) siempre se usa; si
/// no (compilaciones de desarrollo sin configurar), la app sigue funcionando
/// con cuentas guardadas solo en el dispositivo. La interfaz nunca muestra
/// nombres de servicios: solo estados como "Sin conexión" o "Datos
/// sincronizados" (ver `syncStatusProvider`).
final appModeProvider = Provider<AppMode>(
  (ref) =>
      ref.watch(firebaseAvailableProvider) ? AppMode.firebase : AppMode.demo,
);
final isFirebaseModeProvider = Provider<bool>(
  (ref) =>
      ref.watch(appModeProvider) == AppMode.firebase &&
      ref.watch(firebaseAvailableProvider),
);

final isDemoModeProvider = Provider<bool>(
  (ref) => !ref.watch(isFirebaseModeProvider),
);

/// `true` solo en pruebas automáticas: carga personas ficticias en el modo
/// local. La app nunca muestra ni precarga cuentas de ejemplo.
final demoSampleDataProvider = Provider<bool>((ref) => false);

final demoDatabaseProvider = Provider<DemoDatabase>(
  (ref) => DemoDatabase(
    ref.watch(localStoreProvider),
    seedSampleData: ref.watch(demoSampleDataProvider),
  ),
);

// ---------------------------------------------------------------------------
// Repositorios (demo o Firebase según el modo)
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseAuthRepository(
      FirebaseAuth.instance,
      FirebaseFirestore.instance,
    );
  }
  return DemoAuthRepository(ref.watch(demoDatabaseProvider));
});

final childrenRepositoryProvider = Provider<ChildrenRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseChildrenRepository(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
  }
  return DemoChildrenRepository(ref.watch(demoDatabaseProvider));
});

final familiesRepositoryProvider = Provider<FamiliesRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseFamiliesRepository(FirebaseFirestore.instance);
  }
  return DemoFamiliesRepository(ref.watch(demoDatabaseProvider));
});

final classesRepositoryProvider = Provider<ClassesRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseClassesRepository(FirebaseFirestore.instance);
  }
  return DemoClassesRepository(ref.watch(demoDatabaseProvider));
});

final invitationsRepositoryProvider = Provider<InvitationsRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseInvitationsRepository(
      FirebaseFirestore.instance,
      // Misma región que `setGlobalOptions` en functions/index.js.
      FirebaseFunctions.instanceFor(region: 'us-central1'),
      uid: ref.watch(sessionUidProvider),
    );
  }
  return DemoInvitationsRepository(ref.watch(demoDatabaseProvider));
});

final requestsRepositoryProvider = Provider<RequestsRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseRequestsRepository(FirebaseFirestore.instance);
  }
  return DemoRequestsRepository(
    ref.watch(demoDatabaseProvider),
    onSimulatedPush: (request, recipientUids) {
      ref
          .read(inAppNotificationsProvider.notifier)
          .show(
            InAppNotice(
              title: request.notificationTitle,
              body: request.message,
              simulated: true,
              childId: request.childId,
              requestId: request.id,
              urgent: request.isUrgent,
              recipientLabel: request.notifiedNames.isEmpty
                  ? null
                  : request.notifiedNames.join(', '),
            ),
          );
    },
  );
});

final contentRepositoryProvider = Provider<ContentRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseContentRepository(
      FirebaseFirestore.instance,
      FirebaseStorage.instance,
    );
  }
  return DemoContentRepository(ref.watch(demoDatabaseProvider));
});

final passportRepositoryProvider = Provider<PassportRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebasePassportRepository(FirebaseFirestore.instance);
  }
  return DemoPassportRepository(ref.watch(demoDatabaseProvider));
});

final strategiesRepositoryProvider = Provider<StrategiesRepository>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebaseStrategiesRepository(FirebaseFirestore.instance);
  }
  return DemoStrategiesRepository(ref.watch(demoDatabaseProvider));
});

final photoStoreProvider = Provider<PhotoStore>((ref) {
  if (ref.watch(isFirebaseModeProvider)) {
    return FirebasePhotoStore(FirebaseStorage.instance);
  }
  return const LocalPhotoStore();
});

/// Bytes de una foto de perfil (`null` si no está disponible).
final photoBytesProvider = FutureProvider.family<Uint8List?, String>((
  ref,
  photo,
) {
  ref.watch(sessionUidProvider);
  return ref.watch(photoStoreProvider).load(photo);
});

/// Solo existe en modo Firebase y donde hay FCM (no en Windows: allí los
/// avisos llegan con la app abierta, ver `requestWatcherProvider`).
final pushNotificationServiceProvider = Provider<PushNotificationService?>((
  ref,
) {
  if (!ref.watch(isFirebaseModeProvider) ||
      !ref.watch(pushNotificationsSupportedProvider)) {
    return null;
  }
  return PushNotificationService(
    FirebaseMessaging.instance,
    FirebaseFirestore.instance,
  );
});

// ---------------------------------------------------------------------------
// Sesión
// ---------------------------------------------------------------------------

final authStateProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUserProvider = Provider<AppUser?>(
  (ref) => ref.watch(authStateProvider).value,
);

/// Identificador de la cuenta con sesión. Los proveedores con datos de un
/// niño lo observan para descartarse al cambiar de cuenta: nada de la cuenta
/// anterior queda en memoria para la siguiente.
final sessionUidProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider.select((u) => u?.uid)),
);
