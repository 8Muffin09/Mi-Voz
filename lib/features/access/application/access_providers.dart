import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/local_store.dart';
import '../../../core/utils/json_utils.dart';
import '../../../core/utils/stream_utils.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../profiles/application/profiles_providers.dart';

// ---------------------------------------------------------------------------
// Experiencia elegida en "¿Cómo deseas ingresar?"
// ---------------------------------------------------------------------------

/// Experiencia elegida en este dispositivo (`null` si aún no se eligió).
class SelectedExperienceNotifier extends Notifier<UserExperience?> {
  @override
  UserExperience? build() {
    final raw = ref
        .watch(localStoreProvider)
        .getString(LocalStore.keyExperience);
    if (raw == null) return null;
    return enumByName<UserExperience>(
      UserExperience.values,
      raw,
      UserExperience.guardian,
    );
  }

  Future<void> select(UserExperience experience) async {
    await ref
        .read(localStoreProvider)
        .setString(LocalStore.keyExperience, experience.name);
    state = experience;
  }
}

final selectedExperienceProvider =
    NotifierProvider<SelectedExperienceNotifier, UserExperience?>(
      SelectedExperienceNotifier.new,
    );

/// Experiencia con la que se muestra el panel del adulto.
final activeExperienceProvider = Provider<UserExperience>((ref) {
  final chosen = ref.watch(selectedExperienceProvider);
  if (chosen != null) return chosen;
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isGuardian) return UserExperience.guardian;
  return UserExperience.teacher;
});

// ---------------------------------------------------------------------------
// Niños de cada experiencia
// ---------------------------------------------------------------------------

/// Un niño vinculado y el rol con el que el adulto está vinculado a él.
class LinkedChild {
  const LinkedChild(this.child, this.role);

  final ChildProfile child;
  final AdultRole? role;

  bool get asTeacher => role == AdultRole.docente;
}

/// Niños vinculados con el rol del adulto en cada vínculo.
final linkedChildrenProvider = StreamProvider<List<LinkedChild>>((ref) async* {
  final user = ref.watch(currentUserProvider);
  final children = await ref.watch(childrenProvider.future);
  if (user == null || children.isEmpty) {
    yield const [];
    return;
  }
  final repo = ref.watch(childrenRepositoryProvider);
  yield* combineLatestList([
    for (final child in children)
      repo
          .watchLinks(child.id)
          .map(
            (links) => LinkedChild(
              child,
              links.where((l) => l.adultUid == user.uid).firstOrNull?.role,
            ),
          ),
  ]);
});

/// Niños que corresponden a la experiencia activa. Si la cuenta solo tiene
/// una experiencia, son todos sus niños vinculados; si tiene las dos, los
/// alumnos (vínculo como docente) se separan de los hijos.
final experienceChildrenProvider = Provider<AsyncValue<List<ChildProfile>>>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final children = ref.watch(childrenProvider);
  if (user == null || !(user.isGuardian && user.isTeacher)) return children;
  final teacher = ref.watch(activeExperienceProvider) == UserExperience.teacher;
  return ref
      .watch(linkedChildrenProvider)
      .whenData(
        (list) => [
          for (final l in list)
            if (l.asTeacher == teacher) l.child,
        ],
      );
});

// ---------------------------------------------------------------------------
// Alumno actual del docente
// ---------------------------------------------------------------------------

/// Alumno elegido con "Cambiar alumno" (se recuerda por cuenta).
class CurrentStudentNotifier extends Notifier<String?> {
  @override
  String? build() {
    final uid = ref.watch(currentUserProvider)?.uid;
    if (uid == null) return null;
    return ref
        .watch(localStoreProvider)
        .getString(LocalStore.currentStudentKey(uid));
  }

  Future<void> select(String childId) async {
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;
    await ref
        .read(localStoreProvider)
        .setString(LocalStore.currentStudentKey(uid), childId);
    state = childId;
  }
}

final currentStudentIdProvider =
    NotifierProvider<CurrentStudentNotifier, String?>(
      CurrentStudentNotifier.new,
    );

/// Alumno actual autorizado. Si el guardado ya no está vinculado, el primero.
final currentStudentProvider = Provider<ChildProfile?>((ref) {
  final students =
      ref.watch(experienceChildrenProvider).value ?? const <ChildProfile>[];
  final id = ref.watch(currentStudentIdProvider);
  return students.where((c) => c.id == id).firstOrNull ?? students.firstOrNull;
});

// ---------------------------------------------------------------------------
// Perfiles infantiles activados en este dispositivo
// ---------------------------------------------------------------------------

/// Perfiles que un adulto activó en este dispositivo para que el niño entre
/// desde "¿Quién utilizará Mi Voz?" sin contraseña. Guarda `childId → uid del adulto`.
class DeviceProfilesNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() {
    final raw = ref
        .watch(localStoreProvider)
        .getJson(LocalStore.keyDeviceChildren);
    return {
      for (final e in (raw ?? const {}).entries)
        if (e.value is String) e.key: e.value as String,
    };
  }

  Future<void> authorize(String childId, String adultUid) =>
      _save({...state, childId: adultUid});

  Future<void> revoke(String childId) => _save({...state}..remove(childId));

  Future<void> _save(Map<String, String> next) async {
    await ref
        .read(localStoreProvider)
        .setJson(LocalStore.keyDeviceChildren, next);
    state = next;
  }
}

final deviceProfilesProvider =
    NotifierProvider<DeviceProfilesNotifier, Map<String, String>>(
      DeviceProfilesNotifier.new,
    );

/// Perfiles activados en el dispositivo por la cuenta actual y a los que
/// sigue vinculada. Otras cuentas del mismo teléfono no los ven.
final deviceChildrenProvider = Provider<AsyncValue<List<ChildProfile>>>((ref) {
  final user = ref.watch(currentUserProvider);
  final device = ref.watch(deviceProfilesProvider);
  if (user == null) return const AsyncData([]);
  return ref
      .watch(childrenProvider)
      .whenData(
        (children) => [
          for (final c in children)
            if (device[c.id] == user.uid) c,
        ],
      );
});

/// `true` si la cuenta actual activó perfiles infantiles en este dispositivo:
/// entonces entrar al panel de adulto exige la verificación de adulto.
final adultGateRequiredProvider = Provider<bool>((ref) {
  final uid = ref.watch(currentUserProvider)?.uid;
  return uid != null && ref.watch(deviceProfilesProvider).containsValue(uid);
});

// ---------------------------------------------------------------------------
// "Soy alumno" en la creación de perfil
// ---------------------------------------------------------------------------

/// `true` tras elegir "Soy alumno": el adulto que inicie sesión o se
/// registre a continuación pasa directamente a crear el perfil infantil.
class PendingStudentNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final pendingStudentProfileProvider =
    NotifierProvider<PendingStudentNotifier, bool>(PendingStudentNotifier.new);
