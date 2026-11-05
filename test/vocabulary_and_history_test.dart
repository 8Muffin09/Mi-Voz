import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/features/history/domain/history_filter.dart';
import 'package:mi_voz/features/pictograms/domain/vocabulary.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/communication_request.dart';
import 'package:mi_voz/models/pictogram.dart';
import 'package:mi_voz/models/sensory_settings.dart';

ChildProfile child(SensorySettings s) => ChildProfile(
  id: 'c',
  name: 'Juan',
  avatar: '🦁',
  avatarColor: 0,
  gender: GrammaticalGender.masculine,
  ownerUid: 'a',
  memberUids: const ['a'],
  settings: s,
);

CommunicationRequest req(String id, DateTime at, String cat, RequestStatus s) =>
    CommunicationRequest(
      id: id,
      childId: 'c',
      childName: 'Juan',
      categoryId: cat,
      categoryTitle: cat,
      message: id,
      emoji: '💬',
      priority: RequestPriority.normal,
      createdByUid: 'a',
      createdAt: at,
      status: s,
    );

void main() {
  group('Vocabulary (gestión de pictogramas y favoritos)', () {
    const custom = Pictogram(
      id: 'custom_tablet',
      categoryId: 'quiero',
      label: 'Tableta',
      fragment: 'mi tableta',
      emoji: '📱',
      builtIn: false,
    );

    test('incluye pictogramas propios en su categoría', () {
      final v = Vocabulary(
        child: child(const SensorySettings()),
        content: const ChildContent(customPictograms: [custom]),
      );
      expect(
        v.pictogramsFor('quiero').map((p) => p.id),
        contains('custom_tablet'),
      );
      expect(v.byId('custom_tablet')?.label, 'Tableta');
    });

    test('oculta categorías y pictogramas configurados por el adulto', () {
      final v = Vocabulary(
        child: child(
          const SensorySettings(
            hiddenCategoryIds: ['no_quiero'],
            hiddenPictogramIds: ['quiero_agua'],
          ),
        ),
        content: ChildContent.empty,
      );
      expect(
        v.visibleCategories.map((c) => c.id),
        isNot(contains('no_quiero')),
      );
      expect(v.visibleCategories, hasLength(8));
      expect(
        v.pictogramsFor('quiero').map((p) => p.id),
        isNot(contains('quiero_agua')),
      );
      expect(
        v.pictogramsFor('quiero', includeHidden: true).map((p) => p.id),
        contains('quiero_agua'),
      );
    });

    test('favoritos en orden, sin ocultos ni ids inexistentes', () {
      final v = Vocabulary(
        child: child(const SensorySettings(hiddenPictogramIds: ['tengo_frio'])),
        content: const ChildContent(
          favoritePictogramIds: [
            'necesito_bano',
            'tengo_frio',
            'no_existe',
            'custom_tablet',
          ],
          customPictograms: [custom],
        ),
      );
      expect(v.favorites.map((p) => p.id), ['necesito_bano', 'custom_tablet']);
      expect(v.isFavorite('tengo_frio'), isTrue);
    });
  });

  group('HistoryFilter', () {
    final today = DateTime(2026, 3, 10, 12);
    final list = [
      req('a', today, 'quiero', RequestStatus.resolved),
      req(
        'b',
        today.subtract(const Duration(days: 1)),
        'tengo',
        RequestStatus.newRequest,
      ),
      req(
        'c',
        today.subtract(const Duration(days: 5)),
        'quiero',
        RequestStatus.seen,
      ),
    ];

    test('filtra por categoría, estado y fechas', () {
      expect(
        const HistoryFilter(categoryId: 'quiero').apply(list).map((r) => r.id),
        ['a', 'c'],
      );
      expect(
        const HistoryFilter(statuses: {RequestStatus.newRequest})
            .apply(list)
            .single
            .id,
        'b',
      );
      final range = DateTimeRange(
        start: today.subtract(const Duration(days: 1)),
        end: today,
      );
      expect(HistoryFilter(range: range).apply(list).map((r) => r.id), [
        'a',
        'b',
      ]);
    });

    test('agrupa por día', () {
      final groups = HistoryFilter.groupByDay(
        const HistoryFilter().apply(list),
      );
      expect(groups.length, 3);
      expect(groups.keys.first, DateTime(2026, 3, 10));
    });
  });
}
