import '../../../models/app_user.dart';
import '../../../models/caregiver_link.dart';
import '../../../models/child_profile.dart';
import '../../../models/sensory_settings.dart';

/// Perfiles infantiles, vínculos con adultos y adulto responsable.
abstract class ChildrenRepository {
  /// Niños a los que el adulto está vinculado.
  Stream<List<ChildProfile>> watchChildrenForAdult(String uid);

  /// Un perfil; `null` si no existe o si el adulto actual no está vinculado.
  Stream<ChildProfile?> watchChild(String childId);

  Future<ChildProfile> createChild({
    required AppUser owner,
    required String name,
    required String avatar,
    required int avatarColor,
    required GrammaticalGender gender,
    String? lastName,
    SensorySettings settings = const SensorySettings(),

    /// Familia del niño: todos sus adultos obtienen acceso.
    String? familyId,

    /// Identificador fijo (p. ej. al transferir datos de este dispositivo:
    /// repetir la transferencia no crea otro perfil). Por defecto, uno nuevo.
    String? id,
  });

  /// Actualiza los datos básicos. [lastName] y [photo] se guardan tal cual
  /// (`null` los borra).
  Future<void> updateChildProfile(
    ChildProfile child, {
    required String name,
    required String avatar,
    required int avatarColor,
    required GrammaticalGender gender,
    String? lastName,
    String? photo,
  });

  Future<void> updateSettings(String childId, SensorySettings settings);

  /// `adult == null` deja al niño sin responsable.
  Future<void> setResponsible({
    required ChildProfile child,
    required AppUser actor,
    required CaregiverLink? adult,
  });

  /// Elimina el perfil y todos sus datos asociados.
  Future<void> deleteChild(ChildProfile child, {required AppUser actor});

  Stream<List<CaregiverLink>> watchLinks(String childId);

  Stream<List<Invitation>> watchInvitations(ChildProfile child, String uid);

  Future<Invitation> createInvitation({
    required ChildProfile child,
    required AdultRole role,
    required AppUser createdBy,
  });

  Future<void> revokeInvitation(Invitation invitation);

  /// Valida el código y crea el vínculo de forma verificable.
  Future<CaregiverLink> acceptInvitation({
    required String code,
    required AppUser adult,
  });

  Future<void> removeLink({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
  });

  /// Permisos de un adulto sobre el niño (solo el administrador del perfil).
  Future<void> setLinkPermissions({
    required ChildProfile child,
    required AppUser actor,
    required String adultUid,
    required bool receivesRequests,
    required bool canViewPassport,
  });

  /// A quién avisar cuando nadie acompaña (solo el administrador del perfil).
  Future<void> setNoCompanionRule({
    required ChildProfile child,
    required AppUser actor,
    required NoCompanionRule rule,
    required List<String> backupUids,
  });

  /// Tras editar "Mi perfil": actualiza el nombre del adulto en sus propios
  /// vínculos (y como responsable) para que los demás lo vean actualizado.
  Future<void> syncAdultName(AppUser adult, List<ChildProfile> children);
}
