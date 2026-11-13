// Toda fase pronta precisa ter solução, toda medalha precisa ser alcançável e
// os truques mais simples não podem bastar onde a fase pede outra ideia.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/clash.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';

Level _lv(String id) => kBuiltin.firstWhere((l) => l.id == id);

/// Tempo de vitória, ou null se a bola não chegar à meta em [maxT] segundos.
/// [ball]: onde a solução põe a bola (a bola pode ser arrastada na área verde).
double? winTime(Level lv, List<Part> parts, {double maxT = 15, Pt? ball}) {
  final s = Sim(lv, parts.map((q) => q.copy()).toList(), (ball ?? lv.ball).copy());
  try {
    while (s.t < maxT) {
      s.step();
      if (s.won()) return s.t;
    }
    return null;
  } finally {
    s.dispose();
  }
}

// ---------- peças para montar as soluções ----------
Part rod(double ax, double ay, double bx, double by, [String k = 'solid']) => Part.rod(k, Pt(ax, ay), Pt(bx, by));
Part wh(String k, double x, double y, double r) => Part.wheel(k, Pt(x, y), r);

/// Uma roda com motor e a bola presa no eixo.
List<Part> axle(Level lv, double r, [String k = 'cw']) => [Part.wheel(k, lv.ball.copy(), r)];

/// Roda atrás da bola, que empurra sem prendê-la (a borracha no eixo liga o motor).
List<Part> pusher(Level lv, double r) {
  final c = Pt(lv.ball.x - r - 26, 500 - r);
  return [Part.wheel('cw', c, r), Part.rod('water', c.copy(), Pt(c.x - 30, c.y - 40))];
}

/// Carro em triângulo: duas rodas, chassi e um ápice (com a bola, se ela estiver lá).
List<Part> tri(double cx, double r, double d, double apexY) => [
      wh('cw', cx - d, 500 - r, r),
      wh('cw', cx + d, 500 - r, r),
      rod(cx - d, 500 - r, cx + d, 500 - r),
      rod(cx - d, 500 - r, cx, apexY),
      rod(cx + d, 500 - r, cx, apexY),
    ];

/// Carro rígido com a bola presa no ápice do triângulo.
List<Part> rigid(Level lv, double r, double d) {
  final b = lv.ball, w1 = Pt(b.x - d, b.y + 30), w2 = Pt(b.x + d, b.y + 30);
  return [
    Part.wheel('cw', w1, r),
    Part.wheel('cw', w2.copy(), r),
    Part.rod('solid', w1.copy(), w2.copy()),
    Part.rod('solid', w1.copy(), b.copy()),
    Part.rod('solid', b.copy(), w2.copy()),
  ];
}

/// Gaiola com a bola apoiada no chassi (barras não podem atravessar a bola):
/// devolve as peças e onde a bola fica. A bola vai solta dentro.
(List<Part>, Pt) cageB(double x, double r, {double floor = 500, double h = 70, double half = 40, String top = 'solid', double w = 80}) {
  final y = floor - r;
  return ([
    rod(x - w, y, x + w, y),
    rod(x - w, y, x - half, y - h),
    rod(x + w, y, x + half, y - h),
    rod(x - half, y - h, x + half, y - h, top),
    wh('cw', x - w, y, r),
    wh('cw', x + w, y, r),
  ], Pt(x, y - 26));
}

/// Guindaste de pernas abertas: [l1] e [l2] são onde as pernas tocam o chão, em
/// relação ao eixo (negativo: à esquerda). O braço sai da borda esquerda e de cima.
List<Part> craneAt(double cx, double cy, Pt tip, {double l1 = 20, double l2 = 90}) {
  final w = Part.wheel('cw', Pt(cx, cy), 40);
  final rim = w.perim; // 0 direita, 1 baixo, 2 esquerda, 3 cima
  Pt at(int i) => Pt(rnd(rim[i].x), rnd(rim[i].y));
  return [
    w,
    rod(cx, cy, cx + l1, 490),
    rod(cx, cy, cx + l2, 490),
    rod(cx + l1, 490, cx + l2, 490),
    Part.rod('solid', at(2), tip.copy()),
    Part.rod('solid', at(3), tip.copy()),
  ];
}

