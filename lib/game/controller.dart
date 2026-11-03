// Estado e regras da oficina: construção, seleção, câmera, simulação,
// medalhas, compartilhamento e editor de fases. A interface só lê daqui
// e repassa toques e botões.
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/levels.dart';
import '../core/model.dart';
import '../core/share.dart';
import '../core/sim.dart';
import 'storage.dart';

enum Mode { build, run, edit }

const kTools = ['rod', 'water', 'cw', 'ccw', 'free', 'magN', 'magS', 'move', 'select', 'del'];
const kETools = ['block', 'plat', 'lift', 'seesaw', 'door', 'button', 'zone', 'goal', 'ball', 'magN', 'magS', 'edel'];

const kHints = {
  'rod': 'Arraste para criar uma barra. Solte perto de uma junta para conectar.',
  'water': 'Barra de borracha: a única peça que atravessa tudo, inclusive outras barras.',
  'cw': 'Toque para uma roda horária; arraste para mudar o tamanho.',
  'ccw': 'Toque para uma roda anti-horária; arraste para mudar o tamanho.',
  'free': 'Toque para uma roda livre; arraste para mudar o tamanho.',
  'magN': 'Toque para pôr um ímã norte. Ele atrai sul e repele norte.',
  'magS': 'Toque para pôr um ímã sul. Ele atrai norte e repele sul.',
  'move': 'Arraste a bola ou uma junta. Peças presas nela vão junto.',
  'select': 'Toque nas peças ou arraste um retângulo para selecionar. Arraste a seleção para mover.',
  'del': 'Toque numa peça para apagar.',
};
const kEHints = {
  'block': 'Arraste para desenhar um bloco.',
  'plat': 'Arraste para desenhar uma plataforma. Inclinada, vira rampa.',
  'lift': 'Arraste do ponto de partida até o ponto de chegada do elevador.',
  'seesaw': 'Arraste para desenhar a prancha. O eixo fica no meio.',
  'door': 'Arraste para desenhar a porta. Ela abre quando algo pisa num botão.',
  'button': 'Toque para pôr um botão. Qualquer botão abre todas as portas. Sem botões, as portas abrem e fecham sozinhas.',
  'zone': 'Arraste para redesenhar a área de construção.',
  'goal': 'Arraste para redesenhar a área vermelha da meta.',
  'ball': 'Toque para posicionar a bola. Ela precisa ficar na área de construção.',
  'magN': 'Toque para pôr um ímã fixo norte.',
  'magS': 'Toque para pôr um ímã fixo sul.',
  'edel': 'Toque num elemento do cenário para apagar.',
};

String fmt(double n, [int d = 2]) => n.toStringAsFixed(d).replaceAll('.', ',');

class Cam {
  double x, y, z;
  Cam([this.x = 0, this.y = 0, this.z = 1]);
}

/// Ação em andamento com o dedo/mouse.
class Act {
  final String type; // pan | drag | selmove | band | draft | edraft
  Pt? last, start, a, b;
  Part? q, d;
  bool onBall = false, moved = false;
  List<Pt> refs = [];
  List<(Pt, double, double)> followers = [];
  List<(Pt, double, double)> orig = [];
  ({double x0, double x1, double y0, double y1})? bb;
  String? et;
  Pt? down;
  Act(this.type);
}

class WinInfo {
  final bool replay;
  final double t;
  final int n, c;
  final Map<String, bool> m;
  final List<String> fresh;
  final Targets tg;
  WinInfo(this.replay, this.t, this.n, this.c, this.m, this.fresh, this.tg);
}

class GameController extends ChangeNotifier {
  final Store store;
  late List<Level> custom;
  late Map<String, dynamic> builds, balls, medals, recs, bests;
  late Set<String> done;
  late Level level;

  Mode mode = Mode.build;
  bool replaying = false, won = false;
  Sim? sim;
  WinInfo? winInfo;
  List<Part> parts = [];
  Pt ball0 = Pt(0, 0);
  final List<String> _undo = [], _editUndo = [];
  String tool = 'rod', etool = 'block';
  Act? action;
  Pt? snapHint;
  Set<Part> sel = {};
  bool selBall = false;
  Level? editLevel;
  Cam cam = Cam();
  bool panMode = false;

  /// Encaixe: pontas soltas perto de uma junta, roda, ímã ou da bola se ligam a ela.
  /// Desligado, a ponta fica onde o dedo soltar. A escolha fica salva.
  late bool snapOn = store.get<bool>('snap', true);
  String hint = '';
  bool hintWin = false;
  bool shareOpen = false;
  String shareCode = '';
  double viewWidth = kW; // largura da bancada na tela, para o raio de encaixe

  final Map<int, Pt> _pointers = {};
  ({double d0, double z0, Pt wm})? _pinch;
  bool _pinchTail = false;
  double _acc = 0;

