import 'dart:math' as math;

import 'package:flutter/material.dart' hide Ink;
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../core/levels.dart';
import '../core/model.dart';
import '../game/controller.dart';
import '../game/ink.dart';
import '../game/palette.dart';
import 'game_page.dart';
import 'how_to_play.dart';
import 'level_thumb.dart';
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
    final ink = Ink(g, c, mono: GoogleFonts.ibmPlexMono().fontFamily!, display: GoogleFonts.chakraPetch().fontFamily!);
    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(children: [
        // o menu inteiro é uma folha do caderno de laboratório, em papel milimetrado
        Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: _GraphPaper(c)))),
        SafeArea(
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
                padding: EdgeInsets.fromLTRB(16, low ? 12 : 24, 16, 40),
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
                          tooltip: tr('Opções'),
                          icon: Icon(Icons.tune, color: c.muted, size: 22),
                          onPressed: () => showOptions(context, g),
                        ),
                      ]),
                      // a bancada: uma barra de madeira com juntas, como no jogo
                      SizedBox(height: 18, child: CustomPaint(painter: _BenchRule(c))),
                      SizedBox(height: low ? 8 : 12),
                      Text(tr('Monte engenhocas com barras, rodas e ímãs e leve a bola até a meta.'),
                          style: GoogleFonts.ibmPlexSans(fontSize: 16, color: c.ink.withValues(alpha: .75))),
                      SizedBox(height: low ? 10 : 18),
                      Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        TB(
                          c: c,
                          primary: true,
                          label: started ? tr('▶ Continuar: {n}', {'n': tr(g.level.name)}) : tr('▶ Começar'),
                          // na primeira visita, Começar abre o tutorial guiado
                          onTap: () => _play(context, () => !started && !g.tutSeen ? g.startTutorial() : g.chooseLevel(g.level.id!)),
                        ),
                        TB(c: c, icon: Icons.school_outlined, label: 'Tutorial', onTap: () => _play(context, g.startTutorial)),
                        TB(
                            c: c,
                            icon: Icons.architecture,
                            label: 'Criar fase',
                            onTap: () async {
                              final t = await pickTemplate(context, c);
                              if (t != null && context.mounted) _play(context, () => g.newLevel(t));
                            }),
                        TB(c: c, icon: Icons.menu_book_outlined, label: 'Como jogar', onTap: () => _howTo(context, c)),
                      ]),
                      const SizedBox(height: 18),
                      _ProgressCard(c: c, g: g, done: done, stars: stars, maxStars: maxStars),
                      const SizedBox(height: 26),
                      // uma prancha por capítulo, em ordem de dificuldade
                      for (final (ci, (title, sub, count)) in kChapters.indexed) ...[
                        if (ci > 0) const SizedBox(height: 22),
                        Builder(builder: (context) {
                          final first = kChapters.take(ci).fold(0, (a, ch) => a + ch.$3);
                          final levels = kBuiltin.skip(first).take(count).toList();
                          final doneHere = levels.where((l) => pr.isDone(l.id!)).length;
                          return _Sheet(
                            c: c,
                            number: ci + 1,
                            title: tr(title),
                            sub: tr(sub),
                            done: doneHere,
                            count: count,
                            child: _grid([
                              for (final (i, lv) in levels.indexed)
                                (w) => _LevelCard(c: c, g: g, ink: ink, lv: lv, number: first + i + 1, width: w, onTap: () => _openLevel(context, lv)),
                            ]),
                          );
                        }),
                      ],
                      if (pr.custom.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        _Sheet(
                          c: c,
                          title: tr('Minhas fases'),
                          sub: tr('Criadas no editor ou recebidas por código. Estão sempre liberadas.'),
                          child: _grid([
                            for (final lv in pr.custom) (w) => _LevelCard(c: c, g: g, ink: ink, lv: lv, width: w, onTap: () => _openLevel(context, lv)),
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  /// Grade que divide a largura em colunas iguais: 2 no celular, até 5 no computador.
  Widget _grid(List<Widget Function(double)> cards) => LayoutBuilder(builder: (context, box) {
        const gap = 10.0;
        final cols = ((box.maxWidth + gap) / (190 + gap)).floor().clamp(2, 5);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final card in cards) card(w)]);
      });

  static int _targetCount(Level l) => [l.targets.t, l.targets.n, l.targets.c].where((v) => v != null).length;

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

/// Cartão de uma fase: miniatura da bancada, número, nome, medalhas e situação
/// (concluída, nova ou bloqueada).
class _LevelCard extends StatelessWidget {
  final Palette c;
  final GameController g;
  final Ink ink;
  final Level lv;
  final int? number;
  final double width;
  final VoidCallback onTap;
  const _LevelCard({required this.c, required this.g, required this.ink, required this.lv, this.number, required this.width, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pr = g.progress, id = lv.id!, open = pr.isUnlocked(id), done = pr.isDone(id);
    final m = pr.medalsOf(id), tg = lv.targets;
    final medals = [if (tg.t != null) m['t'] == true, if (tg.n != null) m['n'] == true, if (tg.c != null) m['c'] == true];
    final current = g.level.id == id && open;
    // bloqueada: aponta pelo número (que cabe no cartão) a fase que falta concluir
    final need = open ? 0 : kBuiltin.indexOf(pr.blocker(id)!) + 1;
    final status = !open ? tr('Conclua a {n}', {'n': need.toString().padLeft(2, '0')}) : tr(done ? 'Concluída' : 'Nova');
    return SizedBox(
      width: width,
      child: Material(
        color: c.paper,
        elevation: current ? 2 : 0,
        shadowColor: c.ink.withValues(alpha: .25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: current ? c.ink : c.line, width: current ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              LevelThumb(lv: lv, ink: ink, locked: !open),
              if (!open)
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: c.paper.withValues(alpha: .9), shape: BoxShape.circle, border: Border.all(color: c.line)),
                      child: Icon(Icons.lock_outline, size: 18, color: c.muted),
                    ),
                  ),
                ),
              // número da fase como etiqueta presa no canto da prancha
              if (number != null)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(7, 2, 8, 3),
                    decoration: BoxDecoration(
                      color: done ? c.zone : c.ink,
                      borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                    ),
                    child: Text(number!.toString().padLeft(2, '0'),
                        style: GoogleFonts.chakraPetch(fontSize: 15, height: 1.1, fontWeight: FontWeight.w700, color: c.paper)),
                  ),
                ),
              if (done)
                Positioned(
                  right: 6,
                  top: 5,
                  child: Transform.rotate(angle: -.18, child: _Stamp(c: c, text: tr('OK'))),
                ),
            ]),
            Container(height: 1, color: c.line),
            Padding(
              padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tr(lv.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ibmPlexSans(fontSize: 14.5, fontWeight: FontWeight.w600, color: open ? c.ink : c.muted)),
                const SizedBox(height: 4),
                Row(children: [
                  for (final on in medals) Icon(on ? Icons.star : Icons.star_border, size: 17, color: on ? c.medal : c.muted),
                  // desafios extras ganhos nesta fase
                  if (pr.badgesOf(id).isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: tr('Desafios extras ganhos'),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.verified, size: 15, color: c.zone),
                        Text('${pr.badgesOf(id).length}', style: GoogleFonts.ibmPlexMono(fontSize: 11, color: c.zone)),
                      ]),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(status,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.ibmPlexMono(fontSize: 11, color: current ? c.ink : c.muted)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Carimbo de "fase concluída" sobre a miniatura.
class _Stamp extends StatelessWidget {
  final Palette c;
  final String text;
  const _Stamp({required this.c, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.paper.withValues(alpha: .85),
          border: Border.all(color: c.zone, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: GoogleFonts.chakraPetch(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1.5, color: c.zone)),
      );
}

/// Prancha de um capítulo: cabeçalho com o número numa roda, título, subtítulo,
/// quantas fases foram concluídas (numa barra de madeira) e as fases embaixo.
class _Sheet extends StatelessWidget {
  final Palette c;
  final int? number;
  final String title, sub;
  final int done, count;
  final Widget child;
  const _Sheet({required this.c, this.number, required this.title, required this.sub, this.done = 0, this.count = 0, required this.child});

  @override
  Widget build(BuildContext context) {
    // cada capítulo tem a cor de uma peça
    final colors = [c.cw, c.rod, c.water, c.free, c.lift, c.mN, c.ccw];
    final col = number == null ? c.ball : colors[(number! - 1) % colors.length];
    return Container(
      decoration: BoxDecoration(
        color: c.paper.withValues(alpha: .93),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.line),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          SizedBox.square(dimension: 46, child: CustomPaint(painter: _ChapterWheel(c, col, number))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (number != null)
                Text(tr('CAPÍTULO {n}', {'n': number}), style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 1.2, color: c.muted)),
              Text(title, style: GoogleFonts.chakraPetch(fontSize: 22, height: 1.1, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: c.muted)),
            ]),
          ),
          if (count > 0) ...[
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$done/$count', style: GoogleFonts.chakraPetch(fontSize: 18, fontWeight: FontWeight.w700, color: done == count ? c.zone : c.ink)),
              const SizedBox(height: 4),
              SizedBox(width: 74, height: 12, child: CustomPaint(painter: _RodGauge(c, done / count))),
            ]),
          ],
        ]),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

