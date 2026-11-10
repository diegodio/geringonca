part of 'controller.dart';

/// Um passo do tutorial guiado. [target] é o botão a destacar ('cw', 'rod' ou
/// 'play'); [next] é o texto do botão de avançar nos passos que só explicam
/// (os outros avançam sozinhos, quando a pessoa faz o que foi pedido).
class TutStep {
  final String text;
  final String? target, next;
  const TutStep(this.text, {this.target, this.next});
}

const kTutorial = [
  TutStep('Bem-vindo à Geringonça! O objetivo é levar a bola amarela até a área vermelha. Você só pode construir dentro da área verde.', next: 'Começar'),
  TutStep('Toque em Roda ↻ (a laranja) e depois toque na área verde, à esquerda da bola, perto do chão.', target: 'cw'),
  TutStep('Agora ponha outra Roda ↻ à direita da bola. A seta mostra para que lado o motor gira.', target: 'cw'),
  TutStep('Toque em Barra e arraste do centro de uma roda até a bola. Ao soltar perto, a ponta se encaixa sozinha.', target: 'rod'),
  TutStep('Faça o mesmo com a outra roda: uma barra da bola até o centro dela.', target: 'rod'),
  TutStep('Pronto! Toque em ▶ Rodar para ver a engenhoca andar.', target: 'play'),
  TutStep('A engenhoca está andando. Quando a bola entrar inteira na área vermelha, a fase termina. Se travar, toque em Parar, ajuste e rode de novo.'),
  TutStep('Fase concluída! Agora explore as fases, tente as medalhas (★) e crie as suas no editor. Dica: aproxime com dois dedos para construir com precisão.',
      next: 'Concluir'),
];

/// Tutorial guiado: acontece na primeira fase, com a bancada limpa. Cada passo
/// destaca o botão certo e só avança quando a pessoa faz a ação.
mixin _Tutorial on GameState, _BuildTools, _RunControl {
  /// Passo atual; null com o tutorial fechado.
  int? tutStep;
  bool get tutOn => tutStep != null;
  TutStep? get tut => tutStep == null ? null : kTutorial[tutStep!];

  /// O tutorial já foi visto (ou pulado) neste aparelho?
  bool get tutSeen => _tutSeen;
  late bool _tutSeen = store.get<bool>('tut-done', false);

  void _markSeen() {
    _tutSeen = true;
    store.set('tut-done', true);
  }

  /// Botão que o passo atual pede ('cw', 'rod' ou 'play').
  String? get tutTarget => tut?.target;

  List<Part> get _cwWheels => [for (final q in parts) if (q.isWheel && q.k == 'cw') q];

  /// Rodas ↻ ligadas à bola por uma barra (no centro ou num ponto da borda).
  Set<Part> get _linkedWheels {
    final bk = ball0.key, linked = <Part>{};
    for (final r in parts) {
      if (!r.isRod) continue;
      final other = r.a!.key == bk ? r.b! : r.b!.key == bk ? r.a! : null;
      if (other == null) continue;
      for (final w in _cwWheels) {
        if (dist(other, w.c!) < .75 || w.perim.any((p) => dist(other, p) < .75)) linked.add(w);
      }
    }
    return linked;
  }

  /// Onde pôr a próxima roda (passos 2 e 3): um círculo tracejado na bancada.
  Pt? get tutSpot {
    if (tutStep != 1 && tutStep != 2) return null;
    return Pt(ball0.x + (_cwWheels.isEmpty ? -75 : 75), 472);
  }

  /// Barra que falta (passos 4 e 5): do centro de uma roda ainda solta até a bola.
  Seg? get tutLine {
    if (tutStep != 3 && tutStep != 4) return null;
    final linked = _linkedWheels;
    final w = _cwWheels.where((w) => !linked.contains(w)).firstOrNull;
    return w == null ? null : Seg(w.c!, ball0);
  }

  void startTutorial() {
    if (mode == Mode.edit || testing) return tell(tr('Salve ou cancele a fase antes de abrir o tutorial.'));
    if (mode == Mode.run) stop(quiet: true);
    tutStep = null;
    selectLevel('l1');
    if (parts.isNotEmpty) {
      _pushUndo(); // Desfazer devolve a engenhoca que estava na bancada
      parts = [];
      _saveBuild();
    }
    if (!snapOn) {
      snapOn = true;
      store.set('snap', true);
    }
    tutStep = 0;
    _enterStep();
    notifyListeners();
  }

  void _enterStep() {
    final t = tutTarget;
    if (mode == Mode.build && (t == 'cw' || t == 'rod')) tool = t!;
    say(tr(tut!.text));
  }

  /// Botão de avançar dos passos que só explicam.
  void tutNext() {
    final i = tutStep;
    if (i == null) return;
    if (i >= kTutorial.length - 1) return endTutorial();
    tutStep = i + 1;
    fx(Sfx.tap);
    _enterStep();
    notifyListeners();
  }

  /// Fecha o tutorial (pulando ou concluindo). Dá para reabrir pelo menu.
  void endTutorial({bool skipped = false}) {
    if (tutStep == null) return;
    tutStep = null;
    _markSeen();
    if (mode == Mode.build) {
      say(skipped ? tr('Tutorial fechado. Você pode reabri-lo pelo menu ⋮, em Tutorial.') : tr(kHints[tool]!));
    }
    notifyListeners();
  }

  bool _tutDone(int i) => switch (i) {
        1 => _cwWheels.isNotEmpty,
        2 => _cwWheels.length >= 2,
        3 => _linkedWheels.isNotEmpty,
        4 => _linkedWheels.length >= 2,
        5 => mode == Mode.run,
        6 => won,
        _ => false,
      };

  /// Confere se a pessoa fez o que o passo pede. Roda a cada mudança no jogo.
  void _tutCheck() {
    var i = tutStep;
    if (i == null) return;
    // saiu da primeira fase ou abriu o editor: o tutorial acaba
    if (level.id != 'l1' || mode == Mode.edit || testing) {
      tutStep = null;
      _markSeen();
      return;
    }
    final before = i;
    if (i == 6 && mode != Mode.run) i = 5; // parou antes de chegar: volta para "Rodar"
    while (i! < kTutorial.length - 1 && _tutDone(i)) {
      i++;
    }
    if (i != before) {
      tutStep = i;
      // rodando, a linha de dicas fica com as mensagens da simulação
      if (mode == Mode.build) _enterStep();
    }
  }

  @override
  void notifyListeners() {
    _tutCheck();
    super.notifyListeners();
  }
}
