import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/sim.dart';
import 'controller.dart';
import 'palette.dart';

/// Desenha a bancada: papel milimetrado, cenário, engenhoca e painel de tempo.
class BenchPainter extends CustomPainter {
  final GameController g;
  final Palette c;
  final String mono, display;
  BenchPainter(this.g, this.c, {required this.mono, required this.display, required Listenable repaint}) : super(repaint: repaint);

  late Canvas cv;
  late double z;

  Paint _fill(Color col, [double a = 1]) => Paint()..color = col.withValues(alpha: col.a * a);
  Paint _stroke(Color col, double w, [double a = 1]) => Paint()
    ..color = col.withValues(alpha: col.a * a)
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  void _line(double x1, double y1, double x2, double y2, Paint p) => cv.drawLine(Offset(x1, y1), Offset(x2, y2), p);

  void _dashLine(Offset a, Offset b, Paint p, double on, double off) {
    final d = (b - a).distance;
    if (d == 0) return;
    final u = (b - a) / d;
    for (var s = 0.0; s < d; s += on + off) {
      cv.drawLine(a + u * s, a + u * math.min(s + on, d), p);
    }
  }

  void _dashRect(Rect r, Paint p, double on, double off) {
    _dashLine(r.topLeft, r.topRight, p, on, off);
    _dashLine(r.topRight, r.bottomRight, p, on, off);
    _dashLine(r.bottomRight, r.bottomLeft, p, on, off);
    _dashLine(r.bottomLeft, r.topLeft, p, on, off);
  }

  void _dashCircle(Offset o, double r, Paint p, double on, double off) {
    final n = (2 * math.pi * r / (on + off)).floor();
    final step = 2 * math.pi / n, sweep = step * on / (on + off);
    for (var i = 0; i < n; i++) {
      cv.drawArc(Rect.fromCircle(center: o, radius: r), i * step, sweep, false, p);
    }
  }

