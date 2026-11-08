// Tela do jogo, pensada primeiro para celular e tablet:
//   barra superior  voltar, fase (abre a lista), medalhas (abre as metas) e menu ⋮
//   bancada         ocupa todo o espaço que sobra, sem rolar a página
//   dock            muda com o momento: construir, rodar ou a tela de vitória
// Com a tela deitada o dock vai para a lateral, para a bancada usar a altura toda
// (nas Opções dá para fixar sempre na lateral ou sempre embaixo).
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../core/levels.dart';
import '../core/model.dart';
import '../game/controller.dart';
import '../game/oficina_game.dart';
import '../game/palette.dart';
import '../game/progress.dart';
import 'how_to_play.dart';
import 'options.dart';
import 'templates.dart';
import 'platform/link.dart';
import 'widgets.dart';
import 'win_panel.dart';

class GamePage extends StatefulWidget {
  final GameController g;
  const GamePage({super.key, required this.g});
  @override
  State<GamePage> createState() => _GamePageState();
}

/// Peças do dock: ferramenta, nome curto, preço e amostra.
List<(String, String, String, Widget)> _pieces(Palette c) => [
      ('rod', 'Barra', '\$10', Sw.bar(c.rod)),
      ('water', 'Borracha', '\$5', Sw.bar(c.water.withValues(alpha: .7))),
      ('cw', 'Roda ↻', '\$25', Sw.dot(c.cw, c.ink)),
      ('ccw', 'Roda ↺', '\$25', Sw.dot(c.ccw, c.ink)),
      ('free', 'Sem motor', '\$15', Sw.dot(c.free, c.ink)),
      ('magN', 'Ímã N', '\$30', Sw.mag(c.mN, c.ink, 'N')),
      ('magS', 'Ímã S', '\$30', Sw.mag(c.mS, c.ink, 'S')),
    ];

class _GamePageState extends State<GamePage> {
  GameController get g => widget.g;
  late final OficinaGame _game;
  final _name = TextEditingController();
  final _tg = {'t': TextEditingController(), 'n': TextEditingController(), 'c': TextEditingController()};
  final _budget = TextEditingController();
  final _tip = TextEditingController();
  int _edTab = 0; // aba do editor: desenhar, regras, fase
  Object? _editKey;
  DateTime _delArmed = DateTime(0);

  @override
  void initState() {
    super.initState();
    _game = OficinaGame(g, mono: GoogleFonts.ibmPlexMono().fontFamily!, display: GoogleFonts.chakraPetch().fontFamily!);
    g.addListener(_sync);
    _sync();
  }

  /// Copia para os campos do editor o que mudou no controlador (abrir, desfazer).
  void _sync() {
    final key = g.mode == Mode.edit ? (g.editLevel, g.editRev) : null;
    if (key == _editKey) return;
    _editKey = key;
    final lv = g.editLevel;
    if (lv == null) return;
    _name.text = lv.name;
    _tip.text = lv.tip;
    _budget.text = lv.budget?.toString() ?? '';
    final tg = {'t': lv.targets.t, 'n': lv.targets.n, 'c': lv.targets.c};
    _tg.forEach((k, c) => c.text = tg[k] == null ? '' : tg[k].toString().replaceAll('.', ','));
  }

