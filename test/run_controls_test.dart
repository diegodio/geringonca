import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

/// Simula [seconds] de tempo real em quadros de 1/60 s.
void _frames(GameController g, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    g.tick(1 / 60);
  }
}

void main() {
  setUpAll(() async => initializeForge2D());

  group('fases em sequência', () {
    test('começam liberadas a primeira fase e a seguinte (dá para pular uma)', () {
      final g = GameController(Store(null));
      expect(g.progress.isUnlocked('l1'), isTrue);
      expect(g.progress.isUnlocked(kBuiltin[1].id!), isTrue);
      expect(g.progress.isUnlocked(kBuiltin[2].id!), isFalse);
      expect(g.progress.blocker(kBuiltin[2].id!)!.id, 'l1'); // falta uma das duas primeiras
    });

    test('escolher fase bloqueada explica o que falta e não troca', () {
      final g = GameController(Store(null))..chooseLevel(kBuiltin[2].id!);
      expect(g.level.id, 'l1');
      expect(g.hint, contains('Primeiros passos'));
    });

    test('vencer libera mais uma fase e avisa', () {
      final g = GameController(Store(null))..togglePlay();
      _frames(g, 4);
      expect(g.won, isTrue);
      expect(g.winInfo!.unlocked, kBuiltin[2].name);
      expect(g.progress.isUnlocked(kBuiltin[2].id!), isTrue); // pulando a Rampa
      expect(g.progress.isUnlocked(kBuiltin[3].id!), isFalse); // mas não duas
      g.stop();
      g.chooseLevel(kBuiltin[2].id!);
      expect(g.level.id, kBuiltin[2].id);
    });

    test('fases próprias estão sempre liberadas', () {
      final g = GameController(Store(null));
      final id = g.progress.saveLevel(blankLevel());
      expect(g.progress.isUnlocked(id), isTrue);
    });
  });

  group('pausa e câmera lenta', () {
    test('pausado o tempo não anda; Avançar anda 0,1 s', () {
      final g = GameController(Store(null))..togglePlay();
      _frames(g, .5);
      g.togglePause();
      final t = g.sim!.t;
      _frames(g, 1);
      expect(g.sim!.t, t);
      g.stepForward();
      expect(g.sim!.t, closeTo(t + .1, 1e-9));
      g.togglePause();
      _frames(g, .5);
      expect(g.sim!.t, greaterThan(t + .5));
    });

    test('na metade da velocidade, 1 s de tela vira 0,5 s de simulação', () {
      final g = GameController(Store(null))
        ..setSpeed(.5)
        ..togglePlay();
      _frames(g, 1);
      expect(g.sim!.t, closeTo(.5, 1 / 60 + 1e-9));
    });

    test('câmera lenta não muda o resultado', () {
      Pt endAt(double speed) {
        final g = GameController(Store(null))
          ..setSpeed(speed)
          ..togglePlay();
        while (g.sim!.t < 1.5 - 1e-9) {
          g.tick(1 / 60);
        }
        final p = g.sim!.ballPose;
        return Pt(p.x, p.y);
      }

      final a = endAt(1), b = endAt(.25);
      expect(b.x, a.x);
      expect(b.y, a.y);
    });
  });

  group('rastro', () {
    test('grava o caminho e guarda o da última tentativa', () {
      final g = GameController(Store(null))..togglePlay();
      _frames(g, 1);
      expect(g.trail.length, greaterThan(25)); // ~30 pontos por segundo
      final n = g.trail.length, last = g.trail.last;
      g.stop();
      expect(g.trail, isEmpty);
      expect(g.lastTrail.length, n);
      expect(g.lastTrail.last.x, last.x);
      // a bola andou para a direita
      expect(g.lastTrail.last.x, greaterThan(g.lastTrail.first.x + 50));
    });

    test('trocar de fase apaga o rastro antigo', () {
      final g = GameController(Store(null))..togglePlay();
      _frames(g, 4);
      g.stop();
      g.chooseLevel(kBuiltin[1].id!);
      expect(g.lastTrail, isEmpty);
    });

    test('liga e desliga', () {
      final g = GameController(Store(null));
      final on = g.trailOn;
      g.toggleTrail();
      expect(g.trailOn, !on);
    });
  });
}
