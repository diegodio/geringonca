// Gera os ícones do app e o logotipo da tela de carregamento (logo.svg)
// a partir do desenho em lib/ui/logo.dart.
// Rodar: flutter test tool/make_icons_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/game/palette.dart';
import 'package:geringonca/ui/logo.dart';

Future<void> _png(String path, int w, int h, void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  final img = await rec.endRecording().toImage(w, h);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(data!.buffer.asUint8List());
}

void main() {
  test('gera ícones', () async {
    const c = Palette.light;
    final out = Platform.environment['ICON_OUT'] ?? 'web';
    for (final s in [192, 512]) {
      await _png('$out/icons/Icon-$s.png', s, s, (cv) => paintAppIcon(cv, s.toDouble(), c));
      await _png('$out/icons/Icon-maskable-$s.png', s, s, (cv) => paintAppIcon(cv, s.toDouble(), c, maskable: true));
    }
    await _png('$out/favicon.png', 64, 64, (cv) => paintAppIcon(cv, 64, c));
    final (svg, buildMs) = _svg(LogoArt.word());
    File('$out/logo.svg').writeAsStringSync(svg);
    // a tela de carregamento espera a montagem terminar antes de sumir
    if (out == 'web') {
      final idx = File('web/index.html');
      idx.writeAsStringSync(idx.readAsStringSync().replaceFirst(RegExp(r'/\*montagem\*/\d+'), '/*montagem*/$buildMs'));
    }
    // prévia da palavra (só quando gera em outra pasta; não vai para o app)
    if (out == 'web') return;
    final word = LogoArt.word();
    const h = 200.0;
    final w = (h * word.bounds.width / word.bounds.height).ceil();
    for (final (name, pal) in [('light', Palette.light), ('dark', Palette.dark)]) {
      await _png('$out/logo-word-$name.png', w + 40, h.toInt() + 40, (cv) {
        cv.drawRect(Rect.fromLTWH(0, 0, w + 40, h + 40), Paint()..color = pal.bg);
        cv.translate(20, 20);
        LogoPainter(word, pal).paint(cv, Size(w.toDouble(), h));
      });
    }
  });
}


String _hex(Color c) => '#${(c.toARGB32() & 0xffffff).toRadixString(16).padLeft(6, '0')}';
String _n(double v) => (v * 100).round() / 100 == (v * 100).round() ~/ 100 ? '${(v * 100).round() ~/ 100}' : ((v * 100).round() / 100).toString();

