part of 'controller.dart';

/// Editor de fases: desenhar cenário, metas das medalhas, salvar e excluir.
mixin _LevelEditor on GameState {
  String etool = 'block';
  @override
  String get etoolName => etool;
  final List<String> _editUndo = [];

  /// Incrementado quando o editor precisa reler nome e metas (desfazer).
  int editRev = 0;

  bool get canDeleteEdited => editLevel?.id != null && progress.isCustom(editLevel!.id);

  void _enterEdit(Level lv) {
    if (mode == Mode.run) stop();
    editLevel = lv;
    _editUndo.clear();
    mode = Mode.edit;
    action = null;
    say(tr(kEHints[etool]!));
    notifyListeners();
  }

  void editCurrent() {
    final lv = level.copy();
    if (!progress.isCustom(level.id)) {
      lv.id = null;
      lv.name = tr('Cópia de {n}', {'n': tr(level.name)});
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
    say(tr(kEHints[t]!));
    notifyListeners();
  }

  void _pushEU() {
    _editUndo.add(jsonEncode(editLevel!.toJson()));
    if (_editUndo.length > 100) _editUndo.removeAt(0);
  }

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

  /// Peças permitidas na fase em edição (null = todas).
  bool editAllows(String t) => editLevel!.allowed == null || editLevel!.allowed!.contains(t);

  void toggleLooseBall() {
    _pushEU();
    editLevel!.looseBall = !editLevel!.looseBall;
    notifyListeners();
  }

  void setBudget(String raw) {
    final v = int.tryParse(raw.trim().replaceAll('\$', ''));
    editLevel!.budget = v != null && v > 0 ? v : null;
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

  void cancelEdit() {
    _exitEdit();
    say(level.tip.isNotEmpty ? tr(level.tip) : tr(kHints[tool]!));
    notifyListeners();
  }

  void saveEdit() {
    final lv = editLevel!;
    if (!lv.zone.contains(lv.ball)) {
      say(tr('Coloque a bola dentro da área de construção antes de salvar.'));
      return notifyListeners();
    }
    lv.name = lv.name.trim().isEmpty ? tr('Fase sem nome') : lv.name.trim();
    final id = progress.saveLevel(lv);
    _exitEdit();
    selectLevel(id);
    say(tr('Fase "{n}" salva. Monte uma engenhoca e teste.', {'n': lv.name}));
    notifyListeners();
  }

  void deleteEdited() {
    progress.deleteLevel(editLevel!.id!);
    _exitEdit();
    selectLevel('l1');
    say(tr('Fase excluída.'));
    notifyListeners();
  }

  // ---------- toques no editor ----------
  Pt _grid(Pt p) => Pt((p.x / 10).round() * 10.0, (p.y / 10).round() * 10.0);

  @override
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

  @override
  void _editMove(Pt p) {
    final a = action;
    if (a != null && a.type == 'edraft') a.b = _grid(p);
  }

  @override
  void _editUp() {
    final d = action;
    action = null;
    if (d == null || d.type != 'edraft') return;
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
}
