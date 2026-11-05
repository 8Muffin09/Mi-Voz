import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/services/connectivity_service.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/services/photo_store.dart';
import 'package:mi_voz/core/services/speech_service.dart';
import 'package:mi_voz/features/profiles/application/profiles_providers.dart';
import 'package:mi_voz/features/welcome/application/welcome_preferences.dart';
import 'package:mi_voz/models/sensory_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSpeechService implements SpeechService {
  final spoken = <String>[];

  @override
  Future<bool> speak(String text, SensorySettings settings) async {
    spoken.add(text);
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<String>> availableSpanishLanguages() async => const ['es-MX'];

  @override
  void dispose() {}
}

class FakeConnectivity implements ConnectivityService {
  final _controller = StreamController<bool>.broadcast();
  bool online = true;

  void set(bool value) {
    online = value;
    _controller.add(value);
  }

  @override
  Future<bool> isOnline() async => online;

  @override
  Stream<bool> get onlineChanges => _controller.stream;
}

/// Cuenta las reproducciones en lugar de usar el audio del dispositivo.
class FakeMelodyPlayer implements MelodyPlayer {
  int plays = 0;

  @override
  Future<void> play() async => plays++;

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

/// Guarda las fotos en memoria (sin carpetas del dispositivo).
class FakePhotoStore implements PhotoStore {
  final saved = <String, String>{};
  final deleted = <String>[];

  @override
  Future<String> save({required String storagePath, required File file}) async {
    final ref = '${PhotoStore.filePrefix}/memoria/$storagePath';
    saved[storagePath] = ref;
    return ref;
  }

  @override
  Future<Uint8List?> load(String photo) async => null;

  @override
  Future<void> delete(String? photo) async {
    if (photo != null) deleted.add(photo);
  }
}

/// Prepara preferencias en memoria con el modo demostración elegido.
Future<SharedPreferences> demoPrefs({
  Map<String, Object> extra = const {},
}) async {
  await initializeDateFormatting('es');
  SharedPreferences.setMockInitialValues({
    LocalStore.keyAppMode: AppMode.demo.name,
    ...extra,
  });
  return SharedPreferences.getInstance();
}

List<Override> testOverrides(
  SharedPreferences prefs, {
  FakeSpeechService? speech,
  FakeConnectivity? connectivity,
  FakeMelodyPlayer? melody,
  FakePhotoStore? photos,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  firebaseAvailableProvider.overrideWithValue(false),
  // Personas ficticias aisladas, solo para las pruebas.
  demoSampleDataProvider.overrideWithValue(true),
  speechServiceProvider.overrideWithValue(speech ?? FakeSpeechService()),
  connectivityServiceProvider.overrideWithValue(
    connectivity ?? FakeConnectivity(),
  ),
  melodyPlayerProvider.overrideWithValue(melody ?? FakeMelodyPlayer()),
  photoStoreProvider.overrideWithValue(photos ?? FakePhotoStore()),
];

Future<ProviderContainer> demoContainer({
  Map<String, Object> extra = const {},
  FakeConnectivity? connectivity,
  FakeMelodyPlayer? melody,
  FakePhotoStore? photos,
}) async {
  final prefs = await demoPrefs(extra: extra);
  final container = ProviderContainer(
    overrides: testOverrides(
      prefs,
      connectivity: connectivity,
      melody: melody,
      photos: photos,
    ),
  );
  return container;
}

/// Contenedor con la sesión demo de [uid] ya cargada (y sus niños).
Future<ProviderContainer> signedInContainer(
  String? uid, {
  Map<String, Object> extra = const {},
  FakeMelodyPlayer? melody,
  FakePhotoStore? photos,
}) async {
  final container = await demoContainer(
    extra: {LocalStore.keyDemoSession: ?uid, ...extra},
    melody: melody,
    photos: photos,
  );
  container
    ..listen(authStateProvider, (_, _) {})
    ..listen(childrenProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(childrenProvider.future);
  return container;
}

/// Espera a que el flujo de sesión refleje el último cambio.
Future<void> flush() => Future<void>.delayed(Duration.zero);
