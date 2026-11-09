import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart' show initializeForge2D;
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';

/// Um toque com arraste na bancada (sem zoom, coordenadas da tela = da bancada).
void _drag(GameController g, Pt from, Pt to) {
  g.pointerDown(1, from);
  g.pointerMove(1, Pt((from.x + to.x) / 2, (from.y + to.y) / 2));
  g.pointerMove(1, to);
  g.pointerUp(1);
}

void _tap(GameController g, Pt p) {
  g.pointerDown(1, p);
  g.pointerUp(1);
}

GameController _editor([String template = 'vazio']) => GameController(Store(null))..newLevel(template);

void main() {
  setUpAll(() async => initializeForge2D()); // no navegador o Box2D precisa ser carregado antes

  group('ajustar o cenário', () {
    test('arrastar um bloco o move de 20 em 20, e desfazer volta', () {
      final g = _editor()..setETool('block');
      _drag(g, Pt(500, 300), Pt(600, 380));
      final b = g.editLevel!.blocks.single;
      expect([b.x, b.y, b.w, b.h], [500, 300, 100, 80]);
      g.setETool('eselect');
      _drag(g, Pt(550, 340), Pt(593, 318)); // 43, -22 → 40, -20 na grade
      expect([b.x, b.y], [540, 280]);
      g.editUndo();
      final back = g.editLevel!.blocks.single;
      expect([back.x, back.y], [500, 300]);
    });

    test('só tocar seleciona sem criar passo de desfazer', () {
      final g = _editor()..setETool('block');
      _drag(g, Pt(500, 300), Pt(600, 380));
      g.setETool('eselect');
      _tap(g, Pt(550, 340));
      expect(g.esel, (kind: 'block', i: 0));
      g.editUndo(); // desfaz o desenho, não o toque
      expect(g.editLevel!.blocks, isEmpty);
    });

    test('a alça do canto redimensiona, com o canto oposto parado', () {
      final g = _editor()..setETool('block');
      _drag(g, Pt(500, 300), Pt(600, 380));
      g.setETool('eselect');
      _tap(g, Pt(550, 340));
      _drag(g, Pt(600, 380), Pt(700, 420)); // canto de baixo à direita
      final b = g.editLevel!.blocks.single;
      expect([b.x, b.y, b.w, b.h], [500, 300, 200, 120]);
      _drag(g, Pt(500, 300), Pt(800, 500)); // canto de cima passa do oposto: o bloco vira
      expect([b.x, b.y, b.w, b.h], [700, 420, 100, 80]);
    });

    test('as pontas de uma plataforma mudam pelas alças', () {
      final g = _editor()..setETool('plat');
      _drag(g, Pt(400, 400), Pt(600, 400));
      g.setETool('eselect');
      _tap(g, Pt(500, 400));
      _drag(g, Pt(600, 400), Pt(640, 360));
      final s = g.editLevel!.plats.single;
      expect([s.b.x, s.b.y], [640, 360]);
      g.eAdjust('level');
      expect(s.b.y, s.a.y);
    });

    test('propriedades do elevador, duplicar e apagar', () {
      final g = _editor()..setETool('lift');
      _drag(g, Pt(500, 492), Pt(500, 300));
      g.setETool('eselect');
      _tap(g, Pt(500, 400));
      expect(g.esel?.kind, 'lift');
      g
        ..eAdjust('width', 20)
        ..eAdjust('speed', 30)
        ..eAdjust('delay', .5);
      final l = g.editLevel!.lifts.single;
      expect([l.w, l.speed, l.delay], [180, kLiftSpeed + 30, .5]);
      // a velocidade vai e volta no JSON e muda o período
      final again = Level.fromJson(jsonDecode(jsonEncode(g.editLevel!.toJson()))).lifts.single;
      expect(again.speed, kLiftSpeed + 30);
      expect(again.period, lessThan(Lift(l.a, l.b, 160).period));
      g.eDuplicate();
      expect(g.editLevel!.lifts.length, 2);
      expect(g.esel, (kind: 'lift', i: 1));
      g.eDelete();
      expect(g.editLevel!.lifts.length, 1);
    });

    test('ímã troca de polo; área verde, meta e bola não se apagam', () {
      final g = _editor()..setETool('magN');
      _tap(g, Pt(600, 200));
      g.setETool('eselect');
      _tap(g, Pt(600, 200));
      g.eAdjust('pole');
      expect(g.editLevel!.magnets.single.pole, 'S');
      _tap(g, Pt(880, 420)); // meta
      expect(g.esel?.kind, 'goal');
      g.eDelete();
      expect(g.editLevel!.goal, isNotNull);
    });

    test('espelhar duas vezes volta ao original', () {
      final g = _editor('vale');
      final before = jsonEncode(g.editLevel!.toJson());
      g.mirrorLevel();
      expect(jsonEncode(g.editLevel!.toJson()), isNot(before));
      expect(g.editLevel!.goal.x, lessThan(500)); // a meta foi para a esquerda
      g.mirrorLevel();
      final a = g.editLevel!.toJson(), b = jsonDecode(before) as Map;
      expect(jsonEncode(a['blocks']), jsonEncode(b['blocks']));
      expect(jsonEncode(a['goal']), jsonEncode(b['goal']));
    });

    test('grade desligada encaixa de 5 em 5', () {
      final g = _editor()..toggleGrid();
      expect(g.gridStep, 5);
      g.setETool('block');
      _drag(g, Pt(503, 302), Pt(587, 377));
      final b = g.editLevel!.blocks.single;
      expect([b.x, b.y, b.w, b.h], [505, 300, 80, 75]);
    });

    test('todos os modelos abrem com a bola na área verde', () {
      for (final (id, _, _, _) in kTemplates) {
        final lv = GameController(Store(null)).let((g) => g..newLevel(id)).editLevel!;
        expect(lv.zone.contains(lv.ball), isTrue, reason: id);
        expect(lv.id, isNull);
      }
      expect(_editor('semchao').editLevel!.ground, isFalse);
    });
  });

  group('testar sem sair do editor', () {
    test('testar, vencer, verificar, sugerir metas e salvar', () {
      final g = _editor();
      final before = g.level;
      g.testEdit();
      expect(g.testing, isTrue);
      expect(g.mode, Mode.build);
      expect(g.level.id, '__teste');
      g.parts = sampleFor(g.level, g.ball0)!;
      g.togglePlay();
      for (var i = 0; i < 6 * 60 && !g.won; i++) {
        g.tick(1 / 60);
      }
      expect(g.won, isTrue);
      expect(g.editLevel!.verified, isTrue);
      expect(g.progress.triesOf('__teste'), 0); // teste não conta como tentativa
      g.backToEditor();
      expect(g.mode, Mode.edit);
      expect(identical(g.level, before), isTrue);
      expect(g.editLevel!.verified, isTrue);
      g.suggestTargets();
      final tg = g.editLevel!.targets, best = g.bestForTargets!;
      expect(tg.n, best.n);
      expect(tg.c, best.c);
      expect(tg.t, greaterThanOrEqualTo(best.t * 1.1 - 1e-9));
      // salvar leva a engenhoca do teste e a marca de verificada
      g.saveEdit();
      expect(g.level.verified, isTrue);
      expect(g.parts, isNotEmpty);
      expect(g.progress.custom.single.verified, isTrue);
    });

    test('mudar o cenário desfaz a verificação', () {
      final g = _editor()..editLevel!.verified = true;
      g.testBest = (t: 3, n: 6, c: 85);
      g.setETool('block');
      _drag(g, Pt(500, 300), Pt(600, 380));
      expect(g.editLevel!.verified, isFalse);
      expect(g.bestForTargets, isNull);
      // desfazer volta a verificação junto com o cenário
      g.editUndo();
      expect(g.editLevel!.verified, isTrue);
    });

    test('voltar do teste no meio da simulação para e guarda a engenhoca', () {
      final g = _editor()..testEdit();
      g.parts = sampleFor(g.level, g.ball0)!;
      g.togglePlay();
      g.tick(.2);
      g.backToEditor();
      expect(g.mode, Mode.edit);
      expect(g.sim, isNull);
      g.testEdit();
      expect(g.parts.length, sampleFor(g.level, g.ball0)!.length);
    });

    test('a marca de verificada vai no código mas não muda a assinatura', () {
      final lv = blankLevel()..verified = true;
      expect(lv.toJson()['verified'], isTrue);
      expect(Level.fromJson(lv.toJson()).verified, isTrue);
      expect(lv.signature, (blankLevel()..verified = false).signature);
    });

    test('vencer uma fase própria salva a verifica', () {
      final g = GameController(Store(null));
      final id = g.progress.saveLevel(blankLevel());
      g.selectLevel(id);
      g.parts = sampleFor(g.level, g.ball0)!;
      g.togglePlay();
      for (var i = 0; i < 6 * 60 && !g.won; i++) {
        g.tick(1 / 60);
      }
      expect(g.won, isTrue);
      expect(g.progress.find(id)!.verified, isTrue);
    });
  });
}

extension<T> on T {
  U let<U>(U Function(T) f) => f(this);
}