  GameController(this.store) {
    custom = store.get<List>('levels', []).map(Level.fromJson).toList();
    builds = Map<String, dynamic>.from(store.get<Map>('builds', {}));
    balls = Map<String, dynamic>.from(store.get<Map>('balls', {}));
    medals = Map<String, dynamic>.from(store.get<Map>('medals', {}));
    recs = Map<String, dynamic>.from(store.get<Map>('recs', {}));
    bests = Map<String, dynamic>.from(store.get<Map>('bests', {}));
    done = store.get<List>('done', []).whereType<String>().toSet();
    level = findLevel(store.get<Object?>('cur', 'l1') as String? ?? 'l1') ?? kBuiltin[0];
    selectLevel(level.id!);
  }

  List<Level> get allLevels => [...kBuiltin, ...custom];
  Level? findLevel(String id) {
    for (final l in allLevels) {
      if (l.id == id) return l;
    }
    return null;
  }

  Level get cur => mode == Mode.edit ? editLevel! : level;

  void say(String msg, [bool win = false]) {
    hint = msg;
    hintWin = win;
  }

  String get countText => mode == Mode.edit ? 'editando fase' : '${parts.length}/$kLimit peças · custo \$${costOf(parts)}';

  bool get showSelBar => mode == Mode.build && tool == 'select';
  String get selText {
    final n = sel.length;
    if (n > 0) return '$n ${n == 1 ? 'peça' : 'peças'}${selBall ? ' + bola' : ''}';
    return selBall ? 'Bola selecionada' : 'Nada selecionado';
  }

  Map<String, bool> medalsOf(String id) {
    final m = medals[id];
    if (m is! Map) return {};
    return {for (final k in ['t', 'n', 'c']) k: m[k] == true};
  }

  int starsOf(String id) => medalsOf(id).values.where((v) => v).length;
  bool isDone(String id) => done.contains(id);

  Map<String, dynamic>? get best => bests[level.id] is Map ? Map<String, dynamic>.from(bests[level.id]) : null;

  /// Textos das medalhas da fase atual: (ganhou, rótulo, recorde).
  List<(bool, String, String)> get medalChips {
    final tg = level.targets, m = medalsOf(level.id!);
    final r = recs[level.id] is Map ? recs[level.id] as Map : const {};
    final out = <(bool, String, String)>[];
    if (tg.t != null) out.add((m['t'] ?? false, 'Tempo ≤ ${fmt(tg.t!, 1)} s', r['t'] != null ? 'Seu recorde: ${fmt((r['t'] as num).toDouble())} s' : 'Ainda sem recorde'));
    if (tg.n != null) out.add((m['n'] ?? false, 'Peças ≤ ${tg.n}', r['n'] != null ? 'Seu recorde: ${r['n']} peças' : 'Ainda sem recorde'));
    if (tg.c != null) out.add((m['c'] ?? false, 'Custo ≤ \$${tg.c}', r['c'] != null ? 'Seu recorde: \$${r['c']}' : 'Ainda sem recorde'));
    return out;
  }

  // ---------- fases ----------
  void selectLevel(String id) {
    level = findLevel(id) ?? kBuiltin[0];
    store.set('cur', level.id);
    final saved = Pt.fromJson(balls[level.id]);
    ball0 = saved != null && level.zone.contains(saved) ? saved : level.ball.copy();
    final b = builds[level.id];
    parts = b is List
        ? b.map((q) => Part.fromJson(q)).whereType<Part>().toList()
        : (level.id == 'l1' ? sampleFor(level, ball0) ?? [] : []);
    _undo.clear();
    _clearSel();
    cam = Cam();
    say(level.tip.isNotEmpty ? level.tip : kHints[tool]!);
    notifyListeners();
  }

  void chooseLevel(String id) {
    if (mode == Mode.run) stop();
    selectLevel(id);
  }

  void _saveBuild() {
    builds[level.id!] = parts.map((q) => q.toJson()).toList();
    balls[level.id!] = ball0.toJson();
    store.set('builds', builds);
    store.set('balls', balls);
  }

