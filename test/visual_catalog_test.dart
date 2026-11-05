import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/visuals/avatar_catalog.dart';
import 'package:mi_voz/core/visuals/symbol_catalog.dart';
import 'package:mi_voz/core/widgets/child_avatar.dart';
import 'package:mi_voz/core/widgets/visuals.dart';
import 'package:mi_voz/features/pictograms/data/pictogram_catalog.dart';
import 'package:mi_voz/models/app_user.dart';
import 'package:mi_voz/models/child_profile.dart';
import 'package:mi_voz/models/pictogram.dart';

/// Emojis que usaban las versiones anteriores para avatares.
const _oldChildAvatars = [
  '🦁', '🐻', '🐼', '🐨', '🦊', '🐯', '🐸', '🐵', '🐶', '🐱', //
  '🐰', '🦄', '🐢', '🐬', '🦋', '🐝', '🚀', '⭐', '🌈', '🌻',
];
const _oldAdultAvatars = [
  '👩', '👨', '🧑', '👩‍🦱', '👨‍🦱', '👩‍🦰', '👨‍🦳', '👵', //
  '👴', '👩‍🏫', '👨‍🏫', '🧑‍🏫', '🌻', '⭐', '🌈', '🍀',
];

void main() {
  group('Catálogo de avatares', () {
    test('cada avatar tiene identificador único y su archivo SVG', () {
      final ids = AvatarCatalog.all.map((a) => a.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final a in AvatarCatalog.all) {
        expect(File(a.asset).existsSync(), isTrue, reason: a.asset);
        expect(a.label.trim(), isNotEmpty);
      }
    });

    test('hay variedad suficiente para niños y adultos', () {
      expect(AvatarCatalog.forChildren.length, greaterThanOrEqualTo(20));
      expect(AvatarCatalog.portraits.length, greaterThanOrEqualTo(16));
      // Los adultos tienen opciones neutras, sin apariencia por rol.
      expect(
        AvatarCatalog.forAdults.where((a) => a.group != AvatarGroup.portraits),
        isNotEmpty,
      );
      expect(
        AvatarCatalog.byId(AvatarCatalog.defaultAdult)!.group,
        AvatarGroup.characters,
      );
    });

    test('los avatares anteriores (emojis) se traducen a ilustraciones', () {
      for (final e in {..._oldChildAvatars, ..._oldAdultAvatars}) {
        expect(AvatarCatalog.resolve(e), isNotNull, reason: e);
      }
      for (final target in AvatarCatalog.legacyEmoji.values) {
        expect(AvatarCatalog.byId(target), isNotNull, reason: target);
      }
      expect(AvatarCatalog.normalize('🐼', fallback: 'x'), 'animal_panda');
      expect(
        AvatarCatalog.normalize('animal_fox', fallback: 'x'),
        'animal_fox',
      );
      expect(AvatarCatalog.normalize('desconocido', fallback: 'x'), 'x');
    });

    testWidgets('perfil con emoji heredado muestra la ilustración nueva', (
      tester,
    ) async {
      const child = ChildProfile(
        id: 'c1',
        name: 'Juan',
        avatar: '🐼',
        avatarColor: 0xFFB8E0D2,
        gender: GrammaticalGender.masculine,
        ownerUid: 'u1',
        memberUids: ['u1'],
      );
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Center(child: ChildAvatar(child: child)),
          ),
        ),
      );
      final art = tester.widget<AvatarArtImage>(find.byType(AvatarArtImage));
      expect(art.art.id, 'animal_panda');
      expect(find.bySemanticsLabel('Avatar de Juan'), findsOneWidget);
    });
  });

  group('Catálogo de pictogramas', () {
    test('cada identificador tiene su imagen incluida en la app', () {
      for (final id in SymbolCatalog.ids) {
        final file = File('${SymbolCatalog.assetDir}/$id.png');
        expect(file.existsSync(), isTrue, reason: id);
        // Optimizados: pequeños para ir dentro de la app.
        expect(file.lengthSync(), lessThan(60 * 1024), reason: id);
      }
      expect(
        File('${SymbolCatalog.assetDir}/ATRIBUCION.md').existsSync(),
        isTrue,
      );
    });

    test('categorías, pictogramas base, frases y ayuda urgente usan '
        'ilustraciones (no emojis)', () {
      final values = [
        for (final c in PictogramCatalog.categories) c.emoji,
        for (final p in PictogramCatalog.pictograms) p.emoji,
        for (final p in PictogramCatalog.defaultFrequentPhrases) p.emoji,
        for (final p in PictogramCatalog.urgentOptions) p.emoji,
        ...PictogramCatalog.symbolPalette,
      ];
      for (final v in values) {
        expect(SymbolCatalog.isSymbolId(v), isTrue, reason: v);
      }
    });

    test('las posiciones de las nueve categorías no cambian', () {
      expect(
        [for (final c in PictogramCatalog.categories) c.id],
        [
          'quiero', 'necesito', 'tengo', 'me_siento', 'me_duele', //
          'me_molesta', 'no_quiero', 'quiero_ir', 'ayudame',
        ],
      );
    });

    test('ejemplos pedidos: cada frase frecuente tiene su pictograma', () {
      String symbolOf(String text) => PictogramCatalog.defaultFrequentPhrases
          .firstWhere((p) => p.text == text)
          .emoji;
      expect(symbolOf('Necesito agua'), 'necesito_agua');
      expect(symbolOf('Quiero ir al baño'), 'necesito_bano');
      expect(symbolOf('Me molesta mucho el ruido'), 'me_molesta_ruido');
      expect(symbolOf('Necesito descansar'), 'necesito_descansar');
      expect(symbolOf('Quiero ir a casa'), 'quiero_ir_casa');
    });

    test('una frase guardada con emoji sigue diciendo lo mismo', () {
      final old = FrequentPhrase.fromMap(const {
        'id': 'p1',
        'text': 'Necesito agua',
        'emoji': '💧',
      });
      expect(old.text, 'Necesito agua');
      expect(SymbolCatalog.resolve(old.emoji), 'quiero_agua');
      // Todas las correspondencias apuntan a imágenes existentes.
      for (final target in SymbolCatalog.legacyEmoji.values) {
        expect(SymbolCatalog.isSymbolId(target), isTrue, reason: target);
      }
    });

    testWidgets('el pictograma se dibuja desde los recursos de la app '
        '(sin internet)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SymbolImage('quiero_agua', size: 64)),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.image, isA<AssetImage>());
      expect(
        (image.image as AssetImage).assetName,
        'assets/pictograms/quiero_agua.png',
      );
    });

    testWidgets('un emoji propio sin equivalente se conserva', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SymbolImage('🦖')));
      expect(find.text('🦖'), findsOneWidget);
    });
  });

  test('AppUser sin avatar usa uno neutro, no uno por rol', () {
    const teacher = AppUser(
      uid: 'u',
      email: 'a@b.c',
      displayName: 'Ana',
      role: AdultRole.docente,
    );
    expect(teacher.avatarRef, AvatarCatalog.defaultAdult);
  });
}