  @override
  void dispose() {
    g.removeListener(_sync);
    _name.dispose();
    _tip.dispose();
    _budget.dispose();
    for (final c in _tg.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Volta ao menu. Rodando, para a simulação; no editor, pede para salvar ou cancelar antes.
  void _backToMenu() {
    if (g.testing) return g.backToEditor(); // no teste, voltar leva ao editor
    if (g.mode == Mode.edit) return g.tell(tr('Salve ou cancele a fase antes de voltar ao menu.'));
    if (g.mode == Mode.run) g.stop();
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    _game.palette = c;
    return PopScope(
      canPop: g.mode != Mode.edit && !g.testing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          if (g.mode == Mode.run) g.stop();
        } else {
          _backToMenu();
        }
      },
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: g,
            builder: (context, _) => LayoutBuilder(builder: (context, box) {
              // tela deitada: peças e ferramentas na lateral (a menos que a opção diga outra coisa)
              final side = switch (g.panelSide) {
                PanelSide.side => true,
                PanelSide.bottom => false,
                PanelSide.auto => box.maxWidth > box.maxHeight * 1.15,
              };
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: side
                      ? _sideLayout(c, box)
                      : Column(children: [
                          _topBar(c, compact: box.maxWidth < 600),
                          Expanded(child: _stackedLayout(c, box)),
                        ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ---------- barra superior ----------
  Widget _topBar(Palette c, {required bool compact, bool narrow = false}) {
    final lv = g.cur, idx = kBuiltin.indexWhere((l) => l.id == lv.id);
    final m = g.progress.medalsOf(g.level.id!);
    final tg = g.level.targets;
    final stars = [if (tg.t != null) m['t'] == true, if (tg.n != null) m['n'] == true, if (tg.c != null) m['c'] == true];
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
      child: Row(children: [
        IconBtn(c: c, icon: Icons.arrow_back, tooltip: 'Menu', size: narrow ? 40 : 44, onTap: _backToMenu),
        SizedBox(width: narrow ? 0 : 4),
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: g.mode == Mode.edit || g.testing ? null : () => _levelSheet(c),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 2 : 6, vertical: narrow ? 2 : 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(g.mode == Mode.edit ? tr('Editando: {n}', {'n': lv.name}) : g.testing ? tr('Testando: {n}', {'n': lv.name}) : tr(lv.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.chakraPetch(fontSize: narrow ? 16 : (compact ? 19 : 22), fontWeight: FontWeight.w700, color: c.ink)),
                if (g.mode != Mode.edit)
                  Row(children: [
                    Text(g.testing ? tr('Fase de teste') : idx >= 0 ? tr('Fase {n}', {'n': (idx + 1).toString().padLeft(2, '0')}) : tr('Minha fase'),
                        style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
                    if (!g.testing) Icon(Icons.expand_more, size: 16, color: c.muted),
                  ]),
              ]),
            ),
          ),
        ),
        if (g.mode != Mode.edit && stars.isNotEmpty)
          Tooltip(
            message: tr('Metas e desafios'),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _infoSheet(c),
              child: Padding(
                padding: EdgeInsets.all(narrow ? 4 : 8),
                child: Row(children: [
                  for (final on in stars) Icon(on ? Icons.star : Icons.star_border, size: narrow ? 16 : 22, color: on ? c.medal : c.muted),
                ]),
              ),
            ),
          ),
        _menu(c),
      ]),
    );
  }

  Widget _menu(Palette c) {
    final build = g.mode == Mode.build && !g.testing, edit = g.mode == Mode.edit;
    PopupMenuEntry<String> item(String v, IconData icon, String text, {bool enabled = true, bool? check}) => PopupMenuItem(
          value: v,
          enabled: enabled,
          child: Row(children: [
            Icon(icon, size: 20, color: enabled ? c.ink : c.muted),
            const SizedBox(width: 12),
            Expanded(child: Text(tr(text))),
            if (check != null) Icon(check ? Icons.toggle_on : Icons.toggle_off_outlined, color: check ? c.zone : c.muted),
          ]),
        );
    return PopupMenuButton<String>(
      tooltip: tr('Mais opções'),
      icon: Icon(Icons.more_vert, color: c.ink),
      color: c.paper,
      onSelected: (v) => switch (v) {
        'info' => _infoSheet(c),
        'best' => g.replay(),
        'sample' => g.loadSample(),
        'clear' => g.clear(),
        'snap' => g.toggleSnap(),
        'trail' => g.toggleTrail(),
        'pan' => g.togglePan(),
        'zone' => g.zoomZone(),
        'fit' => g.zoomFit(),
        'share' => _shareSheet(c),
        'edit' => g.editCurrent(),
        'new' => _newLevel(c),
        'help' => _howTo(c),
        'sound' => g.setSound(!g.soundOn),
        'options' => showOptions(context, g),
        _ => null,
      },
      itemBuilder: (_) => [
        item('info', Icons.emoji_events_outlined, 'Metas e desafios', enabled: !edit),
        item('best', Icons.slow_motion_video, 'Ver a melhor solução', enabled: build && g.best != null),
        const PopupMenuDivider(),
        item('sample', Icons.auto_fix_high, 'Carregar exemplo', enabled: build && g.hasSample),
        item('clear', Icons.layers_clear_outlined, 'Limpar bancada', enabled: build && g.parts.isNotEmpty),
        const PopupMenuDivider(),
        item('snap', Icons.link, 'Encaixe automático', enabled: !edit, check: g.snapOn),
        item('trail', Icons.timeline, 'Rastro da bola', check: g.trailOn),
        item('pan', Icons.pan_tool_outlined, 'Arrastar a tela (mão)', check: g.panMode),
        item('zone', Icons.center_focus_strong_outlined, 'Aproximar a área verde'),
        item('fit', Icons.fit_screen_outlined, 'Ver a bancada inteira'),
        const PopupMenuDivider(),
        item('share', Icons.ios_share, 'Compartilhar ou abrir link', enabled: build),
        item('edit', Icons.edit_outlined, 'Editar esta fase', enabled: build),
        item('new', Icons.add_box_outlined, 'Criar fase nova', enabled: build),
        item('help', Icons.help_outline, 'Como jogar'),
        const PopupMenuDivider(),
        item('sound', g.soundOn ? Icons.volume_up_outlined : Icons.volume_off_outlined, 'Sons', check: g.soundOn),
        item('options', Icons.tune, 'Opções…'),
      ],
    );
  }

  // ---------- layouts ----------
  /// Retrato, tablet e computador: bancada logo abaixo da barra, dock embaixo.
  /// A bancada é larga (1000 × 560); em pé ela fica limitada pela largura, e o
  /// espaço que sobra mostra a dica e, no celular, a sugestão de girar a tela.
  Widget _stackedLayout(Palette c, BoxConstraints box) {
    final edit = g.mode == Mode.edit;
    final reserve = edit ? box.maxHeight * .45 + 40 : 250.0; // editor, ou dock + dica
    final benchH = ((box.maxWidth - 16) * kH / kW).clamp(120.0, (box.maxHeight - reserve).clamp(120.0, double.infinity)).toDouble();
    final portrait = box.maxHeight > box.maxWidth * 1.2;
    return Column(children: [
      if (edit)
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: box.maxHeight * .45),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: _editorPanel(c))),
            Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: _editorActions(c)),
          ]),
        ),
      SizedBox(height: benchH, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _benchArea(c))),
      Expanded(
        child: SingleChildScrollView(
          child: Column(children: [
            _hintLine(c),
            if (portrait && box.maxWidth < 700 && !edit)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.screen_rotation_outlined, size: 20, color: c.muted),
                  const SizedBox(width: 8),
                  Flexible(child: Text(tr('Gire o celular para ver a bancada maior.'), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted))),
                ]),
              ),
          ]),
        ),
      ),
      if (!edit) _dock(c, vertical: false, maxHeight: box.maxHeight * .5),
    ]);
  }

  /// Tela deitada: a bancada usa a altura toda; o painel lateral reúne a barra
  /// (voltar, fase, medalhas, menu), as peças ou os controles e a dica.
  Widget _sideLayout(Palette c, BoxConstraints box) => Row(children: [
        Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(6, 6, 6, 6), child: _benchArea(c, floatAction: true))),
        Container(
          width: box.maxWidth < 720 ? 240 : (box.maxWidth < 1100 ? 260 : 300),
          decoration: BoxDecoration(color: c.paper, border: Border(left: BorderSide(color: c.line))),
          child: Column(children: [
            _topBar(c, compact: true, narrow: box.maxHeight < 560 || box.maxWidth < 1100),
            Divider(height: 1, color: c.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: g.mode == Mode.edit ? _editorPanel(c) : _dockBody(c, true),
              ),
            ),
            if (g.mode == Mode.edit) ...[
              Divider(height: 1, color: c.line),
              Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 8), child: _editorActions(c)),
            ],
            if (g.winInfo == null && g.hint.isNotEmpty) ...[
              Divider(height: 1, color: c.line),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Text(g.hint,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(
                        fontSize: 12, height: 1.25, color: g.hintWin ? c.goal : c.muted, fontWeight: g.hintWin ? FontWeight.w600 : FontWeight.w400)),
              ),
            ],
          ]),
        ),
      ]);

  // ---------- bancada ----------
  /// A bancada (jogo Flame) no maior tamanho que cabe, com a barra de seleção por cima.
  /// [floatAction]: Rodar e Parar flutuam no canto da bancada (celular deitado),
  /// para ficarem sempre à mão mesmo com o painel lateral cheio.
  Widget _benchArea(Palette c, {bool floatAction = false}) => LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth < box.maxHeight * kW / kH ? box.maxWidth : box.maxHeight * kW / kH;
        return Center(
          child: SizedBox(
            width: w,
            height: w * kH / kW,
            child: Container(
              decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(12), color: c.paper),
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                Positioned.fill(
                  child: MouseRegion(
                    cursor: g.panMode ? SystemMouseCursors.grab : SystemMouseCursors.precise,
                    child: GameWidget(game: _game),
                  ),
                ),
                if (g.showSelBar) Positioned(left: 6, right: floatAction ? 76 : 6, bottom: 6, child: _selectionBar(c)),
                if (floatAction && g.mode != Mode.edit && g.winInfo == null)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: g.mode == Mode.run
                        ? RoundAction(c: c, icon: Icons.stop_rounded, tooltip: 'Parar e voltar a construir', danger: true, onTap: g.togglePlay)
                        : RoundAction(c: c, icon: Icons.play_arrow_rounded, tooltip: 'Rodar', onTap: g.togglePlay),
                  ),
                if (g.cam.z > 1.01 || g.panMode)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: _floating(c, [
                      if (g.panMode) IconBtn(c: c, icon: Icons.pan_tool, tooltip: 'Sair do modo mão', pressed: true, size: 36, onTap: g.togglePan),
                      if (g.cam.z > 1.01) IconBtn(c: c, icon: Icons.fit_screen_outlined, tooltip: 'Ver a bancada inteira', size: 36, onTap: g.zoomFit),
                    ]),
                  ),
              ]),
            ),
          ),
        );
      });

  Widget _floating(Palette c, List<Widget> children) => Material(
        color: c.paper.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(12),
        elevation: 1,
        child: Padding(padding: const EdgeInsets.all(2), child: Row(mainAxisSize: MainAxisSize.min, children: children)),
      );

  Widget _selectionBar(Palette c) => Align(
        alignment: Alignment.bottomCenter,
        child: _floating(c, [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: label(c, g.selText)),
          IconBtn(c: c, icon: Icons.select_all, tooltip: 'Selecionar tudo', size: 40, onTap: g.selectAll),
          IconBtn(c: c, icon: Icons.copy_all_outlined, tooltip: 'Duplicar', size: 40, onTap: g.duplicateSel),
          IconBtn(c: c, icon: Icons.rotate_left, tooltip: 'Girar 15° anti-horário', size: 40, onTap: () => g.rotateSel(-15)),
          IconBtn(c: c, icon: Icons.rotate_right, tooltip: 'Girar 15° horário', size: 40, onTap: () => g.rotateSel(15)),
          IconBtn(c: c, icon: Icons.delete_sweep_outlined, tooltip: 'Apagar seleção', size: 40, onTap: g.deleteSel),
        ]),
      );

  Widget _hintLine(Palette c) => g.winInfo != null
      ? const SizedBox(height: 8)
      : Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
        child: Row(children: [
          Expanded(
            child: Text(g.hint,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.ibmPlexSans(
                    fontSize: 13, height: 1.3, color: g.hintWin ? c.goal : c.muted, fontWeight: g.hintWin ? FontWeight.w600 : FontWeight.w400)),
          ),
          if (g.mode == Mode.build) ...[
            const SizedBox(width: 8),
            Text(g.countText, style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
          ],
        ]),
      );

  // ---------- dock ----------
  Widget _dockBody(Palette c, bool vertical) => switch (g.mode) {
        Mode.run when g.winInfo != null => WinPanel(g: g, c: c, onMenu: _backToMenu),
        Mode.run => _runControls(c, vertical),
        _ => _buildControls(c, vertical),
      };

  Widget _dock(Palette c, {required bool vertical, required double maxHeight}) {
    final body = _dockBody(c, vertical);
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: c.paper,
        border: vertical ? Border(left: BorderSide(color: c.line)) : Border(top: BorderSide(color: c.line)),
      ),
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(8, 8, 8, 10), child: body),
    );
  }

  Widget _buildControls(Palette c, bool vertical) {
    final chips = [
      for (final (id, name, cost, sw) in _pieces(c))
        if (g.toolAllowed(id))
          PieceChip(c: c, swatch: sw, name: name, cost: cost, selected: g.tool == id, onTap: () => g.setTool(id)),
    ];
    final tools = [
      IconBtn(c: c, icon: Icons.open_with, tooltip: 'Mover juntas e a bola', pressed: g.tool == 'move', onTap: () => g.setTool('move')),
      IconBtn(c: c, icon: Icons.highlight_alt, tooltip: 'Selecionar', pressed: g.tool == 'select', onTap: () => g.setTool('select')),
      IconBtn(c: c, icon: Icons.delete_outline, tooltip: 'Apagar peça', pressed: g.tool == 'del', onTap: () => g.setTool('del')),
      IconBtn(c: c, icon: Icons.undo, tooltip: 'Desfazer', onTap: g.undo),
      IconBtn(
          c: c,
          icon: g.snapOn ? Icons.link : Icons.link_off,
          tooltip: g.snapOn ? 'Encaixe automático ligado' : 'Encaixe automático desligado',
          pressed: g.snapOn,
          toggle: true,
          onTap: g.toggleSnap),
    ];
    final play = RoundAction(c: c, icon: Icons.play_arrow_rounded, tooltip: 'Rodar', onTap: g.togglePlay);
    final rules = _rules(g.level);
    final note = rules.isNotEmpty
        ? Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(Icons.info_outline, size: 15, color: c.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(rules.join(' · '), style: GoogleFonts.ibmPlexSans(fontSize: 12, color: c.muted))),
            ]),
          )
        : const SizedBox.shrink();
    final back = g.testing
        ? Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TB(c: c, primary: true, icon: Icons.edit_outlined, label: 'Voltar ao editor', onTap: g.backToEditor),
          )
        : const SizedBox.shrink();
    if (vertical) {
      // dock lateral: fichas compactas em 2 colunas, ferramentas e Rodar lado a lado
      final small = [
        for (final (id, name, cost, sw) in _pieces(c))
          if (g.toolAllowed(id)) PieceChip(c: c, compact: true, swatch: sw, name: name, cost: cost, selected: g.tool == id, onTap: () => g.setTool(id)),
      ];
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        back,
        note,
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(g.countText, style: GoogleFonts.ibmPlexMono(fontSize: 11, color: c.muted)),
        ),
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - 6) / 2;
          return Wrap(spacing: 6, runSpacing: 6, children: [for (final s in small) SizedBox(width: w, child: s)]);
        }),
        const SizedBox(height: 8),
        Wrap(spacing: 0, runSpacing: 0, children: tools),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      back,
      note,
      SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [...tools, const Spacer(), play]),
    ]);
  }

  /// Regras especiais da fase, em frases curtas.
  List<String> _rules(Level lv) => [
        if (lv.allowed != null) tr('Só algumas peças liberadas'),
        if (lv.looseBall) tr('Bola solta: nada se prende a ela'),
        if (lv.budget != null) tr('Orçamento: \${b} (gasto: \${g})', {'b': lv.budget, 'g': costOf(g.parts)}),
      ];

  Widget _runControls(Palette c, bool vertical) {
    Widget speed(double s, String t) => Padding(
          padding: const EdgeInsets.only(right: 4),
          child: ChoiceChip(
            label: Text(t, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: g.speed == s ? c.paper : c.ink)),
            selected: g.speed == s,
            showCheckmark: false,
            selectedColor: c.ink,
            backgroundColor: c.bg,
            side: BorderSide(color: c.line),
            onSelected: (_) => g.setSpeed(s),
          ),
        );
    final controls = [
      IconBtn(c: c, icon: g.paused ? Icons.play_arrow : Icons.pause, tooltip: g.paused ? 'Continuar' : 'Pausar', pressed: g.paused, onTap: g.togglePause),
      IconBtn(c: c, icon: Icons.skip_next, tooltip: 'Avançar 0,1 s (com a simulação pausada)', onTap: g.paused ? g.stepForward : null),
      const SizedBox(width: 6),
      speed(1, '1×'),
      speed(.5, '½×'),
      speed(.25, '¼×'),
    ];
    final stop = RoundAction(c: c, icon: Icons.stop_rounded, tooltip: 'Parar e voltar a construir', danger: true, onTap: g.togglePlay);
    if (vertical) {
      return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 6, children: controls);
    }
    return Row(children: [...controls, const Spacer(), stop]);
  }

  // ---------- editor de fases ----------
  Widget _num(Palette c, String k, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(tr(text), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
        const SizedBox(width: 6),
        SizedBox(
          width: 70,
          child: TextField(
            controller: _tg[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (v) => g.setTarget(k, v),
            style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink),
            decoration: InputDecoration(hintText: '—', isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
          ),
        ),
      ]);

  /// Fase nova: escolhe o modelo e abre o editor.
  Future<void> _newLevel(Palette c) async {
    final t = await pickTemplate(context, c);
    if (t != null) g.newLevel(t);
  }

  /// Editor em três abas (Desenhar, Regras e Fase), com Testar, Cancelar e Salvar
  /// sempre à vista.
  Widget _editorPanel(Palette c) {
    final lv = g.editLevel!;
    const tabs = ['Desenhar', 'Regras', 'Fase'];
    return Panel(c: c, accent: true, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (i, t) in tabs.indexed) TB(c: c, small: true, label: t, pressed: _edTab == i, onTap: () => setState(() => _edTab = i)),
      ]),
      ...switch (_edTab) {
        0 => _edDraw(c, lv),
        1 => _edRules(c, lv),
        _ => _edLevel(c, lv),
      },
    ]);
  }

  /// Testar, Cancelar e Salvar: fora da rolagem, sempre à vista.
  Widget _editorActions(Palette c) => Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.end, children: [
        TB(c: c, small: true, icon: Icons.play_arrow_rounded, label: 'Testar', tooltip: 'Jogar a fase como está, sem sair do editor', onTap: g.testEdit),
        TB(c: c, small: true, label: 'Cancelar', onTap: g.cancelEdit),
        TB(c: c, small: true, primary: true, label: 'Salvar fase', onTap: g.saveEdit),
      ]);

  List<Widget> _edDraw(Palette c, Level lv) {
    Widget et(String id, String text, Widget sw) => TB(c: c, small: true, label: text, leading: sw, pressed: g.etool == id, onTap: () => g.setETool(id));
    return [
      Wrap(spacing: 6, runSpacing: 6, children: [
        TB(c: c, small: true, icon: Icons.ads_click, label: 'Ajustar', pressed: g.etool == 'eselect', onTap: () => g.setETool('eselect')),
        et('block', 'Bloco', Sw.sq(c.ground)),
        et('plat', 'Plataforma', Sw.bar(c.ground)),
        et('lift', 'Elevador', Sw.bar(c.lift)),
        et('seesaw', 'Gangorra', Transform.rotate(angle: -.35, child: Sw.bar(c.lift))),
        et('door', 'Porta', Sw.sq(c.door)),
        et('button', 'Botão', Sw.bar(c.door)),
        et('zone', 'Área de construção', Sw.sq(c.zone.withValues(alpha: .5))),
        et('goal', 'Meta', Sw.sq(c.goal.withValues(alpha: .5))),
        et('ball', 'Bola', Sw.dot(c.ball, c.ink)),
        et('magN', 'Ímã fixo N', Sw.mag(c.mN, c.ink, 'N')),
        et('magS', 'Ímã fixo S', Sw.mag(c.mS, c.ink, 'S')),
        TB(c: c, small: true, icon: Icons.delete_outline, label: 'Apagar', pressed: g.etool == 'edel', onTap: () => g.setETool('edel')),
      ]),
      Wrap(spacing: 6, runSpacing: 6, children: [
        TB(c: c, small: true, icon: Icons.grid_4x4, label: 'Grade', tooltip: 'Encaixar de 20 em 20 cm (desligada: de 5 em 5)', pressed: g.egrid, onTap: g.toggleGrid),
        TB(c: c, small: true, label: 'Chão', pressed: lv.ground, onTap: g.toggleGround),
        TB(c: c, small: true, icon: Icons.flip, label: 'Espelhar', tooltip: 'Inverter a fase da esquerda para a direita', onTap: g.mirrorLevel),
        TB(c: c, small: true, icon: Icons.undo, label: 'Desfazer', onTap: g.editUndo),
      ]),
      if (g.selected != null) _selPanel(c),
    ];
  }

  /// Propriedades do elemento selecionado com a ferramenta Ajustar.
  Widget _selPanel(Palette c) {
    final s = g.esel!, o = g.selected!;
    const names = {
      'block': 'Bloco',
      'door': 'Porta',
      'plat': 'Plataforma',
      'seesaw': 'Gangorra',
      'lift': 'Elevador',
      'magnet': 'Ímã fixo',
      'button': 'Botão',
      'zone': 'Área de construção',
      'goal': 'Meta',
      'ball': 'Bola',
    };
    final step = g.gridStep, single = const ['zone', 'goal', 'ball'].contains(s.kind);
    String m(double v) => '${fmt(v / 100)} m';
    Widget stepper(String name, String value, String prop, double d) => Row(children: [
          Expanded(child: Text(tr(name), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted))),
          IconBtn(c: c, icon: Icons.remove, tooltip: 'Diminuir', size: 36, onTap: () => g.eAdjust(prop, -d)),
          SizedBox(width: 74, child: Text(value, textAlign: TextAlign.center, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.ink))),
          IconBtn(c: c, icon: Icons.add, tooltip: 'Aumentar', size: 36, onTap: () => g.eAdjust(prop, d)),
        ]);
    final rows = <Widget>[
      ...switch (o) {
        R r => [
            stepper('Posição x', m(r.x), 'x', step),
            stepper('Posição y', m(r.y), 'y', step),
            stepper('Largura', m(r.w), 'w', step),
            stepper('Altura', m(r.h), 'h', step),
          ],
        Lift l => [
            stepper('Largura', m(l.w), 'width', 20),
            stepper('Velocidade', '${fmt(l.speed / 100)} m/s', 'speed', 15),
            stepper('Atraso', '${fmt(l.delay, 1)} s', 'delay', .5),
            stepper('Posição x', m(math.min(l.a.x, l.b.x)), 'x', step),
            stepper('Posição y', m(math.min(l.a.y, l.b.y)), 'y', step),
            if (l.hasShaft)
              Text(tr('Vertical e no nível do chão: abre um poço embaixo.'), style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: c.muted)),
          ],
        Seg sg => [
            Text('${fmt(dist(sg.a, sg.b) / 100)} m · ${(math.atan2(sg.a.y - sg.b.y, sg.b.x - sg.a.x) * 180 / math.pi).round()}°',
                style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.ink)),
            stepper('Posição x', m(math.min(sg.a.x, sg.b.x)), 'x', step),
            stepper('Posição y', m(math.min(sg.a.y, sg.b.y)), 'y', step),
            Align(
              alignment: Alignment.centerLeft,
              child: TB(c: c, small: true, icon: Icons.horizontal_rule, label: 'Deixar reto', onTap: () => g.eAdjust('level')),
            ),
          ],
        FixedMag mg => [
            Align(
              alignment: Alignment.centerLeft,
              child: TB(c: c, small: true, icon: Icons.swap_horiz, label: mg.pole == 'N' ? 'Polo: norte' : 'Polo: sul', onTap: () => g.eAdjust('pole')),
            ),
            stepper('Posição x', m(mg.x), 'x', step),
            stepper('Posição y', m(mg.y), 'y', step),
          ],
        Pt pt => [stepper('Posição x', m(pt.x), 'x', step), stepper('Posição y', m(pt.y), 'y', step)],
        _ => <Widget>[],
      },
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 8),
      decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.accent.withValues(alpha: .5))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(tr(names[s.kind]!), style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w700, color: c.ink))),
          if (!single) IconBtn(c: c, icon: Icons.copy_all_outlined, tooltip: 'Duplicar', size: 36, onTap: g.eDuplicate),
          if (!single) IconBtn(c: c, icon: Icons.delete_outline, tooltip: 'Apagar', size: 36, onTap: g.eDelete),
        ]),
        ...rows,
      ]),
    );
  }

  List<Widget> _edRules(Palette c, Level lv) => [
        label(c, 'Peças permitidas'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final (id, name, _, sw) in _pieces(c))
            FilterChip(
              avatar: sw,
              label: Text(tr(name), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.ink)),
              selected: g.editAllows(id),
              selectedColor: c.zone.withValues(alpha: .18),
              checkmarkColor: c.zone,
              backgroundColor: c.bg,
              side: BorderSide(color: c.line),
              onSelected: (_) => g.toggleAllowed(id),
            ),
        ]),
        label(c, 'Regras'),
        Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilterChip(
            avatar: Icon(Icons.sports_baseball_outlined, size: 18, color: c.ink),
            label: Text(tr('Bola solta'), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.ink)),
            tooltip: tr('Nada pode ser preso à bola, e ela não liga motor de roda'),
            selected: lv.looseBall,
            selectedColor: c.zone.withValues(alpha: .18),
            checkmarkColor: c.zone,
            backgroundColor: c.bg,
            side: BorderSide(color: c.line),
            onSelected: (_) => g.toggleLooseBall(),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Text(tr('Orçamento (\$)'), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
            const SizedBox(width: 6),
            SizedBox(
              width: 80,
              child: TextField(
                controller: _budget,
                keyboardType: TextInputType.number,
                onChanged: g.setBudget,
                style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink),
                decoration: InputDecoration(hintText: tr('sem'), isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
              ),
            ),
          ]),
        ]),
      ];

  List<Widget> _edLevel(Palette c, Level lv) {
    final armed = DateTime.now().difference(_delArmed).inMilliseconds < 3000;
    final ok = lv.verified;
    return [
      TextField(
        controller: _name,
        maxLength: 40,
        onChanged: g.setEditName,
        style: GoogleFonts.ibmPlexSans(fontSize: 15, color: c.ink),
        decoration: InputDecoration(labelText: tr('Nome da fase'), counterText: '', isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
      ),
      TextField(
        controller: _tip,
        maxLength: 160,
        minLines: 1,
        maxLines: 3,
        onChanged: g.setEditTip,
        style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink),
        decoration: InputDecoration(
            labelText: tr('Dica para quem joga'), counterText: '', isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
      ),
      Row(children: [
        Icon(ok ? Icons.verified : Icons.help_outline, size: 20, color: ok ? c.zone : c.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(tr(ok ? 'Verificada: você venceu a fase do jeito que ela está.' : 'Não verificada: toque em Testar e vença uma vez.'),
              style: GoogleFonts.ibmPlexSans(fontSize: 13, color: ok ? c.zone : c.muted)),
        ),
      ]),
      label(c, 'Metas das medalhas'),
      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _num(c, 't', 'Tempo (s)'),
        _num(c, 'n', 'Peças'),
        _num(c, 'c', 'Custo'),
        TB(
            c: c,
            small: true,
            icon: Icons.auto_awesome,
            label: 'Sugerir metas',
            tooltip: 'Pela sua melhor vitória no teste',
            onTap: g.bestForTargets == null ? null : g.suggestTargets),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (g.canDeleteEdited) TB(c: c, small: true, icon: Icons.copy_outlined, label: 'Salvar como cópia', onTap: () => g.saveEdit(asCopy: true)),
        if (g.canDeleteEdited)
          TB(
              c: c,
              small: true,
              icon: Icons.delete_forever_outlined,
              label: armed ? 'Toque de novo para excluir' : 'Excluir fase',
              onTap: () {
                if (!armed) {
                  setState(() => _delArmed = DateTime.now());
                  Future.delayed(const Duration(seconds: 3), () => mounted ? setState(() {}) : null);
                  return;
                }
                _delArmed = DateTime(0);
                g.deleteEdited();
              }),
      ]),
    ];
  }

  // ---------- folhas (bottom sheets) ----------
  Future<void> _sheet(Palette c, String title, Widget Function(BuildContext) body) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: c.paper,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(tr(title), style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: c.ink)),
                const SizedBox(height: 12),
                body(ctx),
              ]),
            ),
          ),
        ),
      );

  void _levelSheet(Palette c) => _sheet(c, 'Fases', (ctx) {
        Widget tile(Level l, String number) {
          final pr = g.progress, open = pr.isUnlocked(l.id!), stars = pr.starsOf(l.id!);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            selected: l.id == g.level.id,
            leading: Text(number, style: GoogleFonts.chakraPetch(fontSize: 18, fontWeight: FontWeight.w700, color: pr.isDone(l.id!) ? c.zone : c.muted)),
            title: Text(tr(l.name), style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: open ? c.ink : c.muted)),
            trailing: open
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var k = 0; k < 3; k++) Icon(k < stars ? Icons.star : Icons.star_border, size: 18, color: k < stars ? c.medal : c.line),
                  ])
                : Icon(Icons.lock_outline, color: c.muted),
            onTap: () {
              Navigator.of(ctx).pop();
              g.chooseLevel(l.id!);
            },
          );
        }

        return Column(children: [
          for (final (i, l) in kBuiltin.indexed) tile(l, (i + 1).toString().padLeft(2, '0')),
          if (g.progress.custom.isNotEmpty) ...[
            const Divider(),
            for (final l in g.progress.custom) tile(l, '★'),
          ],
        ]);
      });

  void _infoSheet(Palette c) => _sheet(c, 'Metas e desafios', (ctx) {
        final lv = g.level, badges = g.progress.badgesOf(lv.id!);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (g.progress.isCustom(lv.id)) ...[
            Row(children: [
              Icon(lv.verified ? Icons.verified : Icons.help_outline, size: 18, color: lv.verified ? c.zone : c.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(tr(lv.verified ? 'Verificada: o autor venceu esta fase do jeito que ela está.' : 'Ainda não verificada: ninguém venceu esta fase do jeito que ela está.'),
                    style: GoogleFonts.ibmPlexSans(fontSize: 13, color: lv.verified ? c.zone : c.muted)),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          if (lv.tip.isNotEmpty) ...[
            Text(tr(lv.tip), style: GoogleFonts.ibmPlexSans(fontSize: 14.5, height: 1.4, color: c.ink)),
            const SizedBox(height: 14),
          ],
          label(c, 'Medalhas'),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (on, text, rec) in g.medalChips) Tooltip(message: rec, child: MedalChip(c: c, on: on, text: text)),
          ]),
          const SizedBox(height: 16),
          label(c, 'Desafios extras'),
          const SizedBox(height: 4),
          for (final (id, name, desc) in kChallenges)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(badges.contains(id) ? Icons.verified : Icons.verified_outlined, color: badges.contains(id) ? c.zone : c.muted),
              title: Text(tr(name), style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink)),
              subtitle: Text(tr(desc), style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
            ),
          if (lv.allowed != null) ...[
            const SizedBox(height: 10),
            label(c, 'Peças liberadas nesta fase'),
            const SizedBox(height: 6),
            Text(lv.allowed!.map((t) => tr(kPieceNames[t]!)).join(', '), style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink)),
          ],
          if (lv.looseBall || lv.budget != null) ...[
            const SizedBox(height: 10),
            label(c, 'Regras desta fase'),
            const SizedBox(height: 6),
            if (lv.looseBall)
              Text(tr('Bola solta: nenhuma peça pode ser presa à bola, e ela não liga o motor de uma roda.'),
                  style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink)),
            if (lv.budget != null)
              Text(tr('Orçamento: a engenhoca pode custar no máximo \${b}.', {'b': lv.budget}), style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink)),
          ],
        ]);
      });

  /// Compartilhar: um link que abre o jogo direto nesta fase com a engenhoca montada.
  /// Embaixo, um campo para colar um link ou código recebido (e o código antigo, OG1:).
  void _shareSheet(Palette c) {
    final link = g.linkFor(pageUrl());
    final paste = TextEditingController();
    Future<void> copy(BuildContext ctx, String text, String msg) async {
      await Clipboard.setData(ClipboardData(text: text));
      if (ctx.mounted) Navigator.of(ctx).pop();
      g.tell(msg);
    }

    final sub = GoogleFonts.ibmPlexSans(fontSize: 13.5, color: c.muted);
    _sheet(c, 'Compartilhar', (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('O link abre o jogo nesta fase com a sua engenhoca montada. Mande para alguém tentar bater o seu tempo.'), style: sub),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.bg, borderRadius: BorderRadius.circular(8), border: Border.all(color: c.line)),
            child: Text(link, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: c.ink)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            TB(
                c: c,
                primary: true,
                icon: Icons.ios_share,
                label: 'Compartilhar link',
                onTap: () async {
                  final ok = await systemShare(link, 'Geringonça: ${tr(g.level.name)}');
                  if (!ok && ctx.mounted) return copy(ctx, link, tr('Link copiado. Cole numa conversa para compartilhar.'));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                }),
            TB(c: c, icon: Icons.link, label: 'Copiar link', onTap: () => copy(ctx, link, tr('Link copiado.'))),
            TB(c: c, icon: Icons.copy, label: 'Copiar código', onTap: () => copy(ctx, g.currentCode(), tr('Código copiado.'))),
          ]),
          const SizedBox(height: 18),
          Text(tr('Recebeu um link ou código? Cole aqui:'), style: sub),
          const SizedBox(height: 8),
          TextField(
            controller: paste,
            minLines: 1,
            maxLines: 4,
            style: GoogleFonts.ibmPlexMono(fontSize: 12, color: c.ink),
            decoration: InputDecoration(
                hintText: tr('https://…#c=…  ou  OG1:…'),
                filled: true,
                fillColor: c.bg,
                border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TB(
                c: c,
                icon: Icons.file_open_outlined,
                label: 'Abrir',
                onTap: () {
                  if (paste.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop();
                  g.importCode(paste.text);
                }),
          ),
        ])).whenComplete(paste.dispose);
  }

  void _howTo(Palette c) => _sheet(c, 'Como jogar', (_) => HowToPlay(c: c));
}
