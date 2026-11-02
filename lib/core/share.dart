// Códigos de compartilhamento "OG1:" (base64 de JSON em UTF-8), compatíveis com a versão HTML.
import 'dart:convert';

import 'levels.dart';
import 'model.dart';

String encodeShare(Level level, List<Part> parts, Pt ball) {
  final lv = level.toJson(withId: false);
  final json = jsonEncode({
    'v': 1,
    'ref': isBuiltin(level.id) ? level.id : null,
    'level': lv,
    'parts': parts.map((q) => q.toJson()).toList(),
    'ball': ball.toJson(),
  });
  return 'OG1:${base64Encode(utf8.encode(json))}';
}

Map<String, dynamic> decodeShare(String s) {
  s = s.trim();
  final json = s.startsWith('OG1:') ? utf8.decode(base64Decode(s.substring(4).replaceAll(RegExp(r'\s+'), ''))) : s;
  final o = jsonDecode(json);
  if (o is! Map<String, dynamic>) throw const FormatException('código inválido');
  return o;
}

/// Peças de um código importado, descartando as que ficam longe da área verde.
List<Part> normalizeParts(dynamic list, Level lv) {
  final z = lv.zone, box = R(z.x - 61, z.y - 61, z.w + 122, z.h + 122);
  return (list is List ? list : const [])
      .take(kLimit)
      .map((q) => Part.fromJson(q, ok: box.contains))
      .whereType<Part>()
      .toList();
}
