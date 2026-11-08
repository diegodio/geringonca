// Progresso do jogador: fases próprias, engenhocas salvas, fases concluídas,
// medalhas, recordes, melhores soluções e quais fases já estão liberadas.
// Tudo fica no aparelho, com as mesmas chaves da versão HTML (prefixo "og-").
import 'dart:math' as math;

import '../core/levels.dart';
import '../core/model.dart';
import 'storage.dart';

/// Desafios extras: medalhas bônus que valem em qualquer fase, além de tempo,
/// peças e custo. Nem toda fase permite todos; eles só aparecem depois de ganhos.
const kChallenges = [
  ('norod', 'Sem barras', 'Vença sem usar nenhuma barra.'),
  ('nomotor', 'Sem motor', 'Vença sem rodas com motor.'),
  ('first', 'De primeira', 'Vença na primeira vez que rodar a fase.'),
];

String challengeName(String id) => kChallenges.firstWhere((c) => c.$1 == id).$2;

/// O que uma vitória mudou: medalhas da fase, as novas, desafios extras e a fase liberada.
class WinRecord {
  final Map<String, bool> medals;
  final List<String> fresh;
  final Level? unlocked;
  final Set<String> badges, freshBadges;
  WinRecord(this.medals, this.fresh, this.unlocked, this.badges, this.freshBadges);
}

class Progress {
  final Store store;
  late List<Level> custom;
  late final Map<String, dynamic> _builds, _balls, _medals, _recs, _bests, _badges, _tries;
  late final Set<String> _done;

  Progress(this.store) {
    custom = store.get<List>('levels', []).map(Level.fromJson).toList();
    _builds = Map<String, dynamic>.from(store.get<Map>('builds', {}));
    _balls = Map<String, dynamic>.from(store.get<Map>('balls', {}));
    _medals = Map<String, dynamic>.from(store.get<Map>('medals', {}));
    _recs = Map<String, dynamic>.from(store.get<Map>('recs', {}));
    _bests = Map<String, dynamic>.from(store.get<Map>('bests', {}));
    _badges = Map<String, dynamic>.from(store.get<Map>('badges', {}));
    _tries = Map<String, dynamic>.from(store.get<Map>('tries', {}));
    _done = store.get<List>('done', []).whereType<String>().toSet();
  }

  // ---------- fases ----------
  List<Level> get allLevels => [...kBuiltin, ...custom];

  Level? find(String id) {
    for (final l in allLevels) {
      if (l.id == id) return l;
    }
    return null;
  }

  bool isCustom(String? id) => custom.any((c) => c.id == id);

  String? get currentId => store.get<Object?>('cur', null) as String?;
  set currentId(String? id) => store.set('cur', id);

  /// Fases prontas abrem em sequência: a seguinte libera quando a anterior é concluída.
  /// Fases próprias e importadas estão sempre abertas.
  /// Uma fase já concluída continua aberta, mesmo que entre uma fase nova antes dela.
  bool isUnlocked(String id) {
    final i = kBuiltin.indexWhere((l) => l.id == id);
    return i <= 0 || _done.contains(kBuiltin[i - 1].id) || _done.contains(id);
  }

  /// A fase que precisa ser concluída para liberar [id].
  Level? blocker(String id) {
    final i = kBuiltin.indexWhere((l) => l.id == id);
    return i > 0 && !isUnlocked(id) ? kBuiltin[i - 1] : null;
  }

  // ---------- engenhoca salva por fase ----------
  List<Part>? savedParts(String id) {
    final b = _builds[id];
    return b is List ? b.map((q) => Part.fromJson(q)).whereType<Part>().toList() : null;
  }

  Pt? savedBall(String id) => Pt.fromJson(_balls[id]);

  void saveBuild(String id, List<Part> parts, Pt ball) {
    _builds[id] = parts.map((q) => q.toJson()).toList();
    _balls[id] = ball.toJson();
    store.set('builds', _builds);
    store.set('balls', _balls);
  }

  // ---------- medalhas e recordes ----------
  bool isDone(String id) => _done.contains(id);

  Map<String, bool> medalsOf(String id) {
    final m = _medals[id];
    if (m is! Map) return {};
    return {for (final k in ['t', 'n', 'c']) k: m[k] == true};
  }

  int starsOf(String id) => medalsOf(id).values.where((v) => v).length;

  Map<String, dynamic> recordOf(String id) => _recs[id] is Map ? Map<String, dynamic>.from(_recs[id]) : {};

  /// Melhor solução guardada: {parts, ball, time}.
  Map<String, dynamic>? bestOf(String id) => _bests[id] is Map ? Map<String, dynamic>.from(_bests[id]) : null;

