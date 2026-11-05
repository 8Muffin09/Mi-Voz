import '../../features/pictograms/data/pictogram_catalog.dart';
import '../../models/app_user.dart';
import '../../models/caregiver_link.dart';
import '../../models/child_profile.dart';
import '../../models/classroom.dart';
import '../../models/communication_request.dart';
import '../../models/family.dart';
import '../../models/pictogram.dart';
import '../../models/sensory_passport.dart';
import '../../models/sensory_settings.dart';
import '../../models/support_strategy.dart';
import 'demo_database.dart';

/// Datos de ejemplo del modo demostración. Todos son ficticios.
///
/// - María López (madre): administra a Juan y a Sofía.
/// - Luis Pérez (padre): autorizado con Juan y Sofía.
/// - Ana López (docente, "Maestra Ana"): alumnos Juan y Mateo.
/// - Carlos Ruiz (padre): administra a Mateo.
class DemoSeed {
  const DemoSeed._();

  static const password = 'demo1234';

  static const maria = AppUser(
    uid: 'demo-maria',
    email: 'maria@demo.mivoz',
    displayName: 'María López',
    lastName: 'López',
    role: AdultRole.madre,
    avatar: '👩',
    avatarColor: 0xFFFFE1E6,
    experiences: {UserExperience.guardian},
  );
  static const luis = AppUser(
    uid: 'demo-luis',
    email: 'luis@demo.mivoz',
    displayName: 'Luis Pérez',
    lastName: 'Pérez',
    role: AdultRole.padre,
    avatar: '👨',
    avatarColor: 0xFFDCEBFF,
    experiences: {UserExperience.guardian},
  );
  static const ana = AppUser(
    uid: 'demo-ana',
    email: 'ana@demo.mivoz',
    displayName: 'Ana López',
    lastName: 'López',
    role: AdultRole.docente,
    avatar: '👩‍🏫',
    avatarColor: 0xFFDFF3E8,
    teacherTitle: 'Maestra',
    schoolName: 'Escuela Primaria Arcoíris',
    groupName: '2.º B',
    experiences: {UserExperience.teacher},
  );
  static const carlos = AppUser(
    uid: 'demo-carlos',
    email: 'carlos@demo.mivoz',
    displayName: 'Carlos Ruiz',
    lastName: 'Ruiz',
    role: AdultRole.padre,
    avatar: '👨‍🦱',
    avatarColor: 0xFFFFEBD6,
    experiences: {UserExperience.guardian},
  );

  static const demoUsers = [maria, ana, luis, carlos];

  static const familyLopez = 'demo-familia-lopez';
  static const familyRuiz = 'demo-familia-ruiz';
  static const class2b = 'demo-clase-2b';