  void _onWin() {
    final s = sim!;
    if (replaying) {
      winInfo = WinInfo(true, s.t, s.n, s.cost, {}, [], level.targets);
      say('Replay: meta alcançada em ${fmt(s.t)} s.', true);
      return;
    }
    final id = level.id!, t = s.t, n = s.n, c = s.cost, tg = level.targets;
    done.add(id);
    final r = recs[id] is Map ? recs[id] as Map : const {};
    double mn(dynamic a, double b) => a == null ? b : math.min((a as num).toDouble(), b);
    recs[id] = {'t': mn(r['t'], t), 'n': mn(r['n'], n.toDouble()).round(), 'c': mn(r['c'], c.toDouble()).round()};
    final m = medalsOf(id);
    final fresh = <String>[];
    if (tg.t != null && t <= tg.t! + 1e-9 && m['t'] != true) {
      m['t'] = true;
      fresh.add('tempo');
    }
    if (tg.n != null && n <= tg.n! && m['n'] != true) {
      m['n'] = true;
      fresh.add('peças');
    }
    if (tg.c != null && c <= tg.c! && m['c'] != true) {
      m['c'] = true;
      fresh.add('custo');
    }
    medals[id] = m;
    final b = best;
    if (b == null || t < (b['time'] as num)) {
      bests[id] = {'parts': s.parts.map((q) => q.toJson()).toList(), 'ball': s.ball0.toJson(), 'time': t};
    }
    store.set('done', done.toList());
    store.set('recs', recs);
    store.set('medals', medals);
    store.set('bests', bests);
    var msg = 'Fase concluída em ${fmt(t)} s, com $n ${n == 1 ? 'peça' : 'peças'} e custo \$$c.';
    if (fresh.isNotEmpty) msg += ' Nova medalha: ${fresh.join(', ')}!';
    winInfo = WinInfo(false, t, n, c, Map.of(m), fresh, tg);
    say(msg, true);
  }

  // ---------- construção ----------
  void setTool(String t) {
    tool = t;
    say(kHints[t]!);
    notifyListeners();
  }

  void _pushUndo() {
    _undo.add(jsonEncode({'parts': parts.map((q) => q.toJson()).toList(), 'ball': ball0.toJson()}));
    if (_undo.length > 100) _undo.removeAt(0);
  }

  void _clearSel() {
    sel = {};
    selBall = false;
  }

  void undo() {
    if (_undo.isEmpty) return;
    final o = jsonDecode(_undo.removeLast()) as Map;
    parts = (o['parts'] as List).map((q) => Part.fromJson(q)).whereType<Part>().toList();
    ball0 = Pt.fromJson(o['ball'])!;
    _clearSel();
    _saveBuild();
    notifyListeners();
  }

  void clear() {
    if (parts.isEmpty) return;
    _pushUndo();
    parts = [];
    _clearSel();
    _saveBuild();
    say('Bancada limpa. Use Desfazer para recuperar.');
    notifyListeners();
  }

  void loadSample() {
    final s = sampleFor(level, ball0);
    if (s == null) {
      say('O exemplo não cabe na área de construção nesta posição da bola.');
    } else {
      _pushUndo();
      parts = s;
      _clearSel();
      _saveBuild();
      say('Exemplo carregado: carrinho com gaiola para a bola.');
    }
    notifyListeners();
  }

  void togglePlay() => mode == Mode.run ? stop() : start(parts, ball0, false);

  void replay() {
    final b = best;
    if (b == null || mode != Mode.build) return;
    final ps = (b['parts'] as List).map((q) => Part.fromJson(q)).whereType<Part>().toList();
    start(ps, Pt.fromJson(b['ball']) ?? level.ball.copy(), true);
  }

  // ---------- seleção ----------
  List<Pt> _selPoints() => [for (final q in sel) ...q.points, if (selBall) ball0];

  ({double x0, double x1, double y0, double y1}) _bbox(List<Pt> pts) => (
        x0: pts.map((p) => p.x).reduce(math.min),
        x1: pts.map((p) => p.x).reduce(math.max),
        y0: pts.map((p) => p.y).reduce(math.min),
        y1: pts.map((p) => p.y).reduce(math.max),
      );

  void selectAll() {
    sel = parts.toSet();
    selBall = true;
    notifyListeners();
  }

  void deleteSel() {
    if (sel.isEmpty) {
      say('Nada selecionado para apagar.');
    } else {
      _pushUndo();
      parts = parts.where((q) => !sel.contains(q)).toList();
      _clearSel();
      _saveBuild();
    }
    notifyListeners();
  }

  void duplicateSel() {
    final list = sel.toList();
    if (list.isEmpty) {
      say('Selecione peças para duplicar. A bola não é duplicada.');
      return notifyListeners();
    }
    if (parts.length + list.length > kLimit) {
      say('A cópia passaria do limite de 150 peças.');
      return notifyListeners();
    }
    const offs = [[40, -40], [40, 40], [-40, -40], [-40, 40], [80, 0], [-80, 0], [0, -80], [0, 80], [20, -20], [-20, 20]];
    for (final o in offs) {
      final cl = list.map((q) => q.copy()).toList();
      var ok = true;
      for (final q in cl) {
        for (final pt in q.points) {
          pt.x = rnd(pt.x + o[0]);
          pt.y = rnd(pt.y + o[1]);
          if (!level.zone.contains(pt)) ok = false;
        }
      }
      if (!ok) continue;
      _pushUndo();
      parts.addAll(cl);
      sel = cl.toSet();
      selBall = false;
      _saveBuild();
      say('Cópia criada e selecionada. Arraste para posicionar.');
      return notifyListeners();
    }
    say('Não há espaço na área verde para a cópia. Mova ou gire a seleção antes.');
    notifyListeners();
  }

