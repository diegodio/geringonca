import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../game/controller.dart';
import '../game/palette.dart';
import '../game/progress.dart';
import 'widgets.dart';

/// Tela de vitória: resultado, medalhas com o quanto faltou, desafios extras e
/// o que fazer em seguida. Aparece no lugar do dock, embaixo da bancada.
class WinPanel extends StatelessWidget {
  final GameController g;
  final Palette c;
  final VoidCallback onMenu;
  const WinPanel({super.key, required this.g, required this.c, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    final i = g.winInfo!;
    final rows = <Widget>[];
    if (!i.replay) {
      void row(String name, bool have, double? goal, double got, String unit, {int d = 0}) {
        if (goal == null) return;
        String f(double v) => d == 0 ? v.round().toString() : fmt(v, d);
        final ok = got <= goal + 1e-9;
        String v(double x) => '${unit == '\$' ? '\$' : ''}${f(x)}${unit == 's' ? ' s' : ''}';
        final detail = ok ? tr('meta ≤ {v}', {'v': v(goal)}) : tr('faltou {v}', {'v': v(got - goal)});
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Icon(have ? Icons.star : Icons.star_border, size: 18, color: have ? c.medal : c.muted),
            const SizedBox(width: 8),
            SizedBox(width: 64, child: Text(tr(name), style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.ink))),
            Text('${unit == '\$' ? '\$' : ''}${f(got)}${unit == 's' ? ' s' : ''}', style: GoogleFonts.ibmPlexMono(fontSize: 13, color: c.ink)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(detail,
                  overflow: TextOverflow.ellipsis, style: GoogleFonts.ibmPlexMono(fontSize: 12, color: ok ? c.zone : c.goal)),
            ),
          ]),
        ));
      }

      row('Tempo', i.m['t'] == true, i.tg.t, i.t, 's', d: 2);
      row('Peças', i.m['n'] == true, i.tg.n?.toDouble(), i.n.toDouble(), '');
      row('Custo', i.m['c'] == true, i.tg.c?.toDouble(), i.c.toDouble(), '\$');
    }

    return Panel(c: c, accent: true, children: [
      Row(children: [
        Icon(Icons.emoji_events_outlined, color: c.goal, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr(i.replay ? 'Replay concluído' : 'Fase concluída!'),
                style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: c.goal)),
            Text('${fmt(i.t)} s · ${trN(i.n, '1 peça', '{n} peças')} · \$${i.c}', style: GoogleFonts.ibmPlexMono(fontSize: 12.5, color: c.muted)),
          ]),
        ),
      ]),
      if (rows.isNotEmpty) Column(children: rows),
      if (i.badges.isNotEmpty)
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          label(c, 'Desafios'),
          for (final b in kChallenges.where((b) => i.badges.contains(b.$1)))
            Tooltip(
              message: b.$3,
              child: Chip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(Icons.verified_outlined, size: 16, color: c.zone),
                label: Text(i.freshBadges.contains(b.$1) ? tr('{c} · novo!', {'c': tr(b.$2)}) : tr(b.$2),
                    style: GoogleFonts.ibmPlexSans(fontSize: 12.5, color: c.ink)),
                backgroundColor: c.bg,
                side: BorderSide(color: c.line),
              ),
            ),
        ]),
      if (i.unlocked != null)
        Row(children: [
          Icon(Icons.lock_open, size: 18, color: c.zone),
          const SizedBox(width: 6),
          Text(tr('Fase liberada: {lv}', {'lv': tr(i.unlocked!)}), style: GoogleFonts.ibmPlexSans(fontSize: 14, fontWeight: FontWeight.w600, color: c.zone)),
        ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (i.next != null && !i.replay) TB(c: c, primary: true, icon: Icons.arrow_forward, label: 'Próxima fase', onTap: g.goNext),
        TB(c: c, icon: Icons.replay, label: i.replay ? 'Ver de novo' : 'Tentar de novo', onTap: g.retry),
        TB(c: c, icon: Icons.build_outlined, label: 'Melhorar', onTap: g.improve),
        TB(c: c, icon: Icons.grid_view, label: 'Menu', onTap: onMenu),
      ]),
    ]);
  }
}
