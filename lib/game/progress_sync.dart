// Junta o progresso de dois lugares (este aparelho e a nuvem) sem perder nada:
// fica sempre o melhor de cada um. Função pura, para testar sem internet.
import 'dart:math' as math;

/// Chaves do progresso que vão para a nuvem.
const kSyncKeys = ['done', 'medals', 'recs', 'bests', 'badges', 'tries'];

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : {};

/// Junta [a] e [b]: fases concluídas e desafios somam; medalha ganha em
/// qualquer lado vale; recordes ficam com o menor; a melhor solução é a mais
/// rápida; tentativas ficam com o maior número.
Map<String, dynamic> mergeProgress(Map<String, dynamic> a, Map<String, dynamic> b) {
  final done = {...(a['done'] is List ? a['done'] as List : const []), ...(b['done'] is List ? b['done'] as List : const [])}.whereType<String>().toList()
    ..sort();

  Map<String, dynamic> perLevel(String key, dynamic Function(dynamic x, dynamic y) join) {
    final ma = _map(a[key]), mb = _map(b[key]), out = <String, dynamic>{};
    for (final id in {...ma.keys, ...mb.keys}) {
      final x = ma[id], y = mb[id];
      out[id] = x == null
          ? y
          : y == null
          ? x
          : join(x, y);
    }
    return out;
  }

  num? minOf(dynamic x, dynamic y) {
    if (x is! num) return y is num ? y : null;
    if (y is! num) return x;
    return math.min(x, y);
  }

  return {
    'done': done,
    'medals': perLevel('medals', (x, y) {
      final mx = _map(x), my = _map(y);
      return {
        for (final k in {...mx.keys, ...my.keys}) k: mx[k] == true || my[k] == true,
      };
    }),
    'recs': perLevel('recs', (x, y) {
      final mx = _map(x), my = _map(y);
      return {
        for (final k in {...mx.keys, ...my.keys}) k: minOf(mx[k], my[k]),
      };
    }),
    'bests': perLevel('bests', (x, y) {
      final tx = _map(x)['time'], ty = _map(y)['time'];
      if (tx is! num) return y;
      if (ty is! num) return x;
      return ty < tx ? y : x;
    }),
    'badges': perLevel('badges', (x, y) => {...(x is List ? x : const []), ...(y is List ? y : const [])}.whereType<String>().toList()),
    'tries': perLevel('tries', (x, y) => math.max(x is num ? x : 0, y is num ? y : 0)),
  };
}
