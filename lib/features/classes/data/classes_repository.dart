import '../../../models/app_user.dart';
import '../../../models/child_profile.dart';
import '../../../models/classroom.dart';

/// Clases o grupos escolares de los docentes.
abstract class ClassesRepository {
  /// Clases en las que el adulto es docente (activas y archivadas).
  Stream<List<Classroom>> watchClassesForTeacher(String uid);

  /// Una clase; `null` si no existe o si el adulto actual no es docente.
  Stream<Classroom?> watchClass(String classId);

  Future<Classroom> createClass({
    required AppUser owner,
    required String name,
    String description = '',
  });

  Future<void> updateClass(
    Classroom classroom, {
    required String name,
    required String description,
    required AppUser actor,
  });

  /// Archivar conserva la clase y su historial, sin mostrarla entre las
  /// activas. Se puede reactivar.
  Future<void> setArchived(
    Classroom classroom,
    bool archived, {
    required AppUser actor,
  });

  /// Agrega a la clase un alumno al que el docente ya tiene acceso. No
  /// concede permisos nuevos: los alumnos nuevos llegan con invitación.
  Future<void> addAuthorizedStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  });

  /// Retira al alumno de la clase. Si su acceso venía solo de esta clase,
  /// el docente deja de ver al alumno. Los datos del niño se conservan.
  /// Antes de eliminar la cuenta del docente: retira a los alumnos de su clase
  /// (pierde el acceso que le daba) y la cierra. En Firebase, la Cloud
  /// Function `cleanupOnUserDeleted` borra después la clase archivada.
  Future<void> releaseForAccountDeletion(
    Classroom classroom, {
    required AppUser actor,
  });

  Future<void> removeStudent(
    Classroom classroom,
    ChildProfile child, {
    required AppUser actor,
  });
}
