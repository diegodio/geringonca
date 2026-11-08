// A bancada como jogo Flame.
//
// O Flame cuida do laço do jogo, da câmera (zoom e arraste), da árvore de
// componentes que desenha a cena e dos eventos de toque, arraste e rolagem.
// As regras continuam no GameController e a física no Sim (Forge2D), que
// é recriado a cada tentativa para que a mesma engenhoca sempre rode igual.
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:forge2d/forge2d.dart' show Body;

import '../core/i18n.dart';
import '../core/model.dart';
import '../core/sim.dart';
import 'controller.dart';
import 'ink.dart';
import 'palette.dart';

class OficinaGame extends FlameGame {
  final GameController g;
  final Ink ink;
  OficinaGame(this.g, {required String mono, required String display})
      : ink = Ink(g, Palette.light, mono: mono, display: display),
        super(camera: CameraComponent.withFixedResolution(width: kW, height: kH));

  set palette(Palette p) {
    if (identical(p, ink.c)) return;
    ink.c = p;
    wake();
  }

  // ---------- descanso: parada, a bancada não redesenha ----------
  // Construindo e sem tocar na tela, nada se mexe: depois de alguns quadros o laço
  // do jogo para (poupa bateria e deixa o celular frio). Qualquer mudança no
  // controlador ou toque na bancada acorda.
  int _still = 0;
  bool _asleep = false;

  void wake() {
    _still = 0;
    if (_asleep) {
      _asleep = false;
      resumeEngine();
    }
  }

  void _maybeSleep() {
    if (g.mode == Mode.run || g.action != null) {
      _still = 0;
    } else if (++_still > 20 && !_asleep) {
      _asleep = true;
      pauseEngine();
    }
  }

  Sim? _shownSim;
  final List<Component> _runParts = [];

  @override
  Color backgroundColor() => ink.c.paper;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([
      // quadriculado, zonas e cenário parado: desenhados uma vez e reaproveitados
      _CachedLayer(this, 0, () => 'grade|${g.cam.z}', (i) => i.grid()),
      _CachedLayer(this, 1, () => g.mode == Mode.edit ? null : 'zonas|${_levelKey()}|${g.mode == Mode.run && g.won}',
          (i) => i.zones(g.cur)),
      // rodando, só dá para guardar se nada do cenário se mexe (elevador, gangorra, porta, botão)
      _CachedLayer(this, 2, () => g.mode == Mode.edit || (g.mode == Mode.run && _movingScenery) ? null : 'cenario|${_levelKey()}',
          (i) => i.scenery(g.cur, g.mode == Mode.run ? g.sim : null)),
      // rastro da tentativa atual, ou o da última tentativa (mais claro) enquanto se constrói
      _Layer(this, 4, (i) {
        if (!g.trailOn || g.mode == Mode.edit) return;
        g.mode == Mode.run ? i.trail(g.trail, .8) : i.trail(g.lastTrail, .35);
      }),
      _BuildLayer(this),
    ]);
    camera.viewport.addAll([_InputLayer(this), _Hud(this)]);
    g.addListener(wake);
  }

  /// Identifica a fase na tela (muda ao trocar de fase ou depois de editá-la).
  String _levelKey() => '${identityHashCode(g.cur)}|${g.editRev}';

  bool get _movingScenery {
    final lv = g.cur;
    return lv.lifts.isNotEmpty || lv.seesaws.isNotEmpty || lv.doors.isNotEmpty || lv.buttons.isNotEmpty;
  }

  @override
  void onRemove() {
    g.removeListener(wake);
    super.onRemove();
  }

  @override
  void update(double dt) {
    g.viewWidth = size.x; // raio de encaixe em pixels de tela
    g.tick(dt); // passos fixos de 1/60 s
    _syncRun();
    final vf = camera.viewfinder;
    vf.position = Vector2(g.cam.x, g.cam.y);
    vf.zoom = g.cam.z;
    super.update(dt);
    _maybeSleep();
  }

  /// Cria um componente por corpo quando uma tentativa começa e os remove quando ela termina.
  void _syncRun() {
    final s = g.mode == Mode.run ? g.sim : null;
    if (identical(s, _shownSim)) return;
    world.removeAll(_runParts);
    _runParts.clear();
    _shownSim = s;
    if (s == null) return;
    for (final b in s.bodies) {
      _runParts.add(switch (b.part.t) {
        'rod' => _RodBody(this, s, b),
        'wheel' => _WheelBody(this, s, b),
        _ => _MagnetBody(this, s, b),
      });
    }
    _runParts
      ..add(_BallBody(this, s))
      ..add(_Layer(this, 14, (i) => _rodEnds(i, s)));
    world.addAll(_runParts);
  }

  // as juntas nas pontas das barras ficam por cima das rodas
  void _rodEnds(Ink i, Sim s) {
    for (final b in s.bodies) {
      if (!b.part.isRod) continue;
      final p = s.pose(b.body), cx = math.cos(p.angle) * b.halfLen, sy = math.sin(p.angle) * b.halfLen;
      i.joint(p.x - cx, p.y - sy);
      i.joint(p.x + cx, p.y + sy);
    }
  }
}

