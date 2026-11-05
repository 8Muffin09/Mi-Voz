import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/services/firestore_paths.dart';
import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../access/application/access_providers.dart';
import '../../child/application/child_mode.dart';
import '../../communication/application/outbox.dart';
import '../../notifications/application/in_app_notifications.dart';
import '../../profiles/application/profiles_providers.dart';

/// Acciones de sesión que involucran varias piezas de la app.
class SessionActions {
  SessionActions(this._ref);

  final Ref _ref;

  Future<AppUser> signIn(String email, String password) => _ref
      .read(authRepositoryProvider)
      .signIn(email: email, password: password);

  /// Registra al adulto con su perfil y, si eligió una, sube su fotografía.
  Future<AppUser> register({
    required String email,
    required String password,
    required String displayName,
    required AdultRole role,
    String? lastName,
    String? avatar,
    int? avatarColor,
    String? schoolName,
    String? groupName,
    String? teacherTitle,
    Set<UserExperience> experiences = const {},
    File? photo,
  }) async {
    final user = await _ref
        .read(authRepositoryProvider)
        .register(
          email: email,
          password: password,
          displayName: displayName,
          role: role,
          lastName: lastName,
          avatar: avatar,
          avatarColor: avatarColor,
          schoolName: schoolName,
          groupName: groupName,
          teacherTitle: teacherTitle,
          experiences: experiences,
        );
    if (photo == null) return user;
    final ref = await _ref
        .read(photoStoreProvider)
        .save(storagePath: FirestorePaths.userAvatar(user.uid), file: photo);
    final withPhoto = user.copyWith(photo: () => ref);
    await _ref.read(authRepositoryProvider).updateProfile(withPhoto);
    return withPhoto;
  }

  /// Guarda "Mi perfil". [newPhoto] reemplaza la foto; [removePhoto] la quita.
  Future<AppUser> updateProfile(
    AppUser updated, {
    File? newPhoto,
    bool removePhoto = false,
  }) async {
    final current = _ref.read(currentUserProvider);
    final photos = _ref.read(photoStoreProvider);
    var user = updated;
    if (newPhoto != null) {
      final ref = await photos.save(
        storagePath: FirestorePaths.userAvatar(user.uid),
        file: newPhoto,
      );
      if (current?.photo != null && current!.photo!.startsWith('file:')) {
        await photos.delete(current.photo);
      }
      user = user.copyWith(photo: () => ref);
    } else if (removePhoto) {
      await photos.delete(current?.photo);
      user = user.copyWith(photo: () => null);
    }
    await _ref.read(authRepositoryProvider).updateProfile(user);
    if (current != null && current.displayName != user.displayName) {
      final children = _ref.read(childrenProvider).value ?? const [];
      await _ref.read(childrenRepositoryProvider).syncAdultName(user, children);
    }
    return user;
  }

  /// Agrega una experiencia (familia o docente) a la misma cuenta.
  Future<void> addExperience(
    UserExperience experience, {
    String? schoolName,
    String? groupName,
    String? teacherTitle,
  }) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    var updated = user.copyWith(
      experiences: {...user.effectiveExperiences, experience},
    );
    if (experience == UserExperience.teacher) {
      updated = updated.copyWith(
        schoolName: () => _clean(schoolName) ?? user.schoolName,
        groupName: () => _clean(groupName) ?? user.groupName,
        teacherTitle: () => _clean(teacherTitle) ?? user.teacherTitle,
      );
    }
    await _ref.read(authRepositoryProvider).updateProfile(updated);
    await _ref.read(selectedExperienceProvider.notifier).select(experience);
  }

  Future<void> changePassword(String current, String next) => _ref
      .read(authRepositoryProvider)
      .changePassword(currentPassword: current, newPassword: next);

  /// "Entrar al perfil de Juan": activa el modo niño y deja el perfil
  /// disponible en "¿Quién utilizará Mi Voz?" de este dispositivo.
  Future<void> enterChildProfile(ChildProfile child) async {
    final user = _ref.read(currentUserProvider);
    if (user == null || !child.memberUids.contains(user.uid)) return;
    await _ref
        .read(deviceProfilesProvider.notifier)
        .authorize(child.id, user.uid);
    await _ref.read(childModeProvider.notifier).enter(child.id);
  }

  /// Solicitudes de este dispositivo que aún no llegan al servidor.
  int get pendingRequests => _ref.read(outboxProvider).length;

  /// Cierra sesión de forma segura: el dispositivo deja de recibir avisos,
  /// se sale del modo niño y se borran las cachés locales de perfiles y la
  /// cola de envío (nada de esta cuenta queda visible para la siguiente).
  Future<void> signOut() async {
    await _ref.read(pushNotificationServiceProvider)?.unregister();
    await _ref.read(childModeProvider.notifier).exit();
    await _ref.read(localStoreProvider).clearUserData();
    _ref.invalidate(outboxProvider);
    _ref.read(inAppNotificationsProvider.notifier).clear();
    await _ref.read(authRepositoryProvider).signOut();
  }

  /// "Cambiar cuenta": cierra la sesión actual y prepara el acceso con otra
  /// cuenta en la experiencia indicada.
  Future<void> switchAccount({UserExperience? to}) async {
    await signOut();
    if (to != null) {
      await _ref.read(selectedExperienceProvider.notifier).select(to);
    }
  }

  /// Elimina la cuenta y los datos: perfiles administrados por el adulto
  /// (con todo su contenido) y sus vínculos con otros perfiles.
  Future<void> deleteAccountAndData(String password) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final auth = _ref.read(authRepositoryProvider);
    await auth.verifyPassword(password);

    // Primero las clases que administra (aún tiene acceso a sus alumnos para
    // retirarlos), luego los niños y al final las familias.
    final classesRepo = _ref.read(classesRepositoryProvider);
    final classes = await classesRepo.watchClassesForTeacher(user.uid).first;
    for (final classroom in classes) {
      if (classroom.ownerUid == user.uid) {
        await classesRepo.releaseForAccountDeletion(classroom, actor: user);
      }
    }

    final repo = _ref.read(childrenRepositoryProvider);
    final photos = _ref.read(photoStoreProvider);
    final children = await repo.watchChildrenForAdult(user.uid).first;
    for (final child in children) {
      if (child.ownerUid == user.uid) {
        await repo.deleteChild(child, actor: user);
        await photos.delete(child.photo);
        await _ref.read(deviceProfilesProvider.notifier).revoke(child.id);
      } else {
        await repo.removeLink(child: child, actor: user, adultUid: user.uid);
      }
    }
    final familiesRepo = _ref.read(familiesRepositoryProvider);
    final families = await familiesRepo.watchFamiliesForAdult(user.uid).first;
    for (final family in families) {
      await familiesRepo.releaseForAccountDeletion(family, actor: user);
    }

    await photos.delete(user.photo);
    await _ref.read(pushNotificationServiceProvider)?.unregister();
    await _ref.read(childModeProvider.notifier).exit();
    await _ref.read(localStoreProvider).clearUserData();
    await auth.deleteAccount(password: password);
  }

  static String? _clean(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}

final sessionActionsProvider = Provider<SessionActions>(SessionActions.new);
