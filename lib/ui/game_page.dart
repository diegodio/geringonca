// Tela do jogo, pensada primeiro para celular e tablet:
//   barra superior  voltar, fase (abre a lista), medalhas (abre as metas) e menu ⋮
//   bancada         ocupa todo o espaço que sobra, sem rolar a página
//   dock            muda com o momento: construir, rodar ou a tela de vitória
// Com a tela deitada o dock vai para a lateral, para a bancada usar a altura toda
// (nas Opções dá para fixar sempre na lateral ou sempre embaixo).
//
// Este arquivo tem a barra, os layouts e a bancada; o resto fica ao lado:
//   game_page_dock.dart    peças, ferramentas e controles de rodar
//   game_page_editor.dart  painel do editor de fases
//   game_page_sheets.dart  lista de fases, metas, compartilhar e como jogar
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

part 'game_page_dock.dart';
part 'game_page_editor.dart';
part 'game_page_sheets.dart';

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
    // qualquer mudança no jogo acorda a bancada (ela para de desenhar quando nada muda);
    // a escuta fica aqui porque a bancada pode ser recriada e perder a dela
    g.addListener(_game.wake);
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
    g.removeListener(_game.wake);
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

  /// Para as partes em outros arquivos (game_page_*.dart) pedirem para redesenhar.
  void _rebuild(VoidCallback f) => setState(f);
}
