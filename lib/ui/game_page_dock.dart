part of 'game_page.dart';

/// Dock da bancada: peças e ferramentas ao construir, controles ao rodar, vitória.
extension _Dock on _GamePageState {
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
}
