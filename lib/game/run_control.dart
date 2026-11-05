part of 'controller.dart';

/// Simulação: rodar e parar, replay, pausa, câmera lenta, rastro da bola e vitória.
mixin _RunControl on GameState {
  Sim? sim;
  bool replaying = false, won = false;
  WinInfo? winInfo;
  double _acc = 0;

  /// Pausa e velocidade valem para a tentativa em andamento; a velocidade fica para as próximas.
  bool paused = false;
  double speed = 1;

  /// Rastro: o caminho da bola na tentativa atual e o da última tentativa (visto ao construir).
  late bool trailOn = store.get<bool>('trail', true);
  final List<Pt> trail = [];
  List<Pt> lastTrail = [];
  static const _trailEvery = 2; // um ponto a cada 2 passos (30 por segundo)
  static const _trailMax = 3600; // dois minutos de simulação
  int _stepCount = 0;

  void togglePlay() => mode == Mode.run ? stop() : start(parts, ball0, false);

  void replay() {
    final b = progress.bestOf(level.id!);
    if (b == null || mode == Mode.edit) return;
    final ps = (b['parts'] as List).map((q) => Part.fromJson(q)).whereType<Part>().toList();
    start(ps, Pt.fromJson(b['ball']) ?? level.ball.copy(), true);
  }

  /// Peças da engenhoca que esta fase não permite (nomes, sem repetir).
  List<String> forbiddenIn(List<Part> ps) {
    final ok = level.allowed;
    if (ok == null) return [];
    return {for (final q in ps) if (!ok.contains(toolOf(q))) kPieceNames[toolOf(q)]!}.toList();
  }

  void start(List<Part> ps, Pt b, bool isReplay) {
    final bad = isReplay ? <String>[] : forbiddenIn(ps);
    if (bad.isNotEmpty) {
      tell('Esta fase não permite ${bad.join(', ')}. Apague essas peças para rodar.');
      return;
    }
    if (!isReplay) progress.addTry(level.id!);
    sim?.dispose();
    sim = Sim(level, ps.map((q) => q.copy()).toList(), b.copy());
    mode = Mode.run;
    replaying = isReplay;
    won = false;
    winInfo = null;
    paused = false;
    _acc = 0;
    _stepCount = 0;
    trail
      ..clear()
      ..add(b.copy());
    _clearSel();
    final time = isReplay ? (progress.bestOf(level.id!)!['time'] as num).toDouble() : 0.0;
    final idle = ps.where((q) => q.isWheel && q.k != 'free' && !motorOn(q, ps, b)).length;
    say(isReplay
        ? 'Replay da melhor solução (${fmt(time)} s).'
        : idle > 0
            ? 'Rodando. ${idle == 1 ? 'Uma roda com motor está' : '$idle rodas com motor estão'} com o centro solto e não vai${idle == 1 ? '' : 'o'} girar (seta apagada).'
            : 'Rodando. Leve a bola amarela até a área vermelha.');
    notifyListeners();
  }

  @override
  void stop() {
    sim?.dispose();
    sim = null;
    mode = Mode.build;
    replaying = false;
    won = false;
    winInfo = null;
    paused = false;
    lastTrail = List.of(trail);
    trail.clear();
    setTool(tool);
  }

  void _clearTrail() {
    trail.clear();
    lastTrail = [];
  }

  // ---------- pausa, velocidade e rastro ----------
  void togglePause() {
    if (mode != Mode.run) return;
    paused = !paused;
    say(paused ? 'Pausado. Toque em Avançar para ver passo a passo, ou em Continuar.' : 'Rodando.');
    notifyListeners();
  }

  /// Com a simulação pausada, avança um décimo de segundo (6 passos).
  void stepForward() {
    if (mode != Mode.run || !paused) return;
    for (var i = 0; i < 6; i++) {
      _step();
    }
    notifyListeners();
  }

  void setSpeed(double s) {
    speed = s;
    say(s == 1 ? 'Velocidade normal.' : 'Câmera lenta: ${s == .5 ? 'metade' : 'um quarto'} da velocidade.');
    notifyListeners();
  }

  void toggleTrail() {
    trailOn = !trailOn;
    store.set('trail', trailOn);
    say(trailOn ? 'Rastro ligado: o caminho da bola aparece na bancada.' : 'Rastro desligado.');
    notifyListeners();
  }

  /// Avança a simulação em passos fixos de 1/60 s, qualquer que seja a taxa de quadros.
  /// Chamado pelo laço do Flame (OficinaGame.update). A câmera lenta só muda quantos
  /// passos cabem em cada quadro; cada passo é sempre igual, então o resultado não muda.
  void tick(double elapsed) {
    if (mode != Mode.run || sim == null || paused) return;
    _acc = math.min(_acc + elapsed * speed, kDt * 4);
    while (_acc >= kDt) {
      _acc -= kDt;
      _step();
    }
  }

  void _step() {
    final s = sim!;
    s.step();
    if (++_stepCount % _trailEvery == 0) {
      final p = s.ballPose;
      trail.add(Pt(p.x, p.y));
      if (trail.length > _trailMax) trail.removeAt(0);
    }
    if (!won && s.won()) {
      won = true;
      _onWin();
      notifyListeners(); // medalhas e mensagem mudaram
    }
  }

  /// Próxima fase pronta depois da atual, se existir e já estiver liberada.
  Level? get nextLevel {
    final i = kBuiltin.indexWhere((l) => l.id == level.id);
    if (i < 0 || i + 1 >= kBuiltin.length) return null;
    final n = kBuiltin[i + 1];
    return progress.isUnlocked(n.id!) ? n : null;
  }

  // ---------- ações da tela de vitória ----------
  /// Roda de novo, do começo: a mesma engenhoca, ou o mesmo replay.
  void retry() => replaying ? replay() : start(parts, ball0, false);

  /// Volta à construção para melhorar a engenhoca.
  void improve() => stop();

  /// Vai para a próxima fase pronta.
  void goNext() {
    final n = nextLevel;
    if (n == null) return;
    stop();
    selectLevel(n.id!);
  }

  void _onWin() {
    final s = sim!;
    if (replaying) {
      winInfo = WinInfo(true, s.t, s.n, s.cost, {}, [], level.targets);
      say('Replay: meta alcançada em ${fmt(s.t)} s.', true);
      return;
    }
    final r = progress.recordWin(level, s.t, s.parts, s.ball0);
    var msg = 'Fase concluída em ${fmt(s.t)} s, com ${s.n} ${s.n == 1 ? 'peça' : 'peças'} e custo \$${s.cost}.';
    if (r.fresh.isNotEmpty) msg += ' Nova medalha: ${r.fresh.join(', ')}!';
    if (r.unlocked != null) msg += ' Fase liberada: ${r.unlocked!.name}.';
    if (r.freshBadges.isNotEmpty) msg += ' Desafio: ${r.freshBadges.map(challengeName).join(', ')}!';
    winInfo = WinInfo(false, s.t, s.n, s.cost, Map.of(r.medals), r.fresh, level.targets,
        unlocked: r.unlocked?.name, badges: r.badges, freshBadges: r.freshBadges, next: nextLevel);
    say(msg, true);
  }
}
