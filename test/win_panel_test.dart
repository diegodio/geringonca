// Tela de vitória no painel estreito (celular deitado): nenhum texto cortado com "…".
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/palette.dart';
import 'package:geringonca/game/storage.dart';
import 'package:geringonca/ui/win_panel.dart';

void main() {
  setUpAll(() async => initializeForge2D());

  testWidgets('painel lateral estreito mostra o quanto faltou inteiro', (t) async {
    final g = GameController(Store(null));
    g.parts = sampleFor(g.level, g.ball0)!;
    g.togglePlay();
    for (var i = 0; i < 600 && !g.won; i++) {
      g.tick(1 / 60);
    }
    expect(g.won, isTrue);
    // a fonte dos testes tem letras quadradas, bem mais largas que as do jogo:
    // 360 aqui equivale ao painel lateral de 240 do celular deitado
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 360, child: SingleChildScrollView(child: WinPanel(g: g, c: Palette.light, onMenu: () {}))),
        ),
      ),
    ));
    final cut = [
      for (final p in t.renderObjectList<RenderParagraph>(find.byType(RichText)))
        if (p.didExceedMaxLines) p.text.toPlainText(),
    ];
    expect(cut, isEmpty);
  });
}
