import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/levels.dart';
import '../core/model.dart';
import '../game/controller.dart';
import '../game/oficina_game.dart';
import '../game/palette.dart';

class HomePage extends StatefulWidget {
  final GameController g;
  const HomePage({super.key, required this.g});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  GameController get g => widget.g;
  late final OficinaGame _game;
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _tg = {'t': TextEditingController(), 'n': TextEditingController(), 'c': TextEditingController()};
  Object? _editKey;
  DateTime _delArmed = DateTime(0);

  @override
  void initState() {
    super.initState();
    _game = OficinaGame(g, mono: GoogleFonts.ibmPlexMono().fontFamily!, display: GoogleFonts.chakraPetch().fontFamily!);
    g.addListener(_sync);
  }

  /// Copia para os campos de texto o que mudou no controlador (abrir código, editor, desfazer).
  void _sync() {
    if (g.shareOpen && _code.text.isEmpty) _code.text = g.shareCode;
    if (!g.shareOpen) _code.clear();
    final key = g.mode == Mode.edit ? (g.editLevel, g.editRev) : null;
    if (key != _editKey) {
      _editKey = key;
      final lv = g.editLevel;
      if (lv != null) {
        _name.text = lv.name;
        final tg = {'t': lv.targets.t, 'n': lv.targets.n, 'c': lv.targets.c};
        _tg.forEach((k, c) => c.text = tg[k] == null ? '' : tg[k].toString().replaceAll('.', ','));
      }
    }
  }