  static void populate(DemoDatabase db) {
    final now = DateTime.now();

    for (final u in demoUsers) {
      db.put(DemoDatabase.users, u.uid, {
        ...u.toMap(),
        'createdAt': now.subtract(const Duration(days: 30)),
        'passwordHash': DemoDatabase.hashPassword(u.uid, password),
      });
    }

    // Familias y clase: el mismo niño está en su familia y en su clase.
    db.put(
      DemoDatabase.families,
      familyLopez,
      Family(
        id: familyLopez,
        name: 'Familia López',
        ownerUid: maria.uid,
        adultUids: [maria.uid, luis.uid],
        adultNames: {maria.uid: maria.displayName, luis.uid: luis.displayName},
        adultRoles: {maria.uid: maria.role, luis.uid: luis.role},
        createdAt: now.subtract(const Duration(days: 30)),
      ).toMap(),
    );
    db.put(
      DemoDatabase.families,
      familyRuiz,
      Family(
        id: familyRuiz,
        name: 'Familia Ruiz',
        ownerUid: carlos.uid,
        adultUids: [carlos.uid],
        adultNames: {carlos.uid: carlos.displayName},
        adultRoles: {carlos.uid: carlos.role},
        createdAt: now.subtract(const Duration(days: 12)),
      ).toMap(),
    );
    db.put(
      DemoDatabase.classes,
      class2b,
      Classroom(
        id: class2b,
        name: '2.º B',
        description: 'Grupo de la mañana',
        ownerUid: ana.uid,
        teacherUids: [ana.uid],
        teacherNames: {ana.uid: ana.displayName},
        studentIds: const ['demo-juan', 'demo-mateo'],
        createdAt: now.subtract(const Duration(days: 14)),
      ).toMap(),
    );

    final juan = ChildProfile(
      id: 'demo-juan',
      name: 'Juan',
      avatar: '🦁',
      avatarColor: ChildProfile.colorOptions[1],
      gender: GrammaticalGender.masculine,
      ownerUid: maria.uid,
      memberUids: [maria.uid, luis.uid, ana.uid],
      familyId: familyLopez,
      classIds: const [class2b],
      responsibleUid: maria.uid,
      responsibleName: maria.displayName,
      responsibleSince: now.subtract(const Duration(hours: 2)),
      createdAt: now.subtract(const Duration(days: 30)),
    );
    final sofia = ChildProfile(
      id: 'demo-sofia',
      name: 'Sofía',
      avatar: '🦄',
      avatarColor: ChildProfile.colorOptions[5],
      gender: GrammaticalGender.feminine,
      ownerUid: maria.uid,
      memberUids: [maria.uid, luis.uid],
      familyId: familyLopez,
      settings: const SensorySettings(
        pictogramSize: PictogramSize.large,
        pictogramsPerPage: 6,
      ),
      createdAt: now.subtract(const Duration(days: 20)),
    );
    final mateo = ChildProfile(
      id: 'demo-mateo',
      name: 'Mateo',
      avatar: '🐢',
      avatarColor: ChildProfile.colorOptions[0],
      gender: GrammaticalGender.masculine,
      ownerUid: carlos.uid,
      memberUids: [carlos.uid, ana.uid],
      familyId: familyRuiz,
      classIds: const [class2b],
      settings: const SensorySettings(calmMode: true, soundsEnabled: false),
      createdAt: now.subtract(const Duration(days: 12)),
    );
    for (final c in [juan, sofia, mateo]) {
      db.put(DemoDatabase.children, c.id, c.toMap());
    }

    void link(ChildProfile c, AppUser u, LinkPermission p) {
      final teacher = u.uid == ana.uid;
      final l = CaregiverLink(
        childId: c.id,
        adultUid: u.uid,
        adultName: u.displayName,
        adultEmail: u.email,
        role: u.role,
        permission: p,
        source: teacher ? LinkSource.classroom : LinkSource.family,
        classIds: teacher ? const [class2b] : const [],
        invitedByUid: p == LinkPermission.owner ? null : c.ownerUid,
        createdAt: now.subtract(const Duration(days: 15)),
      );
      db.put(DemoDatabase.links, l.id, l.toMap());
    }

    link(juan, maria, LinkPermission.owner);
    link(juan, luis, LinkPermission.caregiver);
    link(juan, ana, LinkPermission.caregiver);
    link(sofia, maria, LinkPermission.owner);
    link(sofia, luis, LinkPermission.caregiver);
    link(mateo, carlos, LinkPermission.owner);
    link(mateo, ana, LinkPermission.caregiver);

    // Favoritos y frases independientes para cada niño.
    db.put(
      DemoDatabase.content,
      juan.id,
      const ChildContent(
        favoritePictogramIds: PictogramCatalog.defaultFavoriteIds,
        frequentPhrases: PictogramCatalog.defaultFrequentPhrases,
      ).toMap(),
    );
    db.put(
      DemoDatabase.content,
      sofia.id,
      const ChildContent(
        favoritePictogramIds: [
          'quiero_dibujar',
          'quiero_cuento',
          'me_siento_feliz',
          'tengo_sed',
        ],
        frequentPhrases: [
          FrequentPhrase(
            id: 'fp_dibujar',
            text: 'Quiero dibujar',
            emoji: '🖍️',
            categoryId: 'quiero',
            order: 0,
          ),
          FrequentPhrase(
            id: 'fp_cuento',
            text: 'Quiero un cuento',
            emoji: '📖',
            categoryId: 'quiero',
            order: 1,
          ),
          FrequentPhrase(
            id: 'fp_mama',
            text: 'Quiero ir con mamá',
            emoji: '👩',
            categoryId: 'quiero_ir',
            order: 2,
          ),
        ],
      ).toMap(),
    );
    db.put(
      DemoDatabase.content,
      mateo.id,
      const ChildContent(
        favoritePictogramIds: [
          'necesito_audifonos',
          'necesito_solo',
          'quiero_ir_tranquilo',
        ],
        frequentPhrases: [
          FrequentPhrase(
            id: 'fp_tranquilo',
            text: 'Quiero ir a mi lugar tranquilo',
            emoji: '🌈',
            categoryId: 'quiero_ir',
            order: 0,
          ),
          FrequentPhrase(
            id: 'fp_audifonos',
            text: 'Necesito mis audífonos',
            emoji: '🎧',
            categoryId: 'necesito',
            order: 1,
          ),
        ],
      ).toMap(),
    );

    final passport = SensoryPassport(
      childId: juan.id,
      sensitivities: const {
        SensoryArea.noise: Sensitivity(
          level: SensitivityLevel.high,
          notes:
              'Los ruidos fuertes y repentinos (timbre, licuadora) lo alteran.',
        ),
        SensoryArea.light: Sensitivity(
          level: SensitivityLevel.medium,
          notes:
              'Prefiere luz natural; las lámparas fluorescentes le molestan.',
        ),
        SensoryArea.touch: Sensitivity(
          level: SensitivityLevel.medium,
          notes: 'Avisarle antes de tocarlo. Le gustan los abrazos firmes.',
        ),
        SensoryArea.smell: Sensitivity(level: SensitivityLevel.low),
        SensoryArea.texture: Sensitivity(
          level: SensitivityLevel.high,
          notes: 'Etiquetas de ropa y comidas grumosas.',
        ),
      },
      personalPreferences: 'Le encantan los dinosaurios y los trenes.',
      favoriteObjects: const ['Dinosaurio de peluche', 'Audífonos azules'],
      calmingActivities: const ['Escuchar música suave', 'Armar rompecabezas'],
      safePlaces: const ['Rincón de lectura del salón', 'Su habitación'],
      triggers: const [
        'Cambios de rutina sin aviso',
        'Filas largas y ruidosas',
      ],
      supportStrategies: const [
        'Anticipar los cambios con pictogramas',
        'Ofrecer audífonos cuando hay ruido',
      ],
      communicationPreferences:
          'Usa pictogramas y frases cortas. Darle tiempo para responder.',
      updatedAt: now.subtract(const Duration(days: 3)),
      updatedByName: maria.displayName,
    );
    db.put(DemoDatabase.passports, juan.id, passport.toMap());

    final mateoPassport = SensoryPassport(
      childId: mateo.id,
      sensitivities: const {
        SensoryArea.noise: Sensitivity(
          level: SensitivityLevel.high,
          notes: 'Se tapa los oídos en el recreo.',
        ),
      },
      personalPreferences: 'Le gustan las tortugas y los bloques.',
      calmingActivities: const ['Balancearse', 'Contar bloques'],
      safePlaces: const ['Esquina con cojines del salón'],
      communicationPreferences: 'Responde mejor con pocas opciones a la vez.',
      updatedAt: now.subtract(const Duration(days: 5)),
      updatedByName: carlos.displayName,
    );
    db.put(DemoDatabase.passports, mateo.id, mateoPassport.toMap());

    final strategies = [
      SupportStrategy(
        id: 'demo-str-1',
        childId: juan.id,
        title: 'Utilizar audífonos cuando existe demasiado ruido',
        description: 'Se los ofrecemos antes de entrar al supermercado.',
        place: StrategyPlace.home,
        result: StrategyResult.worked,
        createdByUid: maria.uid,
        createdByName: maria.displayName,
        createdByRole: maria.role,
        createdAt: now.subtract(const Duration(days: 6)),
      ),
      SupportStrategy(
        id: 'demo-str-2',
        childId: juan.id,
        title: 'Temporizador visual antes de cambiar de actividad',
        description: 'Aviso de 5 minutos con temporizador de colores.',
        place: StrategyPlace.school,
        result: StrategyResult.partial,
        createdByUid: ana.uid,
        createdByName: ana.displayName,
        createdByRole: ana.role,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      SupportStrategy(
        id: 'demo-str-3',
        childId: mateo.id,
        title: 'Salir unos minutos antes al recreo',
        description: 'Evita el ruido de la salida de todos los grupos.',
        place: StrategyPlace.school,
        result: StrategyResult.worked,
        createdByUid: ana.uid,
        createdByName: ana.displayName,
        createdByRole: ana.role,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ];
    for (final s in strategies) {
      db.put(DemoDatabase.strategies, s.id, s.toMap());
    }

    CommunicationRequest past({
      required String id,
      required ChildProfile child,
      required String categoryId,
      required String message,
      required String emoji,
      required Duration ago,
      required RequestStatus status,
      required AppUser recipient,
      bool urgent = false,
    }) {
      final created = now.subtract(ago);
      final category = PictogramCatalog.categoryById(categoryId);
      return CommunicationRequest(
        id: id,
        childId: child.id,
        childName: child.name,
        categoryId: categoryId,
        categoryTitle: category?.title ?? 'AYUDA URGENTE',
        message: message,
        emoji: emoji,
        priority: urgent ? RequestPriority.high : RequestPriority.normal,
        isUrgent: urgent,
        recipientUid: recipient.uid,
        recipientName: recipient.displayName,
        createdByUid: child.ownerUid,
        createdAt: created,
        status: status,
        statusUpdatedAt: created.add(const Duration(minutes: 3)),
        statusUpdatedByUid: recipient.uid,
        statusUpdatedByName: recipient.displayName,
        seenAt: status.index >= RequestStatus.seen.index
            ? created.add(const Duration(minutes: 1))
            : null,
        attendingAt: status.index >= RequestStatus.attending.index
            ? created.add(const Duration(minutes: 2))
            : null,
        resolvedAt: status == RequestStatus.resolved
            ? created.add(const Duration(minutes: 3))
            : null,
        delivery: DeliveryStatus.delivered,
        deliveredAt: created,
        notification: NotificationStatus.simulated,
        notifiedAt: created,
        notifiedNames: [recipient.displayName],
      );
    }

    final history = [
      past(
        id: 'demo-req-1',
        child: juan,
        categoryId: 'me_molesta',
        message: 'Me molesta mucho el ruido',
        emoji: '🔊',
        ago: const Duration(days: 1, hours: 3),
        status: RequestStatus.resolved,
        recipient: ana,
      ),
      past(
        id: 'demo-req-2',
        child: juan,
        categoryId: 'necesito',
        message: 'Necesito ir al baño',
        emoji: '🚽',
        ago: const Duration(days: 1, hours: 1),
        status: RequestStatus.resolved,
        recipient: ana,
      ),
      past(
        id: 'demo-req-3',
        child: juan,
        categoryId: 'tengo',
        message: 'Tengo hambre',
        emoji: '😋',
        ago: const Duration(hours: 5),
        status: RequestStatus.resolved,
        recipient: maria,
      ),
      past(
        id: 'demo-req-4',
        child: juan,
        categoryId: 'quiero',
        message: 'Quiero escuchar música',
        emoji: '🎵',
        ago: const Duration(minutes: 40),
        status: RequestStatus.seen,
        recipient: maria,
      ),
      past(
        id: 'demo-req-5',
        child: sofia,
        categoryId: 'quiero',
        message: 'Quiero dibujar',
        emoji: '🖍️',
        ago: const Duration(days: 2),
        status: RequestStatus.resolved,
        recipient: maria,
      ),
      past(
        id: 'demo-req-6',
        child: mateo,
        categoryId: 'necesito',
        message: 'Necesito mis audífonos',
        emoji: '🎧',
        ago: const Duration(hours: 3),
        status: RequestStatus.resolved,
        recipient: ana,
      ),
      past(
        id: 'demo-req-7',
        child: mateo,
        categoryId: 'me_siento',
        message: 'Me siento saturado',
        emoji: '🤯',
        ago: const Duration(minutes: 25),
        status: RequestStatus.newRequest,
        recipient: ana,
        urgent: true,
      ),
    ];
    for (final r in history) {
      db.put(DemoDatabase.requests, r.id, r.toMap());
    }
  }
}
