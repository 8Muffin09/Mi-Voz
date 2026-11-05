import '../../../models/app_user.dart';
import '../../../models/family.dart';

/// Familias: adultos responsables y sus niños.
abstract class FamiliesRepository {
  /// Familias en las que participa el adulto.
  Stream<List<Family>> watchFamiliesForAdult(String uid);

  /// Una familia; `null` si no existe o si el adulto actual no pertenece.
  Stream<Family?> watchFamily(String familyId);

  /// Crea una familia con el adulto como administrador y único integrante.
  Future<Family> createFamily({required AppUser owner, required String name});

  Future<void> renameFamily(
    Family family,
    String name, {
    required AppUser actor,
  });

  /// Retira a un adulto (el administrador a otros, o cada adulto a sí
  /// mismo). Pierde el acceso que le daba la familia; los datos de los niños
  /// se conservan.
  Future<void> removeAdult(
    Family family, {
    required AppUser actor,
    required String adultUid,
  });

  /// Actualización de datos anteriores a las familias: agrupa en una familia
  /// del adulto los perfiles que administra y que aún no tienen familia.
  /// Devuelve la familia usada, o `null` si no había nada que agrupar.
  Future<Family?> adoptOrphanChildren(AppUser owner);

  /// Antes de eliminar la cuenta de [actor]: sale de la familia o, si la
  /// administra, la entrega a otro adulto o la borra si se queda vacía. En
  /// Firebase, la entrega la completa la Cloud Function `cleanupOnUserDeleted`
  /// (las reglas no permiten cambiar de administrador desde la app).
  Future<void> releaseForAccountDeletion(
    Family family, {
    required AppUser actor,
  });
}
