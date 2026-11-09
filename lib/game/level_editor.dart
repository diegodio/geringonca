part of 'controller.dart';

/// Elemento do cenário escolhido no editor: o tipo e a posição na lista da fase.
/// Tipos: block, door, plat, seesaw, lift, magnet, button (listas) e zone, goal, ball (únicos).
typedef ESel = ({String kind, int i});

/// Modelos para começar uma fase nova: id, nome, descrição e, se vier de uma fase
/// pronta, o nome dela.
const kTemplates = [
  ('vazio', 'Vazio com chão', 'Chão, área de construção e meta.', null),
  ('semchao', 'Sem chão', 'Só dois apoios: o resto é vazio.', null),
  ('vale', 'Vale', 'Um vão no meio do caminho.', 'Vale'),
  ('escada', 'Escada', 'Degraus até a meta.', 'Escada'),
  ('elevador', 'Elevador', 'Um elevador até um bloco alto.', 'Elevador'),
  ('porta', 'Porta e botão', 'Uma porta que abre com um botão.', 'Porta e botão'),
  ('gangorra', 'Gangorra', 'Uma gangorra até um degrau.', 'Gangorra'),
];

/// Editor de fases: desenhar e ajustar o cenário, regras, metas, testar sem sair,
/// verificar a fase, salvar e excluir.
mixin _LevelEditor on GameState {
  String etool = 'eselect';
  @override
  String get etoolName => etool;
  final List<String> _editUndo = [];

  /// Incrementado quando o editor precisa reler nome, dica e metas (desfazer, metas sugeridas).
  int editRev = 0;

  /// Elemento selecionado com a ferramenta Ajustar.
  ESel? esel;

  /// Grade de 20 px (ligada) ou ajuste fino de 5 px.
  late bool egrid = store.get<bool>('egrid', true);
  double get gridStep => egrid ? 20 : 5;

  /// Melhor vitória no teste desde a última mudança no cenário (para sugerir as metas).
  ({double t, int n, int c})? testBest;

  bool get canDeleteEdited => editLevel?.id != null && progress.isCustom(editLevel!.id);

  void _enterEdit(Level lv) {
    if (mode == Mode.run) stop();
    editLevel = lv;
    _editUndo.clear();
    esel = null;
    testBest = null;
    _testParts = [];
    mode = Mode.edit;
    action = null;
    editRev++;
    say(tr(kEHints[etool]!));
    notifyListeners();
  }

  void editCurrent() {
    final lv = level.copy();
    if (!progress.isCustom(level.id)) {
      lv.id = null;
      lv.name = tr('Cópia de {n}', {'n': tr(level.name)});
      lv.verified = false;
    }
    _enterEdit(lv);
  }

  /// Fase nova a partir de um modelo de [kTemplates] (vazio por padrão).
  void newLevel([String template = 'vazio']) => _enterEdit(templateLevel(template));

  static Level templateLevel(String id) {
    final t = kTemplates.where((t) => t.$1 == id).firstOrNull;
    final from = t?.$4 == null ? null : kBuiltin.where((l) => l.name == t!.$4).firstOrNull;
    if (from != null) {
      return from.copy()
        ..id = null
        ..name = tr('Fase nova')
        ..tip = ''
        ..targets = Targets()
        ..allowed = null
        ..looseBall = false
        ..budget = null
        ..verified = false;
    }
    final lv = blankLevel()..name = tr('Fase nova');
    if (id == 'semchao') {
      lv.ground = false;
      lv.blocks.addAll([R(lv.zone.x - 10, lv.zone.y + lv.zone.h, lv.zone.w + 20, 20), R(lv.goal.x - 10, lv.goal.y + lv.goal.h, lv.goal.w + 20, 20)]);
    }
    return lv;
  }

  void _exitEdit() {
    mode = Mode.build;
    editLevel = null;
    esel = null;
    action = null;
  }

  void setETool(String t) {
    etool = t;
    if (t != 'eselect') esel = null;
    say(tr(kEHints[t]!));
    notifyListeners();
  }

  void toggleGrid() {
    egrid = !egrid;
    store.set('egrid', egrid);
    say(tr(egrid ? 'Grade ligada: tudo encaixa de 20 em 20 cm.' : 'Grade desligada: ajuste fino de 5 em 5 cm.'));
    notifyListeners();
  }

  /// Guarda o estado para desfazer. Toda mudança no cenário ou nas regras passa
  /// por aqui, e por isso desfaz a verificação: a fase precisa ser vencida de novo.
  void _pushEU() {
    _editUndo.add(jsonEncode(editLevel!.toJson()));
    if (_editUndo.length > 100) _editUndo.removeAt(0);
    editLevel!.verified = false;
    testBest = null;
  }

  void editUndo() {
    if (_editUndo.isEmpty) return;
    editLevel = Level.fromJson(jsonDecode(_editUndo.removeLast()));
    esel = null;
    testBest = null;
    editRev++;
    fx(Sfx.undo);
    notifyListeners();
  }

  void toggleGround() {
    _pushEU();
    editLevel!.ground = !editLevel!.ground;
    notifyListeners();
  }

  void setEditName(String v) => editLevel?.name = v;
  void setEditTip(String v) => editLevel?.tip = v.length > 160 ? v.substring(0, 160) : v;

  /// Peças permitidas na fase em edição (null = todas).
  bool editAllows(String t) => editLevel!.allowed == null || editLevel!.allowed!.contains(t);

  void toggleLooseBall() {
    _pushEU();
    editLevel!.looseBall = !editLevel!.looseBall;
    notifyListeners();
  }

  void setBudget(String raw) {
    final v = int.tryParse(raw.trim().replaceAll('\$', ''));
    final b = v != null && v > 0 ? v : null;
    if (b == editLevel!.budget) return;
    final was = editLevel!.verified;
    _pushEU();
    editLevel!.budget = b;
    if (was) notifyListeners(); // o selo de verificada some
  }

  void toggleAllowed(String t) {
    final lv = editLevel!;
    final now = [for (final k in kPieceTools) if (k == t ? !editAllows(k) : editAllows(k)) k];
    if (now.isEmpty) return tell(tr('A fase precisa permitir pelo menos uma peça.'));
    _pushEU();
    lv.allowed = now.length == kPieceTools.length ? null : now;
    notifyListeners();
  }

  void setTarget(String k, String raw) {
    final v = double.tryParse(raw.trim().replaceAll(',', '.'));
    final ok = v != null && v.isFinite && v > 0;
    final tg = editLevel!.targets;
    if (k == 't') tg.t = ok ? (v * 10).round() / 10 : null;
    if (k == 'n') tg.n = ok ? v.round() : null;
    if (k == 'c') tg.c = ok ? v.round() : null;
  }

  /// Melhor vitória conhecida da fase em edição: a do teste ou, sem mudanças desde
  /// que foi salva, o recorde dela.
  ({double t, int n, int c})? get bestForTargets {
    if (testBest != null) return testBest;
    final id = editLevel?.id;
    if (id == null || !editLevel!.verified || !progress.isCustom(id)) return null;
    final r = progress.recordOf(id);
    if (r['t'] == null) return null;
    return (t: (r['t'] as num).toDouble(), n: (r['n'] as num).round(), c: (r['c'] as num).round());
  }

  /// Metas das medalhas a partir das suas vitórias: tempo com 10% de folga, mesmas peças e custo.
  void suggestTargets() {
    final b = bestForTargets;
    if (b == null) return tell(tr('Vença a fase no teste para sugerir as metas.'));
    editLevel!.targets = Targets(t: (b.t * 1.1 * 10).ceil() / 10, n: b.n, c: b.c);
    editRev++;
    say(tr('Metas sugeridas pela sua melhor vitória: tempo com 10% de folga, mesmas peças e custo.'));
    notifyListeners();
  }

  void cancelEdit() {
    _exitEdit();
    say(level.tip.isNotEmpty ? tr(level.tip) : tr(kHints[tool]!));
    notifyListeners();
  }

  void saveEdit({bool asCopy = false}) {
    final lv = editLevel!;
    if (!lv.zone.contains(lv.ball)) {
      _deny(tr('Coloque a bola dentro da área de construção antes de salvar.'));
      return notifyListeners();
    }
    lv.name = lv.name.trim().isEmpty ? tr('Fase sem nome') : lv.name.trim();
    if (asCopy) {
      lv.id = null;
      lv.name = tr('Cópia de {n}', {'n': lv.name});
    }
    final parts = _testParts;
    final id = progress.saveLevel(lv);
    _exitEdit();
    selectLevel(id);
    // a engenhoca do teste vem junto para a fase salva
    if (parts.isNotEmpty && this.parts.isEmpty) {
      this.parts = parts.map((q) => q.copy()).toList();
      _saveBuild();
    }
    say(tr(lv.verified ? 'Fase "{n}" salva e verificada.' : 'Fase "{n}" salva. Monte uma engenhoca e teste.', {'n': lv.name}));
    fx(Sfx.place);
    notifyListeners();
  }

  void deleteEdited() {
    progress.deleteLevel(editLevel!.id!);
    _exitEdit();
    selectLevel('l1');
    say(tr('Fase excluída.'));
    fx(Sfx.remove);
    notifyListeners();
  }

  /// Espelha a fase da esquerda para a direita (a meta passa para o outro lado).
  void mirrorLevel() {
    _pushEU();
    final lv = editLevel!;
    double mx(double x) => kW - x;
    void pt(Pt p) => p.x = mx(p.x);
    void rect(R r) => r.x = kW - r.x - r.w;
    for (final r in [...lv.blocks, ...lv.hills, ...lv.doors, lv.zone, lv.goal]) {
      rect(r);
    }
    for (final s in [...lv.plats, ...lv.seesaws, ...lv.lifts]) {
      pt(s.a);
      pt(s.b);
    }
    for (final m in lv.magnets) {
      m.x = mx(m.x);
    }
    lv.buttons.forEach(pt);
    pt(lv.ball);
    say(tr('Fase espelhada.'));
    notifyListeners();
  }

  // ---------- testar sem sair do editor ----------
  List<Part> _testParts = [];
  Level? _beforeTest;
  List<Part> _partsBeforeTest = [];
  Pt? _ballBeforeTest;

  /// Leva a fase como está para a bancada. O rascunho continua no editor.
  void testEdit() {
    final lv = editLevel!;
    if (!lv.zone.contains(lv.ball)) {
      _deny(tr('Coloque a bola dentro da área de construção antes de testar.'));
      return notifyListeners();
    }
    _beforeTest = level;
    _partsBeforeTest = parts;
    _ballBeforeTest = ball0;
    level = lv.copy()..id = '__teste';
    testing = true;
    mode = Mode.build;
    esel = null;
    action = null;
    parts = _testParts.map((q) => q.copy()).toList();
    ball0 = lv.ball.copy();
    _clearUndo();
    _clearSel();
    _clearTrail();
    _fitTool();
    say(tr('Testando: monte uma engenhoca e toque em Rodar. Vença uma vez para verificar a fase.'));
    notifyListeners();
  }

  /// Volta do teste para o editor, guardando a engenhoca do teste.
  void backToEditor() {
    if (!testing) return;
    if (mode == Mode.run) stop(quiet: true);
    _testParts = parts.map((q) => q.copy()).toList();
    testing = false;
    level = _beforeTest ?? level;
    parts = _partsBeforeTest;
    ball0 = _ballBeforeTest ?? ball0;
    _clearUndo();
    _clearSel();
    _clearTrail();
    mode = Mode.edit;
    action = null;
    editRev++;
    say(tr(editLevel!.verified ? 'De volta ao editor. A fase está verificada: você venceu do jeito que ela está.' : 'De volta ao editor.'));
    notifyListeners();
  }

  /// Vitória no teste: verifica a fase e guarda a melhor marca para sugerir as metas.
  @override
  void _testWon(double t, int n, int c) {
    editLevel!.verified = true;
    final b = testBest;
    testBest = (t: b == null ? t : math.min(b.t, t), n: b == null ? n : math.min(b.n, n), c: b == null ? c : math.min(b.c, c));
  }

  // ---------- seleção e ajustes ----------
  /// Objeto do elemento selecionado (R, Seg, Lift, FixedMag ou Pt).
  Object? _elemOf(ESel s) {
    final lv = editLevel!;
    List<Object> list(String k) => switch (k) {
          'block' => lv.blocks,
          'hill' => lv.hills,
          'door' => lv.doors,
          'plat' => lv.plats,
          'seesaw' => lv.seesaws,
          'lift' => lv.lifts,
          'magnet' => lv.magnets,
          'button' => lv.buttons,
          _ => const [],
        };
    return switch (s.kind) {
      'zone' => lv.zone,
      'goal' => lv.goal,
      'ball' => lv.ball,
      _ => s.i < list(s.kind).length ? list(s.kind)[s.i] : null,
    };
  }

  Object? get selected => esel == null || editLevel == null ? null : _elemOf(esel!);

  /// Elemento do cenário sob o dedo, do menor para o maior.
  ESel? _hitScenery(Pt p) {
    final lv = editLevel!, tol = math.max(8.0, snapRadius() * .5);
    ESel? last<T>(String kind, List<T> arr, bool Function(T) test) {
      for (var i = arr.length - 1; i >= 0; i--) {
        if (test(arr[i])) return (kind: kind, i: i);
      }
      return null;
    }

    if (dist(p, lv.ball) <= kBallR + tol * .3) return (kind: 'ball', i: 0);
    return last<FixedMag>('magnet', lv.magnets, (m) => dist(p, m.p) <= kFixR + tol * .4) ??
        last<Pt>('button', lv.buttons, (b) => (p.x - b.x).abs() <= 27 + tol * .3 && p.y <= b.y + tol * .4 && p.y >= b.y - 10 - tol * .4) ??
        last<Lift>('lift', lv.lifts,
            (l) => ((p.x - l.a.x).abs() <= l.w / 2 && (p.y - l.a.y).abs() <= kLiftT / 2 + tol * .4) || segDist(p, l.a, l.b) <= tol * .6) ??
        last<Seg>('seesaw', lv.seesaws, (s) => segDist(p, s.a, s.b) <= kSeeT / 2 + tol * .6) ??
        last<R>('door', lv.doors, (d) => d.contains(p)) ??
        last<Seg>('plat', lv.plats, (s) => segDist(p, s.a, s.b) <= kPlatT / 2 + tol * .6) ??
        last<R>('block', lv.blocks, (b) => b.contains(p)) ??
        last<R>('hill', lv.hills, (h) => inHill(h, p) || (p.x >= h.x && p.x <= h.x + h.w && (p.y - hillY(h, p.x)).abs() <= tol)) ??
        (lv.goal.contains(p) ? (kind: 'goal', i: 0) : null) ??
        (lv.zone.contains(p) ? (kind: 'zone', i: 0) : null);
  }

  /// Alças do elemento selecionado: os cantos de um retângulo ou as pontas de um segmento.
  List<Pt> get eHandles => switch (selected) {
        R r => [Pt(r.x, r.y), Pt(r.x + r.w, r.y), Pt(r.x + r.w, r.y + r.h), Pt(r.x, r.y + r.h)],
        Seg s => [s.a, s.b],
        _ => const [],
      };

  int _handleAt(Pt p) {
    final hs = eHandles, tol = math.max(12.0, snapRadius() * .7);
    for (var i = 0; i < hs.length; i++) {
      if (dist(p, hs[i]) <= tol) return i;
    }
    return -1;
  }

  /// Cópia do estado de um elemento, para mover e redimensionar a partir do original.
  static Object _clone(Object o) => switch (o) {
        Lift l => l.copy(),
        Seg s => s.copy(),
        R r => r.copy(),
        FixedMag m => m.copy(),
        Pt p => p.copy(),
        _ => o,
      };

  void _moveFrom(Object orig, Object live, double dx, double dy) {
    switch ((orig, live)) {
      case (R o, R l):
        l.x = o.x + dx;
        l.y = o.y + dy;
      case (Seg o, Seg l):
        l.a = Pt(o.a.x + dx, o.a.y + dy);
        l.b = Pt(o.b.x + dx, o.b.y + dy);
      case (FixedMag o, FixedMag l):
        l.x = o.x + dx;
        l.y = o.y + dy;
      case (Pt o, Pt l):
        l.x = o.x + dx;
        l.y = o.y + dy;
    }
  }

  void _resizeFrom(Object orig, Object live, int h, Pt to) {
    switch ((orig, live)) {
      case (R o, R l):
        // o canto oposto fica parado
        final opp = [Pt(o.x + o.w, o.y + o.h), Pt(o.x, o.y + o.h), Pt(o.x, o.y), Pt(o.x + o.w, o.y)][h];
        final r = R.fromPoints(opp, to);
        l
          ..x = r.x
          ..y = r.y
          ..w = math.max(20, r.w)
          ..h = math.max(20, r.h);
        if (to.x < opp.x) l.x = opp.x - l.w;
        if (to.y < opp.y) l.y = opp.y - l.h;
      case (Seg _, Seg l):
        if (h == 0) {
          l.a = to;
        } else {
          l.b = to;
        }
    }
  }

  void eDuplicate() {
    final s = esel;
    final o = selected;
    if (s == null || o == null || const ['zone', 'goal', 'ball'].contains(s.kind)) return;
    _pushEU();
    final c = _clone(o);
    _moveFrom(o, c, 20, 20);
    final lv = editLevel!;
    final list = switch (s.kind) {
      'block' => lv.blocks,
      'hill' => lv.hills,
      'door' => lv.doors,
      'plat' => lv.plats,
      'seesaw' => lv.seesaws,
      'lift' => lv.lifts,
      'magnet' => lv.magnets,
      _ => lv.buttons,
    } as List;
    list.add(c);
    esel = (kind: s.kind, i: list.length - 1);
    fx(Sfx.place);
    say(tr('Cópia criada e selecionada. Arraste para posicionar.'));
    notifyListeners();
  }

  void eDelete() {
    final s = esel;
    if (s == null || const ['zone', 'goal', 'ball'].contains(s.kind)) return;
    _pushEU();
    final lv = editLevel!;
    (switch (s.kind) {
      'block' => lv.blocks,
      'hill' => lv.hills,
      'door' => lv.doors,
      'plat' => lv.plats,
      'seesaw' => lv.seesaws,
      'lift' => lv.lifts,
      'magnet' => lv.magnets,
      _ => lv.buttons,
    } as List)
        .removeAt(s.i);
    esel = null;
    fx(Sfx.remove);
    notifyListeners();
  }

  /// Ajusta uma propriedade do elemento selecionado: x, y, w, h (retângulos e pontos),
  /// width, delay, speed (elevador), pole (ímã), level (deixa o segmento reto).
  void eAdjust(String prop, [double delta = 0]) {
    final o = selected;
    if (o == null) return;
    _pushEU();
    switch ((o, prop)) {
      case (R r, 'x'):
        r.x += delta;
      case (R r, 'y'):
        r.y += delta;
      case (R r, 'w'):
        r.w = math.max(20, r.w + delta);
      case (R r, 'h'):
        r.h = math.max(20, r.h + delta);
      case (Lift l, 'width'):
        l.w = clampD(l.w + delta, 40, 400);
      case (Lift l, 'delay'):
        l.delay = clampD(l.delay + delta, 0, 60);
      case (Lift l, 'speed'):
        l.speed = clampD(l.speed + delta, 30, 300);
      case (Seg s, 'x'):
        s.a = Pt(s.a.x + delta, s.a.y);
        s.b = Pt(s.b.x + delta, s.b.y);
      case (Seg s, 'y'):
        s.a = Pt(s.a.x, s.a.y + delta);
        s.b = Pt(s.b.x, s.b.y + delta);
      case (Seg s, 'level'):
        s.b = Pt(s.b.x, s.a.y);
      case (FixedMag m, 'pole'):
        m.pole = m.pole == 'N' ? 'S' : 'N';
      case (FixedMag m, 'x'):
        m.x += delta;
      case (FixedMag m, 'y'):
        m.y += delta;
      case (Pt p, 'x'):
        p.x += delta;
      case (Pt p, 'y'):
        p.y += delta;
    }
    notifyListeners();
  }

  // ---------- toques no editor ----------
  Pt _grid(Pt p) => Pt((p.x / gridStep).round() * gridStep, (p.y / gridStep).round() * gridStep);

  @override
  void _editDown(Pt p) {
    final g = _grid(p), lv = editLevel!;
    if (etool == 'eselect') {
      final h = esel == null ? -1 : _handleAt(p);
      final hit = h >= 0 ? esel : _hitScenery(p);
      esel = hit;
      if (hit == null) return;
      // o passo de desfazer só entra se o elemento de fato se mexer
      _pending = jsonEncode(lv.toJson());
      _eOrig = _clone(selected!);
      action = h >= 0
          ? (Act('eresize')
            ..start = p
            ..et = '$h')
          : (Act('emove')..start = p);
      return;
    }
    if (etool == 'edel') {
      final hit = _hitScenery(p);
      if (hit != null) {
        esel = hit;
        eDelete();
      }
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
      fx(Sfx.place);
      return;
    }
    if (etool == 'button') {
      _pushEU();
      lv.buttons.add(g);
      fx(Sfx.place);
      return;
    }
    action = Act('edraft')
      ..et = etool
      ..a = g
      ..b = g;
  }

  Object? _eOrig;
  String? _pending;

  /// Primeiro movimento de um arraste: registra o desfazer e desfaz a verificação.
  void _commitPending() {
    final pend = _pending;
    if (pend == null) return;
    _pending = null;
    _editUndo.add(pend);
    if (_editUndo.length > 100) _editUndo.removeAt(0);
    editLevel!.verified = false;
    testBest = null;
  }

  @override
  void _editMove(Pt p) {
    final a = action;
    if (a == null) return;
    if (a.type == 'edraft') a.b = _grid(p);
    final o = _eOrig, live = selected;
    if (o == null || live == null) return;
    if (a.type == 'emove') {
      final s = gridStep;
      final dx = ((p.x - a.start!.x) / s).round() * s, dy = ((p.y - a.start!.y) / s).round() * s;
      if (dx == 0 && dy == 0 && !a.moved) return;
      a.moved = true;
      _commitPending();
      _moveFrom(o, live, dx, dy);
    } else if (a.type == 'eresize') {
      a.moved = true;
      _commitPending();
      _resizeFrom(o, live, int.parse(a.et!), _grid(p));
    }
  }

  @override
  void _editUp() {
    final d = action;
    action = null;
    if (d == null) return;
    if (d.type == 'emove' || d.type == 'eresize') {
      _eOrig = null;
      _pending = null; // só tocou, sem mover: a seleção fica e nada muda
      final live = selected, sel = esel;
      // segmento curto demais depois de redimensionar: volta ao que era
      if (d.moved && d.type == 'eresize' && live is Seg && sel != null && dist(live.a, live.b) < (sel.kind == 'seesaw' ? 60 : 20)) {
        editUndo();
        esel = sel;
        return say(tr('Arraste um pouco mais para desenhar.'));
      }
      return;
    }
    if (d.type != 'edraft') return;
    final lv = editLevel!;
    final t = d.et!;
    if (t == 'plat' || t == 'seesaw' || t == 'lift') {
      if (dist(d.a!, d.b!) < (t == 'seesaw' ? 60 : 20)) return say(tr('Arraste um pouco mais para desenhar.'));
      _pushEU();
      if (t == 'plat') {
        lv.plats.add(Seg(d.a!, d.b!));
      } else if (t == 'seesaw') {
        lv.seesaws.add(Seg(d.a!, d.b!));
      } else {
        lv.lifts.add(Lift(d.a!, d.b!, 160));
      }
      fx(Sfx.place);
      return;
    }
    final r = R.fromPoints(d.a!, d.b!);
    if (r.w < 20 || r.h < 20) return say(tr('Arraste um pouco mais para desenhar.'));
    _pushEU();
    if (t == 'block') {
      lv.blocks.add(r);
    } else if (t == 'hill') {
      lv.hills.add(r);
    } else if (t == 'door') {
      lv.doors.add(r);
    } else if (t == 'zone') {
      lv.zone = r;
    } else {
      lv.goal = r;
    }
    fx(Sfx.place);
  }

}
