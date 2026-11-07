part of 'controller.dart';

/// Construção: ferramentas de peça, desfazer, seleção múltipla e encaixe das pontas.
mixin _BuildTools on GameState {
  @override
  String tool = 'rod';
  final List<String> _undo = [];
  Set<Part> sel = {};
  bool selBall = false;
  Pt? snapHint;

  /// Encaixe: pontas soltas perto de uma junta, roda, ímã ou da bola se ligam a ela.
  /// Desligado, a ponta fica onde o dedo soltar. A escolha fica salva.
  late bool snapOn = store.get<bool>('snap', true);

  bool get showSelBar => mode == Mode.build && tool == 'select';
  String get selText {
    final n = sel.length;
    if (n > 0) return '$n ${n == 1 ? 'peça' : 'peças'}${selBall ? ' + bola' : ''}';
    return selBall ? 'Bola selecionada' : 'Nada selecionado';
  }

  /// A fase atual deixa usar a peça da ferramenta [t]? (Mover, Selecionar e Apagar sempre.)
  bool toolAllowed(String t) => !kPieceTools.contains(t) || level.allowed == null || level.allowed!.contains(t);

  @override
  void setTool(String t) {
    if (!toolAllowed(t)) {
      _deny('Esta fase não permite ${kPieceNames[t]}.');
      return notifyListeners();
    }
    if (t != tool) fx(Sfx.tap);
    tool = t;
    say(kHints[t]!);
    notifyListeners();
  }

  /// Ao trocar de fase, sai de uma ferramenta que a fase nova não permite.
  void _fitTool() {
    if (toolAllowed(tool)) return;
    tool = kPieceTools.firstWhere(toolAllowed, orElse: () => 'move');
  }

  void toggleSnap() {
    snapOn = !snapOn;
    store.set('snap', snapOn);
    fx(Sfx.tap);
    say(snapOn
        ? 'Encaixe ligado: pontas perto de uma junta, roda, ímã ou da bola se conectam a ela.'
        : 'Encaixe desligado: a ponta fica exatamente onde você soltar.');
    notifyListeners();
  }

  // ---------- desfazer ----------
  void _pushUndo() {
    _undo.add(jsonEncode({'parts': parts.map((q) => q.toJson()).toList(), 'ball': ball0.toJson()}));
    if (_undo.length > 100) _undo.removeAt(0);
  }

  void _clearUndo() => _undo.clear();

  @override
  void _clearSel() {
    sel = {};
    selBall = false;
  }

  void undo() {
    if (_undo.isEmpty) return;
    fx(Sfx.undo);
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
    fx(Sfx.remove);
    notifyListeners();
  }

  /// O carrinho de exemplo é o tutorial da primeira fase; nas outras, montar é o desafio.
  bool get hasSample => level.id == 'l1';

  void loadSample() {
    if (!hasSample) return tell('O exemplo só existe na primeira fase. Aqui, a engenhoca é com você!');
    final s = sampleFor(level, ball0);
    if (s != null && !s.every((q) => toolAllowed(toolOf(q)))) {
      _deny('O exemplo usa peças que esta fase não permite.');
    } else if (s == null) {
      _deny('O exemplo não cabe na área de construção nesta posição da bola.');
    } else {
      _pushUndo();
      parts = s;
      _clearSel();
      _saveBuild();
      say('Exemplo carregado: carrinho com gaiola para a bola.');
      fx(Sfx.place);
    }
    notifyListeners();
  }

  /// Bola fora da área verde fica onde está: a fase quer que a engenhoca a alcance.
  bool get _ballMovable => level.zone.contains(ball0);

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
    selBall = _ballMovable;
    notifyListeners();
  }

  void deleteSel() {
    if (sel.isEmpty) {
      _deny('Nada selecionado para apagar.');
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
      _deny('Selecione peças para duplicar. A bola não é duplicada.');
      return notifyListeners();
    }
    if (parts.length + list.length > kLimit) {
      _deny('A cópia passaria do limite de 150 peças.');
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
      fx(Sfx.place);
      return notifyListeners();
    }
    _deny('Não há espaço na área verde para a cópia. Mova ou gire a seleção antes.');
    notifyListeners();
  }

  void rotateSel(double deg) {
    final pts = _selPoints();
    if (sel.isEmpty) {
      _deny('Selecione peças para girar.');
      return notifyListeners();
    }
    final bb = _bbox(pts), cx = (bb.x0 + bb.x1) / 2, cy = (bb.y0 + bb.y1) / 2;
    final a = deg * math.pi / 180, cs = dcos(a), sn = dsin(a);
    final next = pts.map((pt) {
      final dx = pt.x - cx, dy = pt.y - cy;
      return Pt(rnd(cx + dx * cs - dy * sn), rnd(cy + dx * sn + dy * cs));
    }).toList();
    if (!next.every(level.zone.contains)) {
      _deny('Girando, a seleção sairia da área verde. Mova antes de girar.');
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
    fx(Sfx.tap);
    notifyListeners();
  }

  // ---------- encaixe ----------
  @override
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
    // com bola solta, nada encaixa na bola
    if (!endsOnly && !level.looseBall) consider(ball0, math.max(0, dist(p, ball0) - kBallR));
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

  // ---------- toques na construção ----------
  /// Um segundo dedo virou pinça: desfaz o arraste que estava em andamento.
  @override
  void _cancelBuildAction() {
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

  @override
  void _buildDown(Pt p) {
    if (tool == 'del') {
      final i = _hitPart(p);
      if (i >= 0) {
        _pushUndo();
        sel.remove(parts[i]);
        parts.removeAt(i);
        _saveBuild();
        fx(Sfx.remove);
      }
      return;
    }
    if (tool == 'move') {
      // bola fora da área verde (fase que pede alcance) não pode ser arrastada
      final onBall = _ballMovable && dist(p, ball0) <= kBallR + 6;
      final target = onBall ? ball0 : findSnap(p);
      if (target == null) return;
      final refs = <Pt>[];
      if (target.key == ball0.key && _ballMovable) refs.add(ball0);
      for (final q in parts) {
        for (final pt in q.points) {
          if (pt.key == target.key) refs.add(pt);
        }
      }
      // pontas presas na borda de uma roda arrastada pelo eixo vão junto
      if (refs.isEmpty) return;
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
      final onBall = q == null && _ballMovable && dist(p, ball0) <= kBallR + 6;
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
    if (parts.length >= kLimit) return _deny('Limite de 150 peças atingido.');
    if (!toolAllowed(tool)) return _deny('Esta fase não permite ${kPieceNames[tool]}.');
    final isRod = tool == 'rod' || tool == 'water';
    final s = _snapOr(p, endsOnly: !isRod);
    if (!level.zone.contains(s)) return _deny('Construa dentro da área verde.');
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

  @override
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

  @override
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
          selBall = _ballMovable && r.contains(ball0);
        }
      case 'draft':
        final d = a.d!;
        if (d.isRod) {
          if (dist(d.a!, d.b!) < 14) return;
          if (!level.zone.contains(d.b!)) return _deny('As duas pontas precisam ficar na área verde.');
          _pushUndo();
          parts.add(d);
          fx(Sfx.place);
        } else {
          _pushUndo();
          d.r = d.r.roundToDouble();
          parts.add(d);
          fx(Sfx.place);
          if (d.isWheel && d.k != 'free' && !hubConnected(d, parts, hubBall)) {
            say('O motor só gira com o centro da roda preso: ligue uma barra, outra peça ou a bola no eixo.');
          }
        }
        _saveBuild();
    }
  }
}
