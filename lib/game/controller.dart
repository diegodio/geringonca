// Estado e regras do jogo. A interface só lê daqui e repassa toques e botões.
//
// O controlador é montado em partes, cada uma num arquivo:
//   build_tools.dart   construção, seleção e encaixe
//   camera_input.dart  câmera, zoom e toques na bancada
//   run_control.dart   simulação, pausa, câmera lenta, rastro e vitória
//   level_editor.dart  editor de fases
// O progresso (medalhas, recordes, fases liberadas) fica em progress.dart.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/detmath.dart';
import '../core/i18n.dart';
import '../core/levels.dart';
import '../core/model.dart';
import '../core/share.dart';
import '../core/sim.dart';
import 'fx.dart';
import 'progress.dart';
import 'storage.dart';

part 'build_tools.dart';
part 'camera_input.dart';
part 'level_editor.dart';
part 'run_control.dart';

enum Mode { build, run, edit }

/// Onde ficam as peças e as ferramentas: automático (na lateral com a tela deitada),
/// sempre na lateral ou sempre embaixo.
enum PanelSide { auto, side, bottom }

const kHints = {
  'rod': 'Arraste para criar uma barra. Solte perto de uma junta para conectar.',
  'water': 'Barra de borracha: a única peça que atravessa tudo, inclusive outras barras.',
  'cw': 'Toque para uma roda horária; arraste para mudar o tamanho. O motor só gira com o centro preso a alguma coisa.',
  'ccw': 'Toque para uma roda anti-horária; arraste para mudar o tamanho. O motor só gira com o centro preso a alguma coisa.',
  'free': 'Roda sem motor: gira quando é puxada ou empurrada. Toque para colocar; arraste para mudar o tamanho.',
  'magN': 'Toque para pôr um ímã norte. Ele atrai sul e repele norte.',
  'magS': 'Toque para pôr um ímã sul. Ele atrai norte e repele sul.',
  'move': 'Arraste a bola ou uma junta. Peças presas nela vão junto.',
  'select': 'Toque nas peças ou arraste um retângulo para selecionar. Arraste a seleção para mover.',
  'del': 'Toque numa peça para apagar.',
};
const kEHints = {
  'eselect': 'Toque num elemento para selecionar. Arraste para mover; arraste as bolinhas para mudar o tamanho.',
  'block': 'Arraste para desenhar um bloco.',
  'hill': 'Arraste para desenhar um morro: a largura é a base, a altura é o topo.',
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

/// Número com [d] casas: vírgula em português, ponto em inglês.
String fmt(double n, [int d = 2]) {
  final s = n.toStringAsFixed(d);
  return lang == Lang.pt ? s.replaceAll('.', ',') : s;
}

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
  final String? unlocked; // nome da fase que esta vitória liberou
  final Set<String> badges, freshBadges; // desafios extras: todos os da fase e os ganhos agora
  final Level? next; // próxima fase pronta, se já liberada
  WinInfo(this.replay, this.t, this.n, this.c, this.m, this.fresh, this.tg,
      {this.unlocked, this.badges = const {}, this.freshBadges = const {}, this.next});
}

/// Estado que todas as partes compartilham, e o que uma parte usa da outra.
abstract class GameState extends ChangeNotifier {
  final Store store;
  final Progress progress;
  GameState(this.store) : progress = Progress(store);

  late Level level;
  Mode mode = Mode.build;
  List<Part> parts = [];
  Pt ball0 = Pt(0, 0);
  Act? action;
  Level? editLevel;
  Cam cam = Cam();
  String hint = '';
  bool hintWin = false;
  double viewWidth = kW; // largura da bancada na tela, para o raio de encaixe

  Level get cur => mode == Mode.edit ? editLevel! : level;

  // ---------- opções (ficam salvas no aparelho) ----------
  late PanelSide panelSide = PanelSide.values.firstWhere((v) => v.name == store.get<String>('ui-panel', 'auto'), orElse: () => PanelSide.auto);
  late bool soundOn = store.get<bool>('sound', true);
  late bool vibeOn = store.get<bool>('vibe', true);