/// Gaiola: chassi, duas paredes inclinadas e tampa, sobre duas rodas; a bola vai solta dentro.
List<Part> cage(Pt b, double r, {String top = 'solid', double half = 40, double floor = 500, double h = 70}) {
  final by = floor - r;
  return [
    rod(b.x - 80, by, b.x + 80, by),
    rod(b.x - 80, by, b.x - half, by - h),
    rod(b.x + 80, by, b.x + half, by - h),
    rod(b.x - half, by - h, b.x + half, by - h, top),
    wh('cw', b.x - 80, by, r),
    wh('cw', b.x + 80, by, r),
  ];
}

/// Guindaste: armação em triângulo no chão, roda com motor no alto e braço rígido
/// preso em dois pontos da borda, com a bola na ponta.
List<Part> crane(double cx, double cy, Pt tip, {String k = 'cw', double base = 70}) {
  final w = Part.wheel(k, Pt(cx, cy), 40);
  final rim = w.perim; // 0 direita, 1 baixo, 2 esquerda, 3 cima
  Pt at(int i) => Pt(rnd(rim[i].x), rnd(rim[i].y));
  final side = k == 'cw' ? at(0) : at(2);
  return [
    w,
    rod(cx, cy, cx - base, 490),
    rod(cx, cy, cx + base, 490),
    rod(cx - base, 490, cx + base, 490),
    Part.rod('solid', side, tip.copy()),
    Part.rod('solid', at(3), tip.copy()),
  ];
}

/// Roda anti-horária que vai para trás apertar o botão (borracha no eixo para ligar o motor).
List<Part> buttonPresser(double x, [double r = 24]) => [wh('ccw', x, 500 - r - 4, r), rod(x, 500 - r - 4, x + 5, 430, 'water')];

