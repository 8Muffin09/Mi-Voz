import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/features/communication/domain/support_suggestions.dart';
import 'package:mi_voz/models/communication_request.dart';

var _n = 0;

CommunicationRequest _r({
  String message = 'Me molesta el ruido',
  String category = 'me_molesta',
  List<String> pictograms = const ['me_molesta_ruido'],
  String? support,
  SupportFeedback? feedback,
  String childId = 'nino-1',
  DateTime? at,
}) => CommunicationRequest(
  id: 'r${++_n}',
  childId: childId,
  childName: 'Leo',
  categoryId: category,
  categoryTitle: category.toUpperCase(),
  message: message,
  emoji: 'me_molesta_ruido',
  pictogramIds: pictograms,
  priority: RequestPriority.normal,
  createdByUid: 'u',
  createdAt: at ?? DateTime(2026, 11, 1),
  status: RequestStatus.resolved,
  supportProvided: support,
  supportAt: at,
  childFeedback: feedback,
);

void main() {
  test('sugiere primero lo que lo hizo sentir mejor en la misma situación', () {
    final now = _r();
    final history = [
      _r(support: 'Le di sus audífonos', feedback: SupportFeedback.better),
      _r(support: 'Le di sus audífonos', feedback: SupportFeedback.better),
      _r(support: 'Le pedí que esperara', feedback: SupportFeedback.same),
      _r(support: 'Lo llevé al pasillo', feedback: SupportFeedback.worse),
    ];
    final s = SupportSuggestions.forRequest(now, history);
    expect(s.first.text, 'Le di sus audífonos');
    expect(s.first.times, 2);
    expect(s.first.better, 2);
    expect(s.first.sameMessage, isTrue);
    expect(s.first.summary, 'Usado 2 veces · se sintió mejor 2');
    // Lo que solo le hizo sentir peor no se sugiere.
    expect(s.map((x) => x.text), isNot(contains('Lo llevé al pasillo')));
  });

  test(
    'sin valoración del alumno lo dice; "Resuelta" no cuenta como mejor',
    () {
      final s = SupportSuggestions.forRequest(_r(), [
        _r(support: 'Bajé el volumen de la música'),
      ]);
      expect(s.single.rated, 0);
      expect(s.single.summary, contains('sin valoración del alumno'));
    },
  );

  test('si no hay de lo mismo, usa la misma categoría y lo indica', () {
    final now = _r(
      message: 'Me molesta la luz',
      pictograms: ['me_molesta_luz'],
    );
    final s = SupportSuggestions.forRequest(now, [
      _r(support: 'Apagué una lámpara', feedback: SupportFeedback.better),
      _r(
        message: 'Quiero agua',
        category: 'quiero',
        pictograms: ['quiero_agua'],
        support: 'Le di agua',
      ),
    ]);
    expect(s.single.text, 'Apagué una lámpara');
    expect(s.single.sameMessage, isFalse);
  });

  test('no mezcla el historial de otro alumno ni repite el mismo apoyo', () {
    final s = SupportSuggestions.forRequest(_r(), [
      _r(support: 'Respiramos juntos', childId: 'otro'),
      _r(support: 'Le di sus audífonos.', at: DateTime(2026, 10, 1)),
      _r(support: 'le di sus audífonos', at: DateTime(2026, 11, 2)),
    ]);
    expect(s, hasLength(1));
    expect(s.single.times, 2);
    // Se muestra la redacción más reciente.
    expect(s.single.text, 'le di sus audífonos');
  });
}
