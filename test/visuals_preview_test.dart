// Hojas de contacto de los avatares y pictogramas para revisarlos a ojo.
// No es una prueba de regresión: solo se ejecuta con
//   flutter test test/visuals_preview_test.dart --dart-define=PREVIEW=true --update-goldens
// y escribe build/preview/*.png.
import 'package:flutter/material.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_voz/core/demo/demo_seed.dart';
import 'package:mi_voz/features/child/application/child_mode.dart';
import 'package:mi_voz/core/visuals/avatar_catalog.dart';
import 'package:mi_voz/core/visuals/symbol_catalog.dart';
import 'package:mi_voz/core/widgets/visuals.dart';

import 'access_flows_test.dart' show tapKey;
import 'widget_flows_test.dart' show launch, settle, signedInAs;

const _preview = bool.fromEnvironment('PREVIEW');

void main() {
  Future<void> sheet(
    WidgetTester tester,
    String name,
    List<Widget> tiles, {
    int columns = 6,
    double tile = 120,
  }) async {
    final rows = (tiles.length / columns).ceil();
    tester.view.physicalSize = Size(columns * tile, rows * (tile + 24));
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ColoredBox(
            color: Colors.white,
            child: Wrap(children: tiles),
          ),
        ),
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        await tester.pump();
      }
      for (final e in find.byType(Image).evaluate()) {
        final widget = e.widget as Image;
        await precacheImage(widget.image, e);
      }
      await tester.pump();
    });
    await expectLater(
      find.byType(Wrap),
      matchesGoldenFile('../build/preview/$name.png'),
    );
  }

  testWidgets('avatares', (tester) async {
    const colors = [
      0xFFB8E0D2,
      0xFFA0C4FF,
      0xFFFFD6A5,
      0xFFFDFFB6,
      0xFFFFC6C6,
      0xFFD7C4F0,
    ];
    await sheet(tester, 'avatars', [
      for (final (i, a) in AvatarCatalog.all.indexed)
        SizedBox(
          width: 120,
          height: 144,
          child: Column(
            children: [
              Container(
                width: 104,
                height: 104,
                margin: const EdgeInsets.all(4),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Color(colors[i % colors.length]),
                  shape: BoxShape.circle,
                ),
                child: AvatarArtImage(art: a, size: 104),
              ),
              Text(a.id, style: const TextStyle(fontSize: 8)),
            ],
          ),
        ),
    ]);
  }, skip: !_preview);

  testWidgets('pictogramas', (tester) async {
    await sheet(tester, 'symbols', columns: 12, tile: 90, [
      for (final id in SymbolCatalog.ids)
        SizedBox(
          width: 90,
          height: 114,
          child: Column(
            children: [
              SymbolImage(id, size: 80),
              Text(id, style: const TextStyle(fontSize: 7)),
            ],
          ),
        ),
    ]);
  }, skip: !_preview);

  // Pantallas completas con la fuente y los iconos reales (teléfono de
  // 360 × 800 dp).
  Future<void> loadFonts() async {
    Future<void> load(String family, List<String> files) async {
      final loader = FontLoader(family);
      for (final f in files) {
        loader.addFont(
          Future.value(ByteData.sublistView(File(f).readAsBytesSync())),
        );
      }
      await loader.load();
    }

    final flutter = Platform.environment['FLUTTER_ROOT'] ??
        r'C:\Users\Sergi\dev\flutter';
    await load('Atkinson', [
      'assets/fonts/AtkinsonHyperlegible-Regular.ttf',
      'assets/fonts/AtkinsonHyperlegible-Bold.ttf',
    ]);
    await load('MaterialIcons', [
      '$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    ]);
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 60));
        await tester.pump();
      }
      for (final e in find.byType(Image).evaluate()) {
        await precacheImage((e.widget as Image).image, e);
      }
    });
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../build/preview/$name.png'),
    );
  }

  testWidgets('pantallas', (tester) async {
    await loadFonts();
    tester.view.physicalSize = const Size(1080, 2400);
    final c = await launch(tester);
    await tapKey(tester, 'welcome-start');
    await tapKey(tester, 'access-create');
    await shot(tester, 'screen_create_account');
    await tapKey(tester, 'role-selector');
    await shot(tester, 'screen_role_sheet');
    c.dispose;

    final kid = await launch(tester, prefs: signedInAs(DemoSeed.maria.uid));
    await kid.read(childModeProvider.notifier).enter('demo-juan');
    await settle(tester);
    await shot(tester, 'screen_child_home');
    await tapKey(tester, 'quick-phrases');
    await shot(tester, 'screen_phrases');
  }, skip: !_preview);
}