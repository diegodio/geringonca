import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../core/version.dart';
import '../game/controller.dart';
import '../game/palette.dart';
import 'platform/link.dart';

/// Opções do jogo: sons, vibração e onde ficam as peças e as ferramentas.
/// Abre pelo ícone discreto do menu inicial e pelo menu ⋮ da bancada.
Future<void> showOptions(BuildContext context, GameController g) {
  final c = Palette.of(context);
  return showDialog<void>(
    context: context,
    // reconstrói ao mudar uma opção: o idioma troca o título e o botão também
    builder: (ctx) => ListenableBuilder(
      listenable: g,
      builder: (ctx, _) => AlertDialog(
        backgroundColor: c.paper,
        title: Text(tr('Opções'), style: GoogleFonts.chakraPetch(fontWeight: FontWeight.w700, color: c.ink)),
        contentPadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(child: OptionsPanel(g: g, c: c)),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // versão do jogo num canto da janela
          Padding(padding: const EdgeInsets.only(left: 12), child: Text(versionLabel, style: GoogleFonts.ibmPlexMono(fontSize: 11, color: c.muted))),
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(tr('Fechar'))),
        ],
      ),
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
                title: Text(tr(t), style: title.copyWith(fontWeight: FontWeight.w500)),
                subtitle: Text(tr(s), style: sub),
              );
          return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SwitchListTile(
              value: g.soundOn,
              onChanged: g.setSound,
              secondary: Icon(g.soundOn ? Icons.volume_up_outlined : Icons.volume_off_outlined, color: c.ink),
              title: Text(tr('Sons'), style: title),
              subtitle: Text(tr('Peças, motor, vitória e avisos'), style: sub),
            ),
            SwitchListTile(
              value: g.vibeOn,
              onChanged: g.setVibe,
              secondary: Icon(g.vibeOn ? Icons.vibration : Icons.mobile_off_outlined, color: c.ink),
              title: Text(tr('Vibração'), style: title),
              subtitle: Text(tr('Em celulares que vibram pelo navegador (Android)'), style: sub),
            ),
            if (canFullscreen()) _FullscreenTile(c: c, title: title, sub: sub),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(tr('PEÇAS E FERRAMENTAS'), style: GoogleFonts.ibmPlexMono(fontSize: 12, letterSpacing: 1, color: c.muted)),
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
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text('IDIOMA · LANGUAGE', style: GoogleFonts.ibmPlexMono(fontSize: 12, letterSpacing: 1, color: c.muted)),
            ),
            RadioGroup<String>(
              groupValue: g.langPref,
              onChanged: (v) => g.setLang(v ?? 'auto'),
              child: Column(children: [
                RadioListTile<String>(value: 'auto', dense: true, title: Text(tr('Automático (o do aparelho)'), style: title.copyWith(fontWeight: FontWeight.w500))),
                RadioListTile<String>(value: 'pt', dense: true, title: Text('Português', style: title.copyWith(fontWeight: FontWeight.w500))),
                RadioListTile<String>(value: 'en', dense: true, title: Text('English', style: title.copyWith(fontWeight: FontWeight.w500))),
              ]),
            ),
          ]);
        },
      );
}

/// Liga e desliga a tela cheia do navegador (só aparece onde o navegador permite).
class _FullscreenTile extends StatefulWidget {
  final Palette c;
  final TextStyle title, sub;
  const _FullscreenTile({required this.c, required this.title, required this.sub});
  @override
  State<_FullscreenTile> createState() => _FullscreenTileState();
}

class _FullscreenTileState extends State<_FullscreenTile> {
  @override
  Widget build(BuildContext context) {
    final on = isFullscreen();
    return SwitchListTile(
      value: on,
      onChanged: (v) async {
        await setFullscreen(v);
        if (mounted) setState(() {});
      },
      secondary: Icon(on ? Icons.fullscreen_exit : Icons.fullscreen, color: widget.c.ink),
      title: Text(tr('Tela cheia'), style: widget.title),
      subtitle: Text(tr('Deixa só o jogo na tela'), style: widget.sub),
    );
  }
}
