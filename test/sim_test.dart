import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';

double? runUntilWin(Level lv, List<Part> parts, Pt ball, {double maxT = 15}) {
  final sim = Sim(lv, parts, ball);
  try {
    while (sim.t < maxT) {
      sim.step();
      if (sim.won()) return sim.t;
    }
    final p = sim.ballPose;
    // ignore: avoid_print
    print('  sem vitória: bola em (${p.x.toStringAsFixed(0)}, ${p.y.toStringAsFixed(0)})');
    return null;
  } finally {
    sim.dispose();
  }
}

void main() {
  setUpAll(() async => initializeForge2D());

  test('exemplo vence a fase 1', () {
    final lv = kBuiltin[0];
    final t = runUntilWin(lv, sampleFor(lv, lv.ball)!, lv.ball);
    // ignore: avoid_print
    print('fase 1: $t s');
    expect(t, isNotNull);
  });

  test('exemplo nas outras fases (informativo)', () {
    for (final lv in kBuiltin.skip(1)) {
      final s = sampleFor(lv, lv.ball);
      if (s == null) continue;
      // ignore: avoid_print
      print('${lv.name}: ${runUntilWin(lv, s, lv.ball)}');
    }
  });

  test('mesma engenhoca roda igual', () {
    final lv = kBuiltin[0];
    final a = runUntilWin(lv, sampleFor(lv, lv.ball)!, lv.ball);
    final b = runUntilWin(lv, sampleFor(lv, lv.ball)!, lv.ball);
    expect(a, b);
  });
}
