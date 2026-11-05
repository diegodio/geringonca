// Toda fase pronta precisa ter solução, toda medalha precisa ser alcançável e
// as fases novas não podem ser vencidas pelos truques mais simples.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';

Level _lv(String id) => kBuiltin.firstWhere((l) => l.id == id);

/// Tempo de vitória, ou null se a bola não chegar à meta em [maxT] segundos.
double? winTime(Level lv, List<Part> parts, {double maxT = 15}) {
  final s = Sim(lv, parts.map((q) => q.copy()).toList(), lv.ball.copy());
  try {
    while (s.t < maxT) {
      s.step();
      if (s.won()) return s.t;
    }
    return null;
  } finally {
    s.dispose();
  }
}

/// Uma roda com motor e a bola presa no eixo: vence todas as fases da versão HTML.
List<Part> axleWheel(Level lv, double r, [String k = 'cw']) => [Part.wheel(k, lv.ball.copy(), r)];

/// Roda atrás da bola, que empurra sem prendê-la. Uma barra de borracha presa no
/// eixo liga o motor (roda com o centro solto não gira) e atravessa tudo.
List<Part> pusher(Level lv, double r) {
  final c = Pt(lv.ball.x - r - 26, 500 - r);
  return [Part.wheel('cw', c, r), Part.rod('water', c.copy(), Pt(c.x - 30, c.y - 40))];
}

/// Carro rígido: duas rodas, chassi entre elas e a bola no topo de um triângulo.
List<Part> rigidCar(Level lv, double r, double d) {
  final b = lv.ball, w1 = Pt(b.x - d, b.y + 30), w2 = Pt(b.x + d, b.y + 30);
  return [
    Part.wheel('cw', w1, r),
    Part.wheel('cw', w2.copy(), r),
    Part.rod('solid', w1.copy(), w2.copy()),
    Part.rod('solid', w1.copy(), b.copy()),
    Part.rod('solid', b.copy(), w2.copy()),
  ];
}

/// Uma solução de referência por fase; juntas, cada uma ganha as três medalhas.
Map<String, List<Part>> solutions() => {
      'l1': axleWheel(_lv('l1'), 60),
      'l2': axleWheel(_lv('l2'), 60),
      'l3': axleWheel(_lv('l3'), 60),
      'l4': axleWheel(_lv('l4'), 60),
      'l5': axleWheel(_lv('l5'), 60),
      'l6': axleWheel(_lv('l6'), 60),
      'l7': axleWheel(_lv('l7'), 60),
      'l8': axleWheel(_lv('l8'), 60, 'ccw'),
      'l9': axleWheel(_lv('l9'), 40),
      'l10': pusher(_lv('l10'), 28),
      'l13': [Part.wheel('free', Pt(90, 197), 28)],
      'l11': rigidCar(_lv('l11'), 40, 130),
      'l12': rigidCar(_lv('l12'), 40, 130),
    };

/// Truques simples que não podem vencer cada fase nova.
Map<String, Map<String, List<Part>>> tooSimple() {
  final l8 = _lv('l8'), l9 = _lv('l9'), l10 = _lv('l10'), l11 = _lv('l11'), l12 = _lv('l12');
  return {
    'l8': {'roda horária': axleWheel(l8, 60)},
    'l9': {'roda grande': axleWheel(l9, 60)},
    'l10': {for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()} com a bola no eixo': axleWheel(l10, r)},
    'l13': {
      'nada': <Part>[],
      'roda sem motor com a bola no eixo': [Part.wheel('free', _lv('l13').ball.copy(), 40)],
    },
    'l11': {
      for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()}': axleWheel(l11, r),
      'carrinho de exemplo': sampleFor(l11, l11.ball)!,
    },
    'l12': {for (final r in [28.0, 40.0, 60.0]) 'roda r${r.round()}': axleWheel(l12, r)},
  };
}

void main() {
  setUpAll(() async => initializeForge2D());

  test('todas as fases prontas têm solução de referência', () {
    expect(solutions().keys, kBuiltin.map((l) => l.id));
  });

  for (final MapEntry(key: id, value: parts) in solutions().entries) {
    test('$id ${_lv(id).name}: vence e ganha as três medalhas', () {
      final lv = _lv(id), tg = lv.targets;
      expect(parts.every((q) => q.points.every(lv.zone.contains)), isTrue, reason: 'solução fora da área verde');
      expect(parts.every((q) => lv.allowed == null || lv.allowed!.contains(toolOf(q))), isTrue, reason: 'solução usa peça proibida na fase');
      final t = winTime(lv, parts);
      expect(t, isNotNull, reason: 'a solução não vence');
      // ignore: avoid_print
      print('$id ${lv.name}: ${t!.toStringAsFixed(2)} s, ${parts.length} peças, \$${costOf(parts)}');
      expect(t, lessThanOrEqualTo(tg.t!), reason: 'medalha de tempo inalcançável');
      expect(parts.length, lessThanOrEqualTo(tg.n!), reason: 'medalha de peças inalcançável');
      expect(costOf(parts), lessThanOrEqualTo(tg.c!), reason: 'medalha de custo inalcançável');
    });
  }

  for (final MapEntry(key: id, value: tricks) in tooSimple().entries) {
    test('$id ${_lv(id).name}: truques simples não bastam', () {
      for (final MapEntry(key: name, value: parts) in tricks.entries) {
        expect(winTime(_lv(id), parts), isNull, reason: '"$name" venceu');
      }
    });
  }
}
