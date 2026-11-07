import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/palette.dart';

/// Logotipo: "GERINGONÇA" montado com as peças do jogo (barras de madeira com
/// juntas, rodas, borracha e a bola), no mesmo traço da bancada.
class LogoWord extends StatelessWidget {
  final double height;
  const LogoWord({super.key, this.height = 64});

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    final word = LogoArt.word();
    return Semantics(
      label: 'Geringonça',
      header: true,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: AspectRatio(aspectRatio: word.bounds.width / word.bounds.height, child: CustomPaint(painter: LogoPainter(word, c))),
        ),
      ),
    );
  }
}

/// Peça de um desenho do logotipo, em coordenadas próprias (letra com 100 de altura).
sealed class LogoPiece {}

class LRod extends LogoPiece {
  final Offset a, b;
  final bool rubber;
  LRod(this.a, this.b, {this.rubber = false});
}

class LWheel extends LogoPiece {
  final Offset c;
  final double r;
  final String kind; // cw, ccw, free
  final double rot;
  final bool rimJoints;
  LWheel(this.c, this.r, this.kind, {this.rot = math.pi / 4, this.rimJoints = true});
}

class LBall extends LogoPiece {
  final Offset c;
  final double r;
  LBall(this.c, this.r);
}

/// Um desenho pronto: as peças e o retângulo que as contém (com folga para o traço).
class LogoArt {
  final List<LogoPiece> pieces;
  final Rect bounds;
  final double rodW;
  LogoArt(this.pieces, this.rodW) : bounds = _bounds(pieces, rodW);

  static Rect _bounds(List<LogoPiece> ps, double w) {
    var r = Rect.zero;
    var first = true;
    void add(Rect q) {
      r = first ? q : r.expandToInclude(q);
      first = false;
    }

    for (final p in ps) {
      switch (p) {
        case LRod(:final a, :final b):
          add(Rect.fromPoints(a, b).inflate(w / 2 + 1));
        case LWheel(:final c, :final r):
          add(Rect.fromCircle(center: c, radius: r + 3));
        case LBall(:final c, :final r):
          add(Rect.fromCircle(center: c, radius: r + 2));
      }
    }
    return r;
  }

  /// A palavra inteira. Cada letra tem 100 de altura; [x] avança letra a letra.
  static LogoArt word() {
    final ps = <LogoPiece>[];
    var x = 0.0;
    const gap = 26.0;
    void rods(List<Offset> pts, {bool rubber = false}) {
      for (var i = 1; i < pts.length; i++) {
        ps.add(LRod(pts[i - 1].translate(x, 0), pts[i].translate(x, 0), rubber: rubber));
      }
    }

    void g() {
      rods(const [Offset(60, 0), Offset(18, 0), Offset(0, 18), Offset(0, 82), Offset(18, 100), Offset(60, 100), Offset(60, 52), Offset(34, 52)]);
      x += 60 + gap;
    }

    void n() {
      rods(const [Offset(0, 100), Offset(0, 0), Offset(56, 100), Offset(56, 0)]);
      x += 56 + gap;
    }

    g();
    // E
    rods(const [Offset(56, 0), Offset(0, 0), Offset(0, 100), Offset(56, 100)]);
    rods(const [Offset(0, 50), Offset(42, 50)]);
    x += 56 + gap;
    // R: a barriga é uma roda anti-horária presa pela borda
    rods(const [Offset(0, 100), Offset(0, 0), Offset(30, 0)]);
    rods(const [Offset(0, 52), Offset(30, 52), Offset(60, 100)]);
    ps.add(LWheel(Offset(x + 30, 26), 26, 'ccw', rot: 0));
    x += 60 + gap;
    // I: a bola faz o pingo
    rods(const [Offset(0, 0), Offset(0, 100)]);
    ps.add(LBall(Offset(x, -24), 13));
    x += gap;
    n();
    g();
    // O: uma roda com motor
    ps.add(LWheel(Offset(x + 50, 50), 50, 'cw'));
    x += 100 + gap;
    n();
    // Ç: cedilha de borracha
    rods(const [Offset(60, 0), Offset(18, 0), Offset(0, 18), Offset(0, 82), Offset(18, 100), Offset(60, 100)]);
    rods(const [Offset(32, 100), Offset(42, 116), Offset(26, 130)], rubber: true);
    x += 60 + gap;
    // A: travessa de borracha
    rods(const [Offset(0, 100), Offset(30, 0), Offset(60, 100)]);
    rods(const [Offset(11.4, 62), Offset(48.6, 62)], rubber: true);
    return LogoArt(ps, 12);
  }

  /// Marca do ícone: um G de madeira com a roda de motor e a bola, sobre o chão.
  static LogoArt mark() {
    const pts = [Offset(64, 0), Offset(20, 0), Offset(0, 20), Offset(0, 80), Offset(20, 100), Offset(64, 100), Offset(64, 54), Offset(40, 54)];
    return LogoArt([
      for (var i = 1; i < pts.length; i++) LRod(pts[i - 1], pts[i]),
      LWheel(const Offset(64, 100), 24, 'cw', rimJoints: false),
      LBall(const Offset(52, 36.5), 11),
    ], 13);
  }
}

