import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/palette.dart';

/// "Como jogar": aparece embaixo da bancada e no menu inicial.
class HowToPlay extends StatelessWidget {
  final Palette c;
  const HowToPlay({super.key, required this.c});

  static const notes = [
    ('O objetivo', 'Monte uma engenhoca na área verde e toque em Rodar. A fase termina quando a bola amarela fica inteira dentro da área vermelha.'),
    ('Medalhas',
        'Cada fase tem três: tempo, número de peças e custo. Não precisa ganhar todas na mesma engenhoca. A solução mais rápida fica guardada em Melhor solução. Concluir uma fase libera a seguinte.'),
    ('Cenário que se move',
        'Elevadores sobem e descem sem parar. Gangorras giram no eixo do meio. Portas abrem quando algo pisa num botão; numa fase sem botões, elas abrem e fecham a cada 2 s.'),
    ('Seleção e zoom',
        'Use dois dedos para aproximar e arrastar a tela (no computador, Ctrl + rolagem). Em Selecionar, marque várias peças para mover, duplicar ou girar de uma vez.'),
    ('Peças entre si',
        'Barras de madeira não atravessam outras barras de madeira, rodas, ímãs, a bola nem o cenário; só as que já começam encostadas passam uma pela outra. Rodas e ímãs também trombam entre si. Rodas, ímãs e a bola rolam por cima das barras, como numa ponte. Peças presas à roda ou à bola por uma junta, como o eixo, passam por dentro delas. Cada roda tem 4 pontos de conexão na borda, a cada π/2; uma barra presa neles gira junto, como uma manivela. Só a barra azul, de borracha, atravessa tudo. As rodas com motor têm uma seta com o sentido do giro, e o motor só liga se o centro da roda estiver preso a alguma coisa (uma barra, outra peça ou a bola); solta, a roda rola livre e a seta fica apagada. Ímã norte (vermelho) atrai sul (azul) e repele norte.'),
  ];

  @override
  Widget build(BuildContext context) => Wrap(spacing: 28, runSpacing: 18, children: [
        for (final (h, p) in notes)
          SizedBox(
            width: 300,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h, style: GoogleFonts.chakraPetch(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 6),
              Text(p, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink, height: 1.5)),
            ]),
          ),
      ]);
}
