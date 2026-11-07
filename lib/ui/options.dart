import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/controller.dart';
import '../game/palette.dart';

/// Opções do jogo: sons, vibração e onde ficam as peças e as ferramentas.
/// Abre pelo ícone discreto do menu inicial e pelo menu ⋮ da bancada.
Future<void> showOptions(BuildContext context, GameController g) {
  final c = Palette.of(context);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: c.paper,
      title: Text('Opções', style: GoogleFonts.chakraPetch(fontWeight: FontWeight.w700, color: c.ink)),
      contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(child: OptionsPanel(g: g, c: c)),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fechar'))],
    ),
  );
}

class OptionsPanel extends StatelessWidget {
  final GameController g;
  final Palette c;
  const OptionsPanel({super.key, required this.g, required this.c});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: g,
        builder: (context, _) {
          final title = GoogleFonts.ibmPlexSans(fontSize: 15, fontWeight: FontWeight.w600, color: c.ink);
          final sub = GoogleFonts.ibmPlexSans(fontSize: 12.5, color: c.muted);
          Widget side(PanelSide v, String t, String s) => RadioListTile<PanelSide>(
                value: v,
                dense: true,
                title: Text(t, style: title.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(s, style: sub),
              );
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(
              value: g.soundOn,
              onChanged: g.setSound,
              secondary: Icon(g.soundOn ? Icons.volume_up_outlined : Icons.volume_off_outlined, color: c.ink),
              title: Text('Sons', style: title),
              subtitle: Text('Peças, motor, vitória e avisos', style: sub),
            ),
            SwitchListTile(
              value: g.vibeOn,
              onChanged: g.setVibe,
              secondary: Icon(g.vibeOn ? Icons.vibration : Icons.mobile_off_outlined, color: c.ink),
              title: Text('Vibração', style: title),
              subtitle: Text('Em celulares que vibram pelo navegador (Android)', style: sub),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('PEÇAS E FERRAMENTAS', style: GoogleFonts.ibmPlexMono(fontSize: 12, letterSpacing: 1, color: c.muted)),
            ),
            RadioGroup<PanelSide>(
              groupValue: g.panelSide,
              onChanged: (v) => g.setPanelSide(v ?? PanelSide.auto),
              child: Column(children: [
                side(PanelSide.auto, 'Automático', 'Na lateral com a tela deitada; embaixo com ela em pé'),
                side(PanelSide.side, 'Sempre na lateral', 'A bancada usa a altura toda'),
                side(PanelSide.bottom, 'Sempre embaixo', 'A bancada usa a largura toda'),
              ]),
            ),
          ]);
        },
      );
}
