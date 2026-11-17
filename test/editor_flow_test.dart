// Vai e volta entre o editor e o teste muitas vezes, pela tela, para pegar travas.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';
import 'package:geringonca/ui/game_page.dart';

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(() async => initializeForge2D());

  for (final (name, size) in [('em pé', const Size(412, 915)), ('deitado', const Size(915, 412))]) {
    testWidgets('celular $name: editor e teste, ida e volta várias vezes', (t) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = GameController(Store(null));
      await t.pumpWidget(MaterialApp(home: GamePage(g: g)));
      await _frames(t, 20);
      g.newLevel();
      await _frames(t, 20);
      for (var k = 0; k < 4; k++) {
        await t.tap(find.text('Testar').first);
        await _frames(t, 20);
        expect(g.testing, isTrue, reason: 'volta $k: Testar');
        g.parts = sampleFor(g.level, g.ball0)!;
        g.togglePlay();
        await _frames(t, 40);
        expect(g.sim?.t ?? 0, greaterThan(.3), reason: 'volta $k: a simulação andou');
        if (k.isOdd) {
          for (var i = 0; i < 8 * 60 && !g.won; i++) {
            await t.pump(const Duration(milliseconds: 16));
          }
          await _frames(t, 5);
        }
        // metade das vezes pela seta de voltar (rodando ou na vitória), metade parando e tocando no botão
        if (k < 2) {
          await t.tap(find.byTooltip('Menu').first);
        } else {
          if (g.mode == Mode.run) g.togglePlay();
          await _frames(t, 5);
          await t.tap(find.text('VOLTAR AO EDITOR').first);
        }
        await _frames(t, 20);
        expect(g.mode, Mode.edit, reason: 'volta $k: de volta ao editor');
        expect(t.takeException(), isNull);
        // no editor a bancada precisa continuar respondendo: desenhar um bloco
        final n = g.editLevel!.blocks.length;
        g.setETool('block');
        g.pointerDown(1, Pt(500, 200));
        g.pointerMove(1, Pt(540, 240));
        g.pointerMove(1, Pt(580, 280));
        g.pointerUp(1);
        await _frames(t, 5);
        expect(g.editLevel!.blocks.length, n + 1, reason: 'volta $k: o editor responde');
        g.editUndo();
        g.setETool('eselect');
        await _frames(t, 5);
      }
    });
  }
}
