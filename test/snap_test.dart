import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

/// Desenha uma barra começando 10 px ao lado da junta (130, 400) do carrinho de exemplo
/// (mais perto, sem encaixe, ela encostaria na ponta da borracha e seria recusada).
Part _drawNearJoint(GameController g) {
  g.setTool('rod');
  g.pointerDown(1, Pt(140, 400));
  g.pointerMove(1, Pt(250, 300));
  g.pointerUp(1);
  return g.parts.last;
}

void main() {
  test('encaixe ligado prende a ponta na junta vizinha', () {
    final g = GameController(Store(null));
    expect(g.snapOn, isTrue);
    final r = _drawNearJoint(g);
    expect(r.a!.key, Pt(130, 400).key);
  });

  test('encaixe desligado deixa a ponta onde o dedo tocou', () {
    final g = GameController(Store(null))..toggleSnap();
    expect(g.snapOn, isFalse);
    final r = _drawNearJoint(g);
    expect(r.a!.key, Pt(140, 400).key);
    expect(g.parts.length, 7);
  });

  test('barra cruzando outra peça é recusada', () {
    final g = GameController(Store(null))..toggleSnap();
    final n = g.parts.length;
    // atravessa o chassi do carrinho de exemplo (y = 470) sem passar por uma junta
    g.setTool('rod');
    g.pointerDown(1, Pt(130, 440));
    g.pointerMove(1, Pt(132, 470));
    g.pointerMove(1, Pt(135, 489));
    g.pointerUp(1);
    expect(g.parts.length, n);
    expect(g.hint, contains('não pode'));
  });
}