/// O logotipo em SVG para a tela de carregamento, com as cores do tema claro e
/// do escuro. A palavra é montada peça por peça, como alguém construindo na
/// bancada: cada barra é puxada de uma ponta à outra, as juntas estalam quando
/// a barra chega nelas, as rodas crescem do centro e, por último, a bola cai no
/// I e emenda no quique de [pingoAt] (o mesmo do menu).
/// Devolve o SVG e quanto tempo (ms) a montagem leva.
(String, int) _svg(LogoArt art) {
  final b = art.bounds, w = art.rodW;
  final o = StringBuffer();
  String cls(String k) => k == 'cw' ? 'cw' : k == 'ccw' ? 'ccw' : 'free';
  String d(double s) => 'animation-delay:${_n(s)}s';

  // ---- linha do tempo: barras e rodas na ordem das letras; a bola no fim ----
  const rodDur = .14, rodStep = .038, wheelDur = .32, wheelStep = .16, dropDur = .42;
  var clock = .2;
  final rodAt = <LRod, double>{}, wheelAt = <LWheel, double>{};
  final jointAt = <(Offset, double)>[]; // posição e quando aparece
  void joint(Offset p, double t) {
    final i = jointAt.indexWhere((j) => (j.$1 - p).distance < .5);
    if (i < 0) {
      jointAt.add((p, t));
    } else if (t < jointAt[i].$2) {
      jointAt[i] = (p, t);
    }
  }

  for (final p in art.pieces) {
    switch (p) {
      case LRod():
        rodAt[p] = clock;
        joint(p.a, clock);
        joint(p.b, clock + rodDur);
        clock += rodStep;
      case LWheel(c: final c, :final r, :final rot, :final rimJoints):
        clock += .08;
        wheelAt[p] = clock;
        joint(c, clock);
        for (var i = 0; i < (rimJoints ? 4 : 0); i++) {
          final an = rot + i * math.pi / 2;
          joint(c + Offset(math.cos(an), math.sin(an)) * r, clock + wheelDur * .8);
        }
        clock += wheelStep;
      case LBall():
        break;
    }
  }
  final dropAt = clock + .15, buildEnd = dropAt + dropDur;

  o.writeln('<svg xmlns="http://www.w3.org/2000/svg" viewBox="${_n(b.left)} ${_n(b.top)} ${_n(b.width)} ${_n(b.height)}" role="img" aria-label="Geringonça">');
  String vars(Palette p) => '--rod:${_hex(p.rod)};--rub:${_hex(p.water)};--ink:${_hex(p.ink)};--paper:${_hex(p.paper)};'
      '--ball:${_hex(p.ball)};--cw:${_hex(p.cw)};--ccw:${_hex(p.ccw)};--free:${_hex(p.free)}';
  final frames = StringBuffer();
  for (var i = 0; i <= 100; i += 2) {
    final (lift, sq) = pingoAt(i / 100 == 1 ? .999 : i / 100);
    frames.write('$i%{transform:translateY(${_n(-lift)}px) scale(${_n(1 + .16 * sq)},${_n(1 - .16 * sq)})}');
  }
  o.writeln('<style>svg{${vars(Palette.light)}}@media (prefers-color-scheme:dark){svg{${vars(Palette.dark)}}}'
      // barra puxada de uma ponta à outra (o traço cobre a linha inteira no fim)
      '.r,.u{stroke-width:$w;stroke-linecap:round;fill:none;stroke-dasharray:1 1;animation:puxa ${rodDur}s ease-out both}'
      '.r{stroke:var(--rod)}.u{stroke:var(--rub)}'
      '@keyframes puxa{0%{stroke-dashoffset:1;opacity:0}1%{opacity:1}100%{stroke-dashoffset:0;opacity:1}}'
      // junta e roda: aparecem crescendo, com um leve passo além do tamanho
      '.j,.w{transform-box:fill-box;transform-origin:50% 50%}'
      '.j{fill:var(--paper);stroke:var(--ink);stroke-width:${_n(w * .17)};animation:estala .22s ease-out both}'
      '.w{animation:cresce ${wheelDur}s cubic-bezier(.3,1.5,.6,1) both}'
      '@keyframes estala{0%{transform:scale(0)}60%{transform:scale(1.35)}100%{transform:scale(1)}}'
      '@keyframes cresce{0%{transform:scale(0)}100%{transform:scale(1)}}'
      '.o{stroke:var(--ink);stroke-width:${_n(w * .28)}}'
      '.s{stroke:var(--paper);stroke-opacity:.85;stroke-width:${_n(w * .3)};stroke-linecap:round}'
      '.cw{fill:var(--cw)}.ccw{fill:var(--ccw)}.free{fill:var(--free)}'
      // a bola cai no I e emenda no quique
      '.b{fill:var(--ball);stroke:var(--ink);stroke-width:${_n(w * .25)}}'
      '.p{transform-box:fill-box;transform-origin:50% 100%;'
      'animation:cai ${dropDur}s cubic-bezier(.55,0,1,.45) ${_n(dropAt)}s both,q 2.6s linear ${_n(buildEnd)}s infinite}'
      '@keyframes cai{0%{transform:translateY(-140px);opacity:0}15%{opacity:1}100%{transform:translateY(0);opacity:1}}'
      '@keyframes q{$frames}'
      '@media (prefers-reduced-motion:reduce){.r,.u,.j,.w,.p{animation:none}}</style>');
  for (final p in art.pieces) {
    if (p is LRod) {
      o.writeln('<line class="${p.rubber ? 'u' : 'r'}" pathLength="1" style="${d(rodAt[p]!)}" x1="${_n(p.a.dx)}" y1="${_n(p.a.dy)}" x2="${_n(p.b.dx)}" y2="${_n(p.b.dy)}"/>');
    }
  }
  for (final p in art.pieces) {
    switch (p) {
      case LWheel(c: final c, :final r, :final kind, :final rot):
        o.writeln('<g class="w" style="${d(wheelAt[p]!)}">');
        o.writeln('<circle class="${cls(kind)} o" cx="${_n(c.dx)}" cy="${_n(c.dy)}" r="${_n(r)}"/>');
        for (var i = 0; i < 4; i++) {
          final an = rot + i * math.pi / 2;
          o.writeln('<line class="s" x1="${_n(c.dx)}" y1="${_n(c.dy)}" x2="${_n(c.dx + math.cos(an) * r * .8)}" y2="${_n(c.dy + math.sin(an) * r * .8)}"/>');
        }
        if (kind != 'free') {
          final dir = kind == 'cw' ? 1.0 : -1.0;
          final ra = r * .56, sw = math.max(2.0, r * .1), head = math.max(5.0, r * .26);
          final start = -math.pi / 2 - dir * math.pi * .7, end = start + dir * math.pi * 1.25;
          Offset at(double a) => c + Offset(math.cos(a), math.sin(a)) * ra;
          final s0 = at(start), e = at(end);
          o.writeln('<path d="M${_n(s0.dx)} ${_n(s0.dy)}A${_n(ra)} ${_n(ra)} 0 1 ${dir > 0 ? 1 : 0} ${_n(e.dx)} ${_n(e.dy)}" stroke="#fff" stroke-width="${_n(sw)}" stroke-linecap="round" fill="none"/>');
          final t = Offset(-math.sin(end) * dir, math.cos(end) * dir), n = Offset(math.cos(end), math.sin(end));
          final pts = [e + t * head * .9, e + n * head * .55, e - n * head * .55];
          o.writeln('<polygon fill="#fff" points="${pts.map((q) => '${_n(q.dx)},${_n(q.dy)}').join(' ')}"/>');
        }
        o.writeln('</g>');
      case LBall(c: final c, :final r, :final pingo):
        o.writeln('<circle class="b${pingo ? ' p' : ''}" cx="${_n(c.dx)}" cy="${_n(c.dy)}" r="${_n(r)}"/>');
      case LRod():
        break;
    }
  }
  for (final (p, t) in jointAt) {
    o.writeln('<circle class="j" style="${d(t)}" cx="${_n(p.dx)}" cy="${_n(p.dy)}" r="${_n(w * .42)}"/>');
  }
  o.writeln('</svg>');
  return (o.toString(), (buildEnd * 1000).round());
}