/// Ficha de progresso: um cartão de anotações com fita nos cantos, as contas
/// gerais e uma barra de madeira com uma junta por capítulo.
class _ProgressCard extends StatelessWidget {
  final Palette c;
  final GameController g;
  final int done, stars, maxStars;
  const _ProgressCard({required this.c, required this.g, required this.done, required this.stars, required this.maxStars});

  @override
  Widget build(BuildContext context) {
    final pr = g.progress;
    final parts = <double>[];
    var first = 0;
    for (final (_, _, n) in kChapters) {
      parts.add(kBuiltin.skip(first).take(n).where((l) => pr.isDone(l.id!)).length / n);
      first += n;
    }
    TextStyle big(Color col) => GoogleFonts.chakraPetch(fontSize: 24, height: 1, fontWeight: FontWeight.w700, color: col);
    final small = GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted);
    return CustomPaint(
      foregroundPainter: _Tape(c),
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(color: c.paper, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4)),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            // margem vermelha de caderno
            const SizedBox(width: 18),
            Container(width: 1.5, color: c.goal.withValues(alpha: .45)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('FICHA DE PROGRESSO'), style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 1.2, color: c.muted)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 22, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.end, children: [
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('$done', style: big(c.ink)),
                      Text(' / ${kBuiltin.length} ', style: small),
                      Text(tr('fases'), style: small),
                    ]),
                    Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Icon(Icons.star, size: 22, color: c.medal),
                      Text(' $stars', style: big(c.ink)),
                      Text(' / $maxStars ', style: small),
                      Text(tr('medalhas'), style: small),
                    ]),
                  ]),
                  const SizedBox(height: 12),
                  SizedBox(width: double.infinity, height: 22, child: CustomPaint(painter: _ChapterRod(c, parts))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Fundo do menu: papel milimetrado, como a bancada.
class _GraphPaper extends CustomPainter {
  final Palette c;
  _GraphPaper(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = c.bg);
    final minor = Paint()
      ..color = c.grid.withValues(alpha: .55)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = c.gridMajor.withValues(alpha: .55)
      ..strokeWidth = 1;
    for (var x = 0.0, i = 0; x <= size.width; x += 20, i++) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    for (var y = 0.0, i = 0; y <= size.height; y += 20, i++) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(_GraphPaper old) => old.c != c;
}

/// Barra de madeira com juntas nas pontas e uma roda no fim, sob o logotipo.
class _BenchRule extends CustomPainter {
  final Palette c;
  _BenchRule(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2, end = size.width - 12;
    final wood = Paint()
      ..color = c.rod
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(6, y), Offset(end - 14, y), wood);
    final joint = Paint()..color = c.paper;
    final ring = Paint()
      ..color = c.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final x in [6.0, end - 14]) {
      canvas.drawCircle(Offset(x, y), 3.2, joint);
      canvas.drawCircle(Offset(x, y), 3.2, ring);
    }
    // roda com motor na ponta
    canvas.drawCircle(Offset(end, y), 8, Paint()..color = c.cw);
    canvas.drawCircle(Offset(end, y), 8, ring);
    canvas.drawLine(Offset(end - 5, y), Offset(end + 5, y), ring);
    canvas.drawLine(Offset(end, y - 5), Offset(end, y + 5), ring);
  }

  @override
  bool shouldRepaint(_BenchRule old) => old.c != c;
}