/// Camada que só desenha, com uma função do pincel.
class _Layer extends Component {
  final OficinaGame game;
  final void Function(Ink) draw;
  _Layer(this.game, int priority, this.draw) : super(priority: priority);
  @override
  void render(Canvas canvas) => draw(game.ink.on(canvas));
}

/// Camada que não muda a cada quadro: o desenho é gravado uma vez e repetido
/// enquanto a chave for a mesma (a paleta entra na chave). Chave nula: desenha
/// direto (no editor, ou com peças do cenário se mexendo).
class _CachedLayer extends Component {
  final OficinaGame game;
  final String? Function() cacheKey;
  final void Function(Ink) draw;
  _CachedLayer(this.game, int priority, this.cacheKey, this.draw) : super(priority: priority);

  Picture? _pic;
  String? _picKey;

  @override
  void render(Canvas canvas) {
    final k0 = cacheKey();
    if (k0 == null) return draw(game.ink.on(canvas));
    final k = '$k0|${identityHashCode(game.ink.c)}|${lang.name}';
    if (k != _picKey || _pic == null) {
      _pic?.dispose();
      final rec = PictureRecorder();
      draw(game.ink.on(Canvas(rec)));
      _pic = rec.endRecording();
      _picKey = k;
    }
    canvas.drawPicture(_pic!);
  }

  @override
  void onRemove() {
    _pic?.dispose();
    _pic = null;
    super.onRemove();
  }
}

/// Engenhoca em construção, rascunhos e a bola parada (fora da simulação).
class _BuildLayer extends Component {
  final OficinaGame game;
  _BuildLayer(this.game) : super(priority: 5);

  @override
  void render(Canvas canvas) {
    final g = game.g, i = game.ink.on(canvas);
    if (g.mode == Mode.run) return;
    final bp = g.mode == Mode.edit ? g.cur.ball : g.ball0;
    i.ball(bp.x, bp.y, -math.pi / 2);
    final a = g.action;
    if (g.mode == Mode.edit) {
      if (a != null && a.type == 'edraft') i.editDraft(a);
      return;
    }
    i.parts(g.parts);
    if (a != null && a.type == 'draft') {
      final d = a.d!;
      if (d.isRod) {
        i.rod(d.a!.x, d.a!.y, d.b!.x, d.b!.y, d.k, .6);
        i.text('${fmt(dist(d.a!, d.b!) / 100)} m', d.b!.x + 12, d.b!.y - 12, i.c.ink);
      } else if (d.isWheel) {
        i.wheel(d.c!.x, d.c!.y, d.r, d.k, 0, .6);
      } else {
        i.magnet(d.c!.x, d.c!.y, d.r, d.k, false, .6);
      }
    }
    if (a != null && a.type == 'band') {
      final r = R.fromPoints(a.a!, a.b!);
      i.dashRect(Rect.fromLTWH(r.x, r.y, r.w, r.h), i.stroke(i.c.accent, 1.5 / g.cam.z), 5, 4);
    }
    final sh = g.snapHint;
    if (sh != null) canvas.drawCircle(Offset(sh.x, sh.y), 12, i.stroke(i.c.accent, 2.5));
  }
}

/// Peça da simulação: segue a posição e o ângulo do seu corpo no Box2D.
abstract class _SimBody extends PositionComponent {
  final OficinaGame game;
  final Sim sim;
  _SimBody(this.game, this.sim, int priority) : super(priority: priority);
  Body get body;

  @override
  void update(double dt) {
    final p = sim.pose(body);
    position.setValues(p.x, p.y);
    angle = p.angle;
  }

  @override
  void onMount() {
    super.onMount();
    update(0);
  }
}

class _RodBody extends _SimBody {
  final SimPart b;
  _RodBody(OficinaGame g, Sim s, this.b) : super(g, s, 10);
  @override
  Body get body => b.body;
  @override
  void render(Canvas canvas) => game.ink.on(canvas).rod(-b.halfLen, 0, b.halfLen, 0, b.part.k);
}

class _WheelBody extends _SimBody {
  final SimPart b;
  _WheelBody(OficinaGame g, Sim s, this.b) : super(g, s, 12);
  @override
  Body get body => b.body;
  // os raios giram com a roda; a seta fica parada para ser lida
  @override
  void render(Canvas canvas) {
    final i = game.ink.on(canvas)..wheel(0, 0, b.part.r, b.part.k, b.part.rot, 1, false);
    canvas.save();
    canvas.rotate(-angle);
    i.wheelArrow(0, 0, b.part.r, b.part.k, b.powered ? 1 : .3);
    canvas.restore();
  }
}

class _MagnetBody extends _SimBody {
  final SimPart b;
  _MagnetBody(OficinaGame g, Sim s, this.b) : super(g, s, 13);
  @override
  Body get body => b.body;
  // a letra do polo fica sempre de pé: desfaz a rotação antes de desenhar
  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.rotate(-angle);
    game.ink.on(canvas).magnet(0, 0, b.part.r, b.part.k, false);
    canvas.restore();
  }
}

