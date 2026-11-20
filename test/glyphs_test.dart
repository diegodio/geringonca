// Todo caractere dos textos do jogo precisa estar numa fonte que vai junto com
// ele. Senão, na web, o Flutter busca uma fonte no Google na hora; sem internet,
// o caractere vira um quadradinho (foi o que aconteceu com o ⋮ e o ★).
// Lê as fontes do disco: só roda fora do navegador.
@TestOn('vm')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Caracteres que a fonte desenha (tabela cmap, formatos 4 e 12).
Set<int> _cmap(String path) {
  final d = ByteData.sublistView(File(path).readAsBytesSync());
  final n = d.getUint16(4);
  var cmap = -1;
  for (var i = 0; i < n; i++) {
    final rec = 12 + 16 * i;
    if (String.fromCharCodes([for (var k = 0; k < 4; k++) d.getUint8(rec + k)]) == 'cmap') cmap = d.getUint32(rec + 8);
  }
  expect(cmap, isNot(-1), reason: path);
  final out = <int>{};
  for (var i = 0; i < d.getUint16(cmap + 2); i++) {
    final st = cmap + d.getUint32(cmap + 4 + 8 * i + 4);
    switch (d.getUint16(st)) {
      case 4:
        final seg = d.getUint16(st + 6) ~/ 2;
        final ends = st + 14, starts = ends + 2 * seg + 2, deltas = starts + 2 * seg, offs = deltas + 2 * seg;
        for (var s = 0; s < seg; s++) {
          final a = d.getUint16(starts + 2 * s), b = d.getUint16(ends + 2 * s);
          final delta = d.getUint16(deltas + 2 * s), off = d.getUint16(offs + 2 * s);
          for (var ch = a; ch <= b && ch != 0xFFFF; ch++) {
            final g = off == 0 ? (ch + delta) & 0xFFFF : d.getUint16(offs + 2 * s + off + 2 * (ch - a));
            if (g != 0) out.add(ch);
          }
        }
      case 12:
        for (var g = 0; g < d.getUint32(st + 12); g++) {
          final r = st + 16 + 12 * g;
          for (var ch = d.getUint32(r); ch <= d.getUint32(r + 4); ch++) {
            out.add(ch);
          }
        }
    }
  }
  return out;
}

void main() {
  test('todo caractere dos textos tem fonte embutida (funciona sem internet)', () {
    // o texto corrido usa a IBM Plex Sans; as fontes de símbolos entram como reserva (main.dart)
    final have = {
      ..._cmap('assets/fonts/IBMPlexSans-Regular.ttf'),
      for (final f in Directory('assets/symbols').listSync().whereType<File>().where((f) => f.path.endsWith('.ttf'))) ..._cmap(f.path),
    };
    final missing = <String, String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final line in f.readAsLinesSync()) {
        final code = line.trimLeft().startsWith('//') ? '' : line.split(' // ').first;
        // só o que está entre aspas (texto que aparece na tela)
        for (final m in RegExp(r"'((?:[^'\\]|\\.)*)'").allMatches(code)) {
          for (final r in m.group(1)!.runes) {
            if (r > 0x7E && !have.contains(r)) missing.putIfAbsent(String.fromCharCode(r), () => '${f.path}: ${line.trim()}');
          }
        }
      }
    }
    expect(missing, isEmpty);
  });
}
