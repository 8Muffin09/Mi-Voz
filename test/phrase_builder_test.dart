import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/features/pictograms/data/pictogram_catalog.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/pictogram.dart';

Pictogram pic(String id) =>
    PictogramCatalog.pictograms.firstWhere((p) => p.id == id);

PhraseDraft draftFor(String id) {
  final p = pic(id);
  return PhraseDraft(
    category: PictogramCatalog.categoryById(p.categoryId),
    items: [p],
  );
}

void main() {
  group('PhraseBuilder', () {
    test('forma las frases de ejemplo del requerimiento', () {
      expect(PhraseBuilder.build(draftFor('tengo_frio')), 'Tengo frío');
      expect(PhraseBuilder.build(draftFor('quiero_agua')), 'Quiero agua');
      expect(
        PhraseBuilder.build(draftFor('me_siento_enfermo')),
        'Me siento enfermo',
      );
      expect(
        PhraseBuilder.build(draftFor('quiero_ir_casa')),
        'Quiero ir a casa',
      );
      expect(
        PhraseBuilder.build(draftFor('me_duele_cabeza')),
        'Me duele la cabeza',
      );
      expect(
        PhraseBuilder.build(
          draftFor('me_molesta_ruido').copyWith(intensity: Intensity.much),
        ),
        'Me molesta mucho el ruido',
      );
    });

    test('concuerda el verbo con sustantivos plurales', () {
      expect(
        PhraseBuilder.build(draftFor('me_duele_pies')),
        'Me duelen los pies',
      );
    });

    test('usa plural y une con "y" al combinar varios pictogramas', () {
      final draft = draftFor('me_duele_cabeza').add(pic('me_duele_estomago'));
      expect(PhraseBuilder.build(draft), 'Me duelen la cabeza y el estómago');
      final three = draftFor('quiero_agua')
          .add(pic('quiero_comida'))
          .add(pic('quiero_jugar'));
      expect(PhraseBuilder.build(three), 'Quiero agua, comida y jugar');
    });

    test('usa "e" ante palabras que empiezan con sonido /i/', () {
      final draft = draftFor('me_siento_tranquilo')
          .add(pic('me_siento_incomodo'));
      expect(PhraseBuilder.build(draft), 'Me siento tranquilo e incómodo');
    });

    test('aplica la concordancia de género del niño', () {
      expect(
        PhraseBuilder.build(
          draftFor('me_siento_enfermo'),
          gender: GrammaticalGender.feminine,
        ),
        'Me siento enferma',
      );
      expect(
        PhraseBuilder.build(
          draftFor('necesito_solo'),
          gender: GrammaticalGender.feminine,
        ),
        'Necesito estar sola',
      );
    });

    test('expresa la intensidad según la categoría', () {
      expect(
        PhraseBuilder.build(
          draftFor('tengo_hambre').copyWith(intensity: Intensity.much),
        ),
        'Tengo mucha hambre',
      );
      expect(
        PhraseBuilder.build(
          draftFor('tengo_frio').copyWith(intensity: Intensity.little),
        ),
        'Tengo un poco de frío',
      );
      expect(
        PhraseBuilder.build(
          draftFor('me_siento_feliz').copyWith(intensity: Intensity.much),
        ),
        'Me siento muy feliz',
      );
      expect(
        PhraseBuilder.build(
          draftFor('me_duele_cabeza').copyWith(intensity: Intensity.little),
        ),
        'Me duele un poco la cabeza',
      );
    });

    test('agrega "por favor"', () {
      expect(
        PhraseBuilder.build(draftFor('quiero_agua').copyWith(polite: true)),
        'Quiero agua, por favor',
      );
    });

    test('las frases fijas se usan tal cual', () {
      const draft = PhraseDraft.fixed(text: 'Necesito agua', emoji: '💧');
      expect(PhraseBuilder.build(draft), 'Necesito agua');
      expect(draft.supportsIntensity, isFalse);
    });
  });

  group('PhraseDraft (modificar sin escribir)', () {
    test('no repite pictogramas ni mezcla categorías y limita a 3', () {
      var draft = draftFor('quiero_agua');
      draft = draft.add(pic('quiero_agua'));
      expect(draft.items, hasLength(1));
      draft = draft.add(pic('tengo_frio'));
      expect(draft.items, hasLength(1));
      draft = draft
          .add(pic('quiero_comida'))
          .add(pic('quiero_jugar'))
          .add(pic('quiero_dormir'));
      expect(draft.items, hasLength(PhraseDraft.maxItems));
      expect(draft.canAddMore, isFalse);
    });

    test('quitar y reemplazar elementos', () {
      final draft = draftFor('quiero_agua').add(pic('quiero_comida'));
      expect(draft.remove('quiero_agua').items.single.id, 'quiero_comida');
      expect(
        draft.replaceWith(pic('quiero_jugar')).items.single.id,
        'quiero_jugar',
      );
    });
  });

  test(
    'todas las categorías tienen pictogramas desde la primera ejecución',
    () {
      for (final c in PictogramCatalog.categories) {
        final count = PictogramCatalog.pictograms
            .where((p) => p.categoryId == c.id)
            .length;
        expect(count, greaterThanOrEqualTo(7), reason: c.title);
      }
      expect(PictogramCatalog.categories, hasLength(9));
      final ids = PictogramCatalog.pictograms.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids únicos');
    },
  );
}
