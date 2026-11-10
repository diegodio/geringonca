// Mundo físico de uma tentativa, montado com Forge2D (Box2D v3).
//
// O mundo usa as mesmas coordenadas da bancada (y para baixo), com
// 100 px = 1 m. Massa, gravidade e força dos ímãs foram convertidas da
// versão em Matter.js para que as engenhocas se comportem de forma parecida.
// Este arquivo não depende do Flutter: roda em testes com `flutter test`.
import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

import 'model.dart';

const double kScale = 100; // px por metro
const double kDt = 1 / 60;

// Categorias de colisão, como na versão HTML.
const int catEnv = 1, catRod = 2, catWater = 4, catBall = 8, catScen = 16, catCirc = 32;
const int catParts = catRod | catCirc;

// Matter.js usa densidade por px²; aqui é por m² (fator 10⁴), o que mantém as mesmas massas.
const double _dPart = 20, _dBall = 15, _dSeesaw = 20, _dCrate = 8;
// Arrasto do ar do Matter.js (frictionAir = 0,01 por passo) em amortecimento por segundo.
const double _airDamping = 0.6;
// Rodas motorizadas: 0,2 rad por passo de 1/60 s no Matter.js.
const double _motorSpeed = 12;

Vector2 _v(double x, double y) => Vector2(x / kScale, y / kScale);

// Direção e rotação de um segmento só com divisão e raiz quadrada, que dão o
// mesmo resultado em toda plataforma (atan2, cos e sin podem diferir; ver detmath.dart).
(double, double) _dir(Pt a, Pt b) {
  final d = dist(a, b);
  return d == 0 ? (1.0, 0.0) : ((b.x - a.x) / d, (b.y - a.y) / d);
}

Rot _rot(Pt a, Pt b) {
  final (c, s) = _dir(a, b);
  return Rot(c, s);
}
Vector2 _vp(Pt p) => _v(p.x, p.y);

class SimLift {
  final Lift l;
  final double period;
  final Body body;

  /// Fundo móvel do poço (só elevadores com poço): fica [Lift.shaftGap] abaixo do elevador.
  final Body? floor;
  SimLift(this.l, this.period, this.body, [this.floor]);

  static const floorH = 600.0; // altura do fundo do poço, para nunca aparecer a borda de baixo
}

class SimDoor {
  final R d;
  double f = 0; // 0 fechada, 1 aberta
  final Body body;
  SimDoor(this.d, this.body);
}

class SimButton {
  final Pt bt;
  final Shape shape;
  bool pressed = false;
  SimButton(this.bt, this.shape);
}

class SimSeesaw {
  final Body body;
  final double len;
  SimSeesaw(this.body, this.len);
}

class SimCrate {
  final R c;
  final Body body;
  SimCrate(this.c, this.body);
}

class SimPart {
  final Part part;
  final Body body;
  final double halfLen; // barras
  final bool powered; // roda com motor ligado (centro preso a alguma coisa)
  SimPart(this.part, this.body, this.halfLen, {this.powered = false});
}

/// Pose de um corpo em pixels, para desenhar.
class Pose {
  final double x, y, angle;
  const Pose(this.x, this.y, this.angle);
}

class Sim {
  final Level lv;
  final List<Part> parts;
  final Pt ball0;
  late final World world;
  late final Body ball;
  final List<SimPart> bodies = [];
  final List<SimLift> lifts = [];
  final List<SimDoor> doors = [];
  final List<SimButton> buttons = [];
  final List<SimSeesaw> seesaws = [];
  final List<SimCrate> crates = [];
  final List<Body> _motors = [];
  final List<int> _motorDir = [];
  final List<(Body, String, bool)> _mags = []; // corpo, polo, fixo
  final Set<int> _skip = {};
  double t = 0;
  bool pressed = false;
  final int n, cost;

  Sim(this.lv, this.parts, this.ball0)
      : n = parts.length,
        cost = costOf(parts) {
    _build();
  }

  ShapeDef _envDef({double friction = .9}) => ShapeDef(
        material: SurfaceMaterial(friction: friction),
        filter: Filter(categoryBits: catEnv, maskBits: catParts | catBall | catScen),
      );