/// Uma solução de referência por fase, na ordem das fases, e onde ela põe a bola
/// (null: onde a fase deixa).
Map<String, (List<Part>, Pt?)> solutionsWithBall() {
  final l = {for (final lv in kBuiltin) lv.id!: lv};
  (List<Part>, Pt?) p(List<Part> parts) => (parts, null);
  final car12 = [wh('cw', 140, 470, 40), wh('cw', 360, 470, 40), rod(140, 470, 360, 470), rod(140, 470, 250, 440), rod(250, 440, 360, 470)];
  final (cage50, ball50) = cageB(300, 50, w: 70);
  return {
    // ---------- capítulo 1: Oficina ----------
    'l1': p(axle(l['l1']!, 60)),
    'l8': p(axle(l['l8']!, 60, 'ccw')),
    'l14': p(axle(l['l14']!, 60)),
    'l9': p(axle(l['l9']!, 40)),
    // uma roda sem motor em cima do botão, outra leva a bola
    'l7': p([wh('free', 60, 472, 28), ...axle(l['l7']!, 60)]),
    'l10': p(pusher(l['l10']!, 28)),
    // roda grande sem motor desce a ladeira e passa o degrau
    'l2': ([Part.wheel('free', Pt(170, 240), 60)], Pt(170, 240)),
    'l3': p(axle(l['l3']!, 60)),
    'l61': p(axle(l['l61']!, 60)),
    'l62': p(axle(l['l62']!, 60)),
    // ---------- capítulo 2: Terreno ----------
    'l23': p([rod(370, 488, 730, 488), wh('cw', 120, 440, 40)]),
    // a barra se apoia na quina do bloco, sem entrar nele
    'l24': p([rod(380, 490, 640, 354), wh('cw', 150, 440, 40)]),
    'l11': p(rigid(l['l11']!, 40, 130)),
    'l25': ([wh('cw', 60, 440, 60), wh('cw', 280, 440, 60), rod(60, 440, 280, 440), rod(60, 440, 170, 400), rod(280, 440, 170, 400)], Pt(170, 400)),
    'l57': p(axle(l['l57']!, 28)),
    // roda grande sobe o morro íngreme e empurra a bola do topo
    'l58': p([wh('cw', 160, 440, 60), rod(160, 440, 130, 400, 'water')]),
    'l18': p([wh('cw', 50, 474, 24), wh('cw', 150, 474, 24), rod(50, 474, 150, 474), rod(50, 474, 289, 402), rod(150, 474, 289, 402)]),
    'l67': cageB(170, 60),
    'l64': cageB(170, 60),
    'l30': p([rod(230, 488, 500, 488), rod(540, 488, 815, 488), wh('cw', 120, 440, 40)]),
    // ---------- capítulo 3: Carga solta ----------
    'l19': p(cage(l['l19']!.ball, 28)),
    'l20': cageB(170, 40, half: 50),
    'l26': cageB(170, 40),
    'l22': cageB(170, 28, h: 58, half: 30),
    'l27': ([
      wh('cw', 90, 460, 40), wh('cw', 250, 460, 40), rod(90, 460, 250, 460), //
      rod(90, 460, 140, 380), rod(250, 460, 200, 380), rod(140, 380, 200, 380),
    ], Pt(170, 434)),
    'l63': cageB(170, 60, floor: 400),
    'l28': p([rod(370, 488, 730, 488), ...cage(l['l28']!.ball, 28)]),
    'l56': cageB(160, 50, w: 80, h: 60, half: 50),
    'l59': p(cage(l['l59']!.ball, 60, floor: 250)),
    'l60': cageB(150, 40, floor: 250),
    // ---------- capítulo 4: Gravidade ----------
    'l13': p([wh('free', 90, 197, 28)]),
    // rampa em triângulo: a bola desce embalada do poleiro
    'l51': p([rod(150, 215, 360, 490), rod(150, 215, 150, 495), rod(150, 495, 360, 490)]),
    'l15': p([rod(200, 490, 250, 220), wh('free', 250, 220, 28)]),
    'l16': p([rod(670, 490, 670, 300), rod(730, 490, 670, 300), rod(670, 490, 730, 490)]),
    // rampa no canto direito devolve a bola para baixo da prateleira
    'l52': p([rod(970, 330, 700, 492), rod(970, 330, 970, 495), rod(970, 495, 700, 492)]),
    'l17': p([rod(560, 490, 600, 260), rod(640, 490, 600, 260), rod(560, 490, 640, 490)]),
    // calha que pega a bola no ar e desce até o pedestal
    'l55': p([rod(390, 330, 615, 385), rod(390, 330, 390, 495), rod(390, 495, 615, 385), rod(615, 385, 615, 495)]),
    'l21': p([wh('free', 300, 120, 60), wh('free', 360, 120, 60), rod(300, 120, 360, 120)]),
    // uma barra apoiada no calço vira trampolim
    'l54': p([rod(545, 494, 690, 450)]),
    'l29': p([rod(400, 490, 440, 140)]),
    // ---------- capítulo 5: Cenário vivo ----------
    'l6': p(axle(l['l6']!, 60)),
    'l53': p(axle(l['l53']!, 60)),
    'l5': p([wh('cw', 60, 470, 60), wh('cw', 280, 470, 60), rod(60, 470, 280, 470), rod(60, 470, 170, 440), rod(170, 440, 280, 470)]),
    'l31': p(axle(l['l31']!, 40)),
    'l33': p(axle(l['l33']!, 28)),
    'l32': p(axle(l['l32']!, 60)),
    'l35': p(axle(l['l35']!, 60)),
    'l34': p(axle(l['l34']!, 60)),
    'l36': p([wh('cw', 330, 440, 40), wh('ccw', 190, 472, 28), rod(190, 472, 210, 440, 'water')]),
    // carro com antena: a ponta passa embaixo da plataforma e aperta o botão
    'l65': p([...rigid(l['l65']!, 28, 70), rod(170, 440, 170, 315), rod(240, 470, 170, 315)]),
    // ---------- capítulo 6: Ímãs e braços ----------
    'l41': p([wh('free', 420, 478, 28), Part.mag('N', Pt(470, 478)), rod(420, 478, 470, 478)]),
    'l42': p([wh('free', 200, 478, 28), Part.mag('N', Pt(110, 470)), rod(200, 478, 110, 470)]),
    // o ímã norte na frente é puxado para cima do calombo
    'l4': p([...axle(l['l4']!, 60), rod(170, 440, 250, 420), Part.mag('N', Pt(250, 420))]),
    'l43': p([wh('free', 180, 478, 28), Part.mag('N', Pt(100, 470)), rod(180, 478, 100, 470), Part.mag('N', Pt(260, 470)), rod(180, 478, 260, 470)]),
    'l44': ([
      wh('free', 350, 472, 28), wh('free', 490, 472, 28), rod(350, 472, 490, 472), //
      rod(350, 472, 420, 400), rod(490, 472, 420, 400), Part.mag('N', Pt(535, 460)), rod(490, 472, 535, 460),
    ], Pt(420, 446)),
    'l45': p(crane(300, 380, Pt(150, 230))),
    'l66': p(craneAt(280, 330, Pt(170, 440), l1: 20, l2: 65)),
    'l46': p(craneAt(300, 330, Pt(160, 400), l1: -30, l2: 95)),
    'l47': p([
      wh('cw', 300, 300, 40), rod(300, 300, 220, 490), rod(300, 300, 380, 490), rod(220, 490, 380, 490), //
      ...crane(300, 300, Pt(120, 150)).skip(4),
    ]),
    // ---------- capítulo 7: Mestre de obras ----------
    // carro em triângulo e uma roda solta em cima do botão
    'l12': p([...car12, wh('free', 55, 476, 24)]),
    'l37': p(cage(l['l37']!.ball, 28)),
    'l38': cageB(170, 40),
    'l39': p([wh('cw', 330, 440, 28), wh('ccw', 190, 472, 28), rod(190, 472, 210, 440, 'water')]),
    'l48': p([...crane(300, 380, Pt(150, 230)), wh('ccw', 130, 472, 24), rod(130, 472, 135, 430, 'water')]),
    'l40': p([...cage(Pt(300, 440), 28), wh('ccw', 170, 472, 24), rod(170, 472, 175, 430, 'water')]),
    'l49': p([rod(420, 488, 560, 488), wh('cw', 330, 440, 60), wh('ccw', 140, 472, 24), rod(140, 472, 145, 430, 'water')]),
    'l50': ([rod(420, 488, 560, 488), ...cage50, wh('ccw', 160, 472, 24), rod(160, 472, 165, 430, 'water')], ball50),
  };
}