  /// Idioma: 'auto' (o do aparelho), 'pt' ou 'en'.
  late String langPref = store.get<String>('lang', 'auto');

  /// Idioma do aparelho (os testes trocam para não depender da máquina).
  static String Function() deviceLanguage = () => PlatformDispatcher.instance.locale.languageCode;

  /// Aplica a opção de idioma; [device] é o código do idioma do aparelho.
  void applyLang([String? device]) {
    lang = switch (langPref) {
      'pt' => Lang.pt,
      'en' => Lang.en,
      _ => langFor(device ?? deviceLanguage()),
    };
  }

  void setLang(String pref) {
    langPref = pref;
    store.set('lang', pref);
    applyLang();
    // a dica da linha de baixo passa para o idioma novo
    say(mode == Mode.edit ? tr(kEHints[etoolName] ?? '') : tr(kHints[tool]!));
    notifyListeners();
  }

  String get etoolName;

  void setPanelSide(PanelSide v) {
    panelSide = v;
    store.set('ui-panel', v.name);
    notifyListeners();
  }

  void setSound(bool on) {
    soundOn = on;
    store.set('sound', on);
    if (on) fx(Sfx.tap);
    notifyListeners();
  }

  void setVibe(bool on) {
    vibeOn = on;
    store.set('vibe', on);
    if (on) fx(Sfx.tap);
    notifyListeners();
  }

  /// Saída de sons e vibração; a interface liga (nos testes fica muda).
  void Function(Sfx s, {required bool sound, required bool vibe})? fxOut;
  void fx(Sfx s) {
    if (soundOn || vibeOn) fxOut?.call(s, sound: soundOn, vibe: vibeOn);
  }

  /// A bola conta como eixo e ponto de encaixe? Não numa fase com bola solta.
  Pt? get hubBall => level.looseBall ? null : ball0;

  void say(String msg, [bool win = false]) {
    hint = msg;
    hintWin = win;
  }

  /// Mostra uma mensagem na linha de dicas e avisa a interface.
  void tell(String msg) {
    say(msg);
    notifyListeners();
  }

  /// Recusa uma ação: mensagem e o som de erro.
  void _deny(String msg) {
    say(msg);
    fx(Sfx.error);
  }

  /// Testando uma fase do editor: a bancada mostra o rascunho, sem guardar progresso.
  bool testing = false;

  void _saveBuild() {
    if (!testing) progress.saveBuild(level.id!, parts, ball0);
  }

  // implementados nas partes
  String get tool;
  void setTool(String t);
  void selectLevel(String id);
  void stop({bool quiet = false});
  void _clearUndo();
  void _clearTrail();
  void _fitTool();
  void _testWon(double t, int n, int c);
  double snapRadius();
  void _clearSel();
  void _cancelBuildAction();
  void _buildDown(Pt p);
  void _buildMove(Pt p);
  void _buildUp();
  void _editDown(Pt p);
  void _editMove(Pt p);
  void _editUp();
}

class GameController extends GameState with _BuildTools, _CameraInput, _RunControl, _LevelEditor {
  GameController(super.store) {
    applyLang();
    final id = progress.currentId;
    final lv = id == null ? null : progress.find(id);
    selectLevel(lv != null && progress.isUnlocked(lv.id!) ? lv.id! : 'l1');
  }

  String get countText =>
      mode == Mode.edit ? tr('editando fase') : tr('{n}/{max} peças · custo \${c}', {'n': parts.length, 'max': kLimit, 'c': costOf(parts)});

  Map<String, dynamic>? get best => progress.bestOf(level.id!);