  // corpos do cenário nascem sem rotação (plataformas inclinadas são cápsulas)
  Body _static(double cx, double cy, {BodyType type = BodyType.static}) =>
      world.createBody(BodyDef(type: type, position: _v(cx, cy)));

  Body _box(double cx, double cy, double w, double h, {BodyType type = BodyType.static, ShapeDef? def}) {
    final b = _static(cx, cy, type: type);
    b.createShape(Polygon.box(w / 2 / kScale, h / 2 / kScale), def ?? _envDef());
    return b;
  }

  int _shapeIds = 0;
  final Map<Shape, int> _ids = {};
  int _tag(Shape s) => _ids[s] = ++_shapeIds;
  void _noCollide(Shape a, Shape b) {
    final ia = _ids[a]!, ib = _ids[b]!;
    _skip.add(ia < ib ? ia * 100000 + ib : ib * 100000 + ia);
  }

  void _build() {
    world = World(definition: WorldDef(gravity: Vector2(0, 10), enableSleep: false));

    // Paredes, chão e cenário fixo.
    _box(-20, kH / 2, 40, kH * 3);
    _box(kW + 20, kH / 2, 40, kH * 3);
    if (lv.ground) {
      // o chão tem um buraco embaixo de cada elevador com poço
      final holes = [
        for (final l in lv.lifts)
          if (l.hasShaft) (l.a.x - l.w / 2, l.a.x + l.w / 2),
      ]..sort((p, q) => p.$1.compareTo(q.$1));
      var x0 = -100.0;
      for (final (h0, h1) in [...holes, (kW + 100, kW + 100)]) {
        // fundo: o chão desce 1000 px, para fechar as paredes do poço
        if (h0 > x0) _box((x0 + h0) / 2, 1000, h0 - x0, 1000);
        if (h1 > x0) x0 = h1;
      }
    }
    for (final b in lv.blocks) {
      _box(b.x + b.w / 2, b.y + b.h / 2, b.w, b.h);
    }
    // Morros: cadeia fechada pela curva (o pé fecha o laço), sólida por fora e lisa
    // nas emendas, para a bola e as rodas rolarem sem tropeçar.
    for (final h in lv.hills) {
      _static(0, 0).createChain(ChainDef(
        points: [for (final p in hillPoints(h)) _vp(p)],
        isLoop: true,
        materials: [SurfaceMaterial(friction: .9)],
        filter: Filter(categoryBits: catEnv, maskBits: catParts | catBall | catScen),
      ));
    }
    for (final s in lv.plats) {
      final body = _static((s.a.x + s.b.x) / 2, (s.a.y + s.b.y) / 2);
      // cápsula = retângulo com pontas redondas, como a plataforma do HTML
      final half = dist(s.a, s.b) / 2 / kScale;
      final (ux, uy) = _dir(s.a, s.b);
      body.createShape(
        Capsule(
          center1: Vector2(-half * ux, -half * uy),
          center2: Vector2(half * ux, half * uy),
          radius: kPlatT / 2 / kScale,
        ),
        _envDef(),
      );
    }
    for (final m in lv.magnets) {
      final b = _static(m.x, m.y);
      b.createShape(Circle(radius: kFixR / kScale), _envDef());
      _mags.add((b, m.pole, true));
    }
    for (final l in lv.lifts) {
      final p = l.posAt(0);
      final floor = l.hasShaft
          ? _box(p.x, p.y + kLiftT / 2 + l.shaftGap + SimLift.floorH / 2, l.w, SimLift.floorH, type: BodyType.kinematic)
          : null;
      lifts.add(SimLift(l, l.period, _box(p.x, p.y, l.w, kLiftT, type: BodyType.kinematic), floor));
    }
    for (final d in lv.doors) {
      doors.add(SimDoor(d, _box(d.x + d.w / 2, d.y + d.h / 2, d.w, d.h, type: BodyType.kinematic)));
    }
    for (final bt in lv.buttons) {
      final body = _static(bt.x, bt.y - 12);
      final sh = body.createShape(
        Polygon.box(27 / kScale, 12 / kScale),
        ShapeDef(isSensor: true, enableSensorEvents: true, filter: Filter(categoryBits: catEnv, maskBits: catParts | catBall | catScen)),
      );
      buttons.add(SimButton(bt, sh));
    }
    for (final s in lv.seesaws) {
      final mid = Pt((s.a.x + s.b.x) / 2, (s.a.y + s.b.y) / 2), len = dist(s.a, s.b);
      final body = world.createBody(BodyDef(
        type: BodyType.dynamic,
        position: _vp(mid),
        rotation: _rot(s.a, s.b),
        linearDamping: _airDamping,
        angularDamping: _airDamping,
      ));
      body.createShape(
        Polygon.box(len / 2 / kScale, kSeeT / 2 / kScale),
        ShapeDef(
          density: _dSeesaw,
          material: SurfaceMaterial(friction: .9),
          filter: Filter(categoryBits: catScen, maskBits: catEnv | catParts | catBall | catScen),
        ),
      );
      final pivot = _static(mid.x, mid.y);
      world.createRevoluteJoint(RevoluteJointDef(bodyA: pivot, bodyB: body));
      seesaws.add(SimSeesaw(body, len));
    }

    // Caixas soltas: cenário que cai, pode ser empurrado e aperta botões.
    for (final c in lv.crates) {
      crates.add(SimCrate(
          c,
          _box(c.x + c.w / 2, c.y + c.h / 2, c.w, c.h,
              type: BodyType.dynamic,
              def: ShapeDef(
                density: _dCrate,
                material: SurfaceMaterial(friction: .5),
                enableSensorEvents: true,
                filter: Filter(categoryBits: catScen, maskBits: catEnv | catParts | catBall | catScen),
              ))
            ..linearDamping = _airDamping
            ..angularDamping = _airDamping));
    }

    // Bola. Numa fase com bola solta, nada se prende a ela.
    final ballKey = lv.looseBall ? '' : ball0.key;
    final attached = parts.any((q) => q.points.any((p) => p.key == ballKey));
    ball = world.createBody(BodyDef(
      type: BodyType.dynamic,
      position: _vp(ball0),
      linearDamping: _airDamping,
      angularDamping: _airDamping,
    ));
    final ballShape = ball.createShape(
      Circle(radius: kBallR / kScale),
      ShapeDef(
        density: _dBall,
        material: SurfaceMaterial(friction: .6),
        enableSensorEvents: true,
        filter: Filter(categoryBits: catBall, maskBits: catEnv | catParts | catScen),
      ),
    );
    _tag(ballShape);

    // Juntas: pontos com a mesma chave viram um pino entre os corpos.
    final joints = <String, (Pt, List<Body>)>{};
    void addJ(Pt pt, Body body) => joints.putIfAbsent(pt.key, () => (pt, <Body>[])).$2.add(body);
    if (attached) addJ(ball0, ball);

    // Formas de cada peça, com o lugar onde começam (segmento a-b e raio), para
    // decidir quem ignora quem: só pedaços que já começam encostados.
    final pieces = <(Body, Shape, Pt, Pt, double)>[];
    for (final q in parts) {
      late Body b;
      late Shape sh;
      double halfLen = 0;
      if (q.isRod) {
        final len = dist(q.a!, q.b!);
        halfLen = len / 2;
        b = world.createBody(BodyDef(
          type: BodyType.dynamic,
          position: _v((q.a!.x + q.b!.x) / 2, (q.a!.y + q.b!.y) / 2),
          rotation: _rot(q.a!, q.b!),
          linearDamping: _airDamping,
          angularDamping: _airDamping,
        ));
        // ponto da barra a uma distância [d] da ponta a (no mundo)
        Pt along(double d) => Pt(q.a!.x + (q.b!.x - q.a!.x) * d / len, q.a!.y + (q.b!.y - q.a!.y) * d / len);
        final solidDef = ShapeDef(
          density: _dPart,
          material: SurfaceMaterial(friction: .8),
          enableSensorEvents: true,
          filter: Filter(categoryBits: catRod, maskBits: catEnv | catBall | catScen | catCirc | catRod),
        );
        if (q.k == 'solid') {
          // Madeira em três pedaços (ponta, meio, ponta): na junta só as pontas se
          // ignoram; o resto da barra bate em tudo, inclusive em outra barra presa ali.
          // As pontas são cápsulas (redondas, como desenhadas); o meio é uma caixa reta,
          // que empurra para fora sempre do mesmo jeito o que começar sobreposto (a bola
          // em cima do chassi). A caixa entra um pouco nas pontas, para a emenda ficar
          // lisa e nada que role sobre a barra tropeçar nela.
          final e = math.min(12.0, len / 3);
          for (final (from, to) in [(0.0, e), (e, len - e), (len - e, len)]) {
            final mid = from > 0 && to < len;
            final piece = b.createShape(
              mid
                  ? Polygon.offsetBox((to - from) / 2 / kScale + 2 / kScale, 4 / kScale,
                      center: Vector2((from + to) / 2 - len / 2, 0) / kScale, rotation: 0)
                  : Capsule(center1: Vector2(from - len / 2, 0) / kScale, center2: Vector2(to - len / 2, 0) / kScale, radius: 4 / kScale),
              solidDef,
            );
            _tag(piece);
            pieces.add((b, piece, along(from), along(to), 4));
          }
          sh = pieces.last.$2;
        } else {
          // Borracha: o corpo atravessa tudo, mas as pontas batem em tudo, até no chão.
          sh = b.createShape(
            Polygon.box(len / 2 / kScale, 4 / kScale),
            ShapeDef(density: _dPart, filter: Filter(categoryBits: catWater, maskBits: 0)),
          );
          _tag(sh);
          for (final (x, end) in [(-len / 2, q.a!), (len / 2, q.b!)]) {
            final tip = b.createShape(Circle(radius: kTipR / kScale, center: Vector2(x, 0) / kScale), solidDef);
            _tag(tip);
            pieces.add((b, tip, end, end, kTipR));
          }
        }
        addJ(q.a!, b);
        addJ(q.b!, b);
      } else {
        b = world.createBody(BodyDef(
          type: BodyType.dynamic,
          position: _vp(q.c!),
          linearDamping: _airDamping,
          angularDamping: _airDamping,
          allowFastRotation: true,
        ));
        sh = b.createShape(
          Circle(radius: q.r / kScale),
          ShapeDef(
            density: _dPart,
            material: SurfaceMaterial(friction: 1),
            enableSensorEvents: true,
            filter: Filter(categoryBits: catCirc, maskBits: catEnv | catBall | catScen | catRod | catCirc),
          ),
        );
        if (q.isWheel) {
          final dir = q.k == 'cw' ? 1 : q.k == 'ccw' ? -1 : 0;
          // o motor só liga com o centro preso a alguma coisa; solta, a roda rola livre
          if (dir != 0 && hubConnected(q, parts, lv.looseBall ? null : ball0)) {
            _motors.add(b);
            _motorDir.add(dir);
          }
        } else {
          _mags.add((b, q.k, false));
        }
        addJ(q.c!, b);
      }
      if (!q.isRod) {
        _tag(sh);
        pieces.add((b, sh, q.c!, q.c!, q.r));
      }
      bodies.add(SimPart(q, b, halfLen, powered: motorOn(q, parts, lv.looseBall ? null : ball0)));
    }

    // Peças batem umas nas outras e na bola, menos os pedaços que já começam
    // encostados: as pontas presas na mesma junta, a barra que passa pelo eixo da
    // roda, barras desenhadas cruzadas. Senão a engenhoca se empurraria ao começar.
    // Fora isso, madeira não atravessa madeira, roda, ímã nem a bola.
    for (var i = 0; i < pieces.length; i++) {
      final (bi, si, ai, ci, ri) = pieces[i];
      for (var j = i + 1; j < pieces.length; j++) {
        final (bj, sj, aj, cj, rj) = pieces[j];
        if (identical(bi, bj)) continue;
        if (segSegDist(ai, ci, aj, cj) < ri + rj + 1.5) _noCollide(si, sj);
      }
    }
    // A bola não bate nas peças presas nela por uma junta.
    for (final (b, sh, _, _, _) in pieces) {
      final part = bodies.firstWhere((s) => identical(s.body, b)).part;
      if (part.points.any((p) => p.key == ballKey)) _noCollide(ballShape, sh);
    }
    if (_skip.isNotEmpty) {
      world.customFilterCallback = (a, b) {
        final ia = _ids[a], ib = _ids[b];
        if (ia == null || ib == null) return true;
        return !_skip.contains(ia < ib ? ia * 100000 + ib : ib * 100000 + ia);
      };
    }

    void pin(Body a, Body b, Pt pt) {
      final w = _vp(pt);
      // peças presas colidem entre si (o Box2D, por padrão, não deixaria); só os
      // pedaços que já começam encostados na junta se ignoram (filtro acima)
      world.createRevoluteJoint(
          RevoluteJointDef(bodyA: a, bodyB: b, localAnchorA: a.localPoint(w), localAnchorB: b.localPoint(w), collideConnected: true));
    }

    for (final (pt, list) in joints.values) {
      for (var i = 1; i < list.length; i++) {
        pin(list[0], list[i], pt);
      }
    }
    // Pontos na borda das rodas: barras presas ali giram junto, como manivela.
    for (final w in bodies) {
      if (!w.part.isWheel) continue;
      for (final pp in w.part.perim) {
        for (final o in bodies) {
          if (identical(o, w)) continue;
          for (final pt in o.part.points) {
            if (dist(pt, pp) < .75) pin(w.body, o.body, pt);
          }
        }
      }
    }
  }