  /// Desafios extras já ganhos na fase.
  Set<String> badgesOf(String id) => _badges[id] is List ? (_badges[id] as List).whereType<String>().toSet() : {};

  /// Conta uma tentativa (vale para o desafio "De primeira") e devolve quantas já houve.
  int addTry(String id) {
    final n = ((_tries[id] as num?) ?? 0).toInt() + 1;
    _tries[id] = n;
    store.set('tries', _tries);
    return n;
  }

  int triesOf(String id) => ((_tries[id] as num?) ?? 0).toInt();

  /// Registra uma vitória: fase concluída, recordes, medalhas e melhor solução.
  WinRecord recordWin(Level lv, double t, List<Part> parts, Pt ball) {
    final id = lv.id!, n = parts.length, c = costOf(parts), tg = lv.targets;
    final unlockedBefore = kBuiltin.where((l) => isUnlocked(l.id!)).length;
    _done.add(id);
    final r = recordOf(id);
    double mn(dynamic a, double b) => a == null ? b : math.min((a as num).toDouble(), b);
    _recs[id] = {'t': mn(r['t'], t), 'n': mn(r['n'], n.toDouble()).round(), 'c': mn(r['c'], c.toDouble()).round()};
    final m = medalsOf(id);
    final fresh = <String>[];
    void medal(String k, bool ok, String name) {
      if (ok && m[k] != true) {
        m[k] = true;
        fresh.add(name);
      }
    }

    medal('t', tg.t != null && t <= tg.t! + 1e-9, 'tempo');
    medal('n', tg.n != null && n <= tg.n!, 'peças');
    medal('c', tg.c != null && c <= tg.c!, 'custo');
    _medals[id] = m;
    final b = bestOf(id);
    if (b == null || t < (b['time'] as num)) {
      _bests[id] = {'parts': parts.map((q) => q.toJson()).toList(), 'ball': ball.toJson(), 'time': t};
    }
    store.set('done', _done.toList());
    store.set('recs', _recs);
    store.set('medals', _medals);
    store.set('bests', _bests);
    final unlocked = kBuiltin.where((l) => isUnlocked(l.id!)).length > unlockedBefore
        ? kBuiltin.firstWhere((l) => isUnlocked(l.id!) && !_done.contains(l.id))
        : null;
    // desafios extras
    final had = badgesOf(id);
    final now = {
      if (!parts.any((q) => q.isRod)) 'norod',
      if (!parts.any((q) => q.isWheel && q.k != 'free')) 'nomotor',
      if (triesOf(id) <= 1) 'first',
    };
    final all = {...had, ...now};
    _badges[id] = [for (final c in kChallenges) if (all.contains(c.$1)) c.$1];
    store.set('badges', _badges);
    return WinRecord(m, fresh, unlocked, all, now.difference(had));
  }

  // ---------- fases próprias ----------
  String _newId() => 'c${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';

  void _saveCustom() => store.set('levels', custom.map((l) => l.toJson()).toList());

  /// Salva uma fase do editor. Mudou a fase, zera o progresso dela.
  String saveLevel(Level lv) {
    if (lv.id == null) {
      lv.id = _newId();
      custom.add(lv);
    } else {
      custom = custom.map((c) => c.id == lv.id ? lv : c).toList();
    }
    _saveCustom();
    final id = lv.id!;
    _done.remove(id);
    for (final m in [_balls, _medals, _recs, _bests, _badges, _tries]) {
      m.remove(id);
    }
    store.set('badges', _badges);
    store.set('tries', _tries);
    store.set('done', _done.toList());
    store.set('balls', _balls);
    store.set('medals', _medals);
    store.set('recs', _recs);
    store.set('bests', _bests);
    return id;
  }

  /// Fase própria vencida do jeito que está: marca como verificada.
  void markVerified(String id) {
    final lv = find(id);
    if (lv == null || !isCustom(id)) return;
    lv.verified = true;
    _saveCustom();
  }

  void deleteLevel(String id) {
    custom = custom.where((c) => c.id != id).toList();
    _saveCustom();
    _builds.remove(id);
    store.set('builds', _builds);
  }

  /// Fase vinda de um código: reaproveita uma fase própria igual, se já existir.
  String importLevel(Level lv) {
    lv.id = null;
    final sig = lv.signature;
    final same = custom.where((c) => (c.copy()..id = null).signature == sig).firstOrNull;
    if (same != null) return same.id!;
    lv.id = _newId();
    custom.add(lv);
    _saveCustom();
    return lv.id!;
  }

  void importBuild(String id, List<Part> parts, Pt? ball) {
    _builds[id] = parts.map((q) => q.toJson()).toList();
    _balls[id] = ball?.toJson();
    store.set('builds', _builds);
    store.set('balls', _balls);
  }
}