class _BallBody extends _SimBody {
  _BallBody(OficinaGame g, Sim s) : super(g, s, 11);
  @override
  Body get body => sim.ball;
  @override
  void render(Canvas canvas) => game.ink.on(canvas).ball(0, 0, -math.pi / 2);
}

/// Painel fixo na tela: tempo, velocidade da bola e banner de vitória.
class _Hud extends Component {
  final OficinaGame game;
  _Hud(this.game) : super(priority: 20);

  @override
  void render(Canvas canvas) {
    final g = game.g, s = g.sim;
    if (g.mode != Mode.run || s == null) return;
    final i = game.ink.on(canvas);
    final hs = clampD((14 * kW / math.max(1, game.size.x)).roundToDouble(), 14, 30);
    i.text('t = ${fmt(s.t)} s', 16, 12 + hs * 1.2, i.c.ink, size: hs);
    i.text(tr('v(bola) = {v} m/s', {'v': fmt(s.ballSpeed)}), 16, 12 + hs * 2.5, i.c.ink, size: hs);
    var line = 3.8;
    if (g.replaying) {
      i.text('REPLAY', 16, 12 + hs * line, i.c.accent, size: hs);
      line += 1.3;
    }
    if (g.paused || g.speed != 1) {
      final sp = g.speed == 1 ? '' : g.speed == .5 ? '½×' : '¼×';
      i.text([if (g.paused) tr('PAUSADO'), if (sp.isNotEmpty) tr('CÂMERA LENTA {s}', {'s': sp})].join(' · '), 16, 12 + hs * line, i.c.goal, size: hs);
    }
  }
}

/// Recebe os toques na bancada. O toque chega na hora (TapCallbacks); se o
/// dedo andar, o Flame cancela o toque e segue como arraste (DragCallbacks).
/// O arraste tem um id próprio do Flame, então ele é ligado ao toque que
/// começou no mesmo ponto. As posições já vêm em coordenadas da bancada sem
/// zoom (0..1000, 0..560).
class _InputLayer extends PositionComponent with TapCallbacks, DragCallbacks, ScrollCallbacks {
  final OficinaGame game;
  _InputLayer(this.game) : super(size: Vector2(kW, kH));
  GameController get g => game.g;

  final Map<int, Vector2> _taps = {}; // toques em andamento: id -> onde começaram
  final Map<int, int> _dragToTap = {}; // id do arraste -> id do toque
  final Map<int, int> _orphans = {}; // toque cancelado ainda sem arraste: id -> quadros de espera

  static Pt _pt(Vector2 v) => Pt(v.x, v.y);

  @override
  void onTapDown(TapDownEvent e) {
    game.wake();
    _taps[e.pointerId] = e.localPosition.clone();
    g.pointerDown(e.pointerId, _pt(e.localPosition));
  }

  @override
  void onTapUp(TapUpEvent e) {
    _taps.remove(e.pointerId);
    g.pointerUp(e.pointerId);
  }

  @override
  void onTapCancel(TapCancelEvent e) {
    if (!_dragToTap.containsValue(e.pointerId) && _taps.containsKey(e.pointerId)) _orphans[e.pointerId] = 3;
  }

  @override
  void onDragStart(DragStartEvent e) {
    game.wake();
    super.onDragStart(e);
    // o toque livre mais próximo do início do arraste
    int? best;
    var bd = double.infinity;
    for (final MapEntry(key: id, value: at) in _taps.entries) {
      if (_dragToTap.containsValue(id)) continue;
      final d = at.distanceTo(e.localPosition);
      if (d < bd) {
        bd = d;
        best = id;
      }
    }
    if (best == null) {
      best = -1 - e.pointerId; // arraste sem toque registrado
      g.pointerDown(best, _pt(e.localPosition));
    }
    _orphans.remove(best);
    _dragToTap[e.pointerId] = best;
  }

  @override
  void onDragUpdate(DragUpdateEvent e) {
    game.wake();
    final id = _dragToTap[e.pointerId];
    if (id != null) g.pointerMove(id, _pt(e.localEndPosition));
  }

  @override
  void onDragEnd(DragEndEvent e) {
    super.onDragEnd(e);
    final id = _dragToTap.remove(e.pointerId);
    if (id == null) return;
    _taps.remove(id);
    g.pointerUp(id);
  }

  @override
  void onScroll(ScrollEvent e) {
    game.wake();
    final k = HardwareKeyboard.instance;
    if (k.isControlPressed || k.isMetaPressed) g.zoomAt(_pt(e.localPosition), math.exp(-e.scrollDelta.y * .01));
  }

  @override
  void update(double dt) {
    // toque cancelado que não virou arraste (outro gesto ganhou): solta o ponteiro
    if (_orphans.isEmpty) return;
    for (final id in _orphans.keys.toList()) {
      final n = _orphans[id]! - 1;
      if (n > 0) {
        _orphans[id] = n;
      } else {
        _orphans.remove(id);
        if (!_dragToTap.containsValue(id)) {
          _taps.remove(id);
          g.pointerUp(id);
        }
      }
    }
  }
}
