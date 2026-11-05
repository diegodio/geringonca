// Peças permitidas por fase, desafios extras e ações da tela de vitória.
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/model.dart';
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
}
