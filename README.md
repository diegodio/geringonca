# Oficina Geringonça

Jogo de física em Flutter com [Flame](https://flame-engine.org): monte uma engenhoca com barras, rodas e ímãs e leve a bola até a área vermelha.
É a versão Flutter do jogo que começou como página HTML com Matter.js.

## O que tem

- Peças: barra sólida, barra vazada, rodas (horária, anti-horária e livre) e ímãs N/S.
- 7 fases prontas, com medalhas de tempo, peças e custo, e replay da melhor solução.
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
| `lib/game/controller.dart` | Regras: construção, seleção, câmera, medalhas, editor |
| `lib/game/oficina_game.dart` | A bancada como jogo Flame: laço, câmera, componentes e toques |
| `lib/game/ink.dart` | Rotinas de desenho usadas pelos componentes |
| `lib/ui/home_page.dart` | Tela, barras de ferramentas e o `GameWidget` |

O Flame cuida do laço do jogo (passos fixos de 1/60 s), da câmera de zoom e arraste, dos
toques e da árvore de componentes: cada barra, roda, ímã e a bola viram um componente que
segue o seu corpo no Box2D enquanto a simulação roda. A física fica em `Sim`, um mundo
Forge2D novo a cada tentativa, para a mesma engenhoca sempre rodar igual.

As coordenadas são as mesmas da versão HTML (bancada de 1000 × 560, 100 px = 1 m).
