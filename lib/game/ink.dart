import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../core/model.dart';
import '../core/sim.dart';
import 'controller.dart';
import 'palette.dart';

/// Pincel da oficina: as rotinas de desenho que os componentes do Flame usam.
/// Tudo em coordenadas da bancada (1000 x 560, y para baixo).
class Ink {
  final GameController g;
  Palette c;
  final String mono, display;
  Ink(this.g, this.c, {required this.mono, required this.display});

  late Canvas cv;
  double get z => g.cam.z;

  /// Escolhe a tela onde desenhar e devolve o próprio pincel.
  Ink on(Canvas canvas) {
    cv = canvas;
    return this;
  }

  Paint fill(Color col, [double a = 1]) => Paint()..color = col.withValues(alpha: col.a * a);
  Paint stroke(Color col, double w, [double a = 1]) => Paint()
    ..color = col.withValues(alpha: col.a * a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  void line(double x1, double y1, double x2, double y2, Paint p) => cv.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  void dashLine(Offset a, Offset b, Paint p, double on, double off) {
    final d = (b - a).distance;
    if (d == 0) return;
    final u = (b - a) / d;
    for (var s = 0.0; s < d; s += on + off) {
      cv.drawLine(a + u * s, a + u * math.min(s + on, d), p);
    }
  }

  void dashRect(Rect r, Paint p, double on, double off) {
    dashLine(r.topLeft, r.topRight, p, on, off);
    dashLine(r.topRight, r.bottomRight, p, on, off);
    dashLine(r.bottomRight, r.bottomLeft, p, on, off);
    dashLine(r.bottomLeft, r.topLeft, p, on, off);
  }

  void dashCircle(Offset o, double r, Paint p, double on, double off) {
    final n = (2 * math.pi * r / (on + off)).floor();
    final step = 2 * math.pi / n, sweep = step * on / (on + off);
    for (var i = 0; i < n; i++) {
      cv.drawArc(Rect.fromCircle(center: o, radius: r), i * step, sweep, false, p);
    }
  }

  /// Textos já montados, reaproveitados entre quadros (montar texto é caro).
  final _texts = <String, TextPainter>{};

  void text(String s, double x, double y, Color col,
      {double size = 12, String? family, FontWeight w = FontWeight.w500, bool center = false, bool middle = false}) {
    final key = '$s|$size|${col.toARGB32()}|${family ?? mono}|${w.value}';
    var tp = _texts.remove(key);
    tp ??= TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size, fontFamily: family ?? mono, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    _texts[key] = tp; // vai para o fim: os mais usados ficam
    if (_texts.length > 160) _texts.remove(_texts.keys.first)!.dispose();
    // y é a linha de base, como no canvas do HTML (exceto quando middle)
    final dy = middle ? -tp.height / 2 : -tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(cv, Offset(center ? x - tp.width / 2 : x, y + dy));
  }

  // ---------- peças ----------
  void rod(double x1, double y1, double x2, double y2, String kind, [double a = 1]) {
    final p = stroke(kind == 'solid' ? c.rod : c.water, 8, kind == 'solid' ? a : .6 * a)..strokeCap = StrokeCap.round;
    line(x1, y1, x2, y2, p);
  }

  void joint(double x, double y, [double a = 1]) {
    cv.drawCircle(Offset(x, y), 3.5, fill(c.paper, a));
    cv.drawCircle(Offset(x, y), 3.5, stroke(c.ink, 1.5, a));
  }

  /// Roda; as com motor ganham uma seta circular com o sentido do giro.
  /// [arrow] falso deixa a seta para quem desenha (a roda da simulação a mantém parada).
  /// [arrowA] < 1 apaga a seta: roda com motor cujo centro não está preso, que não vai girar.
  void wheel(double x, double y, double r, String kind, double rot, [double a = 1, bool arrow = true, double arrowA = 1]) {
    cv.drawCircle(Offset(x, y), r, fill(c.wheel(kind), a));
    cv.drawCircle(Offset(x, y), r, stroke(c.ink, 2, a));
    final sp = stroke(c.paper, 2.5, .85 * a);
    for (var i = 0; i < 4; i++) {
      final an = rot + i * math.pi / 2;
      line(x, y, x + math.cos(an) * r * .8, y + math.sin(an) * r * .8, sp);
    }
    if (arrow) wheelArrow(x, y, r, kind, a * arrowA);
    joint(x, y, a);
    for (var i = 0; i < 4; i++) {
      final an = rot + i * math.pi / 2;
      joint(x + math.cos(an) * r, y + math.sin(an) * r, a);
    }
  }

  /// Seta circular branca: horária na roda ↻, anti-horária na ↺. A roda livre não tem.
  void wheelArrow(double x, double y, double r, String kind, [double a = 1]) {
    if (kind != 'cw' && kind != 'ccw') return;
    final dir = kind == 'cw' ? 1.0 : -1.0; // ângulo positivo gira no sentido horário na tela (y para baixo)
    final ra = r * .56, w = math.max(2.0, r * .1), head = math.max(5.0, r * .26);
    final start = -math.pi / 2 - dir * math.pi * .7, sweep = dir * math.pi * 1.25;
    final end = start + sweep;
    final rect = Rect.fromCircle(center: Offset(x, y), radius: ra);
    // ponta: triângulo tangente ao arco, apontando no sentido do giro
    final tip = Offset(x + math.cos(end) * ra, y + math.sin(end) * ra);
    final t = Offset(-math.sin(end) * dir, math.cos(end) * dir), n = Offset(math.cos(end), math.sin(end));
    final path = Path()
      ..moveTo(tip.dx + t.dx * head * .9, tip.dy + t.dy * head * .9)
      ..lineTo(tip.dx + n.dx * head * .55, tip.dy + n.dy * head * .55)
      ..lineTo(tip.dx - n.dx * head * .55, tip.dy - n.dy * head * .55)
      ..close();
    // contorno escuro fino por baixo para ler bem em qualquer tema
    cv.drawArc(rect, start, sweep, false, stroke(c.ink, w + 2, .55 * a)..strokeCap = StrokeCap.round);
    cv.drawPath(path, stroke(c.ink, 2, .55 * a)..strokeJoin = StrokeJoin.round);
    cv.drawArc(rect, start, sweep, false, stroke(const Color(0xffffffff), w, a)..strokeCap = StrokeCap.round);
    cv.drawPath(path, fill(const Color(0xffffffff), a));
  }

  void magnet(double x, double y, double r, String pole, bool fixed, [double a = 1]) {
    final col = pole == 'N' ? c.mN : c.mS;
    cv.drawCircle(Offset(x, y), r, fill(col, a));
    cv.drawCircle(Offset(x, y), r, stroke(c.ink, fixed ? 3 : 2, a));
    if (fixed) dashCircle(Offset(x, y), r + 7, stroke(col, 1.5, a), 3, 4);
    text(pole, x, y + 1, Colors.white.withValues(alpha: a), size: (r * .9).roundToDouble(), w: FontWeight.w700, center: true, middle: true);
  }

  void ball(double x, double y, double ang) {
    cv.drawCircle(Offset(x, y), kBallR, fill(c.ball));
    cv.drawCircle(Offset(x, y), kBallR, stroke(c.ink, 2));
    line(x, y, x + math.cos(ang) * kBallR * .7, y + math.sin(ang) * kBallR * .7, stroke(c.ink, 2));
  }

  void plank(double cx, double cy, double len, double thick, double ang, Color color, [double a = 1]) {
    cv.save();
    cv.translate(cx, cy);
    cv.rotate(ang);
    final r = Rect.fromCenter(center: Offset.zero, width: len, height: thick);
    cv.drawRect(r, fill(color, a));
    cv.drawRect(r, stroke(c.ink, 1.5, a));
    cv.restore();
  }

  void plat(Pt a, Pt b, [double al = 1]) =>
      line(a.x, a.y, b.x, b.y, stroke(c.ground, kPlatT, al)..strokeCap = StrokeCap.round);

  void lift(double x, double y, double w, [double a = 1]) {
    plank(x, y, w, kLiftT, 0, c.lift, a);
    final p = stroke(c.paper, 2, a);
    for (final i in [-1, 1]) {
      line(x + i * w / 4 - 6, y + 3, x + i * w / 4 + 6, y - 3, p);
    }
  }

  void pivot(Pt m) {
    final path = Path()
      ..moveTo(m.x, m.y)
      ..lineTo(m.x - 12, m.y + 22)
      ..lineTo(m.x + 12, m.y + 22)
      ..close();
    cv.drawPath(path, fill(c.ink));
  }

  void door(double x, double y, double w, double h, [double a = 1]) {
    final r = Rect.fromLTWH(x, y, w, h);
    cv.drawRect(r, fill(c.door, a));
    cv.save();
    cv.clipRect(r);
    final p = stroke(c.paper, 3, .35 * a);
    for (var k = -w; k < h + w; k += 14) {
      line(x, y + k, x + w, y + k - w, p);
    }
    cv.restore();
    cv.drawRect(r, stroke(c.ink, 1.5, a));
  }

  void button(Pt b, bool pressed) {
    final h = pressed ? 3.0 : 8.0;
    final r = Rect.fromLTWH(b.x - 25, b.y - h, 50, h);
    cv.drawRect(r, fill(c.door));
    cv.drawRect(r, stroke(c.ink, 1.5));
    line(b.x - 32, b.y, b.x + 32, b.y, stroke(c.ink, 1.5));
  }

  // ---------- cenário ----------
  void grid() {
    cv.drawRect(const Rect.fromLTWH(0, 0, kW, kH), fill(c.paper));
    final minor = stroke(c.grid, 1 / z), major = stroke(c.gridMajor, 1 / z);
    for (var x = 0; x <= kW; x += 20) {
      line(x.toDouble(), 0, x.toDouble(), kH, x % 100 != 0 ? minor : major);
    }
    for (var y = 0; y <= kH; y += 20) {
      line(0, y.toDouble(), kW, y.toDouble(), y % 100 != 0 ? minor : major);
    }
  }

  void zones(Level lv) {
    final zr = Rect.fromLTWH(lv.zone.x, lv.zone.y, lv.zone.w, lv.zone.h);
    final gr = Rect.fromLTWH(lv.goal.x, lv.goal.y, lv.goal.w, lv.goal.h);
    cv.drawRect(zr, fill(c.zone, .13));
    cv.drawRect(gr, fill(c.goal, g.won && g.mode == Mode.run ? .4 : .18));
    dashRect(zr, stroke(c.zone, 1.5), 6, 5);
    dashRect(gr, stroke(c.goal, 1.5), 6, 5);
    text(tr('CONSTRUÇÃO'), lv.zone.x + 6, lv.zone.y - 7, c.zone);
    text(tr('META'), lv.goal.x + 6, lv.goal.y - 7, c.goal);
  }

  void scenery(Level lv, Sim? s) {
    if (lv.ground) {
      cv.drawRect(const Rect.fromLTWH(0, 500, kW, kH - 500), fill(c.ground));
      line(0, 500, kW, 500, stroke(c.ink, 1.5));
    }
    for (final p in lv.plats) {
      plat(p.a, p.b);
    }
    // morros antes dos blocos: a parte do morro atrás de um bloco fica escondida
    for (final h in lv.hills) {
      hill(h);
    }
    for (final b in lv.blocks) {
      final r = Rect.fromLTWH(b.x, b.y, b.w, b.h);
      cv.drawRect(r, fill(c.ground));
      cv.drawRect(r, stroke(c.ink, 1.5));
    }
    for (var i = 0; i < lv.crates.length; i++) {
      final k = lv.crates[i];
      final p = s != null ? s.pose(s.crates[i].body) : Pose(k.x + k.w / 2, k.y + k.h / 2, 0);
      crate(p.x, p.y, k.w, k.h, p.angle);
    }
    for (var x = 100; x < kW; x += 100) {
      line(x.toDouble(), kH - 10, x.toDouble(), kH, stroke(c.muted, 1));
      text('${x ~/ 100} m', x + 4, kH - 3, lv.ground ? c.paper : c.muted, size: 11);
    }
    for (var i = 0; i < lv.lifts.length; i++) {
      final l = lv.lifts[i];
      final p0 = l.posAt(0);
      final pos = s != null ? s.pose(s.lifts[i].body) : Pose(p0.x, p0.y, 0);
      // poço: buraco no chão com o fundo móvel, que fica sempre à mesma distância do elevador
      if (lv.ground && l.hasShaft) {
        final x = l.a.x - l.w / 2, top = pos.y + kLiftT / 2 + l.shaftGap;
        cv.drawRect(Rect.fromLTWH(x, 500, l.w, kH - 500), fill(c.paper));
        if (top < kH) cv.drawRect(Rect.fromLTWH(x, top, l.w, kH - top), fill(c.ground));
        final edge = stroke(c.ink, 1.5);
        line(x, 500, x, kH, edge);
        line(x + l.w, 500, x + l.w, kH, edge);
        if (top < kH) line(x, top, x + l.w, top, edge);
      }
      dashLine(Offset(l.a.x, l.a.y), Offset(l.b.x, l.b.y), stroke(c.lift, 1.5), 4, 5);
      if (s == null) cv.drawRect(Rect.fromLTWH(l.b.x - l.w / 2, l.b.y - kLiftT / 2, l.w, kLiftT), stroke(c.lift, 1.5, .5));
      lift(pos.x, pos.y, l.w);
    }
    for (var i = 0; i < lv.seesaws.length; i++) {
      final ss = lv.seesaws[i];
      final mid = Pt((ss.a.x + ss.b.x) / 2, (ss.a.y + ss.b.y) / 2);
      pivot(mid);
      if (s != null) {
        final o = s.seesaws[i], p = s.pose(o.body);
        plank(p.x, p.y, o.len, kSeeT, p.angle, c.lift);
      } else {
        plank(mid.x, mid.y, dist(ss.a, ss.b), kSeeT, math.atan2(ss.b.y - ss.a.y, ss.b.x - ss.a.x), c.lift);
      }
      joint(mid.x, mid.y);
    }
    for (var i = 0; i < lv.doors.length; i++) {
      final d = lv.doors[i];
      final y = s != null ? s.pose(s.doors[i].body).y - d.h / 2 : d.y;
      door(d.x, y, d.w, d.h);
    }
    for (var i = 0; i < lv.buttons.length; i++) {
      button(lv.buttons[i], s != null && s.buttons[i].pressed);
    }
    for (final m in lv.magnets) {
      magnet(m.x, m.y, kFixR, m.pole, true);
    }
  }

  void parts(List<Part> list) {
    if (g.sel.isNotEmpty || g.selBall) {
      final p = stroke(c.accent, 8, .4)..strokeCap = StrokeCap.round;
      for (final q in g.sel) {
        if (q.isRod) {
          line(q.a!.x, q.a!.y, q.b!.x, q.b!.y, Paint.from(p)..strokeWidth = 20);
        } else {
          cv.drawCircle(Offset(q.c!.x, q.c!.y), q.r + 6, p);
        }
      }
      if (g.selBall) cv.drawCircle(Offset(g.ball0.x, g.ball0.y), kBallR + 6, p);
    }
    for (final q in list) {
      if (q.isRod) rod(q.a!.x, q.a!.y, q.b!.x, q.b!.y, q.k);
    }
    for (final q in list) {
      if (q.isWheel) wheel(q.c!.x, q.c!.y, q.r, q.k, q.rot, 1, true, q.k == 'free' || motorOn(q, list, g.hubBall) ? 1 : .3);
    }
    for (final q in list) {
      if (q.isMag) {
        magnet(q.c!.x, q.c!.y, q.r, q.k, false);
        joint(q.c!.x, q.c!.y + q.r * .62);
      }
    }
    for (final q in list) {
      if (q.isRod) {
        joint(q.a!.x, q.a!.y);
        joint(q.b!.x, q.b!.y);
      }
    }
  }

  void editDraft(Act d) {
    const al = .55;
    final a = d.a!, b = d.b!;
    switch (d.et) {
      case 'plat':
        plat(a, b, al);
      case 'seesaw':
        plank((a.x + b.x) / 2, (a.y + b.y) / 2, dist(a, b), kSeeT, math.atan2(b.y - a.y, b.x - a.x), c.lift, al);
      case 'lift':
        lift(a.x, a.y, 160, al);
        lift(b.x, b.y, 160, al);
        dashLine(Offset(a.x, a.y), Offset(b.x, b.y), stroke(c.lift, 1, al), 4, 5);
      default:
        final r = R.fromPoints(a, b);
        if (d.et == 'door') {
          door(r.x, r.y, r.w, r.h, al);
        } else if (d.et == 'hill') {
          hill(r, al);
        } else if (d.et == 'crate') {
          crate(r.x + r.w / 2, r.y + r.h / 2, r.w, r.h, 0, al);
        } else {
          cv.drawRect(Rect.fromLTWH(r.x, r.y, r.w, r.h), fill(d.et == 'zone' ? c.zone : d.et == 'goal' ? c.goal : c.ground, al));
        }
        if (dist(a, b) > 4) measure(r);
        return;
    }
    if (dist(a, b) > 4) measure(Seg(a, b));
  }

  /// Caixa solta: caixote de madeira com as diagonais marcadas.
  void crate(double x, double y, double w, double h, double ang, [double a = 1]) {
    cv.save();
    cv.translate(x, y);
    cv.rotate(ang);
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    cv.drawRect(r, fill(c.crate, a));
    final st = stroke(c.ink, 1.5, a);
    cv.drawRect(r, st);
    final thin = stroke(c.ink, 1, a * .45);
    cv.drawLine(r.topLeft, r.bottomRight, thin);
    cv.drawLine(r.topRight, r.bottomLeft, thin);
    cv.restore();
  }

  /// Morro: a curva preenchida até o pé, com contorno só na curva (o pé encosta
  /// no chão ou num bloco). [a] < 1 no rascunho do editor.
  void hill(R h, [double a = 1]) {
    final pts = hillPoints(h, 48);
    final top = Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      top.lineTo(p.x, p.y);
    }
    final body = Path.from(top)..close();
    cv.drawPath(body, fill(c.ground, a));
    cv.drawPath(top, stroke(c.ink, 1.5, a));
  }

