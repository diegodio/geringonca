// Impressão digital de uma simulação: resume, bit a bit, a posição e o ângulo
// de todos os corpos em todos os passos. Duas plataformas com a mesma
// impressão digital rodaram exatamente a mesma física. Usa só inteiros
// pequenos para dar o mesmo resultado no Dart nativo e no JavaScript.
import 'dart:typed_data';

import 'model.dart';
import 'sim.dart';

const int _mod = 1000000007;

/// Roda [seconds] de simulação e devolve a impressão digital em hexadecimal.
String fingerprint(Level lv, List<Part> parts, Pt ball, {double seconds = 4}) {
  final s = Sim(lv, parts.map((q) => q.copy()).toList(), ball.copy());
  final bytes = ByteData(8);
  var h = 7;
  void add(double v) {
    bytes.setFloat64(0, v);
    for (var i = 0; i < 8; i += 2) {
      h = (h * 31 + bytes.getUint16(i)) % _mod;
    }
  }

  try {
    final steps = (seconds * 60).round();
    for (var i = 0; i < steps; i++) {
      s.step();
      for (final b in [s.ball, ...s.bodies.map((p) => p.body), ...s.seesaws.map((o) => o.body)]) {
        final p = b.position;
        add(p.x);
        add(p.y);
        add(b.rotation.cos);
        add(b.rotation.sin);
      }
    }
  } finally {
    s.dispose();
  }
  return h.toRadixString(16).padLeft(8, '0');
}
