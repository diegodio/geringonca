// Modelo de dados da Geringonça.
//
// As coordenadas ficam em "pixels de mundo" numa bancada de 1000 x 560,
// com y para baixo, iguais às da versão HTML. Assim os códigos de
// compartilhamento (OG1:...) continuam compatíveis entre as duas versões.
import 'dart:math' as math;

import 'detmath.dart';

const double kW = 1000, kH = 560;
const int kLimit = 150;
const double kBallR = 22, kMagR = 18, kFixR = 20, kPlatT = 16, kLiftT = 16, kSeeT = 14;
const double kMagK = 10, kMagRange = 300, kMagMin = 34, kLiftSpeed = 90;
const Map<String, int> kCost = {'solid': 10, 'water': 5, 'cw': 25, 'ccw': 25, 'free': 15, 'N': 30, 'S': 30};

double rnd(double v) => (v * 10).round() / 10;
double clampD(double v, double a, double b) => math.min(b, math.max(a, v));

/// Ponto mutável: arrastar uma junta move o mesmo objeto em todas as peças.
class Pt {
  double x, y;
  Pt(this.x, this.y);
  Pt copy() => Pt(x, y);
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
  static Pt? fromJson(dynamic o) {
    if (o is! Map) return null;
    final x = _num(o['x']), y = _num(o['y']);
    if (x == null || y == null) return null;
    return Pt(x, y);
  }

  String get key => '${x.toStringAsFixed(1)},${y.toStringAsFixed(1)}';
}

double? _num(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) {
    final d = double.tryParse(v);
    return d != null && d.isFinite ? d : null;
  }
  return null;
}

double numOr(dynamic v, double d) => _num(v) ?? d;
double? numOrNull(dynamic v) => v == null || v == '' ? null : _num(v);

double dist(Pt p, Pt q) => math.sqrt((p.x - q.x) * (p.x - q.x) + (p.y - q.y) * (p.y - q.y));

double segDist(Pt p, Pt a, Pt b) {
  final dx = b.x - a.x, dy = b.y - a.y;
  var l2 = dx * dx + dy * dy;
  if (l2 == 0) l2 = 1;
  final u = clampD(((p.x - a.x) * dx + (p.y - a.y) * dy) / l2, 0, 1);
  final ex = p.x - a.x - u * dx, ey = p.y - a.y - u * dy;
  return math.sqrt(ex * ex + ey * ey);
}

/// Distância entre dois segmentos (0 quando se cruzam).
double segSegDist(Pt a, Pt b, Pt c, Pt d) {
  double cross(Pt o, Pt p, Pt q) => (p.x - o.x) * (q.y - o.y) - (p.y - o.y) * (q.x - o.x);
  final d1 = cross(c, d, a), d2 = cross(c, d, b), d3 = cross(a, b, c), d4 = cross(a, b, d);
  if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) && ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) return 0;
  return [segDist(a, c, d), segDist(b, c, d), segDist(c, a, b), segDist(d, a, b)].reduce(math.min);
}

class R {
  double x, y, w, h;
  R(this.x, this.y, this.w, this.h);
  R copy() => R(x, y, w, h);
  bool contains(Pt p) => p.x >= x && p.x <= x + w && p.y >= y && p.y <= y + h;
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'w': w, 'h': h};
  static R? fromJson(dynamic o) {
    if (o is! Map) return null;
    return R(numOr(o['x'], 0), numOr(o['y'], 0), math.max(10, numOr(o['w'], 0)), math.max(10, numOr(o['h'], 0)));
  }

  static R fromPoints(Pt a, Pt b) =>
      R(math.min(a.x, b.x), math.min(a.y, b.y), (a.x - b.x).abs(), (a.y - b.y).abs());
}

Pt clampToRect(Pt p, R r) => Pt(clampD(p.x, r.x, r.x + r.w), clampD(p.y, r.y, r.y + r.h));

