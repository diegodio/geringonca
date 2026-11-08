import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../core/levels.dart';
import '../core/model.dart';
import '../game/controller.dart';
import '../game/palette.dart';
import 'game_page.dart';
import 'how_to_play.dart';
import 'logo.dart';
import 'options.dart';
import 'templates.dart';
import 'widgets.dart';

/// Menu inicial: continuar, escolher fase, criar fase e como jogar.
class MenuPage extends StatelessWidget {
  final GameController g;
  const MenuPage({super.key, required this.g});

  /// Abre a bancada; [prepare] escolhe a fase ou abre o editor antes.
  Future<void> _play(BuildContext context, [VoidCallback? prepare]) async {
    prepare?.call();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GamePage(g: g)));
  }

  void _openLevel(BuildContext context, Level lv) {
    final blocker = g.progress.blocker(lv.id!);
    if (blocker != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(tr('Conclua "{b}" para liberar "{lv}".', {'b': tr(blocker.name), 'lv': tr(lv.name)}))));
      return;
    }
    _play(context, () => g.chooseLevel(lv.id!));
  }

  @override
  Widget build(BuildContext context) {
    final c = Palette.of(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: g,
          builder: (context, _) {
            final pr = g.progress;
            final done = kBuiltin.where((l) => pr.isDone(l.id!)).length;
            final stars = kBuiltin.fold(0, (s, l) => s + pr.starsOf(l.id!));
            final maxStars = kBuiltin.fold(0, (s, l) => s + _targetCount(l));
            final started = done > 0 || pr.savedParts(g.level.id!) != null;
            final low = MediaQuery.of(context).size.height < 500; // celular deitado
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, low ? 12 : 28, 16, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // o nome montado com as peças; encolhe se a tela for estreita
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FittedBox(fit: BoxFit.scaleDown, child: LogoWord(height: low ? 64 : 112)),
                        ),
                      ),
                      // opções num canto discreto: sons, vibração e posição do painel
                      IconButton(
                        tooltip: 'Opções',
                        icon: Icon(Icons.tune, color: c.muted, size: 22),
                        onPressed: () => showOptions(context, g),
                      ),
                    ]),
                    SizedBox(height: low ? 8 : 12),
                    Text(tr('Monte engenhocas com barras, rodas e ímãs e leve a bola até a meta.'),
                        style: GoogleFonts.ibmPlexSans(fontSize: 16, color: c.muted)),
                    SizedBox(height: low ? 10 : 20),
                    Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      TB(
                        c: c,
                        primary: true,
                        label: started ? tr('▶ Continuar: {n}', {'n': tr(g.level.name)}) : tr('▶ Começar'),
                        onTap: () => _play(context, () => g.chooseLevel(g.level.id!)),
                      ),
                      TB(
                          c: c,
                          label: 'Criar fase',
                          onTap: () async {
                            final t = await pickTemplate(context, c);
                            if (t != null && context.mounted) _play(context, () => g.newLevel(t));
                          }),
                      TB(c: c, label: 'Como jogar', onTap: () => _howTo(context, c)),
                    ]),
                    const SizedBox(height: 14),
                    Text(tr('{d} de {t} fases concluídas · {s} de {m} medalhas', {'d': done, 't': kBuiltin.length, 's': stars, 'm': maxStars}),
                        style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.muted)),
                    const SizedBox(height: 26),
                    // um bloco por capítulo, em ordem de dificuldade
                    for (final (ci, (title, sub, count)) in kChapters.indexed) ...[
                      if (ci > 0) const SizedBox(height: 26),
                      Builder(builder: (context) {
                        final first = kChapters.take(ci).fold(0, (a, ch) => a + ch.$3);
                        final levels = kBuiltin.skip(first).take(count).toList();
                        final doneHere = levels.where((l) => pr.isDone(l.id!)).length;
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          _section(c, tr('Capítulo {n} · {t}', {'n': ci + 1, 't': tr(title)}), tr('{s} · {d} de {c} concluídas', {'s': tr(sub), 'd': doneHere, 'c': count})),
                          const SizedBox(height: 12),
                          _grid([
                            for (final (i, lv) in levels.indexed)
                              (w) => _LevelCard(c: c, g: g, lv: lv, number: first + i + 1, width: w, onTap: () => _openLevel(context, lv)),
                          ]),
                        ]);
                      }),
                    ],
                    if (pr.custom.isNotEmpty) ...[
                      const SizedBox(height: 26),
                      _section(c, tr('Minhas fases'), tr('Criadas no editor ou recebidas por código. Estão sempre liberadas.')),
                      const SizedBox(height: 12),
                      _grid([
                        for (final lv in pr.custom) (w) => _LevelCard(c: c, g: g, lv: lv, width: w, onTap: () => _openLevel(context, lv)),
                      ]),
                    ],
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Grade que divide a largura em colunas iguais: 2 no celular, até 5 no computador.
  Widget _grid(List<Widget Function(double)> cards) => LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        final cols = ((box.maxWidth + gap) / (180 + gap)).floor().clamp(2, 5);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final card in cards) card(w)]);
      });

  static int _targetCount(Level l) => [l.targets.t, l.targets.n, l.targets.c].where((v) => v != null).length;

  Widget _section(Palette c, String title, String sub) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 2),
        Text(sub, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.muted)),
      ]);

  void _howTo(BuildContext context, Palette c) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: c.paper,
          title: Text(tr('Como jogar'), style: GoogleFonts.chakraPetch(fontWeight: FontWeight.w700, color: c.ink)),
          content: SingleChildScrollView(child: HowToPlay(c: c)),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('Fechar')))],
        ),
      );
}

/// Cartão de uma fase: número, nome, medalhas e situação (concluída, nova ou bloqueada).
class _LevelCard extends StatelessWidget {
  final Palette c;
  final GameController g;
  final Level lv;
  final int? number;
  final double width;
  final VoidCallback onTap;
  const _LevelCard({required this.c, required this.g, required this.lv, this.number, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pr = g.progress, id = lv.id!, open = pr.isUnlocked(id), done = pr.isDone(id);
    final m = pr.medalsOf(id), tg = lv.targets;
    final medals = [if (tg.t != null) m['t'] == true, if (tg.n != null) m['n'] == true, if (tg.c != null) m['c'] == true];
    final current = g.level.id == id;
    // bloqueada: aponta a fase anterior pelo número, que cabe no cartão
    final status = !open ? tr('Conclua a {n}', {'n': (number! - 1).toString().padLeft(2, '0')}) : tr(done ? 'Concluída' : 'Nova');
    return SizedBox(
      width: width,
      child: Opacity(
        opacity: open ? 1 : .55,
        child: Material(
          color: c.paper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: current && open ? c.ink : c.line, width: current && open ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (number != null)
                    Text(number!.toString().padLeft(2, '0'),
                        style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: done ? c.zone : c.muted)),
                  const Spacer(),
                  if (!open) Icon(Icons.lock_outline, size: 18, color: c.muted),
                  if (open && done) Icon(Icons.check_circle_outline, size: 18, color: c.zone),
                ]),
                const SizedBox(height: 4),
                Text(tr(lv.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink)),
                const SizedBox(height: 6),
                Row(children: [
                  for (final on in medals) Icon(on ? Icons.star : Icons.star_border, size: 18, color: on ? c.medal : c.muted),
                  // desafios extras ganhos nesta fase
                  if (pr.badgesOf(id).isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: tr('Desafios extras ganhos'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified, size: 16, color: c.zone),
                        Text('${pr.badgesOf(id).length}', style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.zone)),
                      ]),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