  @override
  void dispose() {
    g.removeListener(_sync);
    _code.dispose();
    _name.dispose();
    for (final c in _tg.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: g,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(c),
                    const SizedBox(height: 10),
                    _levelRow(c),
                    if (g.shareOpen) ...[const SizedBox(height: 10), _sharePanel(c)],
                    const SizedBox(height: 10),
                    if (g.mode != Mode.edit) _buildBars(c) else _editBar(c),
                    const SizedBox(height: 10),
                    _bench(c),
                    const SizedBox(height: 10),
                    _status(c),
                    const SizedBox(height: 6),
                    Text(g.hint,
                        style: GoogleFonts.ibmPlexMono(
                            fontSize: 13, color: g.hintWin ? c.goal : c.muted, fontWeight: g.hintWin ? FontWeight.w500 : FontWeight.w400)),
                    _notes(c),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Palette c) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 16,
        runSpacing: 6,
        children: [
          Text('Oficina Geringonça', style: GoogleFonts.chakraPetch(fontSize: 30, fontWeight: FontWeight.w700, color: c.ink)),
          Text('Barras, rodas, ímãs e juntas em Box2D', style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.muted)),
        ],
      );

  Widget _label(Palette c, String s) =>
      Text(s.toUpperCase(), style: GoogleFonts.ibmPlexMono(fontSize: 11.5, letterSpacing: 1, color: c.muted));

  Widget _levelRow(Palette c) {
    final run = g.mode == Mode.run, edit = g.mode == Mode.edit;
    final best = g.best;
    final items = <DropdownMenuItem<String>>[];
    void group(String title, List<Level> list) {
      if (list.isEmpty) return;
      items.add(DropdownMenuItem(enabled: false, value: '#$title', child: _label(c, title)));
      for (final l in list) {
        final stars = g.starsOf(l.id!);
        items.add(DropdownMenuItem(
          value: l.id,
          child: Text('${g.isDone(l.id!) ? '✓ ' : ''}${l.name}${stars > 0 ? ' ${'★' * stars}' : ''}',
              overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink)),
        ));
      }
    }

    group('Fases', kBuiltin);
    group('Minhas fases', g.custom);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _label(c, 'Fase'),
        _Boxed(
          c: c,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: g.level.id,
              isDense: true,
              dropdownColor: c.paper,
              items: items,
              onChanged: edit ? null : (v) => v != null && !v.startsWith('#') ? g.chooseLevel(v) : null,
            ),
          ),
        ),
        for (final (on, text, rec) in g.medalChips)
          Tooltip(
            message: rec,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: on ? c.medal : null,
                border: Border.all(color: on ? c.medal : c.line),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('${on ? '★' : '☆'} $text', style: GoogleFonts.ibmPlexMono(fontSize: 12.5, color: on ? c.medalInk : c.muted)),
            ),
          ),
        TB(c: c, label: 'Melhor solução', tooltip: best != null ? 'Melhor tempo: ${fmt((best['time'] as num).toDouble())} s' : 'Conclua a fase para guardar uma solução', onTap: best == null || g.mode != Mode.build ? null : g.replay),
        TB(c: c, label: 'Compartilhar', onTap: run || edit ? null : g.toggleShare),
        TB(c: c, label: 'Editar fase', onTap: run || edit ? null : g.editCurrent),
        TB(c: c, label: 'Nova fase', onTap: run || edit ? null : g.newLevel),
      ],
    );
  }

  Widget _sharePanel(Palette c) => _Panel(
        c: c,
        children: [
          _label(c, 'Código da fase com a sua engenhoca'),
          TextField(
            controller: _code,
            minLines: 3,
            maxLines: 6,
            style: GoogleFonts.ibmPlexMono(fontSize: 12, color: c.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: c.bg,
              isDense: true,
              border: OutlineInputBorder(borderSide: BorderSide(color: c.line)),
            ),
          ),
          Text('Envie o código para alguém. Para abrir um código recebido, apague este, cole o novo e toque em Importar.',
              style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
          Row(children: [
            TB(
                c: c,
                label: 'Copiar',
                onTap: () async {
                  if (_code.text.trim().isEmpty) _code.text = g.currentCode();
                  await Clipboard.setData(ClipboardData(text: _code.text));
                  g.say('Código copiado.');
                  setState(() {});
                }),
            const SizedBox(width: 6),
            TB(c: c, label: 'Importar', onTap: () => g.importCode(_code.text)),
            const Spacer(),
            TB(c: c, label: 'Fechar', onTap: g.closeShare),
          ]),
        ],
      );

  Widget _buildBars(Palette c) {
    final run = g.mode == Mode.run;
    Widget tool(String id, String label, Widget sw, [String? cost]) =>
        TB(c: c, label: label, leading: sw, cost: cost, pressed: g.tool == id, onTap: run ? null : () => g.setTool(id));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        tool('rod', 'Barra', Sw.bar(c.rod), '\$10'),
        tool('water', 'Vazada', Sw.bar(c.water.withValues(alpha: .6)), '\$5'),
        tool('cw', 'Roda ↻', Sw.dot(c.cw, c.ink), '\$25'),
        tool('ccw', 'Roda ↺', Sw.dot(c.ccw, c.ink), '\$25'),
        tool('free', 'Livre', Sw.dot(c.free, c.ink), '\$15'),
        tool('magN', 'Ímã N', Sw.mag(c.mN, c.ink, 'N'), '\$30'),
        tool('magS', 'Ímã S', Sw.mag(c.mS, c.ink, 'S'), '\$30'),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TB(c: c, label: 'Mover', pressed: g.tool == 'move', onTap: run ? null : () => g.setTool('move')),
            TB(c: c, label: 'Selecionar', pressed: g.tool == 'select', onTap: run ? null : () => g.setTool('select')),
            TB(c: c, label: 'Apagar', pressed: g.tool == 'del', onTap: run ? null : () => g.setTool('del')),
            Container(width: 1, height: 28, color: c.line, margin: const EdgeInsets.symmetric(horizontal: 4)),
            TB(c: c, label: 'Desfazer', onTap: run ? null : g.undo),
            TB(c: c, label: 'Limpar', onTap: run ? null : g.clear),
            TB(c: c, label: 'Exemplo', onTap: run ? null : g.loadSample),
          ]),
        ),
        const SizedBox(width: 6),
        TB(c: c, label: run ? '■ Parar' : '▶ Rodar', primary: true, running: run, onTap: g.togglePlay),
      ]),
      if (g.showSelBar) ...[
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _label(c, g.selText),
          TB(c: c, label: 'Tudo', onTap: g.selectAll),
          TB(c: c, label: 'Duplicar', onTap: g.duplicateSel),
          TB(c: c, label: '↺ 15°', onTap: () => g.rotateSel(-15)),
          TB(c: c, label: '↻ 15°', onTap: () => g.rotateSel(15)),
          TB(c: c, label: 'Apagar seleção', onTap: g.deleteSel),
        ]),
      ],
    ]);
  }

  Widget _num(Palette c, String k, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted)),
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

  Widget _editBar(Palette c) {
    final lv = g.editLevel!;
    Widget et(String id, String label, Widget sw) => TB(c: c, label: label, leading: sw, pressed: g.etool == id, onTap: () => g.setETool(id));
    final armed = DateTime.now().difference(_delArmed).inMilliseconds < 3000;
    return _Panel(c: c, dashed: true, children: [
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _label(c, 'Editor'),
        _label(c, 'Nome'),
        SizedBox(
          width: 220,
          child: TextField(
            controller: _name,
            maxLength: 40,
            onChanged: g.setEditName,
            style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink),
            decoration: InputDecoration(counterText: '', isDense: true, border: OutlineInputBorder(borderSide: BorderSide(color: c.line))),
          ),
        ),
        TB(c: c, label: 'Chão', pressed: lv.ground, onTap: g.toggleGround),
      ]),
      Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
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
        TB(c: c, label: 'Apagar', pressed: g.etool == 'edel', onTap: () => g.setETool('edel')),
        Container(width: 1, height: 28, color: c.line, margin: const EdgeInsets.symmetric(horizontal: 4)),
        TB(c: c, label: 'Desfazer', onTap: g.editUndo),
      ]),
      Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        _label(c, 'Metas das medalhas'),
        _num(c, 't', 'Tempo (s)'),
        _num(c, 'n', 'Peças'),
        _num(c, 'c', 'Custo'),
      ]),
      Row(children: [
        if (g.canDeleteEdited)
          TB(
              c: c,
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
        const Spacer(),
        TB(c: c, label: 'Cancelar', onTap: g.cancelEdit),
        const SizedBox(width: 6),
        TB(c: c, label: 'Salvar fase', primary: true, onTap: g.saveEdit),
      ]),
    ]);
  }

  /// A bancada é um jogo Flame; os toques, o zoom e o desenho ficam com ele.
  Widget _bench(Palette c) {
    _game.palette = c;
    return Container(
      decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8), color: c.paper),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: kW / kH,
        child: MouseRegion(
          cursor: g.panMode ? SystemMouseCursors.grab : SystemMouseCursors.precise,
          child: GameWidget(game: _game),
        ),
      ),
    );
  }

  Widget _status(Palette c) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 6,
        children: [
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            TB(c: c, label: '−', small: true, tooltip: 'Afastar', onTap: g.zoomOut),
            Text('×${fmt(g.cam.z, 1)}', style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.muted)),
            TB(c: c, label: '+', small: true, tooltip: 'Aproximar', onTap: g.zoomIn),
            TB(c: c, label: 'Área verde', small: true, onTap: g.zoomZone),
            TB(c: c, label: 'Tudo', small: true, onTap: g.zoomFit),
            TB(c: c, label: '✋ Mão', small: true, pressed: g.panMode, onTap: g.togglePan),
          ]),
          Text(g.countText, style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.muted, fontFeatures: const [FontFeature.tabularFigures()])),
        ],
      );

  Widget _notes(Palette c) {
    Widget note(String h, String p) => SizedBox(
          width: 300,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(h, style: GoogleFonts.chakraPetch(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink)),
            const SizedBox(height: 6),
            Text(p, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink, height: 1.5)),
          ]),
        );
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 18),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.line))),
      child: Wrap(spacing: 28, runSpacing: 18, children: [
        note('Medalhas',
            'Cada fase tem três: tempo, número de peças e custo. Não precisa ganhar todas na mesma engenhoca. A solução mais rápida fica guardada em Melhor solução.'),
        note('Cenário que se move',
            'Elevadores sobem e descem sem parar. Gangorras giram no eixo do meio. Portas abrem quando algo pisa num botão; numa fase sem botões, elas abrem e fecham a cada 2 s.'),
        note('Seleção e zoom',
            'Use dois dedos para aproximar e arrastar a tela (no computador, Ctrl + rolagem). Em Selecionar, marque várias peças para mover, duplicar ou girar de uma vez.'),
        note('Peças entre si',
            'Rodas, ímãs e a bola rolam por cima de barras sólidas, como numa ponte. Peças presas à roda ou à bola por uma junta, como o eixo, passam por dentro delas. Cada roda tem 4 pontos de conexão na borda, a cada π/2; uma barra presa neles gira junto, como uma manivela. Barras vazadas atravessam tudo. Ímã norte (vermelho) atrai sul (azul) e repele norte.'),
      ]),
    );
  }
}

