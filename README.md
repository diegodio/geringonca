# Geringonça

Jogo de física em Flutter com [Flame](https://flame-engine.org): monte uma engenhoca com barras, rodas e ímãs e leve a bola até a área vermelha.
É a versão Flutter do jogo que começou como página HTML com Matter.js.

## O que tem

- Peças: barra de madeira, barra de borracha, rodas (horária, anti-horária e livre) e ímãs N/S.
- A madeira não atravessa outras barras de madeira, rodas, ímãs, a bola nem o cenário; rodas e ímãs
  também trombam entre si. Peças que já começam encostadas passam uma pela outra. Só a borracha
  atravessa tudo.
- Rodas com motor mostram uma seta com o sentido do giro.
- Botão Encaixe: liga ou desliga a conexão automática das pontas nas juntas.
- Menu inicial: continuar de onde parou, grade de fases com medalhas e cadeados, criar fase
  e como jogar.
- 12 fases prontas em ordem de dificuldade, liberadas em sequência: cada uma abre quando a
  anterior é concluída. Fases próprias e importadas estão sempre abertas.
  - 1 a 7 (Primeiros passos a Porta e botão): as fases da versão HTML.
  - 8 Marcha à ré: a meta fica atrás; pede a roda anti-horária.
  - 9 Túnel: passagem baixa; a roda grande fica entalada.
  - 10 Entrega: a bola cai num buraco onde nenhuma roda cabe; é preciso empurrá-la.
  - 11 Túnel e fosso: nenhuma roda sozinha passa; pede um carro rígido de duas rodas.
  - 12 Grande final: túnel, fosso, botão e porta.
- Medalhas de tempo, peças e custo, e replay da melhor solução.
- Simulação com pausa, avanço de 0,1 s em 0,1 s e câmera lenta (½× e ¼×). A câmera lenta não
  muda o resultado: só mostra os mesmos passos mais devagar.
- Rastro da bola, com um ponto a cada meio segundo (pontos afastados: a bola acelerou). Depois
  de parar, o rastro da última tentativa fica mais claro na bancada.
- Editor de fases: bloco, plataforma, elevador, gangorra, porta, botão, ímã fixo, área de construção e meta.
- Códigos de compartilhamento `OG1:...`, compatíveis com os da versão HTML.
- Zoom com dois dedos (ou Ctrl + rolagem), seleção múltipla, desfazer, tema claro e escuro.
- Progresso salvo no aparelho.

## Rodar

Precisa do Flutter 3.38 ou mais novo. No Android também do NDK, e no iOS do Xcode, porque o
[Forge2D](https://pub.dev/packages/forge2d) compila o Box2D nativo durante o build.

```sh
flutter pub get
flutter run            # celular ou emulador conectado
flutter run -d chrome  # web (o Box2D roda em WebAssembly)
flutter test           # testes da física e dos códigos
```

## Organização

| Arquivo | Conteúdo |
| --- | --- |
| `lib/core/model.dart` | Peças, fases e leitura de JSON |
| `lib/core/levels.dart` | As 7 fases prontas e o carrinho de exemplo |
| `lib/core/sim.dart` | Mundo físico com Forge2D (Box2D v3). Não depende do Flutter |
| `lib/core/share.dart` | Códigos `OG1:` |
| `lib/core/detmath.dart` | Seno e cosseno que dão o mesmo resultado em toda plataforma |
| `lib/core/fingerprint.dart` | Impressão digital de uma simulação, para comparar plataformas |
| `lib/game/controller.dart` | Estado compartilhado e a classe que junta as partes abaixo |
| `lib/game/build_tools.dart` | Construção: peças, desfazer, seleção e encaixe |
| `lib/game/camera_input.dart` | Câmera, zoom e toques na bancada |
| `lib/game/run_control.dart` | Simulação: rodar, replay, pausa, câmera lenta, rastro e vitória |
| `lib/game/level_editor.dart` | Editor de fases |
| `lib/game/progress.dart` | Progresso: fases liberadas, medalhas, recordes e engenhocas salvas |
| `lib/game/oficina_game.dart` | A bancada como jogo Flame: laço, câmera, componentes e toques |
| `lib/game/ink.dart` | Rotinas de desenho usadas pelos componentes |
| `lib/ui/menu_page.dart` | Menu inicial e grade de fases |
| `lib/ui/home_page.dart` | Tela do jogo, barras de ferramentas e o `GameWidget` |
| `lib/ui/how_to_play.dart` | Texto de "Como jogar" |

O Flame cuida do laço do jogo (passos fixos de 1/60 s), da câmera de zoom e arraste, dos
toques e da árvore de componentes: cada barra, roda, ímã e a bola viram um componente que
segue o seu corpo no Box2D enquanto a simulação roda. A física fica em `Sim`, um mundo
Forge2D novo a cada tentativa, para a mesma engenhoca sempre rodar igual.

As coordenadas são as mesmas da versão HTML (bancada de 1000 × 560, 100 px = 1 m).

## Fases testadas

`test/levels_test.dart` tem uma solução de referência para cada fase pronta e confere que:

- ela vence a fase;
- ela ganha as três medalhas, então toda medalha é alcançável;
- nas fases 8 a 12, os truques mais simples (uma roda com a bola no eixo, o carrinho de
  exemplo) não bastam.

Ao criar uma fase pronta nova, acrescente a solução dela nesse teste.

## Mesma física em todo lugar

Os códigos de compartilhamento e o replay só funcionam se a mesma engenhoca der o mesmo
resultado em qualquer aparelho. Para isso:

- O Box2D é compilado com `-ffp-contract=off`, numa cópia do Forge2D em `third_party/forge2d`
  (ver `GERINGONCA.md` lá dentro). Sem isso, celulares ARM fundem multiplicação e soma (FMA) e
  chegam a números diferentes dos do computador e da web.
- A física em Dart não usa `sin`, `cos`, `atan2` nem `pow` da plataforma, que variam entre
  sistemas: usa `detmath.dart`, raiz quadrada e as quatro operações.
- `test/determinism_test.dart` compara a impressão digital de 7 engenhocas com valores fixos.
  Rode nos dois ambientes:

```sh
flutter test test/determinism_test.dart                    # nativo (Box2D em C)
flutter test test/determinism_test.dart --platform chrome  # web (Box2D em WebAssembly)
```

Verificado em x86 nativo, no Chrome e num Box2D compilado com FMA (como nos celulares ARM).
Ainda não foi rodado num celular de verdade.

