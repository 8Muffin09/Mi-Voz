import '../../models/caregiver_link.dart';
import '../../models/child_profile.dart';
import '../../models/classroom.dart';
import '../../models/communication_request.dart';
import '../../models/family.dart';
import '../../models/support_strategy.dart';

/// Reglas de autorización por roles. Las mismas reglas están en
/// `firebase/firestore.rules`; aquí se usan para la interfaz y para el
/// backend local del modo demostración.
class Permissions {
  const Permissions._();

  static bool isMember(ChildProfile child, String? uid) =>
      uid != null && child.memberUids.contains(uid);

  static bool isOwner(ChildProfile child, String? uid) =>
      uid != null && child.ownerUid == uid && isMember(child, uid);

  /// Ver perfil, solicitudes, historial, pasaporte y estrategias.
  static bool canView(ChildProfile child, String? uid) => isMember(child, uid);

  /// Editar pasaporte, favoritos, pictogramas y opciones sensoriales.
  static bool canEditSupport(ChildProfile child, String? uid) =>
      isMember(child, uid);

  /// Invitar o desvincular adultos.
  static bool canManageCaregivers(ChildProfile child, String? uid) =>
      isOwner(child, uid);

  static bool canDeleteChild(ChildProfile child, String? uid) =>
      isOwner(child, uid);

  /// Un adulto puede marcarse a sí mismo como responsable; el
  /// administrador puede asignar a cualquier adulto vinculado.
  static bool canSetResponsible(
    ChildProfile child, {
    required String? actorUid,
    required String? targetUid,
  }) {
    if (!isMember(child, actorUid)) return false;
    if (targetUid == null) {
      // Dejar de acompañar: el propio responsable o el administrador.
      return child.responsibleUid == actorUid || isOwner(child, actorUid);
    }
    if (!isMember(child, targetUid)) return false;
    return targetUid == actorUid || isOwner(child, actorUid);
  }

  /// El administrador puede quitar a cualquiera excepto a sí mismo;
  /// cualquier adulto puede desvincularse a sí mismo.
  static bool canRemoveLink(
    ChildProfile child, {
    required String? actorUid,
    required String targetUid,
  }) {
    if (!isMember(child, actorUid) || !isMember(child, targetUid)) return false;
    if (targetUid == child.ownerUid) return false;
    return isOwner(child, actorUid) || actorUid == targetUid;
  }

  static bool canCreateRequest(ChildProfile child, String? uid) =>
      isMember(child, uid);

  static bool canUpdateRequest(ChildProfile child, String? uid) =>
      isMember(child, uid);

  static bool canEditStrategy(
    ChildProfile child,
    SupportStrategy strategy,
    String? uid,
  ) =>
      isMember(child, uid) &&
      (strategy.createdByUid == uid || isOwner(child, uid));

  /// Ver el Pasaporte Sensorial: adulto vinculado al que la familia no le
  /// retiró ese permiso.
  static bool canViewPassport(
    ChildProfile child,
    String? uid,
    CaregiverLink? link,
  ) => isMember(child, uid) && (link?.canViewPassport ?? true);

  /// Cambiar los permisos de los adultos de un niño: su administrador.
  static bool canManageLinkPermissions(ChildProfile child, String? uid) =>
      isOwner(child, uid);

  /// Renombrar la familia o retirar adultos: su administrador.
  static bool canManageFamily(Family family, String? uid) =>
      family.isOwner(uid);

  /// Retirar a un adulto de la familia: el administrador (a otros) o el
  /// propio adulto (a sí mismo). El administrador no puede retirarse.
  static bool canRemoveFamilyAdult(
    Family family, {
    required String? actorUid,
    required String targetUid,
  }) {
    if (!family.isAdult(actorUid) || !family.isAdult(targetUid)) return false;
    if (targetUid == family.ownerUid) return false;
    return family.isOwner(actorUid) || actorUid == targetUid;
  }

  /// Editar, archivar la clase y retirar alumnos: su docente propietario.
  static bool canManageClass(Classroom classroom, String? uid) =>
      classroom.isOwner(uid);

  /// Agregar a la clase un alumno al que el docente ya tiene acceso: no
  /// amplía permisos (los alumnos nuevos llegan con invitación).
  static bool canAddAuthorizedStudent(
    Classroom classroom,
    ChildProfile child,
    String? uid,
  ) => canManageClass(classroom, uid) && isMember(child, uid);

  /// Los estados solo avanzan: Nueva → Vista → Atendiendo → Resuelta.
  static bool isValidTransition(RequestStatus from, RequestStatus to) =>
      to.index > from.index;
}

/// Decide a quién va dirigida una solicitud.
/// A quién llega el aviso de una solicitud. La Cloud Function
/// `notifyOnRequestCreated` aplica exactamente la misma lógica.
class RecipientPlan {
  const RecipientPlan({required this.companion, required this.byRule});

  /// Adulto que acompaña ahora (vinculado y autorizado a recibir), o `null`.
  final String? companion;

  /// Destinatarios según la regla "si nadie acompaña" del niño.
  final List<String> byRule;

  /// Primer intento: quien acompaña o, si no hay, la regla.
  List<String> get primary => companion == null ? byRule : [companion!];

  /// Si quien acompaña no tiene dispositivos para recibir el aviso.
  List<String> get fallback => [
    for (final uid in byRule)
      if (uid != companion) uid,
  ];
}

class RecipientResolver {
  const RecipientResolver._();

  /// El adulto responsable actual si sigue vinculado; si no, `null`
  /// (se aplica la regla "si nadie acompaña").
  static String? recipientUid(ChildProfile child) =>
      child.hasResponsible ? child.responsibleUid : null;

  static String? recipientName(ChildProfile child) =>
      child.hasResponsible ? child.responsibleName : null;

  /// Calcula los destinatarios autorizados. Con [links], se excluye a los
  /// adultos a los que la familia no permite recibir solicitudes. Nunca se
  /// avisa a todos los adultos salvo que el administrador lo haya elegido.
  static RecipientPlan plan(
    ChildProfile child, {
    Iterable<CaregiverLink> links = const [],
  }) {
    final blocked = {
      for (final l in links)
        if (!l.receivesRequests) l.adultUid,
    };
    bool allowed(String uid) =>
        child.memberUids.contains(uid) && !blocked.contains(uid);

    final companion = recipientUid(child);
    final byRule = switch (child.noCompanionRule) {
      NoCompanionRule.admin => [child.ownerUid],
      NoCompanionRule.chosen => child.backupUids,
      NoCompanionRule.all => child.memberUids,
    };
    return RecipientPlan(
      companion: companion != null && allowed(companion) ? companion : null,
      byRule: List.unmodifiable(byRule.where(allowed).toSet()),
    );
  }

  /// Destinatarios del primer intento (ver [plan]).
  static List<String> recipients(
    ChildProfile child, {
    Iterable<CaregiverLink> links = const [],
  }) => plan(child, links: links).primary;
}
