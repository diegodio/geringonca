import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

/// Desenha uma barra começando 6 px ao lado da junta (130, 400) do carrinho de exemplo.
Part _drawNearJoint(GameController g) {
  g.setTool('rod');
  g.pointerDown(1, Pt(136, 400));
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
    expect(r.a!.key, Pt(136, 400).key);
    expect(g.parts.length, 7);
  });
}
