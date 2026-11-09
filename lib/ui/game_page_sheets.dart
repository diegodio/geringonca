part of 'game_page.dart';

/// Folhas que sobem de baixo: lista de fases, metas e desafios, compartilhar e como jogar.
extension _Sheets on _GamePageState {
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
