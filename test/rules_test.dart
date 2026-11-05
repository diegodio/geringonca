// Peças permitidas por fase, desafios extras e ações da tela de vitória.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/core/sim.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/progress.dart';
import 'package:geringonca/game/storage.dart';

void _runUntilWin(GameController g, {double maxT = 10}) {
  for (var i = 0; i < maxT * 60 && !g.won; i++) {
    g.tick(1 / 60);
  }
}

/// Fase 1 com uma roda grande e a bola no eixo: vence sem barras.
GameController _l1WithWheel() {
  final g = GameController(Store(null));
  g.parts = [Part.wheel('cw', g.ball0.copy(), 60)];
  return g;
}

void main() {
  setUpAll(() async => initializeForge2D());

  group('peças permitidas', () {
    test('ferramenta proibida não é escolhida', () {
      final g = GameController(Store(null))..selectLevel('l13');
      expect(g.toolAllowed('cw'), isFalse);
      expect(g.tool, isNot('cw'));
      g.setTool('cw');
      expect(g.tool, isNot('cw'));
      expect(g.hint, contains('roda horária'));
    });

    test('com peça proibida a fase não roda', () {
      final g = GameController(Store(null))..selectLevel('l13');
      g.parts = [Part.wheel('cw', Pt(90, 190), 28)];
      g.togglePlay();
      expect(g.mode, Mode.build);
      expect(g.hint, contains('não permite'));
    });

    test('ao sair da fase restrita, as ferramentas voltam', () {
      final g = GameController(Store(null))..selectLevel('l13');
      g.selectLevel('l1');
      expect(g.toolAllowed('cw'), isTrue);
    });

    test('o editor escolhe as peças e grava no código', () {
      final g = GameController(Store(null))..newLevel();
      g.toggleAllowed('magN');
      g.toggleAllowed('magS');
      expect(g.editLevel!.allowed, ['rod', 'water', 'cw', 'ccw', 'free']);
      expect(Level.fromJson(g.editLevel!.toJson()).allowed, ['rod', 'water', 'cw', 'ccw', 'free']);
      for (final t in ['magN', 'magS']) {
        g.toggleAllowed(t);
      }
      expect(g.editLevel!.allowed, isNull, reason: 'todas permitidas = sem restrição');
    });
  });

  group('desafios extras', () {
    test('sem barras e de primeira', () {
      final g = _l1WithWheel()..togglePlay();
      _runUntilWin(g);
      expect(g.won, isTrue);
      expect(g.winInfo!.badges, containsAll(['norod', 'first']));
      expect(g.winInfo!.badges, isNot(contains('nomotor')));
      expect(g.progress.badgesOf('l1'), containsAll(['norod', 'first']));
    });

    test('"De primeira" não vale na segunda tentativa', () {
      final g = _l1WithWheel()..togglePlay();
      g.stop();
      g.togglePlay();
      _runUntilWin(g);
      expect(g.winInfo!.badges, isNot(contains('first')));
    });

    test('todo desafio tem nome', () {
      for (final c in kChallenges) {
        expect(challengeName(c.$1), isNotEmpty);
      }
    });
  });

  group('tela de vitória', () {
    test('próxima fase', () {
      final g = _l1WithWheel()..togglePlay();
      _runUntilWin(g);
      expect(g.winInfo!.next?.id, 'l2');
      g.goNext();
      expect(g.mode, Mode.build);
      expect(g.level.id, 'l2');
    });

    test('tentar de novo e melhorar', () {
      final g = _l1WithWheel()..togglePlay();
      _runUntilWin(g);
      g.retry();
      expect(g.mode, Mode.run);
      expect(g.won, isFalse);
      expect(g.sim!.t, 0);
      _runUntilWin(g);
      g.improve();
      expect(g.mode, Mode.build);
    });
  });

  group('regras novas', () {
    test('orçamento: acima do limite a fase não roda', () {
      final g = GameController(Store(null))..selectLevel('l30');
      g.parts = [for (var i = 0; i < 3; i++) Part.wheel('cw', Pt(100 + i * 60.0, 440), 28)];
      g.togglePlay();
      expect(g.mode, Mode.build);
      expect(g.hint, contains('orçamento'));
    });

    test('bola solta: nada se prende à bola nem liga motor por ela', () {
      final lv = kBuiltin.firstWhere((l) => l.id == 'l19');
      expect(lv.looseBall, isTrue);
      final s = Sim(lv, [Part.wheel('cw', lv.ball.copy(), 40)], lv.ball.copy());
      expect(s.bodies.first.powered, isFalse, reason: 'a bola não conta como eixo');
      s.dispose();
      final g = GameController(Store(null))..selectLevel('l19');
      expect(g.findSnap(g.ball0.copy()), isNull, reason: 'a bola não é ponto de encaixe');
    });

    test('atraso do elevador desloca o ciclo', () {
      final a = Lift(Pt(0, 500), Pt(0, 300), 100), b = Lift(Pt(0, 500), Pt(0, 300), 100, a.period / 2);
      expect(a.posAt(0).y, 500);
      expect(b.posAt(0).y, closeTo(300, 1e-9));
      // o atraso vai e volta no JSON (códigos de compartilhamento e fases salvas)
      final lv = Level(name: 'x', zone: zone0(), goal: R(0, 0, 10, 10), ball: Pt(100, 400), lifts: [b]);
      expect(Level.fromJson(lv.toJson()).lifts.first.delay, closeTo(b.delay, 1e-9));
    });

    test('o exemplo só existe na primeira fase', () {
      final g = GameController(Store(null));
      expect(g.hasSample, isTrue);
      g.selectLevel('l2');
      expect(g.hasSample, isFalse);
      final before = g.parts.length;
      g.loadSample();
      expect(g.parts.length, before);
    });

    test('bola fora da área verde não pode ser arrastada', () {
      final g = GameController(Store(null))..selectLevel('l18');
      final b = g.ball0.copy();
      g.setTool('move');
      g.pointerDown(1, b);
      g.pointerMove(1, Pt(100, 400));
      g.pointerUp(1);
      expect(g.ball0.x, b.x);
      expect(g.ball0.y, b.y);
    });
  });
}