  /// Textos das medalhas da fase atual: (ganhou, rótulo, recorde).
  List<(bool, String, String)> get medalChips {
    final tg = level.targets, m = progress.medalsOf(level.id!), r = progress.recordOf(level.id!);
    final out = <(bool, String, String)>[];
    final none = tr('Ainda sem recorde');
    if (tg.t != null) {
      out.add((m['t'] ?? false, tr('Tempo ≤ {v} s', {'v': fmt(tg.t!, 1)}), r['t'] != null ? tr('Seu recorde: {v} s', {'v': fmt((r['t'] as num).toDouble())}) : none));
    }
    if (tg.n != null) out.add((m['n'] ?? false, tr('Peças ≤ {v}', {'v': tg.n}), r['n'] != null ? tr('Seu recorde: {v} peças', {'v': r['n']}) : none));
    if (tg.c != null) out.add((m['c'] ?? false, tr('Custo ≤ \${v}', {'v': tg.c}), r['c'] != null ? tr('Seu recorde: \${v}', {'v': r['c']}) : none));
    return out;
  }

  // ---------- fases ----------
  @override
  void selectLevel(String id) {
    level = progress.find(id) ?? kBuiltin[0];
    progress.currentId = level.id;
    final saved = progress.savedBall(level.id!);
    ball0 = saved != null && level.zone.contains(saved) ? saved : level.ball.copy();
    parts = progress.savedParts(level.id!) ?? (level.id == 'l1' ? sampleFor(level, ball0) ?? [] : []);
    _clearUndo();
    _clearSel();
    _clearTrail();
    _fitTool();
    cam = Cam();
    say(level.tip.isNotEmpty ? tr(level.tip) : tr(kHints[tool]!));
    notifyListeners();
  }

  /// Troca de fase pela lista. Fases bloqueadas avisam o que falta.
  void chooseLevel(String id) {
    final b = progress.blocker(id);
    if (b != null) {
      _deny(tr('Fase bloqueada: conclua "{b}" para liberar.', {'b': tr(b.name)}));
      return notifyListeners();
    }
    if (mode == Mode.run) stop();
    selectLevel(id);
  }

  // ---------- compartilhar ----------
  bool shareOpen = false;
  String shareCode = '';

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

  /// Link para esta fase e a engenhoca atual (o código vai depois do #, não sai do aparelho
  /// até alguém abrir o link).
  String linkFor(String pageUrl) => '$pageUrl#c=${linkCode(level, parts, ball0)}';

  /// Abre um código ou link recebido. Verdadeiro quando a fase ficou aberta na bancada.
  bool importCode(String code) {
    final i = code.indexOf('#c=');
    if (i >= 0) code = Uri.decodeComponent(code.substring(i + 3));
    Map<String, dynamic> o;
    try {
      o = decodeShare(code);
    } catch (_) {
      _deny(tr('Código inválido. Cole o link ou o código completo (começa por OG1:).'));
      notifyListeners();
      return false;
    }
    if (mode == Mode.run) stop();
    final ref = o['ref'];
    final id = ref is String && isBuiltin(ref) ? ref : progress.importLevel(Level.fromJson(o['level'] ?? o));
    final lv = progress.find(id)!;
    final hasParts = o['parts'] is List;
    if (hasParts) {
      final b = Pt.fromJson(o['ball']);
      final ball = b == null ? null : Pt(rnd(b.x), rnd(b.y));
      progress.importBuild(id, normalizeParts(o['parts'], lv), ball != null && lv.zone.contains(ball) ? ball : null);
    }
    shareOpen = false;
    final blocker = progress.blocker(id);
    if (blocker != null) {
      say(tr('A engenhoca de "{lv}" ficou guardada, mas a fase ainda está bloqueada: conclua "{b}" para liberar.', {'lv': tr(lv.name), 'b': tr(blocker.name)}));
      notifyListeners();
      return false;
    }
    selectLevel(id);
    say(tr(hasParts ? 'Código importado: fase "{lv}" com a engenhoca. Toque em Rodar.' : 'Código importado: fase "{lv}".', {'lv': tr(lv.name)}));
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    sim?.dispose();
    super.dispose();
  }
}
