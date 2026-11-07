import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';

/// Fase vazia com chão; a bola fica longe das barras.
Level _lab() => Level(name: 'lab', zone: R(0, 0, 1000, 560), goal: R(990, 0, 10, 10), ball: Pt(900, 470));

Sim _run(List<Part> parts, double seconds) {
  final s = Sim(_lab(), parts, Pt(900, 470));
  while (s.t < seconds) {
    s.step();
  }
  return s;
}

double _y(Sim s, int i) => s.pose(s.bodies[i].body).y;

void main() {
  setUpAll(() async => initializeForge2D());

  test('madeira cai sobre madeira e para em cima', () {
    final s = _run([
      Part.rod('solid', Pt(300, 495), Pt(500, 495)), // no chão
      Part.rod('solid', Pt(320, 400), Pt(480, 400)), // solta, acima
    ], 2);
    // a de baixo fica no chão (centro em 496) e a de cima uma espessura acima
    expect(_y(s, 1), closeTo(488, 2));
    s.dispose();
  });

  test('borracha atravessa madeira e o cenário', () {
    final s = _run([
      Part.rod('solid', Pt(300, 495), Pt(500, 495)),
      Part.rod('water', Pt(320, 400), Pt(480, 400)),
    ], 2);
    expect(_y(s, 1), greaterThan(560));
    s.dispose();
  });

  test('triângulo de barras presas na mesma junta fica parado', () {
    final s = _run([
      Part.rod('solid', Pt(300, 490), Pt(460, 490)),
      Part.rod('solid', Pt(300, 490), Pt(380, 400)),
      Part.rod('solid', Pt(460, 490), Pt(380, 400)),
    ], 2);
    for (final b in s.bodies) {
      expect(b.body.linearVelocity.length, lessThan(.05));
    }
    s.dispose();
  });

  test('barras cruzadas em X no início não se empurram', () {
    final s = _run([
      Part.rod('solid', Pt(300, 200), Pt(460, 310)),
      Part.rod('solid', Pt(300, 310), Pt(460, 200)),
    ], .2);
    // ainda no ar: caem juntas, sem serem lançadas para os lados
    for (final b in s.bodies) {
      expect(b.body.linearVelocity.x.abs(), lessThan(.3));
    }
    s.dispose();
  });

  test('roda cai sobre outra roda e para em cima', () {
    final s = _run([
      Part.wheel('free', Pt(400, 472), 28), // no chão
      Part.wheel('free', Pt(400, 380), 28), // solta, logo acima
    ], 1);
    final a = s.pose(s.bodies[0].body), b = s.pose(s.bodies[1].body);
    // as duas continuam separadas: os centros ficam a pelo menos dois raios
    expect(dist(Pt(a.x, a.y), Pt(b.x, b.y)), greaterThan(55));
    s.dispose();
  });

  test('roda que começa perto de uma barra solta não a atravessa', () {
    final s = _run([
      Part.rod('solid', Pt(300, 495), Pt(500, 495)), // no chão, topo em 491
      Part.wheel('free', Pt(400, 461), 28), // base a 2 px da barra
    ], 1);
    // a roda para em cima da barra, sem atravessá-la até o chão
    expect(s.pose(s.bodies[1].body).y, closeTo(463, 2));
    s.dispose();
  });

  test('roda com barra de madeira presa no eixo anda sem travar', () {
    final s = _run([Part.wheel('cw', Pt(400, 460), 40), Part.rod('solid', Pt(400, 460), Pt(370, 420))], 1);
    expect(s.pose(s.bodies[0].body).x, greaterThan(600));
    s.dispose();
  });

  group('motor só gira com o centro preso', () {
    double xAfter(List<Part> parts) {
      final s = _run(parts, 1);
      final x = s.pose(s.bodies[0].body).x;
      s.dispose();
      return x;
    }

    test('roda com o centro solto fica parada', () {
      expect(xAfter([Part.wheel('cw', Pt(400, 460), 40)]), closeTo(400, 2));
    });

    test('com uma barra no eixo, anda', () {
      expect(xAfter([Part.wheel('cw', Pt(400, 460), 40), Part.rod('water', Pt(400, 460), Pt(370, 420))]), greaterThan(600));
    });

    test('com a bola no eixo, anda', () {
      final lv = Level(name: 'lab', zone: R(0, 0, 1000, 560), goal: R(990, 0, 10, 10), ball: Pt(400, 460));
      final s = Sim(lv, [Part.wheel('cw', Pt(400, 460), 40)], Pt(400, 460));
      while (s.t < 1) {
        s.step();
      }
      expect(s.pose(s.bodies[0].body).x, greaterThan(600));
      s.dispose();
    });

    test('ponta presa só na borda não liga o motor', () {
      final w = Part.wheel('cw', Pt(400, 460), 40);
      expect(hubConnected(w, [w, Part.rod('solid', w.perim[0], Pt(300, 400))], Pt(900, 470)), isFalse);
      expect(motorOn(Part.wheel('free', Pt(400, 460), 40), [], Pt(400, 460)), isFalse);
    });
  });

  test('elevador empurra para dentro do poço e devolve ao chão', () {
    // elevador começa no alto (atraso de meio período) e desce sobre a roda parada no chão
    final l = Lift(Pt(640, 508), Pt(640, 308), 220);
    final lv = Level(name: 'lab', zone: R(0, 0, 1000, 560), goal: R(990, 0, 10, 10), ball: Pt(60, 470), lifts: [Lift(l.a, l.b, l.w, l.period / 2)]);
    final s = Sim(lv, [Part.wheel('free', Pt(640, 470), 28)], Pt(60, 470));
    var deepest = 0.0, aboveLift = false;
    while (s.t < l.period - 1e-9) { // um ciclo: do alto, desce até o chão e volta ao alto
      s.step();
      final w = s.pose(s.bodies[0].body), e = s.pose(s.lifts[0].body);
      if (w.y > deepest) deepest = w.y;
      if (w.y < e.y) aboveLift = true; // não pode ser jogada por cima do elevador
    }
    final end = s.pose(s.bodies[0].body);
    s.dispose();
    expect(aboveLift, isFalse);
    expect(deepest, greaterThan(560), reason: 'deveria descer para dentro do poço');
    // no fim, com o elevador no alto de novo, a roda está de volta no nível do chão
    expect(end.y, closeTo(472, 3));
  });

  test('distância entre segmentos', () {
    expect(segSegDist(Pt(0, 0), Pt(10, 10), Pt(0, 10), Pt(10, 0)), 0);
    expect(segSegDist(Pt(0, 0), Pt(10, 0), Pt(0, 5), Pt(10, 5)), 5);
  });

  test('exemplo continua vencendo a fase 1', () {
    final lv = kBuiltin[0];
    final s = Sim(lv, sampleFor(lv, lv.ball)!, lv.ball);
    var won = false;
    while (s.t < 10 && !won) {
      s.step();
      won = s.won();
    }
    expect(won, isTrue);
    s.dispose();
  });
}
