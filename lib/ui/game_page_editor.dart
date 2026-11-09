part of 'game_page.dart';

/// Painel do editor de fases: abas Desenhar, Regras e Fase, propriedades do selecionado e ações.
extension _Editor on _GamePageState {
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
        for (final (i, t) in tabs.indexed) TB(c: c, small: true, label: t, pressed: _edTab == i, onTap: () => _rebuild(() => _edTab = i)),
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
                  _rebuild(() => _delArmed = DateTime.now());
                  Future.delayed(const Duration(seconds: 3), () => mounted ? _rebuild(() {}) : null);
                  return;
                }
                _delArmed = DateTime(0);
                g.deleteEdited();
              }),
      ]),
    ];
  }
}