/// Peça da engenhoca. t: rod | wheel | mag. k: solid | water | cw | ccw | free | N | S.
class Part {
  final String t, k;
  Pt? a, b, c;
  double r;
  double rot;
  Part.rod(this.k, Pt this.a, Pt this.b)
      : t = 'rod',
        r = 0,
        rot = 0;
  Part.wheel(this.k, Pt this.c, this.r, [this.rot = 0]) : t = 'wheel';
  Part.mag(this.k, Pt this.c)
      : t = 'mag',
        r = kMagR,
        rot = 0;

  bool get isRod => t == 'rod';
  bool get isWheel => t == 'wheel';
  bool get isMag => t == 'mag';
  bool get isCircle => !isRod;
  List<Pt> get points => isRod ? [a!, b!] : [c!];
  int get cost => kCost[k] ?? 0;

  /// Quatro pontos de conexão na borda de cada roda, espaçados de π/2.
  List<Pt> get perim => List.generate(4, (i) {
        final ang = rot + i * math.pi / 2;
        return Pt(c!.x + r * dcos(ang), c!.y + r * dsin(ang));
      });

  Part copy() => isRod
      ? Part.rod(k, a!.copy(), b!.copy())
      : isWheel
          ? Part.wheel(k, c!.copy(), r, rot)
          : Part.mag(k, c!.copy());

  Map<String, dynamic> toJson() => isRod
      ? {'t': t, 'k': k, 'a': a!.toJson(), 'b': b!.toJson()}
      : isWheel
          ? {'t': t, 'k': k, 'c': c!.toJson(), 'r': r, if (rot != 0) 'rot': rot}
          : {'t': t, 'k': k, 'c': c!.toJson(), 'r': r};

  /// Lê uma peça; [ok] valida cada ponto (por exemplo, perto da área verde).
  static Part? fromJson(dynamic q, {bool Function(Pt)? ok}) {
    if (q is! Map) return null;
    Pt? pt(dynamic o) {
      final p = Pt.fromJson(o);
      if (p == null) return null;
      p.x = rnd(p.x);
      p.y = rnd(p.y);
      return ok == null || ok(p) ? p : null;
    }

    if (q['t'] == 'rod') {
      final a = pt(q['a']), b = pt(q['b']);
      return a != null && b != null ? Part.rod(q['k'] == 'water' ? 'water' : 'solid', a, b) : null;
    }
    final c = pt(q['c']);
    if (c == null) return null;
    if (q['t'] == 'wheel') {
      final k = const ['cw', 'ccw', 'free'].contains(q['k']) ? q['k'] as String : 'free';
      final r0 = _num(q['r']);
      return Part.wheel(k, c, clampD(r0 == null || r0 == 0 ? 28 : r0.roundToDouble(), 16, 60), numOr(q['rot'], 0));
    }
    if (q['t'] == 'mag') return Part.mag(q['k'] == 'S' ? 'S' : 'N', c);
    return null;
  }
}

int costOf(List<Part> list) => list.fold(0, (s, q) => s + q.cost);

/// As ferramentas que criam peças, na ordem da barra de peças.
const kPieceTools = ['rod', 'water', 'cw', 'ccw', 'free', 'magN', 'magS'];

/// Nome de cada peça para mensagens.
const kPieceNames = {
  'rod': 'barra de madeira',
  'water': 'barra de borracha',
  'cw': 'roda horária',
  'ccw': 'roda anti-horária',
  'free': 'roda sem motor',
  'magN': 'ímã norte',
  'magS': 'ímã sul',
};

/// A ferramenta que cria a peça [q].
String toolOf(Part q) => q.isRod ? (q.k == 'solid' ? 'rod' : 'water') : q.isWheel ? q.k : 'mag${q.k}';

/// O centro da roda [w] está preso a alguma coisa: a ponta de uma barra, o
/// centro de outra peça ou a bola. [ball] é null quando a bola não conta
/// (fase com bola solta).
bool hubConnected(Part w, List<Part> parts, Pt? ball) {
  final k = w.c!.key;
  return ball?.key == k || parts.any((o) => !identical(o, w) && o.points.any((p) => p.key == k));
}

