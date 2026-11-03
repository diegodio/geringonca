import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/share.dart';

void main() {
  test('código OG1 vai e volta', () {
    final lv = kBuiltin[0];
    final parts = sampleFor(lv, lv.ball)!;
    final o = decodeShare(encodeShare(lv, parts, lv.ball));
    expect(o['ref'], 'l1');
    expect(normalizeParts(o['parts'], lv).length, parts.length);
  });

  test('lê código gerado pela versão HTML (btoa de UTF-8)', () {
    // mesmo formato do encodeShare do HTML: 'OG1:' + btoa(unescape(encodeURIComponent(json)))
    final json = jsonEncode({
      'v': 1,
      'ref': null,
      'level': {'name': 'Fase com acentuação', 'zone': {'x': 40, 'y': 270, 'w': 310, 'h': 220}, 'goal': {'x': 790, 'y': 360, 'w': 180, 'h': 140}, 'ball': {'x': 170, 'y': 440}},
      'parts': [
        {'t': 'rod', 'k': 'solid', 'a': {'x': 100, 'y': 400}, 'b': {'x': 200, 'y': 400}},
        {'t': 'wheel', 'k': 'cw', 'c': {'x': 100, 'y': 400}, 'r': 28},
        {'t': 'mag', 'k': 'S', 'c': {'x': 9999, 'y': 0}},
      ],
      'ball': {'x': 170, 'y': 440},
    });
    final o = decodeShare('OG1:${base64Encode(utf8.encode(json))}');
    expect(o['level']['name'], 'Fase com acentuação');
    expect(normalizeParts(o['parts'], kBuiltin[0]).length, 2); // o ímã longe da área é descartado
  });
}