  void rotateSel(double deg) {
    final pts = _selPoints();
    if (sel.isEmpty) {
      say('Selecione peças para girar.');
      return notifyListeners();
    }
    final bb = _bbox(pts), cx = (bb.x0 + bb.x1) / 2, cy = (bb.y0 + bb.y1) / 2;
    final a = deg * math.pi / 180, cs = math.cos(a), sn = math.sin(a);
    final next = pts.map((pt) {
      final dx = pt.x - cx, dy = pt.y - cy;
      return Pt(rnd(cx + dx * cs - dy * sn), rnd(cy + dx * sn + dy * cs));
    }).toList();
    if (!next.every(level.zone.contains)) {
      say('Girando, a seleção sairia da área verde. Mova antes de girar.');
      return notifyListeners();
    }
    _pushUndo();
    for (var i = 0; i < pts.length; i++) {
      pts[i].x = next[i].x;
      pts[i].y = next[i].y;
    }
    for (final q in sel) {
      if (q.isWheel) q.rot += a;
    }
    _saveBuild();
    say('Seleção girada ${deg.abs().round()}° no sentido ${deg > 0 ? 'horário.' : 'anti-horário.'}');
    notifyListeners();
  }

  // ---------- encaixe ----------
  double snapRadius() => clampD(28 * kW / (viewWidth * cam.z), 10, 48);

  Pt? findSnap(Pt p, {List<Part>? list, bool endsOnly = false}) {
    Pt? best;
    var bs = snapRadius();
    void consider(Pt pt, double score) {
      if (score < bs) {
        bs = score;
        best = pt;
      }
    }

    for (final q in list ?? parts) {
      if (q.isWheel) {
        final rim = q.perim;
        for (final pt in rim) {
          consider(pt, dist(p, pt));
        }
        if (!endsOnly) {
          consider(q.c!, dist(p, q.c!));
          // dedo dentro da roda: vale o ponto (centro ou borda) mais próximo
          if (dist(p, q.c!) <= q.r) consider([...rim, q.c!].reduce((m, pt) => dist(p, pt) < dist(p, m) ? pt : m), 0);
        }
      } else if (q.isCircle) {
        if (!endsOnly) consider(q.c!, math.max(0, dist(p, q.c!) - q.r));
      } else {
        consider(q.a!, dist(p, q.a!));
        consider(q.b!, dist(p, q.b!));
      }
    }
    if (!endsOnly) consider(ball0, math.max(0, dist(p, ball0) - kBallR));
    final b = best;
    return b == null ? null : Pt(rnd(b.x), rnd(b.y));
  }

  // Mover continua usando findSnap direto: ali é escolher a junta a arrastar, não corrigir a posição.
  Pt _snapOr(Pt p, {bool endsOnly = false}) => (snapOn ? findSnap(p, endsOnly: endsOnly) : null) ?? Pt(rnd(p.x), rnd(p.y));

  int _hitPart(Pt p) {
    final tol = math.max(6.0, snapRadius() * .5);
    for (var i = parts.length - 1; i >= 0; i--) {
      final q = parts[i];
      if (q.isCircle && dist(p, q.c!) <= q.r + tol * .4) return i;
      if (q.isRod && segDist(p, q.a!, q.b!) <= tol) return i;
    }
    return -1;
  }

  // ---------- câmera ----------
  Pt toWorld(Pt sp) => Pt(cam.x + sp.x / cam.z, cam.y + sp.y / cam.z);
  void _clampCam() {
    cam.z = clampD(cam.z, 1, 4);
    cam.x = clampD(cam.x, 0, kW - kW / cam.z);
    cam.y = clampD(cam.y, 0, kH - kH / cam.z);
  }

  void zoomAt(Pt sp, double f) {
    final wp = toWorld(sp);
    cam.z = clampD(cam.z * f, 1, 4);
    cam.x = wp.x - sp.x / cam.z;
    cam.y = wp.y - sp.y / cam.z;
    _clampCam();
    notifyListeners();
  }

  void zoomIn() => zoomAt(Pt(kW / 2, kH / 2), 1.5);
  void zoomOut() => zoomAt(Pt(kW / 2, kH / 2), 1 / 1.5);
  void zoomFit() {
    cam = Cam();
    notifyListeners();
  }

  void zoomZone() {
    final z = cur.zone;
    cam.z = clampD(math.min(kW / (z.w + 80), kH / (z.h + 80)), 1, 4);
    cam.x = z.x + z.w / 2 - kW / (2 * cam.z);
    cam.y = z.y + z.h / 2 - kH / (2 * cam.z);
    _clampCam();
    notifyListeners();
  }

