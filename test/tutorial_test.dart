import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

void main() {
  setUpAll(() async => initializeForge2D());

  /// Põe uma peça na bancada e avisa o jogo, como um toque faria.
  void add(GameController g, Part q) {
    g.parts.add(q);
    g.tell(g.hint);
  }

  test('o tutorial avança quando a pessoa faz cada ação e termina com a fase vencida', () {
    final g = GameController(Store(null));
    expect(g.tutSeen, isFalse);
    g.startTutorial();
    expect(g.level.id, 'l1');
    expect(g.parts, isEmpty, reason: 'começa com a bancada limpa');
    expect(g.tutStep, 0);
    g.tutNext();
    expect(g.tutStep, 1);
    expect(g.tutTarget, 'cw');
    expect(g.tool, 'cw');

    final b = g.ball0;
    expect(g.tutSpot!.x, lessThan(b.x)); // a primeira roda vai à esquerda da bola
    add(g, Part.wheel('cw', Pt(b.x - 75, 472), 28));
    expect(g.tutStep, 2);
    expect(g.tutSpot!.x, greaterThan(b.x));
    add(g, Part.wheel('cw', Pt(b.x + 75, 472), 28));
    expect(g.tutStep, 3);
    expect(g.tool, 'rod');
    expect(g.tutLine, isNotNull);

    add(g, Part.rod('solid', Pt(b.x - 75, 472), b.copy()));
    expect(g.tutStep, 4);
    add(g, Part.rod('solid', b.copy(), Pt(b.x + 75, 472)));
    expect(g.tutStep, 5);
    expect(g.tutTarget, 'play');

    g.togglePlay();
    expect(g.tutStep, 6);
    g.stop(); // parou antes de chegar: o tutorial volta a pedir Rodar
    expect(g.tutStep, 5);

    g.togglePlay();
    for (var i = 0; i < 600 && !g.won; i++) {
      g.tick(1 / 60);
    }
    expect(g.won, isTrue, reason: 'a engenhoca do tutorial precisa vencer a primeira fase');
    expect(g.tutStep, kTutorial.length - 1);
    g.tutNext();
    expect(g.tutOn, isFalse);
    expect(g.tutSeen, isTrue);
  });

  test('pular fecha o tutorial e guarda que já foi visto', () {
    final g = GameController(Store(null))..startTutorial();
    g.endTutorial(skipped: true);
    expect(g.tutOn, isFalse);
    expect(g.tutSeen, isTrue);
    expect(g.hint, contains('Tutorial'));
  });

  test('abrir o tutorial com peças na bancada deixa desfazer', () {
    final g = GameController(Store(null));
    final before = g.parts.length;
    expect(before, greaterThan(0)); // o carrinho de exemplo
    g.startTutorial();
    expect(g.parts, isEmpty);
    g.endTutorial(skipped: true);
    g.undo();
    expect(g.parts, hasLength(before));
  });

  test('trocar de fase encerra o tutorial', () {
    final g = GameController(Store(null))..startTutorial();
    g.chooseLevel(kBuiltin[1].id!);
    expect(g.tutOn, isFalse);
  });
}