  void _text(String s, double x, double y, Color col,
      {double size = 12, String? family, FontWeight w = FontWeight.w500, bool center = false, bool middle = false}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(color: col, fontSize: size, fontFamily: family ?? mono, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    // y é a linha de base, como no canvas do HTML (exceto quando middle)
    final dy = middle ? -tp.height / 2 : -tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(cv, Offset(center ? x - tp.width / 2 : x, y + dy));
  }

  // ---------- peças ----------
  void _rod(double x1, double y1, double x2, double y2, String kind, [double a = 1]) {
    final p = _stroke(kind == 'solid' ? c.rod : c.water, 8, kind == 'solid' ? a : .6 * a)..strokeCap = StrokeCap.round;
    _line(x1, y1, x2, y2, p);
  }

  void _joint(double x, double y, [double a = 1]) {
    cv.drawCircle(Offset(x, y), 3.5, _fill(c.paper, a));
    cv.drawCircle(Offset(x, y), 3.5, _stroke(c.ink, 1.5, a));
  }

  void _wheel(double x, double y, double r, String kind, double rot, [double a = 1]) {
    cv.drawCircle(Offset(x, y), r, _fill(c.wheel(kind), a));
    cv.drawCircle(Offset(x, y), r, _stroke(c.ink, 2, a));
    final sp = _stroke(c.paper, 2.5, .85 * a);
    for (var i = 0; i < 4; i++) {
      final an = rot + i * math.pi / 2;
      _line(x, y, x + math.cos(an) * r * .8, y + math.sin(an) * r * .8, sp);
    }
    _joint(x, y, a);
    for (var i = 0; i < 4; i++) {
      final an = rot + i * math.pi / 2;
      _joint(x + math.cos(an) * r, y + math.sin(an) * r, a);
    }
  }

  void _magnet(double x, double y, double r, String pole, bool fixed, [double a = 1]) {
    final col = pole == 'N' ? c.mN : c.mS;
    cv.drawCircle(Offset(x, y), r, _fill(col, a));
    cv.drawCircle(Offset(x, y), r, _stroke(c.ink, fixed ? 3 : 2, a));
    if (fixed) _dashCircle(Offset(x, y), r + 7, _stroke(col, 1.5, a), 3, 4);
    _text(pole, x, y + 1, Colors.white.withValues(alpha: a), size: (r * .9).roundToDouble(), w: FontWeight.w700, center: true, middle: true);
  }

  void _ball(double x, double y, double ang) {
    cv.drawCircle(Offset(x, y), kBallR, _fill(c.ball));
    cv.drawCircle(Offset(x, y), kBallR, _stroke(c.ink, 2));
    _line(x, y, x + math.cos(ang) * kBallR * .7, y + math.sin(ang) * kBallR * .7, _stroke(c.ink, 2));
  }

  void _plank(double cx, double cy, double len, double thick, double ang, Color fill, [double a = 1]) {
    cv.save();
    cv.translate(cx, cy);
    cv.rotate(ang);
    final r = Rect.fromCenter(center: Offset.zero, width: len, height: thick);
    cv.drawRect(r, _fill(fill, a));
    cv.drawRect(r, _stroke(c.ink, 1.5, a));
    cv.restore();
  }

  void _plat(Pt a, Pt b, [double al = 1]) =>
      _line(a.x, a.y, b.x, b.y, _stroke(c.ground, kPlatT, al)..strokeCap = StrokeCap.round);

  void _lift(double x, double y, double w, [double a = 1]) {
    _plank(x, y, w, kLiftT, 0, c.lift, a);
    final p = _stroke(c.paper, 2, a);
    for (final i in [-1, 1]) {
      _line(x + i * w / 4 - 6, y + 3, x + i * w / 4 + 6, y - 3, p);
    }
  }

  void _pivot(Pt m) {
    final path = Path()
      ..moveTo(m.x, m.y)
      ..lineTo(m.x - 12, m.y + 22)
      ..lineTo(m.x + 12, m.y + 22)
      ..close();
    cv.drawPath(path, _fill(c.ink));
  }

  void _door(double x, double y, double w, double h, [double a = 1]) {
    final r = Rect.fromLTWH(x, y, w, h);
    cv.drawRect(r, _fill(c.door, a));
    cv.save();
    cv.clipRect(r);
    final p = _stroke(c.paper, 3, .35 * a);
    for (var k = -w; k < h + w; k += 14) {
      _line(x, y + k, x + w, y + k - w, p);
    }
    cv.restore();
    cv.drawRect(r, _stroke(c.ink, 1.5, a));
  }

  void _button(Pt b, bool pressed) {
    final h = pressed ? 3.0 : 8.0;
    final r = Rect.fromLTWH(b.x - 25, b.y - h, 50, h);
    cv.drawRect(r, _fill(c.door));
    cv.drawRect(r, _stroke(c.ink, 1.5));
    _line(b.x - 32, b.y, b.x + 32, b.y, _stroke(c.ink, 1.5));
  }

  // ---------- cenário ----------
  void _grid() {
    cv.drawRect(const Rect.fromLTWH(0, 0, kW, kH), _fill(c.paper));
    final minor = _stroke(c.grid, 1 / z), major = _stroke(c.gridMajor, 1 / z);
    for (var x = 0; x <= kW; x += 20) {
      _line(x.toDouble(), 0, x.toDouble(), kH, x % 100 != 0 ? minor : major);
    }
    for (var y = 0; y <= kH; y += 20) {
      _line(0, y.toDouble(), kW, y.toDouble(), y % 100 != 0 ? minor : major);
    }
  }

  void _zones(Level lv) {
    final zr = Rect.fromLTWH(lv.zone.x, lv.zone.y, lv.zone.w, lv.zone.h);
    final gr = Rect.fromLTWH(lv.goal.x, lv.goal.y, lv.goal.w, lv.goal.h);
    cv.drawRect(zr, _fill(c.zone, .13));
    cv.drawRect(gr, _fill(c.goal, g.won && g.mode == Mode.run ? .4 : .18));
    _dashRect(zr, _stroke(c.zone, 1.5), 6, 5);
    _dashRect(gr, _stroke(c.goal, 1.5), 6, 5);
    _text('CONSTRUÇÃO', lv.zone.x + 6, lv.zone.y - 7, c.zone);
    _text('META', lv.goal.x + 6, lv.goal.y - 7, c.goal);
  }

  void _scenery(Level lv, Sim? s) {
    if (lv.ground) {
      cv.drawRect(const Rect.fromLTWH(0, 500, kW, kH - 500), _fill(c.ground));
      _line(0, 500, kW, 500, _stroke(c.ink, 1.5));
    }
    for (final p in lv.plats) {
      _plat(p.a, p.b);
    }
    for (final b in lv.blocks) {
      final r = Rect.fromLTWH(b.x, b.y, b.w, b.h);
      cv.drawRect(r, _fill(c.ground));
      cv.drawRect(r, _stroke(c.ink, 1.5));
    }
    for (var x = 100; x < kW; x += 100) {
      _line(x.toDouble(), kH - 10, x.toDouble(), kH, _stroke(c.muted, 1));
      _text('${x ~/ 100} m', x + 4, kH - 3, lv.ground ? c.paper : c.muted, size: 11);
    }
    for (var i = 0; i < lv.lifts.length; i++) {
      final l = lv.lifts[i];
      _dashLine(Offset(l.a.x, l.a.y), Offset(l.b.x, l.b.y), _stroke(c.lift, 1.5), 4, 5);
      if (s == null) cv.drawRect(Rect.fromLTWH(l.b.x - l.w / 2, l.b.y - kLiftT / 2, l.w, kLiftT), _stroke(c.lift, 1.5, .5));
      final pos = s != null ? s.pose(s.lifts[i].body) : Pose(l.a.x, l.a.y, 0);
      _lift(pos.x, pos.y, l.w);
    }
    for (var i = 0; i < lv.seesaws.length; i++) {
      final ss = lv.seesaws[i];
      final mid = Pt((ss.a.x + ss.b.x) / 2, (ss.a.y + ss.b.y) / 2);
      _pivot(mid);
      if (s != null) {
        final o = s.seesaws[i], p = s.pose(o.body);
        _plank(p.x, p.y, o.len, kSeeT, p.angle, c.lift);
      } else {
        _plank(mid.x, mid.y, dist(ss.a, ss.b), kSeeT, math.atan2(ss.b.y - ss.a.y, ss.b.x - ss.a.x), c.lift);
      }
      _joint(mid.x, mid.y);
    }
    for (var i = 0; i < lv.doors.length; i++) {
      final d = lv.doors[i];
      final y = s != null ? s.pose(s.doors[i].body).y - d.h / 2 : d.y;
      _door(d.x, y, d.w, d.h);
    }
    for (var i = 0; i < lv.buttons.length; i++) {
      _button(lv.buttons[i], s != null && s.buttons[i].pressed);
    }
    for (final m in lv.magnets) {
      _magnet(m.x, m.y, kFixR, m.pole, true);
    }
  }

  void _parts(List<Part> list) {
    if (g.sel.isNotEmpty || g.selBall) {
      final p = _stroke(c.accent, 8, .4)..strokeCap = StrokeCap.round;
      for (final q in g.sel) {
        if (q.isRod) {
          _line(q.a!.x, q.a!.y, q.b!.x, q.b!.y, Paint.from(p)..strokeWidth = 20);
        } else {
          cv.drawCircle(Offset(q.c!.x, q.c!.y), q.r + 6, p);
        }
      }
      if (g.selBall) cv.drawCircle(Offset(g.ball0.x, g.ball0.y), kBallR + 6, p);
    }
    for (final q in list) {
      if (q.isRod) _rod(q.a!.x, q.a!.y, q.b!.x, q.b!.y, q.k);
    }
    for (final q in list) {
      if (q.isWheel) _wheel(q.c!.x, q.c!.y, q.r, q.k, q.rot);
    }
    for (final q in list) {
      if (q.isMag) {
        _magnet(q.c!.x, q.c!.y, q.r, q.k, false);
        _joint(q.c!.x, q.c!.y + q.r * .62);
      }
    }
    for (final q in list) {
      if (q.isRod) {
        _joint(q.a!.x, q.a!.y);
        _joint(q.b!.x, q.b!.y);
      }
    }
  }

  void _editDraft(Act d) {
    const al = .55;
    final a = d.a!, b = d.b!;
    switch (d.et) {
      case 'plat':
        _plat(a, b, al);
      case 'seesaw':
        _plank((a.x + b.x) / 2, (a.y + b.y) / 2, dist(a, b), kSeeT, math.atan2(b.y - a.y, b.x - a.x), c.lift, al);
      case 'lift':
        _lift(a.x, a.y, 160, al);
        _lift(b.x, b.y, 160, al);
        _dashLine(Offset(a.x, a.y), Offset(b.x, b.y), _stroke(c.lift, 1, al), 4, 5);
      default:
        final r = R.fromPoints(a, b);
        if (d.et == 'door') {
          _door(r.x, r.y, r.w, r.h, al);
        } else {
          cv.drawRect(Rect.fromLTWH(r.x, r.y, r.w, r.h), _fill(d.et == 'zone' ? c.zone : d.et == 'goal' ? c.goal : c.ground, al));
        }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    cv = canvas;
    final s = size.width / kW, lv = g.cur, cam = g.cam;
    z = cam.z;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(s * cam.z);
    canvas.translate(-cam.x, -cam.y);
    _grid();
    _zones(lv);
    final sim = g.mode == Mode.run ? g.sim : null;
    _scenery(lv, sim);

    if (sim != null) {
      final ends = <Offset>[];
      for (final b in sim.bodies) {
        if (!b.part.isRod) continue;
        final p = sim.pose(b.body), cx = math.cos(p.angle) * b.halfLen, sy = math.sin(p.angle) * b.halfLen;
        _rod(p.x - cx, p.y - sy, p.x + cx, p.y + sy, b.part.k);
        ends.addAll([Offset(p.x - cx, p.y - sy), Offset(p.x + cx, p.y + sy)]);
      }
      final bp = sim.ballPose;
      _ball(bp.x, bp.y, bp.angle - math.pi / 2);
      for (final b in sim.bodies) {
        if (b.part.isWheel) {
          final p = sim.pose(b.body);
          _wheel(p.x, p.y, b.part.r, b.part.k, p.angle + b.part.rot);
        }
      }
      for (final b in sim.bodies) {
        if (b.part.isMag) {
          final p = sim.pose(b.body);
          _magnet(p.x, p.y, b.part.r, b.part.k, false);
        }
      }
      for (final e in ends) {
        _joint(e.dx, e.dy);
      }
    } else {
      final bp = g.mode == Mode.edit ? lv.ball : g.ball0;
      _ball(bp.x, bp.y, -math.pi / 2);
      final a = g.action;
      if (g.mode == Mode.build) {
        _parts(g.parts);
        if (a != null && a.type == 'draft') {
          final d = a.d!;
          if (d.isRod) {
            _rod(d.a!.x, d.a!.y, d.b!.x, d.b!.y, d.k, .6);
            _text('${fmt(dist(d.a!, d.b!) / 100)} m', d.b!.x + 12, d.b!.y - 12, c.ink);
          } else if (d.isWheel) {
            _wheel(d.c!.x, d.c!.y, d.r, d.k, 0, .6);
          } else {
            _magnet(d.c!.x, d.c!.y, d.r, d.k, false, .6);
          }
        }
        if (a != null && a.type == 'band') {
          final r = R.fromPoints(a.a!, a.b!);
          _dashRect(Rect.fromLTWH(r.x, r.y, r.w, r.h), _stroke(c.accent, 1.5 / cam.z), 5, 4);
        }
        final sh = g.snapHint;
        if (sh != null) cv.drawCircle(Offset(sh.x, sh.y), 12, _stroke(c.accent, 2.5));
      } else if (a != null && a.type == 'edraft') {
        _editDraft(a);
      }
    }
    canvas.restore();

    // painel fixo na tela (não acompanha o zoom)
    if (sim != null) {
      canvas.save();
      canvas.scale(s);
      final v = sim.ballSpeed;
      final hs = clampD((14 * kW / size.width).roundToDouble(), 14, 30);
      _text('t = ${fmt(sim.t)} s', 16, 12 + hs * 1.2, c.ink, size: hs);
      _text('v(bola) = ${fmt(v)} m/s', 16, 12 + hs * 2.5, c.ink, size: hs);
      if (g.replaying) _text('REPLAY', 16, 12 + hs * 3.8, c.accent, size: hs);
      if (g.winInfo != null) _winBanner(g.winInfo!);
      canvas.restore();
    }
  }

  void _winBanner(WinInfo i) {
    const w = 660.0, h = 190.0, x = (kW - w) / 2, y = 60.0;
    final r = const Rect.fromLTWH(x, y, w, h);
    cv.drawRect(r, _fill(c.paper, .95));
    cv.drawRect(r, _stroke(c.goal, 4));
    _text(i.replay ? 'REPLAY CONCLUÍDO' : 'FASE CONCLUÍDA!', kW / 2, y + 62, c.goal, size: 52, family: display, w: FontWeight.w700, center: true);
    _text('${fmt(i.t)} s · ${i.n} ${i.n == 1 ? 'peça' : 'peças'} · \$${i.c}', kW / 2, y + 112, c.ink, size: 30, center: true);
    if (!i.replay) {
      const names = {'t': 'tempo', 'n': 'peças', 'c': 'custo'};
      final tg = {'t': i.tg.t, 'n': i.tg.n, 'c': i.tg.c};
      final bits = ['t', 'n', 'c']
          .where((k) => tg[k] != null)
          .map((k) => '${i.m[k] == true ? '★ ' : '☆ '}${names[k]}${i.fresh.contains(names[k]) ? ' (nova!)' : ''}');
      _text(bits.join('   '), kW / 2, y + 160, c.ink, size: 26, center: true);
    }
  }

  @override
  bool shouldRepaint(covariant BenchPainter old) => true;
}