  void toggleSnap() {
    snapOn = !snapOn;
    store.set('snap', snapOn);
    say(snapOn
        ? 'Encaixe ligado: pontas perto de uma junta, roda, ímã ou da bola se conectam a ela.'
        : 'Encaixe desligado: a ponta fica exatamente onde você soltar.');
    notifyListeners();
  }

  void togglePan() {
    panMode = !panMode;
    notifyListeners();
  }

  // ---------- entrada ----------
  void _cancelAction() {
    final a = action;
    if (a != null && (a.type == 'drag' || a.type == 'selmove')) {
      for (final (pt, x, y) in a.orig) {
        pt.x = x;
        pt.y = y;
      }
      if (_undo.isNotEmpty) _undo.removeLast();
    }
    action = null;
    snapHint = null;
  }

  bool hasPointer(int id) => _pointers.containsKey(id);

  /// [sp] em coordenadas da bancada (0..1000, 0..560) sem zoom.
  void pointerDown(int id, Pt sp, {bool secondary = false}) {
    _pointers[id] = sp;
    if (_pointers.length == 2) {
      _cancelAction();
      final v = _pointers.values.toList(), mid = Pt((v[0].x + v[1].x) / 2, (v[0].y + v[1].y) / 2);
      _pinch = (d0: math.max(10, dist(v[0], v[1])), z0: cam.z, wm: toWorld(mid));
      return notifyListeners();
    }
    if (_pointers.length > 2 || _pinchTail) return;
    if (secondary || panMode || mode == Mode.run) {
      action = Act('pan')..last = sp;
      return;
    }
    final p = toWorld(sp);
    mode == Mode.edit ? _editDown(p) : _buildDown(p);
    notifyListeners();
  }

  void pointerMove(int id, Pt sp) {
    if (!_pointers.containsKey(id)) return;
    _pointers[id] = sp;
    final pinch = _pinch;
    if (pinch != null) {
      if (_pointers.length < 2) return;
      final v = _pointers.values.toList(), mid = Pt((v[0].x + v[1].x) / 2, (v[0].y + v[1].y) / 2);
      cam.z = clampD(pinch.z0 * dist(v[0], v[1]) / pinch.d0, 1, 4);
      cam.x = pinch.wm.x - mid.x / cam.z;
      cam.y = pinch.wm.y - mid.y / cam.z;
      _clampCam();
      return notifyListeners(); // atualiza o rótulo de zoom
    }
    final a = action;
    if (a == null) return;
    if (a.type == 'pan') {
      cam.x -= (sp.x - a.last!.x) / cam.z;
      cam.y -= (sp.y - a.last!.y) / cam.z;
      a.last = sp;
      _clampCam();
      return;
    }
    // só a bancada muda; o Flame redesenha a cada quadro
    final p = toWorld(sp);
    mode == Mode.edit ? _editMove(p) : _buildMove(p);
  }

  /// Soltar ou cancelar: termina a ação na última posição conhecida.
  void pointerUp(int id) {
    final last = _pointers.remove(id);
    if (last == null) return;
    if (_pinch != null) {
      if (_pointers.length < 2) {
        _pinch = null;
        _pinchTail = _pointers.isNotEmpty;
      }
      return;
    }
    if (_pinchTail) {
      if (_pointers.isEmpty) _pinchTail = false;
      return;
    }
    final a = action;
    if (a == null) return;
    if (a.type == 'pan') {
      action = null;
      return notifyListeners();
    }
    final p = toWorld(last);
    if (mode == Mode.edit) {
      _editMove(p);
      _editUp();
    } else {
      _buildMove(p);
      _buildUp();
    }
    notifyListeners();
  }