Map<String, List<Part>> solutions() => solutionsWithBall().map((k, v) => MapEntry(k, v.$1));

/// Truques simples que não podem vencer a fase.
Map<String, Map<String, List<Part>>> tooSimple() {
  final l = {for (final lv in kBuiltin) lv.id!: lv};
  List<Part> none() => [];
  return {
    'l7': {'só a roda na bola': axle(l['l7']!, 60), 'carrinho de exemplo': sampleFor(l['l7']!, l['l7']!.ball)!},
    'l2': {'nada': none(), 'roda pequena': [Part.wheel('free', Pt(170, 262), 28)], 'roda média': [Part.wheel('free', Pt(170, 250), 40)]},
    'l62': {'roda média': axle(l['l62']!, 40), 'roda pequena': axle(l['l62']!, 28)},
    'l5': {'roda grande': axle(l['l5']!, 60), 'roda média': axle(l['l5']!, 40)},
    'l4': {'roda grande sem ímã': axle(l['l4']!, 60), 'carro rígido sem ímã': rigid(l['l4']!, 60, 130)},
    'l22': {'carrinho de exemplo': sampleFor(l['l22']!, l['l22']!.ball)!, 'empurrador': pusher(l['l22']!, 28)},
    'l46': {'roda grande': axle(l['l46']!, 60)},
    'l12': {'carro sem peso no botão': [wh('cw', 140, 470, 40), wh('cw', 360, 470, 40), rod(140, 470, 360, 470), rod(140, 470, 250, 440), rod(250, 440, 360, 470)]},
    'l53': {'nada': none()},
    'l56': {'nada': none()},
    'l64': {'roda grande': axle(l['l64']!, 60), 'carro rígido': rigid(l['l64']!, 60, 130)},
    'l67': {'carro rígido': rigid(l['l67']!, 60, 130)},
    'l8': {'roda horária': axle(l['l8']!, 60)},
    'l14': {'roda média': axle(l['l14']!, 40), 'roda pequena': axle(l['l14']!, 28)},
    'l9': {'roda grande': axle(l['l9']!, 60)},
    'l10': {for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()} com a bola no eixo': axle(l['l10']!, r)},
    'l13': {'nada': none(), 'roda sem motor com a bola no eixo': [Part.wheel('free', l['l13']!.ball.copy(), 40)]},
    'l15': {'nada': none(), 'barra só inclinada': [rod(200, 490, 250, 200)]},
    'l16': {'nada': none()},
    'l17': {'nada': none()},
    'l18': {'carro sem braço': [wh('cw', 50, 470, 28), wh('cw', 150, 470, 28), rod(50, 470, 150, 470)]},
    'l19': {for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()} na bola': axle(l['l19']!, r)},
    'l21': {'uma roda grande': [wh('free', 320, 180, 60)]},
    'l23': {for (final r in [40.0, 60.0]) 'roda r${r.round()} sem ponte': axle(l['l23']!, r)},
    'l24': {for (final r in [40.0, 60.0]) 'roda r${r.round()} sem rampa': axle(l['l24']!, r)},
    'l11': {for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()}': axle(l['l11']!, r)},
    'l25': {'roda grande': axle(l['l25']!, 60)},
    'l27': {for (final r in [40.0, 60.0]) 'roda r${r.round()} na bola': axle(l['l27']!, r)},
    'l28': {'carro sem ponte': tri(150, 40, 110, 380)},
    'l29': {'nada': none()},
    'l30': {'roda grande sem ponte': axle(l['l30']!, 60)},
    'l31': {'roda grande': axle(l['l31']!, 60)},
    'l32': {'roda média': axle(l['l32']!, 40)},
    'l33': {'roda média': axle(l['l33']!, 40), 'roda grande': axle(l['l33']!, 60)},
    'l34': {'roda média': axle(l['l34']!, 40)},
    'l35': {'roda média': axle(l['l35']!, 40)},
    'l36': {'sem apertar o botão': axle(l['l36']!, 60)},
    'l37': {for (final r in [28.0, 60.0]) 'roda r${r.round()} na bola': axle(l['l37']!, r)},
    'l38': {for (final r in [28.0, 60.0]) 'roda r${r.round()} na bola': axle(l['l38']!, r)},
    'l39': {'sem apertar o botão': axle(l['l39']!, 28)},
    'l40': {'carrinho de exemplo': sampleFor(l['l40']!, l['l40']!.ball)!},
    'l41': {'só o ímã': [Part.mag('N', Pt(460, 470))]},
    'l42': {'só o ímã': [Part.mag('N', Pt(120, 478))]},
    'l43': {'só o ímã de trás': [wh('free', 180, 478, 28), Part.mag('N', Pt(100, 470)), rod(180, 478, 100, 470)]},
    'l45': {for (final r in [40.0, 60.0]) 'roda r${r.round()}': axle(l['l45']!, r)},
    'l48': {'guindaste sem o botão': crane(300, 380, Pt(150, 230))},
    'l49': {'roda média': [rod(420, 488, 560, 488), wh('cw', 330, 460, 40), wh('ccw', 140, 472, 24), rod(140, 472, 145, 430, 'water')]},
    'l51': {'nada': none(), 'barra solta, sem apoio': [rod(150, 215, 360, 490)]},
    'l52': {'nada': none()},
    'l54': {'nada': none()},
    'l55': {'nada': none()},
    'l57': {'roda média': axle(l['l57']!, 40)},
    'l58': {
      'nada': none(),
      'roda média': [wh('cw', 160, 460, 40), rod(160, 460, 130, 420, 'water')],
      'roda pequena': [wh('cw', 160, 472, 28), rod(160, 472, 130, 432, 'water')],
    },
    'l59': {'gaiola lenta': cage(l['l59']!.ball, 28, floor: 250)},
    'l60': {'nada': none(), 'gaiola de rodas grandes': cage(l['l60']!.ball, 60, floor: 250)},
    'l61': {'roda média': axle(l['l61']!, 40), 'roda pequena': axle(l['l61']!, 28)},
    'l63': {'roda grande': axle(l['l63']!, 60), 'roda média': axle(l['l63']!, 40)},
    'l65': {
      'sem antena': rigid(l['l65']!, 28, 70),
      'antena curta': [...rigid(l['l65']!, 28, 70), rod(170, 440, 170, 350), rod(240, 470, 170, 350)],
      'roda grande': axle(l['l65']!, 60),
    },
    'l66': {'roda grande': axle(l['l66']!, 60), 'carrinho de exemplo': sampleFor(l['l66']!, l['l66']!.ball)!},
  };
}