/// Pinta um [LogoArt] centralizado e escalado para caber no espaço dado.
class LogoPainter extends CustomPainter {
  final LogoArt art;
  final Palette c;
  LogoPainter(this.art, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final b = art.bounds;
    final s = math.min(size.width / b.width, size.height / b.height);
    canvas.save();
    canvas.translate((size.width - b.width * s) / 2, (size.height - b.height * s) / 2);
    canvas.scale(s);
    canvas.translate(-b.left, -b.top);
    paintArt(canvas, art, c);
    canvas.restore();
  }

  /// Desenha as peças: primeiro a madeira e a borracha, depois rodas, bola e juntas por cima.
  static void paintArt(Canvas cv, LogoArt art, Palette c) {
    final w = art.rodW;
    Paint stroke(Color col, double sw) => Paint()
      ..color = col
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    final joints = <Offset>[];
    void joint(Offset p) {
      if (joints.any((q) => (q - p).distance < .5)) return;
      joints.add(p);
    }

    for (final p in art.pieces) {
      if (p is LRod) {
        cv.drawLine(p.a, p.b, stroke(p.rubber ? c.water : c.rod, w));
        joint(p.a);
        joint(p.b);
      }
    }
    for (final p in art.pieces) {
      switch (p) {
        case LWheel(c: final o, :final r, :final kind, :final rot, :final rimJoints):
          cv.drawCircle(o, r, Paint()..color = c.wheel(kind));
          cv.drawCircle(o, r, stroke(c.ink, w * .28));
          for (var i = 0; i < 4; i++) {
            final an = rot + i * math.pi / 2;
            cv.drawLine(o, o + Offset(math.cos(an), math.sin(an)) * r * .8, stroke(c.paper.withValues(alpha: .85), w * .3));
          }
          if (kind != 'free') _arrow(cv, o, r, kind == 'cw' ? 1 : -1, c);
          joint(o);
          for (var i = 0; i < (rimJoints ? 4 : 0); i++) {
            final an = rot + i * math.pi / 2;
            joint(o + Offset(math.cos(an), math.sin(an)) * r);
          }
        case LBall(c: final o, :final r):
          cv.drawCircle(o, r, Paint()..color = c.ball);
          cv.drawCircle(o, r, stroke(c.ink, w * .25));
        case LRod():
          break;
      }
    }
    final jr = w * .42;
    for (final p in joints) {
      cv.drawCircle(p, jr, Paint()..color = c.paper);
      cv.drawCircle(p, jr, stroke(c.ink, w * .17));
    }
  }

  /// Seta de giro branca, como a das rodas com motor da bancada.
  static void _arrow(Canvas cv, Offset o, double r, double dir, Palette c) {
    final ra = r * .56, sw = math.max(2.0, r * .1), head = math.max(5.0, r * .26);
    final start = -math.pi / 2 - dir * math.pi * .7, sweep = dir * math.pi * 1.25, end = start + sweep;
    final rect = Rect.fromCircle(center: o, radius: ra);
    final tip = o + Offset(math.cos(end), math.sin(end)) * ra;
    final t = Offset(-math.sin(end) * dir, math.cos(end) * dir), n = Offset(math.cos(end), math.sin(end));
    final path = Path()
      ..moveTo(tip.dx + t.dx * head * .9, tip.dy + t.dy * head * .9)
      ..lineTo(tip.dx + n.dx * head * .55, tip.dy + n.dy * head * .55)
      ..lineTo(tip.dx - n.dx * head * .55, tip.dy - n.dy * head * .55)
      ..close();
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    cv.drawArc(rect, start, sweep, false, white);
    cv.drawPath(path, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(LogoPainter old) => old.c != c || old.art != art;
}

/// Ícone do app: a marca sobre o papel quadriculado da bancada, com o chão embaixo.
/// [maskable] deixa a marca menor e o fundo até a borda (o Android recorta o formato).
void paintAppIcon(Canvas cv, double size, Palette c, {bool maskable = false}) {
  final full = Rect.fromLTWH(0, 0, size, size);
  final shape = maskable ? RRect.fromRectAndRadius(full, Radius.zero) : RRect.fromRectAndRadius(full, Radius.circular(size * .22));
  cv.save();
  cv.clipRRect(shape);
  cv.drawRect(full, Paint()..color = c.paper);
  final art = LogoArt.mark();
  final b = art.bounds;
  final box = size * (maskable ? .5 : .64);
  final s = box / math.max(b.width, b.height);
  final left = (size - b.width * s) / 2, top = (size - b.height * s) / 2 - size * .03;
  final groundY = top + (b.bottom - 3 - b.top) * s;
  // quadriculado alinhado ao chão
  final step = size / 8;
  final grid = Paint()
    ..color = c.grid
    ..strokeWidth = math.max(1, size / 160);
  for (var x = step / 2; x < size; x += step) {
    cv.drawLine(Offset(x, 0), Offset(x, size), grid);
  }
  for (var y = groundY - step; y > -step; y -= step) {
    cv.drawLine(Offset(0, y), Offset(size, y), grid);
  }
  cv.drawRect(Rect.fromLTRB(0, groundY, size, size), Paint()..color = c.ground);
  cv.drawLine(Offset(0, groundY), Offset(size, groundY), Paint()
    ..color = c.ink
    ..strokeWidth = math.max(1, size / 96));
  cv.save();
  cv.translate(left, top);
  cv.scale(s);
  cv.translate(-b.left, -b.top);
  LogoPainter.paintArt(cv, art, c);
  cv.restore();
  cv.restore();
}
