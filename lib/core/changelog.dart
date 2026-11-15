// Novidades de cada publicação, da mais nova para a mais antiga. A janela
// "Novidades" do menu mostra esta lista. Ao publicar algo que o jogador nota,
// acrescente uma entrada no topo (os textos passam por tr(); a tradução fica em
// i18n_en.dart). O número é o da publicação (veja version.dart).

/// Uma publicação: número (null = a que está rodando agora), data e o que mudou.
typedef ChangelogEntry = ({String? version, String date, List<String> items});

const List<ChangelogEntry> kChangelog = [
  (
    version: null,
    date: '2026-11-15',
    items: [
      'Créditos do estúdio no pé do menu.',
      'Esta janela de novidades: toque na versão para abri-la.',
    ],
  ),
  (
    version: '0.20',
    date: '2026-11-14',
    items: ['A versão do jogo aparece no pé do menu e nas Opções.'],
  ),
  (
    version: '0.19',
    date: '2026-11-13',
    items: [
      'Barras de madeira não podem começar cruzando nada que não esteja ligado a elas por uma junta.',
      'As 67 fases foram revistas e reorganizadas em 7 capítulos, em ordem de dificuldade.',
      'Menu novo, como um caderno de laboratório, com a miniatura de cada fase.',
      'Abertura nova do Aftershock Studios.',
    ],
  ),
  (
    version: '0.17',
    date: '2026-11-10',
    items: [
      'Tutorial guiado na primeira fase.',
      'Caixas soltas: caem, podem ser empurradas e apertam botões.',
      'Dá para pular uma fase que empacar.',
      'Tela cheia nas Opções.',
    ],
  ),
  (
    version: '0.16',
    date: '2026-11-10',
    items: ['Madeira não atravessa madeira nem outras peças; a borracha atravessa, mas as pontas batem.'],
  ),
];

/// Todos os textos das novidades (para o teste de tradução).
List<String> get changelogTexts => [for (final e in kChangelog) ...e.items];