  void _buildDown(Pt p) {
    if (tool == 'del') {
      final i = _hitPart(p);
      if (i >= 0) {
        _pushUndo();
        sel.remove(parts[i]);
        parts.removeAt(i);
        _saveBuild();
      }
      return;
    }
    if (tool == 'move') {
      final onBall = dist(p, ball0) <= kBallR + 6;
      final target = onBall ? ball0 : findSnap(p);
      if (target == null) return;
      final refs = <Pt>[];
      if (target.key == ball0.key) refs.add(ball0);
      for (final q in parts) {
        for (final pt in q.points) {
          if (pt.key == target.key) refs.add(pt);
        }
      }
      // pontas presas na borda de uma roda arrastada pelo eixo vão junto
      final followers = <(Pt, double, double)>[];
      for (final q in parts) {
        if (!q.isWheel || !refs.contains(q.c)) continue;
        for (final pp in q.perim) {
          for (final o in parts) {
            if (identical(o, q)) continue;
            for (final pt in o.points) {
              if (!refs.contains(pt) && !followers.any((f) => identical(f.$1, pt)) && dist(pt, pp) < .75) {
                followers.add((pt, pt.x - q.c!.x, pt.y - q.c!.y));
              }
            }
          }
        }
      }
      _pushUndo();
      action = Act('drag')
        ..refs = refs
        ..followers = followers
        ..orig = [for (final pt in [...refs, ...followers.map((f) => f.$1)]) (pt, pt.x, pt.y)];
      return;
    }
    if (tool == 'select') {
      final i = _hitPart(p);
      final q = i >= 0 ? parts[i] : null;
      final onBall = q == null && dist(p, ball0) <= kBallR + 6;
      if ((q != null && sel.contains(q)) || (onBall && selBall)) {
        final pts = _selPoints();
        _pushUndo();
        action = Act('selmove')
          ..start = p
          ..q = q
          ..onBall = onBall
          ..bb = _bbox(pts)
          ..orig = [for (final pt in pts) (pt, pt.x, pt.y)];
      } else {
        action = Act('band')
          ..a = p
          ..b = p
          ..q = q
          ..onBall = onBall;
      }
      return;
    }
    if (parts.length >= kLimit) return say('Limite de 150 peças atingido.');
    final isRod = tool == 'rod' || tool == 'water';
    final s = _snapOr(p, endsOnly: !isRod);
    if (!level.zone.contains(s)) return say('Construa dentro da área verde.');
    final Part d;
    if (isRod) {
      d = Part.rod(tool == 'rod' ? 'solid' : 'water', s, s.copy());
    } else if (tool == 'magN' || tool == 'magS') {
      d = Part.mag(tool == 'magN' ? 'N' : 'S', s);
    } else {
      d = Part.wheel(tool, s, 28);
    }
    action = Act('draft')
      ..d = d
      ..down = p;
  }

  void _buildMove(Pt p) {
    final a = action;
    if (a == null) return;
    switch (a.type) {
      case 'drag':
        final c = clampToRect(p, level.zone), cx = rnd(c.x), cy = rnd(c.y);
        for (final pt in a.refs) {
          pt.x = cx;
          pt.y = cy;
        }
        for (final (pt, dx, dy) in a.followers) {
          pt.x = rnd(cx + dx);
          pt.y = rnd(cy + dy);
        }
      case 'selmove':
        final z = level.zone, bb = a.bb!;
        final dx = clampD(p.x - a.start!.x, z.x - bb.x0, z.x + z.w - bb.x1);
        final dy = clampD(p.y - a.start!.y, z.y - bb.y0, z.y + z.h - bb.y1);
        if (dist(p, a.start!) > 4 / cam.z) a.moved = true;
        if (a.moved) {
          for (final (pt, x, y) in a.orig) {
            pt.x = rnd(x + dx);
            pt.y = rnd(y + dy);
          }
        }
      case 'band':
        a.b = p;
      case 'draft':
        final d = a.d!;
        if (d.isRod) {
          snapHint = snapOn ? findSnap(p) : null;
          d.b = snapHint ?? Pt(rnd(p.x), rnd(p.y));
        } else if (d.isWheel) {
          final r = dist(p, a.down!);
          d.r = r > 10 ? clampD(r, 16, 60) : 28;
        }
    }
  }

  void _buildUp() {
    final a = action;
    action = null;
    snapHint = null;
    if (a == null) return;
    switch (a.type) {
      case 'drag':
        _saveBuild();
      case 'selmove':
        if (a.moved) {
          _saveBuild();
        } else {
          if (_undo.isNotEmpty) _undo.removeLast();
          if (a.q != null) {
            sel.remove(a.q);
          } else if (a.onBall) {
            selBall = false;
          }
        }
      case 'band':
        if (dist(a.a!, a.b!) < 6 / cam.z) {
          if (a.q != null) {
            sel.add(a.q!);
          } else if (a.onBall) {
            selBall = true;
          } else {
            _clearSel();
          }
        } else {
          final r = R.fromPoints(a.a!, a.b!);
          sel = parts.where((q) => q.points.every(r.contains)).toSet();
          selBall = r.contains(ball0);
        }
      case 'draft':
        final d = a.d!;
        if (d.isRod) {
          if (dist(d.a!, d.b!) < 14) return;
          if (!level.zone.contains(d.b!)) return say('As duas pontas precisam ficar na área verde.');
          _pushUndo();
          parts.add(d);
        } else {
          _pushUndo();
          d.r = d.r.roundToDouble();
          parts.add(d);
        }
        _saveBuild();
    }
  }

  // ---------- simulação ----------
  void start(List<Part> ps, Pt b, bool isReplay) {
    sim?.dispose();
    sim = Sim(level, ps.map((q) => q.copy()).toList(), b.copy());
    mode = Mode.run;
    replaying = isReplay;
    won = false;
    winInfo = null;
    _acc = 0;
    _clearSel();
    say(isReplay ? 'Replay da melhor solução (${fmt((best!['time'] as num).toDouble())} s).' : 'Rodando. Leve a bola amarela até a área vermelha.');
    notifyListeners();
  }