void main() {
  setUpAll(() async => initializeForge2D());

  test('são 67 fases em 7 capítulos, e cada uma tem solução de referência', () {
    expect(kBuiltin, hasLength(67));
    expect(kChapters.map((c) => c.$3).fold(0, (a, b) => a + b), 67);
    expect(kBuiltin.map((l) => l.id).toSet(), hasLength(67));
    expect(solutions().keys.toList(), kBuiltin.map((l) => l.id).toList());
  });

  for (final MapEntry(key: id, value: (parts, ball0)) in solutionsWithBall().entries) {
    test('$id ${_lv(id).name}: vence e ganha as três medalhas', () {
      final lv = _lv(id), tg = lv.targets, ball = ball0 ?? lv.ball;
      expect(parts.every((q) => q.points.every(lv.zone.contains)), isTrue, reason: 'solução fora da área verde');
      if (ball0 != null) expect(lv.zone.contains(ball0), isTrue, reason: 'a bola só pode ser posta na área verde');
      expect(clashes(parts, lv, ball), isEmpty, reason: 'barra sobrepondo uma peça, a bola ou o cenário');
      expect(parts.every((q) => lv.allowed == null || lv.allowed!.contains(toolOf(q))), isTrue, reason: 'solução usa peça proibida na fase');
      if (lv.budget != null) expect(costOf(parts), lessThanOrEqualTo(lv.budget!), reason: 'solução acima do orçamento');
      final t = winTime(lv, parts, ball: ball);
      expect(t, isNotNull, reason: 'a solução não vence');
      // ignore: avoid_print
      print('$id ${lv.name}: ${t!.toStringAsFixed(2)} s, ${parts.length} peças, \$${costOf(parts)}');
      expect(t, lessThanOrEqualTo(tg.t!), reason: 'medalha de tempo inalcançável');
      expect(parts.length, lessThanOrEqualTo(tg.n!), reason: 'medalha de peças inalcançável');
      expect(costOf(parts), lessThanOrEqualTo(tg.c!), reason: 'medalha de custo inalcançável');
    });
  }

  for (final MapEntry(key: id, value: tricks) in tooSimple().entries) {
    test('$id ${_lv(id).name}: truques simples não bastam', () {
      for (final MapEntry(key: name, value: parts) in tricks.entries) {
        expect(winTime(_lv(id), parts), isNull, reason: '"$name" venceu');
      }
    });
  }
}
