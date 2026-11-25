import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/app/providers.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/core/services/local_store.dart';
import 'package:mi_voz/core/utils/app_exception.dart';
import 'package:mi_voz/features/authentication/data/auth_repository.dart';
import 'package:mi_voz/features/authentication/presentation/verify_email_screen.dart';
import 'package:mi_voz/features/communication/application/communication_service.dart';
import 'package:mi_voz/features/communication/application/outbox.dart';
import 'package:mi_voz/features/invitations/presentation/invitation_widgets.dart';
import 'package:mi_voz/features/pictograms/domain/phrase_builder.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/communication_request.dart';

import 'accounts_and_access_test.dart' show seedChild, settleProviders;
import 'helpers.dart';

/// Autenticación falsa para la pantalla "Revisa tu correo": cuenta cuántas
/// veces se reenvía y responde lo que diga [verifiedOnServer].
class _FakeAuth extends Fake implements AuthRepository {
  bool verifiedOnServer = false;
  int resent = 0;
  int checks = 0;
  bool offline = false;

  @override
  Future<void> sendEmailVerification() async {
    if (offline) throw const OfflineException();
    resent++;
  }

  @override
  Future<bool> refreshEmailVerification() async {
    checks++;
    if (offline) throw const OfflineException();
    return verifiedOnServer;
  }

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(
    const AppUser(
      uid: 'u-nuevo',
      email: 'nuevo@gmail.com',
      displayName: 'Nuevo',
      role: AdultRole.madre,
      emailVerified: false,
    ),
  );
}