  void step() {
    t += kDt;
    // Elevadores e portas são cinemáticos: a velocidade leva o corpo até a posição do próximo passo.
    for (final o in lifts) {
      final p = o.l.posAt(t);
      o.body.linearVelocity = (_v(p.x, p.y) - o.body.position)..scale(1 / kDt);
      final f = o.floor;
      if (f != null) {
        final goal = _v(p.x, p.y + kLiftT / 2 + o.l.shaftGap + SimLift.floorH / 2);
        f.linearVelocity = (goal - f.position)..scale(1 / kDt);
      }
    }
    for (final o in doors) {
      final target = buttons.isNotEmpty ? (pressed ? 1.0 : 0.0) : (t % 4 >= 2 ? 1.0 : 0.0);
      o.f += clampD(target - o.f, -kDt * 2, kDt * 2);
      final goal = _v(o.d.x + o.d.w / 2, o.d.y + o.d.h / 2 - o.d.h * o.f);
      o.body.linearVelocity = (goal - o.body.position)..scale(1 / kDt);
    }
    for (var i = 0; i < _motors.length; i++) {
      final m = _motors[i];
      final av = m.angularVelocity;
      m.angularVelocity = av + (_motorDir[i] * _motorSpeed - av) * .35;
    }
    for (var i = 0; i < _mags.length; i++) {
      for (var j = i + 1; j < _mags.length; j++) {
        final (a, pa, fa) = _mags[i];
        final (b, pb, fb) = _mags[j];
        if (fa && fb) continue;
        final d = (b.position - a.position)..scale(kScale);
        final len = d.length;
        if (len > kMagRange || len < 1) continue;
        // força do Matter.js × 10⁴ = newtons com as massas equivalentes
        final m = math.max(len, kMagMin);
        final f = kMagK / (m * m) * (pa == pb ? -1 : 1) * 1e4;
        final dir = d / len;
        if (!fa) a.applyForce(dir * f);
        if (!fb) b.applyForce(dir * -f);
      }
    }
    world.step(kDt, subStepCount: 8);
    if (buttons.isNotEmpty) {
      for (final ev in world.sensorEvents.begin) {
        for (final o in buttons) {
          if (ev.sensor == o.shape) {
            o.pressed = true;
            pressed = true;
          }
        }
      }
    }
  }

  Pose pose(Body b) {
    final p = b.position;
    return Pose(p.x * kScale, p.y * kScale, b.angle);
  }

  Pose get ballPose => pose(ball);

  /// Velocidade da bola em m/s.
  double get ballSpeed => ball.linearVelocity.length;

  bool won() {
    final p = ball.position, g = lv.goal;
    final x = p.x * kScale, y = p.y * kScale;
    return x - kBallR >= g.x - 1 && x + kBallR <= g.x + g.w + 1 && y - kBallR >= g.y - 1 && y + kBallR <= g.y + g.h + 1;
  }

  void dispose() {
    world.customFilterCallback = null;
    world.destroy();
  }
}