/// Amostras de cor dos botões de peça.
class Sw extends StatelessWidget {
  final Color color;
  final Color? border;
  final double w, h, radius;
  final String? letter;
  const Sw._(this.color, {this.border, this.w = 14, this.h = 14, this.radius = 7, this.letter});
  factory Sw.dot(Color c, Color ink) => Sw._(c, border: ink);
  factory Sw.bar(Color c) => Sw._(c, w: 18, h: 6, radius: 3);
  factory Sw.sq(Color c) => Sw._(c, radius: 3);
  factory Sw.mag(Color c, Color ink, String l) => Sw._(c, border: ink, letter: l);
  @override
  Widget build(BuildContext context) => Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
          border: border != null ? Border.all(color: border!, width: 1.5) : null,
        ),
        child: letter != null
            ? Text(letter!, style: GoogleFonts.ibmPlexMono(fontSize: 8, height: 1, fontWeight: FontWeight.w700, color: Colors.white))
            : null,
      );
}

/// Botão compacto da oficina.
class TB extends StatelessWidget {
  final Palette c;
  final String label;
  final String? cost, tooltip;
  final Widget? leading;
  final bool pressed, primary, running, small;
  final VoidCallback? onTap;
  const TB({
    super.key,
    required this.c,
    required this.label,
    this.cost,
    this.tooltip,
    this.leading,
    this.pressed = false,
    this.primary = false,
    this.running = false,
    this.small = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary ? (running ? c.goal : c.ink) : c.paper;
    final fg = primary ? (running ? Colors.white : c.paper) : c.ink;
    final bd = primary ? bg : (pressed ? c.ink : c.line);
    final style = primary
        ? GoogleFonts.chakraPetch(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: .6, color: fg)
        : GoogleFonts.ibmPlexSans(fontSize: small ? 13 : 13.5, fontWeight: FontWeight.w500, color: fg);
    Widget btn = Opacity(
      opacity: onTap == null ? .45 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: bd, width: pressed && !primary ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: primary ? 16 : 10, vertical: small ? 6 : 8),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (leading != null) ...[leading!, const SizedBox(width: 7)],
              Text(primary ? label.toUpperCase() : label, style: style),
              if (cost != null) ...[
                const SizedBox(width: 6),
                Text(cost!, style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
              ],
            ]),
          ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tooltip!, child: btn);
    return btn;
  }
}

class _Boxed extends StatelessWidget {
  final Palette c;
  final Widget child;
  const _Boxed({required this.c, required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: c.paper, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
        child: child,
      );
}

class _Panel extends StatelessWidget {
  final Palette c;
  final List<Widget> children;
  final bool dashed;
  const _Panel({required this.c, required this.children, this.dashed = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.paper,
          border: Border.all(color: dashed ? c.accent : c.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
          ],
        ),
      );
}
