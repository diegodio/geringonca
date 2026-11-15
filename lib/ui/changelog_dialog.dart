import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/changelog.dart';
import '../core/i18n.dart';
import '../game/palette.dart';

/// Histórico de versões: o que mudou em cada versão, da mais nova para a mais antiga.
Future<void> showChangelog(BuildContext context, Palette c) => showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.paper,
        title: Text(tr('Versões'), style: GoogleFonts.chakraPetch(fontWeight: FontWeight.w700, color: c.ink)),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              for (final (i, e) in kChangelog.indexed) ...[
                if (i > 0) Divider(height: 24, color: c.line),
                Row(children: [
                  Text('v${e.version}', style: GoogleFonts.chakraPetch(fontSize: 16, fontWeight: FontWeight.w700, color: c.ink)),
                  const SizedBox(width: 8),
                  Text(e.date, style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.muted)),
                  if (i == 0) ...[
                    const SizedBox(width: 8),
                    Text(tr('esta versão'), style: GoogleFonts.ibmPlexMono(fontSize: 11.5, color: c.zone)),
                  ],
                ]),
                const SizedBox(height: 6),
                for (final it in e.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('•  ', style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.muted)),
                      Expanded(child: Text(tr(it), style: GoogleFonts.ibmPlexSans(fontSize: 14, height: 1.35, color: c.ink))),
                    ]),
                  ),
              ],
            ]),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('Fechar')))],
      ),
    );
