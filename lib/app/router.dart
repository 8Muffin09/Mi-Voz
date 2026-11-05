import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/access/application/access_providers.dart';
import '../features/access/presentation/access_choice_screen.dart';
import '../features/access/presentation/create_account_screen.dart';
import '../features/access/presentation/group_setup_screen.dart';
import '../features/access/presentation/kids_access_screen.dart';
import '../features/access/presentation/start_screen.dart';
import '../features/access/presentation/switch_user_screen.dart';
import '../features/account/presentation/edit_profile_screen.dart';
import '../features/account/presentation/my_profile_screen.dart';
import '../features/adult/presentation/adult_home_screen.dart';
import '../features/adult/presentation/adult_shell.dart';
import '../features/adult/presentation/request_detail_screen.dart';
import '../features/adult/presentation/requests_screen.dart';
import '../features/authentication/presentation/forgot_password_screen.dart';
import '../features/authentication/presentation/login_screen.dart';
import '../features/authentication/presentation/register_screen.dart';
import '../features/authentication/presentation/splash_screen.dart';
import '../features/child/application/child_mode.dart';
import '../features/access/presentation/widgets/role_illustration.dart';
import '../features/classes/presentation/class_detail_screen.dart';
import '../features/classes/presentation/class_form_screen.dart';
import '../features/classes/presentation/classes_screen.dart';
import '../features/child/presentation/categories_screen.dart';
import '../features/child/presentation/child_home_screen.dart';
import '../features/child/presentation/communicate_screen.dart';
import '../features/child/presentation/favorites_screen.dart';
import '../features/child/presentation/frequent_phrases_screen.dart';
import '../features/child/presentation/phrase_builder_screen.dart';
import '../features/child/presentation/pictogram_selection_screen.dart';
import '../features/child/presentation/urgent_help_screen.dart';
import '../features/families/presentation/family_screens.dart';
import '../features/history/presentation/history_screen.dart';
import '../features/invitations/presentation/join_screen.dart';
import '../features/migration/presentation/migration_screen.dart';
import '../features/pictograms/presentation/pictogram_admin_screen.dart';
import '../features/profiles/presentation/caregivers_screen.dart';
import '../features/profiles/presentation/child_form_screen.dart';
import '../features/profiles/presentation/children_admin_screen.dart';
import '../features/profiles/presentation/profile_selection_screen.dart';
import '../features/profiles/presentation/responsible_adult_screen.dart';
import '../features/sensory_passport/presentation/passport_screen.dart';
import '../features/settings/presentation/general_settings_screen.dart';
import '../features/settings/presentation/sensory_settings_screen.dart';
import '../features/strategies/presentation/strategies_screen.dart';
import '../features/teacher/presentation/teacher_home_screen.dart';
import '../features/tutorial/presentation/tutorial_screen.dart';
import '../models/app_user.dart';
import 'providers.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Notifica al router cuando cambia algo que afecta a las guardas.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    // Solo cuando cambia quién inició sesión (no al editar su perfil): un
    // refresco a mitad de una navegación la desharía.
    ref.listen(
      authStateProvider.select(
        (a) => (a.isLoading && !a.hasValue, a.value?.uid),
      ),
      (_, _) => notifyListeners(),
    );
    ref.listen(childModeProvider, (_, _) => notifyListeners());
    ref.listen(splashDoneProvider, (_, _) => notifyListeners());
    ref.listen(activeExperienceProvider, (_, _) => notifyListeners());
  }
}

/// Pantallas sin sesión: bienvenida, acceso, creación de cuenta y tutorial.
const _publicRoutes = {
  Routes.start,
  Routes.access,
  Routes.createProfile,
  Routes.createStudent,
  Routes.tour,
  Routes.login,
  Routes.register,
  Routes.forgotPassword,
};

/// Pantallas de entrada que no tienen sentido con una sesión iniciada.
const _signedOutOnly = {
  Routes.start,
  Routes.access,
  Routes.createProfile,
  Routes.createStudent,
  Routes.login,
  Routes.register,
  Routes.forgotPassword,
};

