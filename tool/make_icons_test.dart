// Gera os ícones do app a partir do desenho em lib/ui/logo.dart.
// Rodar: flutter test tool/make_icons_test.dart
import 'dart:io';
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