/// Roda com motor que vai girar: horária ou anti-horária, com o centro preso.
/// Solta, ela rola como uma roda livre.
bool motorOn(Part q, List<Part> parts, Pt? ball) => q.isWheel && q.k != 'free' && hubConnected(q, parts, ball);

class Seg {
  Pt a, b;
  Seg(this.a, this.b);
  Seg copy() => Seg(a.copy(), b.copy());
  Map<String, dynamic> toJson() => {'a': a.toJson(), 'b': b.toJson()};
  static Seg? fromJson(dynamic o) {
    if (o is! Map) return null;
    final a = Pt.fromJson(o['a']), b = Pt.fromJson(o['b']);
    return a != null && b != null ? Seg(a, b) : null;
  }
}

class Lift extends Seg {
  double w;

  /// Atraso em segundos: elevadores com atrasos diferentes andam fora de sincronia.
  double delay;
  Lift(super.a, super.b, this.w, [this.delay = 0]);
  @override
  Lift copy() => Lift(a.copy(), b.copy(), w, delay);
  @override
  Map<String, dynamic> toJson() => {...super.toJson(), 'w': w, if (delay != 0) 'delay': delay};
  double get period => math.max(3, 2 * dist(a, b) / kLiftSpeed);

  /// Centro do elevador no instante [t]: vai de [a] a [b] e volta, suave nas pontas.
  Pt posAt(double t) {
    final s = (1 - dcos(2 * math.pi * (t + delay) / period)) / 2;
    return Pt(a.x + (b.x - a.x) * s, a.y + (b.y - a.y) * s);
  }

  /// Elevador vertical cuja posição mais baixa fica no nível do chão (y = 500).
  /// Embaixo dele o chão vira um poço: em vez de esmagar o que está embaixo e
  /// jogar por cima, o elevador empurra para dentro do poço, e o fundo do poço
  /// sobe junto quando o elevador sobe, devolvendo tudo ao nível do chão.
  bool get hasShaft => (a.x - b.x).abs() < .5 && (math.max(a.y, b.y) - kLiftT / 2 - 500).abs() < 2;

  /// Folga entre a parte de baixo do elevador e o fundo do poço; é a altura
  /// livre que havia embaixo do elevador no ponto mais alto.
  double get shaftGap => 500 - (math.min(a.y, b.y) + kLiftT / 2);
}

class FixedMag {
  double x, y;
  String pole;
  FixedMag(this.x, this.y, this.pole);
  Pt get p => Pt(x, y);
  FixedMag copy() => FixedMag(x, y, pole);
  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'pole': pole};
}

class Targets {
  double? t;
  int? n, c;
  Targets({this.t, this.n, this.c});
  Targets copy() => Targets(t: t, n: n, c: c);
  Map<String, dynamic> toJson() => {'t': t, 'n': n, 'c': c};
  static Targets fromJson(dynamic o) {
    if (o is! Map) return Targets();
    return Targets(t: numOrNull(o['t']), n: numOrNull(o['n'])?.round(), c: numOrNull(o['c'])?.round());
  }
}

class Level {
  String? id;
  String name, tip;
  bool ground;
  R zone, goal;
  Pt ball;
  List<R> blocks, doors;
  List<Seg> plats, seesaws;
  List<Lift> lifts;
  List<FixedMag> magnets;
  List<Pt> buttons;
  Targets targets;

  /// Peças que a fase deixa usar (ver [kPieceTools]); null libera todas.
  List<String>? allowed;

  /// Bola solta: nenhuma peça pode ser presa à bola, e ela não conta como eixo de roda.
  bool looseBall;

  /// Custo máximo da engenhoca; null = sem limite.
  int? budget;

