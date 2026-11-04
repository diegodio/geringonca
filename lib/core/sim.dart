// Mundo físico de uma tentativa, montado com Forge2D (Box2D v3).
//
// O mundo usa as mesmas coordenadas da bancada (y para baixo), com
// 100 px = 1 m. Massa, gravidade e força dos ímãs foram convertidas da
// versão em Matter.js para que as engenhocas se comportem de forma parecida.
// Este arquivo não depende do Flutter: roda em testes com `flutter test`.
import 'dart:math' as math;

import 'package:forge2d/forge2d.dart';

import 'detmath.dart';
import 'model.dart';

const double kScale = 100; // px por metro
const double kDt = 1 / 60;

// Categorias de colisão, como na versão HTML.
const int catEnv = 1, catRod = 2, catWater = 4, catBall = 8, catScen = 16, catCirc = 32;
const int catParts = catRod | catCirc;

// Matter.js usa densidade por px²; aqui é por m² (fator 10⁴), o que mantém as mesmas massas.
const double _dPart = 20, _dBall = 15, _dSeesaw = 20;
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
  SimLift(this.l, this.period, this.body);
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

class SimPart {
  final Part part;
  final Body body;
  final double halfLen; // barras
  SimPart(this.part, this.body, this.halfLen);
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
    if (lv.ground) _box(kW / 2, 540, kW + 200, 80);
    for (final b in lv.blocks) {
      _box(b.x + b.w / 2, b.y + b.h / 2, b.w, b.h);
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
      lifts.add(SimLift(l, l.period, _box(l.a.x, l.a.y, l.w, kLiftT, type: BodyType.kinematic)));
    }
    for (final d in lv.doors) {
      doors.add(SimDoor(d, _box(d.x + d.w / 2, d.y + d.h / 2, d.w, d.h, type: BodyType.kinematic)));
    }
    for (final bt in lv.buttons) {
      final body = _static(bt.x, bt.y - 12);
      final sh = body.createShape(
        Polygon.box(27 / kScale, 12 / kScale),
        ShapeDef(isSensor: true, enableSensorEvents: true, filter: Filter(categoryBits: catEnv, maskBits: catParts | catBall)),
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

    // Bola.
    final ballKey = ball0.key;
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

    final shapeOf = <Body, Shape>{};
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
        sh = b.createShape(
          Polygon.box(len / 2 / kScale, 4 / kScale),
          ShapeDef(
            density: _dPart,
            material: SurfaceMaterial(friction: .8),
            enableSensorEvents: q.k == 'solid',
            filter: q.k == 'solid'
                ? Filter(categoryBits: catRod, maskBits: catEnv | catBall | catScen | catCirc | catRod)
                : Filter(categoryBits: catWater, maskBits: 0),
          ),
        );
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
          if (dir != 0) {
            _motors.add(b);
            _motorDir.add(dir);
          }
        } else {
          _mags.add((b, q.k, false));
        }
        addJ(q.c!, b);
      }
      _tag(sh);
      shapeOf[b] = sh;
      bodies.add(SimPart(q, b, halfLen));
    }

    // Rodas e ímãs passam por cima de barras sólidas, menos as que já começam encostadas.
    final rods = bodies.where((s) => s.part.isRod && s.part.k == 'solid').toList();
    final circs = bodies.where((s) => !s.part.isRod).toList();
    for (final c in circs) {
      for (final r in rods) {
        if (segDist(c.part.c!, r.part.a!, r.part.b!) < c.part.r + 8) _noCollide(shapeOf[c.body]!, shapeOf[r.body]!);
      }
    }
    // Madeira bate em madeira, menos nas barras que já começam encostadas
    // (presas na mesma junta ou cruzadas em X); senão a engenhoca se empurraria ao começar.
    for (var i = 0; i < rods.length; i++) {
      for (var j = i + 1; j < rods.length; j++) {
        final a = rods[i].part, b = rods[j].part;
        if (segSegDist(a.a!, a.b!, b.a!, b.b!) < 8) _noCollide(shapeOf[rods[i].body]!, shapeOf[rods[j].body]!);
      }
    }
    // Rodas e ímãs trombam entre si, menos os que já começam encostados ou sobrepostos.
    for (var i = 0; i < circs.length; i++) {
      for (var j = i + 1; j < circs.length; j++) {
        final a = circs[i].part, b = circs[j].part;
        if (dist(a.c!, b.c!) < a.r + b.r + 2) _noCollide(shapeOf[circs[i].body]!, shapeOf[circs[j].body]!);
      }
    }
    // A bola não bate nas peças presas nela por uma junta.
    for (final s in [...rods, ...circs]) {
      if (s.part.points.any((p) => p.key == ballKey)) _noCollide(ballShape, shapeOf[s.body]!);
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
      world.createRevoluteJoint(RevoluteJointDef(bodyA: a, bodyB: b, localAnchorA: a.localPoint(w), localAnchorB: b.localPoint(w)));
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
      final s = (1 - dcos(2 * math.pi * t / o.period)) / 2;
      final target = _v(o.l.a.x + (o.l.b.x - o.l.a.x) * s, o.l.a.y + (o.l.b.y - o.l.a.y) * s);
      o.body.linearVelocity = (target - o.body.position)..scale(1 / kDt);
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