  void stop() {
    sim?.dispose();
    sim = null;
    mode = Mode.build;
    replaying = false;
    won = false;
    winInfo = null;
    setTool(tool);
  }

  /// Avança a simulação em passos fixos de 1/60 s, qualquer que seja a taxa de quadros.
  /// Chamado pelo laço do Flame (OficinaGame.update).
  void tick(double elapsed) {
    final s = sim;
    if (mode != Mode.run || s == null) return;
    _acc = math.min(_acc + elapsed, kDt * 4);
    while (_acc >= kDt) {
      _acc -= kDt;
      s.step();
      if (!won && s.won()) {
        won = true;
        _onWin();
        notifyListeners(); // medalhas e mensagem mudaram
      }
    }
  }

  // ---------- compartilhar ----------
  void toggleShare() {
    shareOpen = !shareOpen;
    if (shareOpen) shareCode = encodeShare(level, parts, ball0);
    notifyListeners();
  }

  void closeShare() {
    shareOpen = false;
    notifyListeners();
  }

  String currentCode() => encodeShare(level, parts, ball0);

  void importCode(String code) {
    Map<String, dynamic> o;
    try {
      o = decodeShare(code);
    } catch (_) {
      say('Código inválido. Cole o texto completo, começando por OG1:');
      return notifyListeners();
    }
    if (mode == Mode.run) stop();
    String id;
    if (o['ref'] is String && isBuiltin(o['ref'] as String)) {
      id = o['ref'] as String;
    } else {
      final lv = Level.fromJson(o['level'] ?? o)..id = null;
      final sig = lv.signature;
      final same = custom.where((c) => (c.copy()..id = null).signature == sig).firstOrNull;
      if (same != null) {
        id = same.id!;
      } else {
        lv.id = 'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
        custom.add(lv);
        store.set('levels', custom.map((l) => l.toJson()).toList());
        id = lv.id!;
      }
    }
    final lv = findLevel(id)!;
    final hasParts = o['parts'] is List;
    if (hasParts) {
      builds[id] = normalizeParts(o['parts'], lv).map((q) => q.toJson()).toList();
      final b = Pt.fromJson(o['ball']);
      balls[id] = b != null && lv.zone.contains(Pt(rnd(b.x), rnd(b.y))) ? Pt(rnd(b.x), rnd(b.y)).toJson() : null;
      store.set('builds', builds);
      store.set('balls', balls);
    }
    selectLevel(id);
    shareOpen = false;
    say('Código importado: fase "${lv.name}"${hasParts ? ' com a engenhoca. Toque em Rodar.' : '.'}');
    notifyListeners();
  }

  // ---------- editor de fases ----------
  bool get canDeleteEdited => editLevel?.id != null && custom.any((c) => c.id == editLevel!.id);

  void _enterEdit(Level lv) {
    if (mode == Mode.run) stop();
    editLevel = lv;
    _editUndo.clear();
    mode = Mode.edit;
    action = null;
    shareOpen = false;
    say(kEHints[etool]!);
    notifyListeners();
  }

  void editCurrent() {
    final lv = level.copy();
    if (!custom.any((c) => c.id == level.id)) {
      lv.id = null;
      lv.name = 'Cópia de ${level.name}';
    }
    _enterEdit(lv);
  }

  void newLevel() => _enterEdit(blankLevel());

  void _exitEdit() {
    mode = Mode.build;
    editLevel = null;
    action = null;
  }

  void setETool(String t) {
    etool = t;
    say(kEHints[t]!);
    notifyListeners();
  }

  void _pushEU() {
    _editUndo.add(jsonEncode(editLevel!.toJson()));
    if (_editUndo.length > 100) _editUndo.removeAt(0);
  }

  /// Incrementado quando o editor precisa reler nome e metas (desfazer).
  int editRev = 0;

  void editUndo() {
    if (_editUndo.isEmpty) return;
    editLevel = Level.fromJson(jsonDecode(_editUndo.removeLast()));
    editRev++;
    notifyListeners();
  }

  void toggleGround() {
    _pushEU();
    editLevel!.ground = !editLevel!.ground;
    notifyListeners();
  }

  void setEditName(String v) => editLevel?.name = v;

  void setTarget(String k, String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    final ok = v != null && v.isFinite && v > 0;
    final tg = editLevel!.targets;
    if (k == 't') tg.t = ok ? (v * 10).round() / 10 : null;
    if (k == 'n') tg.n = ok ? v.round() : null;
    if (k == 'c') tg.c = ok ? v.round() : null;
  }

  void cancelEdit() {
    _exitEdit();
    say(level.tip.isNotEmpty ? level.tip : kHints[tool]!);
    notifyListeners();
  }

