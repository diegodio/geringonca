// Miniatura de uma fase: a bancada desenhada pequena, com o mesmo pincel do jogo
// (papel milimetrado, área verde, meta, cenário e a bola). O menu usa uma por cartão.
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;

import '../core/model.dart';
import '../game/ink.dart';
import '../game/palette.dart';

class LevelThumb extends StatelessWidget {
  final Level lv;
  final Ink ink;

  /// Fase bloqueada: a miniatura fica cinza.
  final bool locked;
  const LevelThumb({super.key, required this.lv, required this.ink, this.locked = false});

  // tira a cor (fase bloqueada)
  static const _grey = ColorFilter.matrix([
    .3, .59, .11, 0, 0, //
    .3, .59, .11, 0, 0,
    .3, .59, .11, 0, 0,
    0, 0, 0, .55, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    Widget art = RepaintBoundary(child: CustomPaint(painter: _ThumbPainter(lv, ink, ink.c), size: Size.infinite));
    if (locked) art = ColorFiltered(colorFilter: _grey, child: art);
    return AspectRatio(aspectRatio: kW / kH, child: art);
  }
}

class _ThumbPainter extends CustomPainter {
  final Level lv;
  final Ink ink;
  final Palette c; // na comparação: trocar o tema redesenha
  _ThumbPainter(this.lv, this.ink, this.c);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / kW;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(s);
    final i = ink.on(canvas);
    // papel com só as linhas grossas (a cada metro): as finas sumiriam neste tamanho
    canvas.drawRect(const Rect.fromLTWH(0, 0, kW, kH), i.fill(c.paper));
    final major = i.stroke(c.gridMajor, .8 / s);
    for (var x = 100; x < kW; x += 100) {
      i.line(x.toDouble(), 0, x.toDouble(), kH, major);
    }
    for (var y = 100; y < kH; y += 100) {
      i.line(0, y.toDouble(), kW, y.toDouble(), major);
    }
    for (final (r, col) in [(lv.zone, c.zone), (lv.goal, c.goal)]) {
      final rect = Rect.fromLTWH(r.x, r.y, r.w, r.h);
      canvas.drawRect(rect, i.fill(col, .2));
      canvas.drawRect(rect, i.stroke(col, 1.2 / s));
    }
    i.scenery(lv, null, rulers: false);
    i.ball(lv.ball.x, lv.ball.y, -math.pi / 2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => !identical(old.lv, lv) || old.c != c;
}