  /// Elemento selecionado no editor: contorno, alças para redimensionar e, enquanto
  /// arrasta, as medidas (em metros, como na bancada).
  void editSelection() {
    final o = g.selected;
    if (o == null) return;
    final acc = stroke(c.accent, 2 / z), soft = stroke(c.accent, 18, .25)..strokeCap = StrokeCap.round;
    switch (o) {
      case R r:
        dashRect(Rect.fromLTWH(r.x - 4, r.y - 4, r.w + 8, r.h + 8), acc, 6 / z, 4 / z);
      case Lift l:
        line(l.a.x, l.a.y, l.b.x, l.b.y, soft);
        cv.drawRect(Rect.fromCenter(center: Offset(l.a.x, l.a.y), width: l.w + 8, height: kLiftT + 8), acc);
      case Seg s:
        line(s.a.x, s.a.y, s.b.x, s.b.y, soft);
      case FixedMag m:
        cv.drawCircle(Offset(m.x, m.y), kFixR + 9, acc);
      case Pt p:
        final ball = identical(p, g.cur.ball);
        cv.drawCircle(Offset(p.x, p.y - (ball ? 0 : 5)), ball ? kBallR + 8 : 32, acc);
    }
    for (final h in g.eHandles) {
      cv.drawCircle(Offset(h.x, h.y), 8 / z, fill(c.paper));
      cv.drawCircle(Offset(h.x, h.y), 8 / z, stroke(c.accent, 2.5 / z));
    }
    final a = g.action;
    if (a != null && (a.type == 'emove' || a.type == 'eresize') && a.moved) measure(o);
  }