  void saveEdit() {
    final lv = editLevel!;
    if (!lv.zone.contains(lv.ball)) {
      say('Coloque a bola dentro da área de construção antes de salvar.');
      return notifyListeners();
    }
    lv.name = lv.name.trim().isEmpty ? 'Fase sem nome' : lv.name.trim();
    if (lv.id == null) {
      lv.id = 'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
      custom.add(lv);
    } else {
      custom = custom.map((c) => c.id == lv.id ? lv : c).toList();
    }
    store.set('levels', custom.map((l) => l.toJson()).toList());
    final id = lv.id!;
    done.remove(id);
    balls.remove(id);
    medals.remove(id);
    recs.remove(id);
    bests.remove(id);
    store.set('done', done.toList());
    store.set('balls', balls);
    store.set('medals', medals);
    store.set('recs', recs);
    store.set('bests', bests);
    _exitEdit();
    selectLevel(id);
    say('Fase "${lv.name}" salva. Monte uma engenhoca e teste.');
    notifyListeners();
  }

  void deleteEdited() {
    final id = editLevel!.id;
    custom = custom.where((c) => c.id != id).toList();
    store.set('levels', custom.map((l) => l.toJson()).toList());
    builds.remove(id);
    store.set('builds', builds);
    _exitEdit();
    selectLevel('l1');
    say('Fase excluída.');
    notifyListeners();
  }

  Pt _grid(Pt p) => Pt((p.x / 10).round() * 10.0, (p.y / 10).round() * 10.0);

  void _editDown(Pt p) {
    final g = _grid(p), lv = editLevel!;
    if (etool == 'edel') {
      final tol = math.max(8.0, snapRadius() * .5);
      bool tryDel<T>(List<T> arr, bool Function(T) test) {
        for (var i = arr.length - 1; i >= 0; i--) {
          if (test(arr[i])) {
            _pushEU();
            arr.removeAt(i);
            return true;
          }
        }
        return false;
      }

      tryDel<FixedMag>(lv.magnets, (m) => dist(p, m.p) <= kFixR + tol * .4) ||
          tryDel<Pt>(lv.buttons, (b) => (p.x - b.x).abs() <= 27 + tol * .3 && p.y <= b.y + tol * .4 && p.y >= b.y - 10 - tol * .4) ||
          tryDel<Lift>(lv.lifts, (l) => ((p.x - l.a.x).abs() <= l.w / 2 && (p.y - l.a.y).abs() <= kLiftT / 2 + tol * .4) || segDist(p, l.a, l.b) <= tol * .6) ||
          tryDel<Seg>(lv.seesaws, (s) => segDist(p, s.a, s.b) <= kSeeT / 2 + tol * .6) ||
          tryDel<R>(lv.doors, (d) => d.contains(p)) ||
          tryDel<Seg>(lv.plats, (s) => segDist(p, s.a, s.b) <= kPlatT / 2 + tol * .6) ||
          tryDel<R>(lv.blocks, (b) => b.contains(p));
      return;
    }
    if (etool == 'ball') {
      _pushEU();
      lv.ball = g;
      return;
    }
    if (etool == 'magN' || etool == 'magS') {
      _pushEU();
      lv.magnets.add(FixedMag(g.x, g.y, etool == 'magN' ? 'N' : 'S'));
      return;
    }
    if (etool == 'button') {
      _pushEU();
      lv.buttons.add(g);
      return;
    }
    action = Act('edraft')
      ..et = etool
      ..a = g
      ..b = g;
  }

  void _editMove(Pt p) {
    final a = action;
    if (a != null && a.type == 'edraft') a.b = _grid(p);
  }

  void _editUp() {
    final d = action;
    action = null;
    if (d == null || d.type != 'edraft') return;
    final lv = editLevel!;
    final t = d.et!;
    if (t == 'plat' || t == 'seesaw' || t == 'lift') {
      if (dist(d.a!, d.b!) < (t == 'seesaw' ? 60 : 20)) return say('Arraste um pouco mais para desenhar.');
      _pushEU();
      if (t == 'plat') {
        lv.plats.add(Seg(d.a!, d.b!));
      } else if (t == 'seesaw') {
        lv.seesaws.add(Seg(d.a!, d.b!));
      } else {
        lv.lifts.add(Lift(d.a!, d.b!, 160));
      }
      return;
    }
    final r = R.fromPoints(d.a!, d.b!);
    if (r.w < 20 || r.h < 20) return say('Arraste um pouco mais para desenhar.');
    _pushEU();
    if (t == 'block') {
      lv.blocks.add(r);
    } else if (t == 'door') {
      lv.doors.add(r);
    } else if (t == 'zone') {
      lv.zone = r;
    } else {
      lv.goal = r;
    }
  }

  @override
  void dispose() {
    sim?.dispose();
    super.dispose();
  }
}
