import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/share.dart';
import 'package:geringonca/core/sim.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

Level _lab({List<R>? crates, List<Pt>? buttons, List<R>? doors}) => Level(
    name: 'lab', zone: R(0, 0, 1000, 560), goal: R(990, 0, 10, 10), ball: Pt(900, 470), crates: crates, buttons: buttons, doors: doors);

Sim _run(Level lv, List<Part> parts, double seconds) {
  final s = Sim(lv, parts, lv.ball.copy());
  while (s.t < seconds) {
    s.step();
  }
  return s;
}

void main() {
  setUpAll(() async => initializeForge2D());

  test('caixa solta cai e para no chão', () {
    final s = _run(_lab(crates: [R(300, 200, 60, 60)]), [], 2);
    final p = s.pose(s.crates[0].body);
    expect(p.y, closeTo(470, 2)); // chão em 500, meia caixa acima
    expect(p.x, closeTo(330, 1));
    s.dispose();
  });

  test('caixas empilham', () {
    final s = _run(_lab(crates: [R(300, 440, 60, 60), R(300, 300, 60, 60)]), [], 2);
    expect(s.pose(s.crates[1].body).y, closeTo(410, 2));
    s.dispose();
  });

  test('roda com motor empurra a caixa', () {
    final s = _run(_lab(crates: [R(300, 440, 60, 60)]), [Part.wheel('cw', Pt(200, 460), 40), Part.rod('water', Pt(200, 460), Pt(170, 420))], 1.5);
    expect(s.pose(s.crates[0].body).x, greaterThan(450));
    s.dispose();
  });

  test('madeira não atravessa a caixa', () {
    final s = _run(_lab(crates: [R(300, 440, 100, 60)]), [Part.rod('solid', Pt(310, 300), Pt(390, 300))], 1.5);
    expect(s.pose(s.bodies[0].body).y, closeTo(436, 2)); // em cima da caixa (topo em 440)
    s.dispose();
  });

  test('caixa que cai no botão abre a porta', () {
    final s = _run(_lab(crates: [R(380, 300, 50, 50)], buttons: [Pt(405, 500)], doors: [R(600, 400, 30, 100)]), [], 2);
    expect(s.pressed, isTrue);
    expect(s.doors[0].f, greaterThan(.5));
    s.dispose();
  });

  test('caixas vão e voltam no código da fase, e fases antigas não mudam', () {
    final lv = _lab(crates: [R(300, 200, 60, 80)]);
    final back = Level.fromJson(decodeShare(encodeShare(lv, [], lv.ball))['level']);
    expect(back.crates, hasLength(1));
    expect(back.crates[0].h, 80);
    expect(_lab().toJson().containsKey('crates'), isFalse); // a assinatura das fases sem caixa fica igual
  });

  test('editor: desenhar, mover, espelhar e apagar uma caixa solta', () {
    final g = GameController(Store(null))..newLevel();
    g.setETool('crate');
    g.pointerDown(1, Pt(400, 300));
    g.pointerMove(1, Pt(440, 340));
    g.pointerMove(1, Pt(480, 380));
    g.pointerUp(1);
    expect(g.editLevel!.crates, hasLength(1));
    g.mirrorLevel();
    expect(g.editLevel!.crates[0].x, closeTo(kW - 480, 1));
    g.setETool('edel');
    final c = g.editLevel!.crates[0];
    g.pointerDown(1, Pt(c.x + c.w / 2, c.y + c.h / 2));
    g.pointerUp(1);
    expect(g.editLevel!.crates, isEmpty);
  });
}
