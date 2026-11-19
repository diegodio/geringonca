// Histórico de versões, da mais nova para a mais antiga. A primeira entrada é a
// versão atual do jogo (veja version.dart); a janela que abre ao tocar na versão,
// no pé do menu, mostra a lista inteira.
//
// Formato 0.xx.yy: xx sobe a cada atualização grande (e yy volta a 00); yy
// conta as pequenas atualizações da mesma versão. Toda publicação ganha uma
// entrada no topo, com a data do dia em GMT-3 (horário de Brasília). Os textos
// passam por tr(); a tradução fica em i18n_en.dart.
//
// As versões até a 0.21.00 vêm das publicações no GitHub Pages (a 0.18 falhou
// e não saiu; o conteúdo dela foi na 0.19.00).

typedef ChangelogEntry = ({String version, String date, List<String> items});

const List<ChangelogEntry> kChangelog = [
  (
    version: '0.25.00',
    date: '2026-11-19',
    items: [
      'Corrigida a trava ao salvar uma fase do editor e voltar ao menu.',
    ],
  ),
  (
    version: '0.24.00',
    date: '2026-11-17',
    items: [
      'Botão Refazer ao lado do Desfazer, na construção e no editor.',
      'Lupa: ao arrastar a ponta de uma barra ou uma junta, um círculo acima do dedo mostra ampliado o que está embaixo dele.',
    ],
  ),
  (
    version: '0.23.00',
    date: '2026-11-17',
    items: [
      'Rodas, ímãs e barras precisam caber inteiros na área de construção; o que passa da borda fica vermelho e não é construído.',
      'A área de construção vai até o chão.',
      'As argolas na borda das rodas não batem em nada: quem bate é o círculo da roda.',
    ],
  ),
  (
    version: '0.22.00',
    date: '2026-11-17',
    items: [
      'Barra ou borracha com a ponta fora da área de construção fica vermelha antes de soltar.',
      'Criar fase sempre começa em branco, com chão; o chão liga e desliga no editor e no menu ⋮.',
      'Só dá para salvar uma fase depois de vencê-la no Testar.',
      'Editor mais firme ao ir e voltar do teste.',
    ],
  ),
  (
    version: '0.21.02',
    date: '2026-11-14',
    items: ['No pé do menu, só o número da versão abre o histórico.'],
  ),
  (
    version: '0.21.01',
    date: '2026-11-14',
    items: [
      'Histórico com todas as versões, desde a primeira.',
      'Versões no formato 0.xx.yy: o último número conta as pequenas atualizações.',
      'Datas no horário de Brasília.',
    ],
  ),
  (
    version: '0.21.00',
    date: '2026-11-14',
    items: [
      'Créditos do estúdio no pé do menu.',
      'Histórico de versões: toque na versão, no pé do menu, para abrir.',
    ],
  ),
  (
    version: '0.20.00',
    date: '2026-11-14',
    items: ['A versão do jogo aparece no pé do menu e nas Opções.'],
  ),
  (
    version: '0.19.00',
    date: '2026-11-13',
    items: [
      'Barras de madeira não podem começar cruzando nada que não esteja ligado a elas por uma junta.',
      'As 67 fases foram revistas e reorganizadas em 7 capítulos, em ordem de dificuldade.',
      'Menu novo, como um caderno de laboratório, com a miniatura de cada fase.',
      'Abertura nova do Aftershock Studios.',
    ],
  ),
  (
    version: '0.17.00',
    date: '2026-11-10',
    items: [
      'Tutorial guiado na primeira fase.',
      'Caixas soltas: caem, podem ser empurradas e apertam botões.',
      'Dá para pular uma fase que empacar.',
      'Tela cheia nas Opções.',
    ],
  ),
  (
    version: '0.16.00',
    date: '2026-11-09',
    items: ['Madeira não atravessa madeira nem outras peças; a borracha atravessa, mas as pontas batem.'],
  ),
  (
    version: '0.15.00',
    date: '2026-11-08',
    items: ['Capítulo Morros e rampas: o morro entra no cenário e no editor, com 10 fases novas.'],
  ),
  (
    version: '0.14.00',
    date: '2026-11-08',
    items: ['O jogo carrega mais rápido (WebAssembly e fontes embutidas) e grava o progresso com menos frequência.'],
  ),
  (
    version: '0.13.00',
    date: '2026-11-08',
    items: ['Testar uma fase do editor volta a funcionar com o celular em pé.'],
  ),
  (
    version: '0.12.00',
    date: '2026-11-08',
    items: ['Editor de fases completo: ajustar elementos, propriedades, testar sem sair, verificação, modelos e abas.'],
  ),
  (
    version: '0.11.00',
    date: '2026-11-07',
    items: [
      'Dá para jogar sem internet.',
      'Compartilhar uma fase com a engenhoca por link.',
      'Versão em inglês.',
      'Melhor desempenho em celulares simples e ícones novos.',
    ],
  ),
  (
    version: '0.10.00',
    date: '2026-11-07',
    items: ['A tela de carregamento monta a palavra peça por peça; um toque pula.'],
  ),
  (
    version: '0.09.00',
    date: '2026-11-06',
    items: [
      'Com a tela deitada, peças e ferramentas ficam na lateral.',
      'Opções, sons e vibração.',
      'Tela de carregamento com o pingo do i quicando.',
    ],
  ),
  (
    version: '0.08.00',
    date: '2026-11-06',
    items: ['Logotipo e ícone desenhados com as peças do jogo.'],
  ),
  (
    version: '0.07.00',
    date: '2026-11-06',
    items: ['O app instalado funciona com a tela deitada, e as rodas batem em toda madeira.'],
  ),
  (
    version: '0.06.00',
    date: '2026-11-05',
    items: ['50 fases em 5 capítulos.', 'Elevador com poço, bola solta e orçamento máximo.'],
  ),
  (
    version: '0.05.00',
    date: '2026-11-04',
    items: [
      'O motor só gira com o eixo da roda preso a alguma coisa.',
      'Interface pensada para celular e tablet.',
      'Tela de vitória, peças permitidas por fase e desafios extras.',
    ],
  ),
  (
    version: '0.04.00',
    date: '2026-11-03',
    items: ['Menu inicial e 5 fases novas em ordem de dificuldade.'],
  ),
  (
    version: '0.03.00',
    date: '2026-11-03',
    items: [
      'Pausa, câmera lenta e rastro da bola.',
      'Fases liberadas em sequência.',
      'A mesma física em todo aparelho.',
    ],
  ),
  (
    version: '0.02.00',
    date: '2026-11-03',
    items: ['Bancada nova, peças sólidas, setas nas rodas, botão de encaixe e o nome Geringonça.'],
  ),
  (
    version: '0.01.00',
    date: '2026-11-02',
    items: ['Primeira versão publicada na web.'],
  ),
];

/// Todos os textos do histórico (para o teste de tradução).
List<String> get changelogTexts => [for (final e in kChangelog) ...e.items];
