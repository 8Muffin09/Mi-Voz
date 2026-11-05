/// Rutas de Firestore y Storage. Los datos de cada niño viven bajo
/// `children/{childId}` para que las reglas de seguridad verifiquen la
/// pertenencia del adulto en cada lectura y escritura.
class FirestorePaths {
  const FirestorePaths._();

  static const users = 'users';
  static const children = 'children';
  static const invitations = 'invitations';
  static const families = 'families';
  static const classes = 'classes';
  static const notificationTokens = 'notification_tokens';

  static const caregiverLinks = 'caregiver_links';
  static const requests = 'communication_requests';
  static const passports = 'sensory_passports';
  static const strategies = 'support_strategies';
  static const favorites = 'favorites';
  static const pictograms = 'pictograms';

  static const passportDocId = 'main';

  static String user(String uid) => '$users/$uid';
  static String child(String childId) => '$children/$childId';
  static String family(String familyId) => '$families/$familyId';
  static String classroom(String classId) => '$classes/$classId';
  static String childSub(String childId, String sub) =>
      '$children/$childId/$sub';

  static String pictogramImage(String childId, String pictogramId) =>
      'children/$childId/pictograms/$pictogramId.jpg';

  /// Fotos de perfil opcionales (privadas según `storage.rules`).
  static String childAvatar(String childId) =>
      'children/$childId/avatar/photo.jpg';
  static String userAvatar(String uid) => 'users/$uid/avatar/photo.jpg';
}