/// Número do capítulo dentro de uma roda, com raios, na cor do capítulo.
class _ChapterWheel extends CustomPainter {
  final Palette c;
  final Color col;
  final int? n;
  _ChapterWheel(this.c, this.col, this.n);
  @override
  void paint(Canvas canvas, Size size) {
    final o = size.center(Offset.zero), r = size.shortestSide / 2 - 1.5;
    final ink = Paint()
      ..color = c.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(o, r, Paint()..color = col);
    canvas.drawCircle(o, r, ink);
    // raios a cada 45°
    final spoke = Paint()
      ..color = c.paper.withValues(alpha: .8)
      ..strokeWidth = 2;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4 + math.pi / 8;
      canvas.drawLine(o + Offset(math.cos(a), math.sin(a)) * (r * .55), o + Offset(math.cos(a), math.sin(a)) * (r - 3), spoke);
    }
    canvas.drawCircle(o, r * .52, Paint()..color = c.paper);
    canvas.drawCircle(o, r * .52, ink..strokeWidth = 1.5);
    final tp = TextPainter(
      text: TextSpan(text: n == null ? '★' : '$n', style: GoogleFonts.chakraPetch(fontSize: r * .7, fontWeight: FontWeight.w700, color: c.ink)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_ChapterWheel old) => old.c != c || old.col != col || old.n != n;
}

/// Medidor em forma de barra: a parte feita é madeira; o resto, tracejado.
class _RodGauge extends CustomPainter {
  final Palette c;
  final double f;
  _RodGauge(this.c, this.f);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2, x0 = 4.0, x1 = size.width - 4;
    final dash = Paint()
      ..color = c.muted.withValues(alpha: .6)
      ..strokeWidth = 1.5;
    for (var x = x0; x < x1; x += 7) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 4, x1), y), dash);
    }
    if (f > 0) {
      canvas.drawLine(
          Offset(x0, y),
          Offset(x0 + (x1 - x0) * f, y),
          Paint()
            ..color = c.rod
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round);
    }
    final ring = Paint()
      ..color = c.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final x in [x0, x1]) {
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = c.paper);
      canvas.drawCircle(Offset(x, y), 3, ring);
    }
  }

  @override
  bool shouldRepaint(_RodGauge old) => old.c != c || old.f != f;
}

