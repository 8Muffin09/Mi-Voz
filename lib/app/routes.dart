/// Rutas de navegación de la app.
class Routes {
  const Routes._();

  static const splash = '/splash';

  /// Bienvenida: logo, explicación, "Comenzar" y "Conocer cómo funciona".
  static const start = '/start';

  /// "Iniciar sesión" o "Crear una cuenta".
  static const access = '/access';

  /// "Crear una cuenta": selector único de tipo de perfil.
  static const createProfile = '/create';

  /// Perfil de alumno: lo crea y vincula un adulto responsable.
  static const createStudent = '/create/student';

  /// Tutorial "Conocer cómo funciona" (sin datos reales).
  static const tour = '/tour';

  /// Recorrido que empieza en el rol indicado (teacher, guardian, child).
  static String tourFor(String role) => '/tour?role=$role';

  /// Perfiles infantiles activados en este dispositivo (sesión guardada).
  static const kidsAccess = '/kids';

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';

  /// "¿Quién utilizará Mi Voz?": activa el modo niño para un perfil.
  static const profiles = '/profiles';

  // Modo niño
  static const child = '/child';
  static const childCategories = '/child/categories';
  static String childCategory(String categoryId) =>
      '/child/category/$categoryId';
  static const childPhrase = '/child/phrase';
  static String childCommunicate(String requestId) =>
      '/child/communicate/$requestId';
  static const childFavorites = '/child/favorites';
  static const childPhrases = '/child/phrases';
  static const childUrgent = '/child/urgent';

  // Adulto (pestañas)
  static const adult = '/adult';
  static const adultRequests = '/adult/requests';
  static const adultHistory = '/adult/history';
  static const adultSettings = '/adult/settings';

  // Adulto (pantallas apiladas)
  static String requestDetail(String childId, String requestId) =>
      '/adult/request/$childId/$requestId';
  static const kids = '/adult/kids';
  static const kidNew = '/adult/kids/new';
  static String kidEdit(String id) => '/adult/kids/$id/edit';
  static String caregivers(String id) => '/adult/kids/$id/caregivers';
  static String passport(String id) => '/adult/kids/$id/passport';
  static String strategies(String id) => '/adult/kids/$id/strategies';
  static String sensory(String id) => '/adult/kids/$id/sensory';
  static String pictogramAdmin(String id) => '/adult/kids/$id/pictograms';
  static String responsible(String id) => '/adult/kids/$id/responsible';
  static String childHistory(String id) => '/adult/kids/$id/history';
  static const join = '/adult/join';

  /// Tras registrarse: crear la clase o la familia, o unirse con un código.
  static const setupClass = '/adult/setup/class';
  static const setupFamily = '/adult/setup/family';

  /// Transferir a la cuenta los perfiles guardados solo en este dispositivo.
  static const transfer = '/adult/transfer';

  /// "Selecciona un alumno" (cambia el alumno actual del docente).
  static const students = '/adult/students';

  /// "Cambiar perfil": perfil, alumno, experiencia o cuenta.
  static const switchUser = '/adult/switch';

  /// Clases del docente.
  static const classes = '/adult/classes';
  static const classNew = '/adult/classes/new';
  static String classDetail(String id) => '/adult/classes/$id';
  static String classEdit(String id) => '/adult/classes/$id/edit';

  /// Familias del padre, madre o tutor.
  static const familyNew = '/adult/family/new';
  static String family(String id) => '/adult/family/$id';

  /// "Mi perfil" del adulto.
  static const me = '/adult/me';
  static const meEdit = '/adult/me/edit';
}
