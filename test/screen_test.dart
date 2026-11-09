// Testes de tela: montam a tela do jogo de verdade (com a bancada do Flame) e
// percorrem um caminho como quem joga, para pegar problemas que os testes de
// regras não veem.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';
import 'package:geringonca/ui/game_page.dart';

/// Quadros de 1/60 s, como o navegador.
Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  setUpAll(() async => initializeForge2D());

  for (final (name, size) in [('em pé', const Size(412, 915)), ('deitado', const Size(915, 412))]) {
    testWidgets('celular $name: criar fase, Testar e Rodar faz a simulação andar', (t) async {
      t.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final g = GameController(Store(null));
      await t.pumpWidget(MaterialApp(home: GamePage(g: g)));
      await _frames(t, 30); // a bancada carrega e, parada, entra em descanso

      g.newLevel();
      await _frames(t, 30);
      g.testEdit();
      await _frames(t, 30); // de novo parada: descansa

      g.parts = sampleFor(g.level, g.ball0)!;
      g.togglePlay(); // o botão Rodar fica fora da bancada
      await _frames(t, 60);
      expect(g.sim, isNotNull);
      expect(g.sim!.t, greaterThan(.5), reason: 'a simulação precisa andar depois de Rodar');

      g.togglePlay();
      g.backToEditor();
      await _frames(t, 5);
      expect(g.mode, Mode.edit);
    });
  }

  testWidgets('jogar uma fase pela tela até a vitória', (t) async {
    t.view
      ..physicalSize = const Size(915, 412)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = GameController(Store(null));
    await t.pumpWidget(MaterialApp(home: GamePage(g: g)));
    await _frames(t, 30);
    g.togglePlay(); // fase 1 começa com o exemplo montado
    for (var i = 0; i < 8 * 60 && !g.won; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    expect(g.won, isTrue);
    await _frames(t, 2);
    expect(find.text('Fase concluída!'), findsOneWidget);
  });
}
