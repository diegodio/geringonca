// Barras não podem começar sobrepostas nem cruzando nada, a não ser o que está
// ligado a elas por uma junta. Este arquivo diz o que está ligado a quê e quais
// barras começam invadindo outra peça, a bola ou o cenário. A construção usa para
// recusar uma barra mal posta; a simulação, para saber quem pode se ignorar.
import 'dart:math' as math;

import 'model.dart';

/// Quanto uma barra pode encostar sem contar como sobreposição (px).
const double kClashTol = 1;

/// Meia espessura da barra de madeira.
const double kRodR = 4;

/// [a] e [b] estão ligadas por uma junta? Contam o mesmo ponto (ponta, eixo ou
/// ímã) e os 4 pontos de conexão na borda de uma roda.
bool linked(Part a, Part b) {
  if (identical(a, b)) return true;
  final ka = {for (final p in a.points) p.key};
  if (b.points.any((p) => ka.contains(p.key))) return true;
  bool rim(Part w, Part o) => w.isWheel && w.perim.any((pp) => o.points.any((p) => dist(p, pp) < .75));
  return rim(a, b) || rim(b, a);
}

/// A peça está presa na bola? [ball] nulo: bola solta (nada se prende).
bool linkedToBall(Part q, Pt? ball) => ball != null && q.points.any((p) => p.key == ball.key);

/// Uma forma do mundo, para medir distância a um segmento.
sealed class _Shape {
  const _Shape();

  /// Distância do segmento a-b até a superfície da forma (0 se cruzar ou estiver dentro).
  double distTo(Pt a, Pt b);
}

/// Cápsula: segmento com raio (um círculo quando as pontas coincidem).
class _Cap extends _Shape {
  final Pt a, b;
  final double r;
  const _Cap(this.a, this.b, this.r);
  @override
  double distTo(Pt p, Pt q) => math.max(0, segSegDist(p, q, a, b) - r);
}

/// Polígono convexo ou não (retângulos e morros), dado pelos vértices em ordem.
class _Poly extends _Shape {
  final List<Pt> v;
  final bool Function(Pt) inside;
  const _Poly(this.v, this.inside);

  factory _Poly.rect(R r) => _Poly([Pt(r.x, r.y), Pt(r.x + r.w, r.y), Pt(r.x + r.w, r.y + r.h), Pt(r.x, r.y + r.h)], r.contains);

  @override
  double distTo(Pt p, Pt q) {
    if (inside(p) || inside(q)) return 0;
    var d = double.infinity;
    for (var i = 0; i < v.length; i++) {
      d = math.min(d, segSegDist(p, q, v[i], v[(i + 1) % v.length]));
      if (d == 0) return 0;
    }
    return d;
  }
}

/// O cenário fixo da fase como estava no começo da tentativa (t = 0).
List<_Shape> _scenery(Level lv) {
  final out = <_Shape>[];
  if (lv.ground) {
    // chão com os buracos dos poços de elevador, como na simulação
    final holes = [
      for (final l in lv.lifts)
        if (l.hasShaft) (l.a.x - l.w / 2, l.a.x + l.w / 2),
    ]..sort((p, q) => p.$1.compareTo(q.$1));
    var x0 = -100.0;
    for (final (h0, h1) in [...holes, (kW + 100, kW + 100)]) {
      if (h0 > x0) out.add(_Poly.rect(R(x0, 500, h0 - x0, 1000)));
      if (h1 > x0) x0 = h1;
    }
  }
  for (final b in [...lv.blocks, ...lv.doors, ...lv.crates]) {
    out.add(_Poly.rect(b));
  }
  for (final h in lv.hills) {
    out.add(_Poly([...hillPoints(h), Pt(h.x + h.w, h.y + h.h), Pt(h.x, h.y + h.h)], (p) => inHill(h, p)));
  }
  for (final s in lv.plats) {
    out.add(_Cap(s.a, s.b, kPlatT / 2));
  }
  for (final s in lv.seesaws) {
    out.add(_Cap(s.a, s.b, kSeeT / 2));
  }
  for (final m in lv.magnets) {
    out.add(_Cap(m.p, m.p, kFixR));
  }
  for (final l in lv.lifts) {
    final p = l.posAt(0);
    out.add(_Poly.rect(R(p.x - l.w / 2, p.y - kLiftT / 2, l.w, kLiftT)));
  }
  return out;
}

/// Forma de uma peça para o teste: barra de madeira inteira, pontas da borracha
/// (o corpo dela atravessa tudo), roda e ímã.
List<_Cap> _capsOf(Part q) => q.isRod
    ? (q.k == 'solid' ? [_Cap(q.a!, q.b!, kRodR)] : [_Cap(q.a!, q.a!, kTipR), _Cap(q.b!, q.b!, kTipR)])
    : [_Cap(q.c!, q.c!, q.r)];

/// O que a barra [q] invade: 'parte', 'bola' ou 'cenario'; null se estiver livre.
/// [ball] é a bola (nula se a fase é de bola solta: aí nada se liga a ela, mas ela
/// continua sendo um obstáculo, em [ballPos]).
String? clashOf(Part q, List<Part> parts, Level lv, Pt ballPos) => _clash(q, parts, ballPos, lv.looseBall, _scenery(lv));

String? _clash(Part q, List<Part> parts, Pt ballPos, bool looseBall, List<_Shape> scenery) {
  if (!q.isRod) return null;
  final mine = _capsOf(q);
  bool hits(_Shape s) => mine.any((c) => s.distTo(c.a, c.b) < c.r - kClashTol);
  for (final o in parts) {
    if (identical(o, q) || linked(q, o)) continue;
    // madeira contra madeira e roda/ímã; pontas de borracha contra qualquer peça sólida
    for (final oc in _capsOf(o)) {
      if (hits(oc)) return 'parte';
    }
  }
  if (!(linkedToBall(q, looseBall ? null : ballPos)) && hits(_Cap(ballPos, ballPos, kBallR))) return 'bola';
  for (final s in scenery) {
    if (hits(s)) return 'cenario';
  }
  return null;
}

/// Barras da engenhoca que começam invadindo algo, com o motivo.
Map<Part, String> clashes(List<Part> parts, Level lv, Pt ball) {
  final sc = _scenery(lv), out = <Part, String>{};
  for (final q in parts) {
    final c = _clash(q, parts, ball, lv.looseBall, sc);
    if (c != null) out[q] = c;
  }
  return out;
}