/// Guardas de navegación:
/// - Sin sesión → bienvenida, acceso, registro y tutorial.
/// - Con sesión guardada → panel del adulto, o el selector de perfiles
///   infantiles si esta cuenta activó perfiles en el dispositivo (así el
///   niño no llega al panel sin PIN o contraseña).
/// - En modo niño → solo rutas `/child` (ni el botón Atrás ni un enlace
///   llevan a herramientas de adulto); al salir, al selector de perfiles.
/// - Crear perfiles infantiles → solo en la experiencia de familia.
/// Las reglas de Firestore aplican los permisos reales en el servidor.
String? appRedirect(Ref ref, GoRouterState state) {
  final location = state.matchedLocation;
  final splashDone = ref.read(splashDoneProvider);
  final auth = ref.read(authStateProvider);
  final childModeId = ref.read(childModeProvider);

  if (!splashDone || (auth.isLoading && !auth.hasValue)) {
    return location == Routes.splash ? null : Routes.splash;
  }

  final user = auth.value;
  if (user == null) {
    return _publicRoutes.contains(location) ? null : Routes.start;
  }
  if (childModeId != null) {
    return location.startsWith(Routes.child) ? null : Routes.child;
  }
  if (location.startsWith(Routes.child)) return Routes.profiles;
  if (location == Routes.splash || _signedOutOnly.contains(location)) {
    return ref.read(adultGateRequiredProvider)
        ? Routes.kidsAccess
        : Routes.adult;
  }
  if (location == Routes.kidNew &&
      ref.read(activeExperienceProvider) != UserExperience.guardian) {
    return Routes.adult;
  }
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => appRedirect(ref, state),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.start, builder: (_, _) => const StartScreen()),
      GoRoute(
        path: Routes.access,
        builder: (_, _) => const AccessChoiceScreen(),
      ),
      GoRoute(
        path: Routes.createProfile,
        builder: (_, _) => const CreateAccountScreen(),
        routes: [
          GoRoute(
            path: 'student',
            builder: (_, _) => const StudentProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: Routes.tour,
        builder: (_, s) => TutorialScreen(
          initialRole: AccessRole.values
              .asNameMap()[s.uri.queryParameters['role']],
        ),
      ),
      GoRoute(
        path: Routes.kidsAccess,
        builder: (_, _) => const KidsAccessScreen(),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: Routes.profiles,
        builder: (_, _) => const ProfileSelectionScreen(),
      ),

      // ---------------- Modo niño ----------------
      GoRoute(
        path: Routes.child,
        builder: (_, _) => const ChildHomeScreen(),
        routes: [
          GoRoute(
            path: 'categories',
            builder: (_, _) => const CategoriesScreen(),
          ),
          GoRoute(
            path: 'category/:categoryId',
            builder: (_, s) => PictogramSelectionScreen(
              categoryId: s.pathParameters['categoryId']!,
            ),
          ),
          GoRoute(
            path: 'phrase',
            builder: (_, _) => const PhraseBuilderScreen(),
          ),
          GoRoute(
            path: 'communicate/:requestId',
            builder: (_, s) =>
                CommunicateScreen(requestId: s.pathParameters['requestId']!),
          ),
          GoRoute(
            path: 'favorites',
            builder: (_, _) => const FavoritesScreen(),
          ),
          GoRoute(
            path: 'phrases',
            builder: (_, _) => const FrequentPhrasesScreen(),
          ),
          GoRoute(path: 'urgent', builder: (_, _) => const UrgentHelpScreen()),
        ],
      ),

      // ---------------- Adulto: pestañas ----------------
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AdultShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adult,
                builder: (_, _) => const _HomeByExperience(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adultRequests,
                builder: (_, _) => const RequestsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adultHistory,
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.adultSettings,
                builder: (_, _) => const GeneralSettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      // ---------------- Adulto: pantallas apiladas ----------------
      GoRoute(
        path: '/adult/request/:childId/:requestId',
        builder: (_, s) => RequestDetailScreen(
          childId: s.pathParameters['childId']!,
          requestId: s.pathParameters['requestId']!,
        ),
      ),
      GoRoute(
        path: Routes.transfer,
        builder: (_, _) => const MigrationScreen(),
      ),
      GoRoute(
        path: Routes.setupClass,
        builder: (_, _) => const GroupSetupScreen(teacher: true),
      ),
      GoRoute(
        path: Routes.setupFamily,
        builder: (_, _) => const GroupSetupScreen(teacher: false),
      ),
      GoRoute(
        path: Routes.join,
        builder: (_, s) =>
            JoinScreen(initialCode: s.uri.queryParameters['code']),
      ),
      GoRoute(
        path: Routes.students,
        builder: (_, _) => const ProfileSelectionScreen(selectStudent: true),
      ),
      GoRoute(
        path: Routes.classes,
        builder: (_, _) => const ClassesScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ClassFormScreen()),
          GoRoute(
            path: ':classId',
            builder: (_, s) =>
                ClassDetailScreen(classId: s.pathParameters['classId']!),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (_, s) =>
                    ClassFormScreen(classId: s.pathParameters['classId']),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.familyNew,
        builder: (_, _) => const FamilyFormScreen(),
      ),
      GoRoute(
        path: '/adult/family/:familyId',
        builder: (_, s) =>
            FamilyScreen(familyId: s.pathParameters['familyId']!),
      ),
      GoRoute(
        path: Routes.switchUser,
        builder: (_, _) => const SwitchUserScreen(),
      ),
      GoRoute(
        path: Routes.me,
        builder: (_, _) => const MyProfileScreen(),
        routes: [
          GoRoute(path: 'edit', builder: (_, _) => const EditProfileScreen()),
        ],
      ),
      GoRoute(
        path: Routes.kids,
        builder: (_, _) => const ChildrenAdminScreen(),
        routes: [
          GoRoute(path: 'new', builder: (_, _) => const ChildFormScreen()),
          GoRoute(
            path: ':childId/edit',
            builder: (_, s) =>
                ChildFormScreen(childId: s.pathParameters['childId']),
          ),
          GoRoute(
            path: ':childId/caregivers',
            builder: (_, s) =>
                CaregiversScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/passport',
            builder: (_, s) =>
                PassportScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/strategies',
            builder: (_, s) =>
                StrategiesScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/sensory',
            builder: (_, s) =>
                SensorySettingsScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/pictograms',
            builder: (_, s) =>
                PictogramAdminScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/responsible',
            builder: (_, s) =>
                ResponsibleAdultScreen(childId: s.pathParameters['childId']!),
          ),
          GoRoute(
            path: ':childId/history',
            builder: (_, s) =>
                HistoryScreen(childId: s.pathParameters['childId']),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

/// Inicio del adulto según la experiencia: panel de familia o panel docente.
class _HomeByExperience extends ConsumerWidget {
  const _HomeByExperience();

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(activeExperienceProvider) == UserExperience.teacher
      ? const TeacherHomeScreen()
      : const AdultHomeScreen();
}
