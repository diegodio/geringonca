// Códigos de compartilhamento "OG1:" (base64 de JSON em UTF-8), compatíveis com a versão HTML.
import 'dart:convert';

import 'levels.dart';
import 'model.dart';

/// [compact]: para links, as fases prontas vão só pela referência (o link fica curto).
String encodeShare(Level level, List<Part> parts, Pt ball, {bool compact = false}) {
  final builtin = isBuiltin(level.id);
  final json = jsonEncode({
    'v': 1,
    'ref': builtin ? level.id : null,
    if (!(compact && builtin)) 'level': level.toJson(withId: false),
    'parts': parts.map((q) => q.toJson()).toList(),
    'ball': ball.toJson(),
  });
  return 'OG1:${base64Encode(utf8.encode(json))}';
}

/// Código para link: o mesmo conteúdo em base64 próprio para endereços, sem "OG1:".
String linkCode(Level level, List<Part> parts, Pt ball) =>
    base64Url.encode(base64Decode(encodeShare(level, parts, ball, compact: true).substring(4))).replaceAll('=', '');

/// Lê um código "OG1:...", o código de um link (base64 de endereço) ou o JSON puro.
Map<String, dynamic> decodeShare(String s) {
  s = s.trim();
  final String json;
  if (s.startsWith('{')) {
    json = s;
  } else {
    var b = (s.startsWith('OG1:') ? s.substring(4) : s).replaceAll(RegExp(r'\s+'), '').replaceAll('-', '+').replaceAll('_', '/');
    b = b.padRight((b.length + 3) ~/ 4 * 4, '=');
    json = utf8.decode(base64Decode(b));
  }
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
