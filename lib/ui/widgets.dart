// Componentes visuais compartilhados: botões, amostras de cor e cartões.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../game/palette.dart';

/// Rótulo pequeno em caixa alta.
Widget label(Palette c, String s) =>
    Text(tr(s).toUpperCase(), style: GoogleFonts.ibmPlexMono(fontSize: 11, letterSpacing: 1, color: c.muted));

/// Amostras de cor das peças.
class Sw extends StatelessWidget {
  final Color color;
  final Color? border;
  final double w, h, radius;
  final String? letter;
  const Sw._(this.color, {this.border, this.w = 16, this.h = 16, this.radius = 8, this.letter});
  factory Sw.dot(Color c, Color ink) => Sw._(c, border: ink);
  factory Sw.bar(Color c) => Sw._(c, w: 22, h: 7, radius: 4);
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
            ? Text(letter!, style: GoogleFonts.ibmPlexMono(fontSize: 9, height: 1, fontWeight: FontWeight.w700, color: Colors.white))
            : null,
      );
}

/// Botão com texto. [primary] é o botão principal (escuro); [running] o deixa vermelho.
class TB extends StatelessWidget {
  final Palette c;
  final String label;
  final String? cost, tooltip;
  final Widget? leading;
  final IconData? icon;
  final bool pressed, primary, running, small;
  final VoidCallback? onTap;
  const TB({
    super.key,
    required this.c,
    required this.label,
    this.cost,
    this.tooltip,
    this.leading,
    this.icon,
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
        : GoogleFonts.ibmPlexSans(fontSize: small ? 13 : 14, fontWeight: FontWeight.w500, color: fg);
    Widget btn = Opacity(
      opacity: onTap == null ? .4 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: bd, width: pressed && !primary ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: small ? 36 : 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: primary ? 18 : 12),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(primary ? tr(label).toUpperCase() : tr(label), style: style),
                if (cost != null) ...[
                  const SizedBox(width: 6),
                  Text(cost!, style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) btn = Tooltip(message: tr(tooltip!), child: btn);
    return btn;
  }
}

/// Botão quadrado só com ícone, com área de toque de 44 px.
class IconBtn extends StatelessWidget {
  final Palette c;
  final IconData icon;
  final String tooltip;
  final bool pressed;

  /// Chave liga/desliga: ligada fica com contorno e ícone coloridos, para não parecer
  /// uma ferramenta escolhida.
  final bool toggle;
  final VoidCallback? onTap;
  final double size;
  const IconBtn(
      {super.key, required this.c, required this.icon, required this.tooltip, this.pressed = false, this.toggle = false, this.onTap, this.size = 44});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tr(tooltip),
        child: Opacity(
          opacity: onTap == null ? .35 : 1,
          child: Material(
            color: pressed && !toggle ? c.ink : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: toggle && pressed ? BorderSide(color: c.accent, width: 1.5) : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(icon, size: 22, color: toggle ? (pressed ? c.accent : c.muted) : (pressed ? c.paper : c.ink)),
              ),
            ),
          ),
        ),
      );
}

/// Botão redondo grande: Rodar, Parar.
class RoundAction extends StatelessWidget {
  final Palette c;
  final IconData icon;
  final String tooltip;
  final bool danger;
  final VoidCallback? onTap;
  const RoundAction({super.key, required this.c, required this.icon, required this.tooltip, this.danger = false, this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tr(tooltip),
        child: Material(
          color: danger ? c.goal : c.ink,
          shape: const CircleBorder(),
          elevation: 2,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 60, height: 60, child: Icon(icon, size: 32, color: danger ? Colors.white : c.paper)),
          ),
        ),
      );
}

/// Ficha de peça no dock: amostra, nome e preço; destacada quando escolhida.
class PieceChip extends StatelessWidget {
  final Palette c;
  final Widget swatch;
  final String name, cost;
  final bool selected, compact;
  final VoidCallback? onTap;
  const PieceChip(
      {super.key, required this.c, required this.swatch, required this.name, required this.cost, this.selected = false, this.compact = false, this.onTap});

  @override
  Widget build(BuildContext context) => compact ? _compact() : _full();

  /// Em linha: amostra, nome e preço, com 44 px de altura.
  Widget _compact() => Material(
        color: selected ? c.ink : c.bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              SizedBox(width: 22, child: Center(child: swatch)),
              const SizedBox(width: 6),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(tr(name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSans(fontSize: 12.5, height: 1.15, fontWeight: FontWeight.w600, color: selected ? c.paper : c.ink)),
                  Text(cost, style: GoogleFonts.ibmPlexMono(fontSize: 10, height: 1.15, color: selected ? c.paper.withValues(alpha: .75) : c.muted)),
                ]),
              ),
            ]),
          ),
        ),
      );

  Widget _full() => Material(
        color: selected ? c.ink : c.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minWidth: 72, minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            // cabe na faixa de 64 px com folga; com letra grande no aparelho, encolhe em vez de cortar
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(height: 18, child: Center(child: swatch)),
                const SizedBox(height: 3),
                Text(tr(name),
                    style: GoogleFonts.ibmPlexSans(fontSize: 12.5, height: 1.15, fontWeight: FontWeight.w600, color: selected ? c.paper : c.ink)),
                Text(cost, style: GoogleFonts.ibmPlexMono(fontSize: 10.5, height: 1.15, color: selected ? c.paper.withValues(alpha: .75) : c.muted)),
              ]),
            ),
          ),
        ),
      );
}

/// Caixa com borda arredondada.
class Panel extends StatelessWidget {
  final Palette c;
  final List<Widget> children;
  final bool accent;
  const Panel({super.key, required this.c, required this.children, this.accent = false});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.paper,
          border: Border.all(color: accent ? c.accent : c.line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 10), children[i]],
          ],
        ),
      );
}

/// Ficha de medalha: dourada quando ganha.
class MedalChip extends StatelessWidget {
  final Palette c;
  final bool on;
  final String text;
  const MedalChip({super.key, required this.c, required this.on, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: on ? c.medal : null,
          border: Border.all(color: on ? c.medal : c.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(on ? Icons.star : Icons.star_border, size: 15, color: on ? c.medalInk : c.muted),
          const SizedBox(width: 5),
          Flexible(child: Text(text, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: on ? c.medalInk : c.muted))),
        ]),
      );
}
