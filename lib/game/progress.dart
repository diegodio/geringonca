// Progresso do jogador: fases próprias, engenhocas salvas, fases concluídas,
// medalhas, recordes, melhores soluções e quais fases já estão liberadas.
// Tudo fica no aparelho, com as mesmas chaves da versão HTML (prefixo "og-").
import 'dart:math' as math;

import '../core/levels.dart';
import '../core/model.dart';
import 'progress_sync.dart';
import 'storage.dart';

/// Sem conta, só as primeiras fases ficam abertas (quando o jogo tem servidor).
const kGuestLevels = 7;

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

  /// Chamado quando o progresso ou as fases próprias mudam (a conta manda para a nuvem).
  void Function()? onChanged;
  void _changed() => onChanged?.call();

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

  /// Fases prontas abrem em sequência, e dá para pular uma que empacar: a fase
  /// abre quando no máximo uma das anteriores está por fazer.
  /// Fases próprias e importadas estão sempre abertas.
  /// Uma fase já concluída continua aberta, mesmo que entre uma fase nova antes dela.
  bool isUnlocked(String id) {
    final i = kBuiltin.indexWhere((l) => l.id == id);
    if (needsAccount(id)) return false;
    if (i <= 0 || _done.contains(id)) return true;
    return kBuiltin.take(i).where((l) => !_done.contains(l.id)).length <= 1;
  }

  /// Sem conta, só as [kGuestLevels] primeiras fases prontas abrem. Nulo: sem
  /// limite (o jogo não tem servidor, ou a pessoa entrou na conta).
  int? guestLimit;

  /// A fase só abre para quem entrou na conta?
  bool needsAccount(String id) {
    final lim = guestLimit;
    if (lim == null) return false;
    return kBuiltin.indexWhere((l) => l.id == id) >= lim;
  }

  /// A fase que precisa ser concluída para liberar [id]: a primeira das anteriores por fazer.
  /// Nulo também quando o que falta é entrar na conta (veja [needsAccount]).
  Level? blocker(String id) {
    final i = kBuiltin.indexWhere((l) => l.id == id);
    if (i <= 0 || isUnlocked(id) || needsAccount(id)) return null;
    return kBuiltin.take(i).firstWhere((l) => !_done.contains(l.id));
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
    _changed();
    return n;
  }

  int triesOf(String id) => ((_tries[id] as num?) ?? 0).toInt();

  /// Registra uma vitória: fase concluída, recordes, medalhas e melhor solução.
  WinRecord recordWin(Level lv, double t, List<Part> parts, Pt ball) {
    final id = lv.id!, n = parts.length, c = costOf(parts), tg = lv.targets;
    final lockedBefore = kBuiltin.where((l) => !isUnlocked(l.id!)).toList();
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
    final unlocked = lockedBefore.where((l) => isUnlocked(l.id!)).firstOrNull;
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
    _changed();
    return WinRecord(m, fresh, unlocked, all, now.difference(had));
  }

  // ---------- fases próprias ----------
  /// Id novo pela hora; se já existe uma fase com ele (duas no mesmo milissegundo), avança.
  String _newId() {
    var t = DateTime.now().millisecondsSinceEpoch;
    while (find('c${t.toRadixString(36)}') != null) {
      t++;
    }
    return 'c${t.toRadixString(36)}';
  }

  void _saveCustom() {
    store.set('levels', custom.map((l) => l.toJson()).toList());
    _changed();
  }

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

  // ---------- nuvem ----------
  /// O que vai para a nuvem (veja progress_sync.dart).
  Map<String, dynamic> syncData() => {
        'done': _done.toList()..sort(),
        'medals': _medals,
        'recs': _recs,
        'bests': _bests,
        'badges': _badges,
        'tries': _tries,
      };

  /// Junta o progresso que veio da nuvem com o deste aparelho e grava o resultado.
  Map<String, dynamic> mergeFrom(Map<String, dynamic> remote) {
    final m = mergeProgress(syncData(), remote);
    _done
      ..clear()
      ..addAll((m['done'] as List).whereType<String>());
    for (final (key, mine) in [('medals', _medals), ('recs', _recs), ('bests', _bests), ('badges', _badges), ('tries', _tries)]) {
      mine
        ..clear()
        ..addAll(Map<String, dynamic>.from(m[key] as Map));
      store.set(key, mine);
    }
    store.set('done', _done.toList());
    return m;
  }

  /// Id na nuvem de cada fase própria (id local -> id remoto).
  late final Map<String, dynamic> _remote = Map<String, dynamic>.from(store.get<Map>('remote-levels', {}));
  String? remoteIdOf(String localId) => _remote[localId] as String?;
  Map<String, String> get remoteIds => _remote.map((k, v) => MapEntry(k, v as String));

  void setRemoteId(String localId, String? remoteId) {
    if (remoteId == null) {
      _remote.remove(localId);
    } else {
      _remote[localId] = remoteId;
    }
    store.set('remote-levels', _remote);
  }

  /// Fase que veio da nuvem: entra (ou é atualizada) entre as fases próprias,
  /// com o id local ligado ao da nuvem.
  void putRemoteLevel(String remoteId, Level lv) {
    final local = _remote.entries.where((e) => e.value == remoteId).map((e) => e.key).firstOrNull;
    if (local != null && custom.any((c) => c.id == local)) {
      lv.id = local;
      custom = custom.map((c) => c.id == local ? lv : c).toList();
    } else {
      lv.id = 'r$remoteId';
      custom.add(lv);
      _remote[lv.id!] = remoteId;
      store.set('remote-levels', _remote);
    }
    store.set('levels', custom.map((l) => l.toJson()).toList());
  }
}