/// Barra do progresso geral: um trecho de madeira por capítulo, ligados por juntas;
/// cada trecho se enche conforme as fases do capítulo são concluídas.
class _ChapterRod extends CustomPainter {
  final Palette c;
  final List<double> parts;
  _ChapterRod(this.c, this.parts);
  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2, x0 = 6.0, x1 = size.width - 6;
    final seg = (x1 - x0) / parts.length;
    final empty = Paint()
      ..color = c.line
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final wood = Paint()
      ..color = c.rod
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(x0, y), Offset(x1, y), empty);
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] > 0) canvas.drawLine(Offset(x0 + seg * i, y), Offset(x0 + seg * (i + parts[i]), y), wood);
    }
    final ring = Paint()
      ..color = c.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var i = 0; i <= parts.length; i++) {
      final o = Offset(x0 + seg * i, y);
      canvas.drawCircle(o, 4.5, Paint()..color = i > 0 && parts[i - 1] >= 1 ? c.zone : c.paper);
      canvas.drawCircle(o, 4.5, ring);
    }
  }

  @override
  bool shouldRepaint(_ChapterRod old) => old.c != c || old.parts.join() != parts.join();
}

/// Duas tiras de fita adesiva prendendo a ficha no caderno.
class _Tape extends CustomPainter {
  final Palette c;
  _Tape(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final tape = Paint()..color = c.medal.withValues(alpha: .32);
    for (final (x, ang) in [(34.0, -.12), (size.width - 34, .1)]) {
      canvas.save();
      canvas.translate(x, 8);
      canvas.rotate(ang);
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 58, height: 16), tape);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_Tape old) => old.c != c;
}
