// A mesma engenhoca precisa dar o mesmo resultado em qualquer aparelho: os
// códigos de compartilhamento e o replay dependem disso. Este teste roda as
// engenhocas abaixo e compara a impressão digital da simulação com valores
// fixos. Ele roda no Dart nativo (Box2D compilado em C) e no navegador
// (Box2D em WebAssembly):
//   flutter test test/determinism_test.dart
//   flutter test test/determinism_test.dart --platform chrome
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/fingerprint.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';

Level _lv(String id) => kBuiltin.firstWhere((l) => l.id == id);

/// Engenhocas que passam por todas as partes da física: motores, juntas,
/// ímãs, elevador, gangorra, porta com botão e manivela numa roda girada.
Map<String, (Level, List<Part>, Pt)> scenarios() {
  (Level, List<Part>, Pt) sample(String id, [List<Part> extra = const []]) {
    final lv = _lv(id);
    return (lv, [...sampleFor(lv, lv.ball)!, ...extra], lv.ball);
  }

  final l1 = _lv('l1'), b = l1.ball;
  final crank = Part.wheel('cw', Pt(b.x + 60, b.y + 10), 40, 0.2617993877991494); // girada 15°
  return {
    'carrinho na fase 1': sample('l1'),
    'rampa': sample('l2'),
    'ímã no carrinho': sample('l4', [Part.mag('N', Pt(_lv('l4').ball.x - 40, _lv('l4').ball.y - 40))]),
    'elevador': sample('l5'),
    'gangorra': sample('l6'),
    'porta e botão': sample('l7'),
    // a borracha no eixo liga o motor da manivela (roda com o centro solto não gira)
    'manivela': (l1, [crank, Part.rod('water', crank.c!.copy(), Pt(b.x + 60, b.y - 50)), Part.rod('solid', crank.perim[0], Pt(b.x - 100, b.y + 10)), Part.wheel('free', Pt(b.x - 100, b.y + 10), 24)], b),
    'motor com o centro solto': (l1, [Part.wheel('cw', Pt(b.x + 60, b.y + 10), 40)], b),
  };
}

/// Impressões digitais de referência. Se uma mudança proposital na física as
/// alterar, rode o teste, confira e atualize os valores aqui.
/// Valores obtidos no Dart nativo (x86) e conferidos no Chrome (WebAssembly)
/// e num Box2D compilado com FMA ligado e -ffp-contract=off (o caso dos celulares ARM).
const golden = <String, String>{
  'carrinho na fase 1': '0c66aee6',
  'rampa': '2d1bdab3',
  'ímã no carrinho': '0d11de44',
  'elevador': '33ea872c',
  'gangorra': '0143d11a',
  'porta e botão': '34445e78',
  'manivela': '173f5d01',
  'motor com o centro solto': '358c5e37',
};

void main() {
  setUpAll(() async => initializeForge2D());

  for (final MapEntry(key: name, value: (lv, parts, ball)) in scenarios().entries) {
    test(name, () {
      final fp = fingerprint(lv, parts, ball);
      // ignore: avoid_print
      print('FP $name = $fp');
      expect(fp, golden[name], reason: 'a física mudou nesta plataforma ou no código');
    });
  }
}
