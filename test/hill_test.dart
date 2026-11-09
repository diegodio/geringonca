import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';

Level _lab(R hill, Pt ball) => Level(name: 'lab', zone: R(0, 0, 1000, 560), goal: R(990, 0, 10, 10), ball: ball, hills: [hill]);

Sim _run(Level lv, List<Part> parts, double seconds) {
  final s = Sim(lv, parts, lv.ball.copy());
  while (s.t < seconds) {
    s.step();
  }
  return s;
}

void main() {
  setUpAll(() async => initializeForge2D());
  final hill = R(300, 300, 400, 200); // pé em y=500, topo em y=300 no meio (x=500)

  test('a forma: pés no chão, topo no meio, plana nas pontas', () {
    expect(hillY(hill, 300), 500);
    expect(hillY(hill, 700), closeTo(500, 1e-9));
    expect(hillY(hill, 500), closeTo(300, 1e-9));
    expect(inHill(hill, Pt(500, 400)), isTrue);
    expect(inHill(hill, Pt(500, 290)), isFalse);
    expect(inHill(hill, Pt(320, 450)), isFalse); // perto do pé a curva ainda está baixa
    final pts = hillPoints(hill);
    expect(pts.first.x, 300);
    expect(pts.last.x, 700);
  });

  test('a bola cai na encosta, não atravessa, e rola para o lado de fora', () {
    final s = _run(_lab(hill, Pt(420, 200)), [], 4);
    final p = s.pose(s.ball);
    expect(p.x, lessThan(300), reason: 'rolou encosta abaixo para a esquerda');
    expect(p.y, closeTo(500 - kBallR, 2), reason: 'parou no chão');
    s.dispose();
  });

  test('a bola não atravessa nem caindo bem no topo', () {
    final s = _run(_lab(hill, Pt(501, 100)), [], .8);
    expect(s.pose(s.ball).y, lessThan(300 - kBallR + 3));
    s.dispose();
  });

  test('uma roda com motor sobe e passa por cima do morro', () {
    final w = Part.wheel('cw', Pt(150, 460), 40);
    final s = _run(_lab(hill, Pt(150, 460)), [w], 8);
    expect(s.pose(s.bodies[0].body).x, greaterThan(720), reason: 'passou o morro');
    s.dispose();
  });

  test('o morro vai e volta no JSON', () {
    final lv = Level.fromJson(_lab(hill, Pt(0, 0)).toJson());
    expect(lv.hills.single.toJson(), hill.toJson());
    expect(Level.fromJson(Level(name: 'x', zone: R(0, 0, 1, 1), goal: R(0, 0, 1, 1), ball: Pt(0, 0)).toJson()).hills, isEmpty);
  });
}