void main() {
  group('Verificación de correo', () {
    test(
      'la espera entre reenvíos se respeta y se recuerda por cuenta',
      () async {
        final prefs = await demoPrefs();
        final store = LocalStore(prefs);
        var now = DateTime(2026, 11, 23, 10);
        final cooldown = ResendCooldown(store, 'u1', clock: () => now);
        expect(cooldown.remaining, Duration.zero);
        await cooldown.markSent();
        expect(cooldown.remaining, verificationResendCooldown);
        now = now.add(const Duration(seconds: 20));
        expect(cooldown.remaining, const Duration(seconds: 40));
        // Otra cuenta no hereda la espera.
        expect(
          ResendCooldown(store, 'u2', clock: () => now).remaining,
          Duration.zero,
        );
        now = now.add(const Duration(seconds: 41));
        expect(cooldown.remaining, Duration.zero);
      },
    );

    testWidgets('"Ya confirmé" consulta el servidor y no marca nada por sí '
        'solo; reenviar respeta la espera', (tester) async {
      final auth = _FakeAuth();
      final prefs = await demoPrefs(
        extra: {
          // El primer correo se envió hace 2 minutos: ya se puede reenviar.
          ResendCooldown.key('u-nuevo'): DateTime.now()
              .subtract(const Duration(minutes: 2))
              .toUtc()
              .toIso8601String(),
        },
      );
      final container = ProviderContainer(
        overrides: [
          ...testOverrides(prefs),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      container.listen(currentUserProvider, (_, _) {});
      await container.read(authStateProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: VerifyEmailScreen()),
        ),
      );
      expect(find.text('Revisa tu correo'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.textContaining('nuevo@gmail.com'), findsOneWidget);

      await tester.tap(find.byKey(const Key('verify-check')));
      await tester.pump();
      expect(auth.checks, 1);
      expect(
        find.textContaining('Todavía no aparece confirmado'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('verify-resend')));
      await tester.pump();
      expect(auth.resent, 1);
      // Inmediatamente después, el botón queda en espera.
      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('verify-resend')),
      );
      expect(button.onPressed, isNull);
      expect(find.textContaining(RegExp(r'((60|59) s)')), findsOneWidget);

      auth.offline = true;
      await tester.tap(find.byKey(const Key('verify-check')));
      await tester.pump();
      expect(find.textContaining('Sin conexión'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('Solicitudes', () {
    test('doble toque en "Comunicar": una sola solicitud', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      await settleProviders();
      final juan = seedChild(c, 'demo-juan');
      const draft = PhraseDraft.fixed(
        text: 'Necesito agua',
        emoji: 'necesito_agua',
      );
      final service = c.read(communicationServiceProvider);
      final now = DateTime.now();
      final results = await Future.wait([
        service.send(child: juan, draft: draft, now: now),
        service.send(
          child: juan,
          draft: draft,
          now: now.add(const Duration(milliseconds: 400)),
        ),
      ]);
      expect(results[0].id, results[1].id);
      final stored = c
          .read(demoDatabaseProvider)
          .where('communication_requests', (r) => r['id'] == results[0].id);
      expect(stored, hasLength(1));
      // Otra frase distinta sí es otra solicitud.
      final other = await service.send(
        child: juan,
        draft: const PhraseDraft.fixed(
          text: 'Quiero ir al baño',
          emoji: 'necesito_bano',
        ),
        now: now.add(const Duration(seconds: 1)),
      );
      expect(other.id, isNot(results[0].id));
      expect(c.read(outboxProvider), isEmpty);
    });

    test('atención con historial, apoyo brindado y valoración del alumno '
        'separados', () async {
      final c = await signedInContainer(DemoSeed.maria.uid);
      addTearDown(c.dispose);
      await settleProviders();
      final juan = seedChild(c, 'demo-juan');
      final service = c.read(communicationServiceProvider);
      final sent = await service.send(
        child: juan,
        draft: const PhraseDraft.fixed(
          text: 'Me molesta el ruido',
          emoji: 'me_molesta_ruido',
        ),
      );
      final repo = c.read(requestsRepositoryProvider);
      Future<CommunicationRequest> fresh() async =>
          (await repo.watchRequest(juan.id, sent.id).first)!;

      await service.updateStatus(await fresh(), RequestStatus.seen);
      await service.updateStatus(await fresh(), RequestStatus.attending);
      // Retroceder no hace nada.
      await service.updateStatus(await fresh(), RequestStatus.seen);
      expect((await fresh()).status, RequestStatus.attending);
      await service.updateStatus(
        await fresh(),
        RequestStatus.resolved,
        support: 'Le llevé a un lugar tranquilo',
      );
      var r = await fresh();
      expect(r.status, RequestStatus.resolved);
      expect(r.supportProvided, 'Le llevé a un lugar tranquilo');
      expect(r.supportByUid, DemoSeed.maria.uid);
      // Resuelta NO significa "mejor": la valoración sigue vacía.
      expect(r.childFeedback, isNull);

      await service.setChildFeedback(r, SupportFeedback.same);
      r = await fresh();
      expect(r.childFeedback, SupportFeedback.same);
      expect(r.supportProvided, 'Le llevé a un lugar tranquilo');

      final events = await repo.watchEvents(juan.id, sent.id).first;
      expect(
        [for (final e in events) e.type],
        ['seen', 'attending', 'resolved', 'support', 'feedback'],
      );
      expect(events.every((e) => e.byUid == DemoSeed.maria.uid), isTrue);
    });

    test('quien no está vinculado no registra apoyo ni valoración', () async {
      final c = await signedInContainer(DemoSeed.carlos.uid);
      addTearDown(c.dispose);
      await settleProviders();
      final db = c.read(demoDatabaseProvider);
      final row = db
          .where('communication_requests', (r) => r['childId'] == 'demo-juan')
          .first;
      final request = CommunicationRequest.fromMap(row);
      final repo = c.read(requestsRepositoryProvider);
      final carlos = c.read(currentUserProvider)!;
      expect(
        () => repo.setChildFeedback(
          request: request,
          actor: carlos,
          feedback: SupportFeedback.better,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(await repo.watchEvents('demo-juan', request.id).first, isEmpty);
    });
  });

  testWidgets('sin la nube, las invitaciones avisan que solo sirven en este '
      'teléfono', (tester) async {
    final prefs = await demoPrefs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: testOverrides(prefs),
        child: const MaterialApp(
          home: Scaffold(body: LocalOnlyInvitationsNotice()),
        ),
      ),
    );
    expect(find.byKey(const Key('local-invitations-notice')), findsOneWidget);
    expect(find.textContaining('solo en este dispositivo'), findsOneWidget);
  });
}