  /// Medidas de um elemento do cenário, centradas acima dele (abaixo, se não couber),
  /// sempre dentro da bancada: largura × altura, comprimento e ângulo, ou a posição.
  void measure(Object o) {
    void at(String s, double cx, double top, double bottom) {
      final x = clampD(cx, 70 / z, kW - 70 / z), y = top - 10 / z > 20 / z ? top - 10 / z : bottom + 22 / z;
      text(s, x, y, c.ink, size: 13 / z, center: true);
    }

    switch (o) {
      case R r:
        at('${fmt(r.w / 100)} × ${fmt(r.h / 100)} m', r.x + r.w / 2, r.y, r.y + r.h);
      case Seg s:
        final ang = (math.atan2(s.a.y - s.b.y, s.b.x - s.a.x) * 180 / math.pi).round();
        at('${fmt(dist(s.a, s.b) / 100)} m · $ang°', (s.a.x + s.b.x) / 2, math.min(s.a.y, s.b.y) - 6, math.max(s.a.y, s.b.y) + 6);
      case FixedMag m:
        at('${fmt(m.x / 100)}; ${fmt(m.y / 100)} m', m.x, m.y - kFixR - 6, m.y + kFixR + 6);
      case Pt p:
        at('${fmt(p.x / 100)}; ${fmt(p.y / 100)} m', p.x, p.y - 30, p.y + 10);
    }
  }

  /// Rastro da bola: linha do caminho e um ponto a cada meio segundo, para ver
  /// onde a bola acelera (pontos afastados) ou freia (pontos juntos).
  /// [pts] tem um ponto a cada 1/30 s.
  void trail(List<Pt> pts, double a) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts.first.x, pts.first.y);
    for (final p in pts.skip(1)) {
      path.lineTo(p.x, p.y);
    }
    cv.drawPath(path, stroke(c.accent, 2.5 / z, a)
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round);
    final dot = fill(c.accent, a);
    for (var k = 0; k < pts.length; k += 15) {
      cv.drawCircle(Offset(pts[k].x, pts[k].y), 3.5 / math.sqrt(z), dot);
    }
  }
}
