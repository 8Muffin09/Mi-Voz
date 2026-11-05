import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/utils/json_utils.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/caregiver_link.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:mi_voz/models/pictogram.dart';
import 'package:mi_voz/models/sensory_passport.dart';
import 'package:mi_voz/models/sensory_settings.dart';

void main() {
  test('parseDate acepta Timestamp, ISO y milisegundos', () {
    final d = DateTime.utc(2026, 5, 1, 10);
    expect(parseDate(Timestamp.fromDate(d))!.toUtc(), d);
    expect(parseDate(d.toIso8601String())!.toUtc(), d);
    expect(parseDate(d.millisecondsSinceEpoch)!.toUtc(), d);
    expect(parseDate(null), isNull);
  });

  test('ChildProfile ida y vuelta conserva ajustes y responsable', () {
    final child = ChildProfile(
      id: 'c1',
      name: 'Sofía',
      avatar: '🦄',
      avatarColor: 0xFFFFFFFF,
      gender: GrammaticalGender.feminine,
      ownerUid: 'a',
      memberUids: const ['a', 'b'],
      responsibleUid: 'b',
      responsibleName: 'B',
      settings: const SensorySettings(
        calmMode: true,
        pictogramsPerPage: 4,
        hiddenCategoryIds: ['no_quiero'],
      ),
    );
    final copy = ChildProfile.fromMap(child.toMap());
    expect(copy.gender, GrammaticalGender.feminine);
    expect(copy.settings.calmMode, isTrue);
    expect(copy.settings.pictogramsPerPage, 4);
    expect(copy.settings.hiddenCategoryIds, ['no_quiero']);
    expect(copy.hasResponsible, isTrue);
  });

  test('SensorySettings ignora valores inválidos', () {
    final s = SensorySettings.fromMap({'pictogramsPerPage': 7, 'ttsRate': 5});
    expect(s.pictogramsPerPage, 9);
    expect(s.ttsRate, 1.0);
    expect(const SensorySettings(calmMode: true).effectiveSounds, isFalse);
  });

  test(
    'CommunicationRequest: el mapa de creación no incluye campos del backend',
    () {
      final r = CommunicationRequest(
        id: 'r1',
        childId: 'c1',
        childName: 'Juan',
        categoryId: 'me_molesta',
        categoryTitle: 'ME MOLESTA',
        message: 'Me molesta mucho el ruido',
        emoji: '🔊',
        priority: RequestPriority.normal,
        createdByUid: 'a',
        createdAt: DateTime(2026, 1, 1),
      );
      final create = r.toCreateMap();
      expect(create['status'], 'new');
      expect(create.containsKey('notification'), isFalse);
      expect(create.containsKey('delivery'), isFalse);
      expect(r.notificationTitle, 'Juan necesita atención');

      final back = CommunicationRequest.fromMap(r.toMap());
      expect(back.status, RequestStatus.newRequest);
      expect(back.message, r.message);
      expect(back.delivery, DeliveryStatus.pendingSync);
    },
  );

  test(
    'CommunicationRequest lee el resultado de la notificación del backend',
    () {
      final r = CommunicationRequest.fromMap({
        'id': 'r',
        'status': 'attending',
        'createdAt': '2026-01-01T00:00:00Z',
        'notification': {
          'status': 'sent',
          'recipientNames': ['Maestra Rosa'],
        },
      });
      expect(r.status, RequestStatus.attending);
      expect(r.notification, NotificationStatus.sent);
      expect(r.notifiedNames, ['Maestra Rosa']);
      expect(r.delivery, DeliveryStatus.delivered);
    },
  );

  test('Invitation caducidad y uso', () {
    final now = DateTime(2026, 1, 1);
    final inv = Invitation(
      code: 'ABCDEFGH',
      childId: 'c',
      childName: 'Juan',
      role: AdultRole.docente,
      createdByUid: 'a',
      createdByName: 'A',
      createdAt: now,
      expiresAt: now.add(Invitation.validity),
    );
    expect(inv.isValid(now), isTrue);
    expect(inv.isValid(now.add(const Duration(days: 3))), isFalse);
    expect(
      Invitation.fromMap({...inv.toMap(), 'usedBy': 'b'}).isValid(now),
      isFalse,
    );
  });

  test('ChildContent y SensoryPassport ida y vuelta', () {
    const content = ChildContent(
      favoritePictogramIds: ['quiero_agua'],
      frequentPhrases: [FrequentPhrase(id: 'f', text: 'Hola', emoji: '👋')],
    );
    expect(
      ChildContent.fromMap(content.toMap()).frequentPhrases.single.text,
      'Hola',
    );

    const passport = SensoryPassport(
      childId: 'c',
      sensitivities: {
        SensoryArea.noise: Sensitivity(level: SensitivityLevel.high),
      },
      safePlaces: ['Rincón'],
    );
    final back = SensoryPassport.fromMap(passport.toMap());
    expect(back.sensitivity(SensoryArea.noise).level, SensitivityLevel.high);
    expect(back.sensitivity(SensoryArea.light).level, SensitivityLevel.none);
    expect(back.safePlaces, ['Rincón']);
  });
}