  Level({
    this.id,
    required this.name,
    this.tip = '',
    this.ground = true,
    required this.zone,
    required this.goal,
    required this.ball,
    List<R>? blocks,
    List<R>? doors,
    List<Seg>? plats,
    List<Seg>? seesaws,
    List<Lift>? lifts,
    List<FixedMag>? magnets,
    List<Pt>? buttons,
    Targets? targets,
    this.allowed,
    this.looseBall = false,
    this.budget,
  })  : blocks = blocks ?? [],
        doors = doors ?? [],
        plats = plats ?? [],
        seesaws = seesaws ?? [],
        lifts = lifts ?? [],
        magnets = magnets ?? [],
        buttons = buttons ?? [],
        targets = targets ?? Targets();

  Level copy() => Level.fromJson(toJson())..id = id;

  Map<String, dynamic> toJson({bool withId = true}) => {
        if (withId) 'id': id,
        'name': name,
        'tip': tip,
        'ground': ground,
        'zone': zone.toJson(),
        'goal': goal.toJson(),
        'ball': ball.toJson(),
        'blocks': blocks.map((e) => e.toJson()).toList(),
        'plats': plats.map((e) => e.toJson()).toList(),
        'magnets': magnets.map((e) => e.toJson()).toList(),
        'lifts': lifts.map((e) => e.toJson()).toList(),
        'seesaws': seesaws.map((e) => e.toJson()).toList(),
        'doors': doors.map((e) => e.toJson()).toList(),
        'buttons': buttons.map((e) => e.toJson()).toList(),
        'targets': targets.toJson(),
        if (allowed != null) 'allowed': allowed,
        if (looseBall) 'looseBall': true,
        if (budget != null) 'budget': budget,
      };

  /// Lê uma fase com limites de tamanho, como a versão HTML (também serve para códigos importados).
  static Level fromJson(dynamic o) {
    final m = o is Map ? o : const {};
    List<T> arr<T>(dynamic a, int max, T? Function(dynamic) f) =>
        (a is List ? a : const []).take(max).map(f).whereType<T>().toList();
    return Level(
      id: m['id'] is String ? m['id'] as String : null,
      name: (m['name'] ?? 'Fase importada').toString().substring(0, math.min(40, (m['name'] ?? 'Fase importada').toString().length)),
      tip: (m['tip'] ?? '').toString().substring(0, math.min(160, (m['tip'] ?? '').toString().length)),
      ground: m['ground'] != false,
      zone: R.fromJson(m['zone']) ?? zone0(),
      goal: R.fromJson(m['goal']) ?? R(790, 360, 180, 140),
      ball: Pt.fromJson(m['ball']) ?? Pt(170, 440),
      blocks: arr(m['blocks'], 80, R.fromJson),
      plats: arr(m['plats'], 80, Seg.fromJson),
      seesaws: arr(m['seesaws'], 20, Seg.fromJson),
      lifts: arr(m['lifts'], 20, (l) {
        final s = Seg.fromJson(l);
        if (s == null) return null;
        final w = numOr((l as Map)['w'], 0);
        return Lift(s.a, s.b, clampD(w == 0 ? 160 : w, 40, 400), clampD(numOr(l['delay'], 0), 0, 60));
      }),
      doors: arr(m['doors'], 20, R.fromJson),
      buttons: arr(m['buttons'], 20, Pt.fromJson),
      magnets: arr(m['magnets'], 40, (g) {
        if (g is! Map) return null;
        return FixedMag(numOr(g['x'], 0), numOr(g['y'], 0), g['pole'] == 'S' ? 'S' : 'N');
      }),
      targets: Targets.fromJson(m['targets']),
      allowed: m['allowed'] is List ? kPieceTools.where((t) => (m['allowed'] as List).contains(t)).toList() : null,
      looseBall: m['looseBall'] == true,
      budget: numOrNull(m['budget'])?.round(),
    );
  }

  /// Assinatura para reconhecer uma fase importada que já existe.
  String get signature => toJson(withId: false).toString();
}

R zone0() => R(40, 270, 310, 220);
