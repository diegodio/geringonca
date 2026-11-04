# Cópia do forge2d 0.15.3

Esta é uma cópia do pacote [forge2d](https://pub.dev/packages/forge2d) 0.15.3
(licença MIT, ver `LICENSE`), usada pelo jogo via `dependency_overrides` no
`pubspec.yaml` da raiz.

## O que mudou em relação ao original

1. `hook/build.dart`: o Box2D é compilado com `-ffp-contract=off`.
   Sem isso, em processadores ARM (celulares Android e iPhones) o compilador
   funde multiplicação e soma numa instrução só (FMA). O resultado de cada
   conta muda na última casa e a mesma engenhoca termina diferente no celular,
   no computador e na web. É a mesma opção que o projeto Box2D usa para ser
   determinístico entre plataformas.
2. `pubspec.yaml`: removida a linha `resolution: workspace`, que só vale dentro
   do repositório original.
3. Removidas as pastas `test/` e `example/` e o `analysis_options.yaml` (usava o pacote flame_lint).

O módulo WebAssembly (`lib/src/backend/wasm/box2d.wasm`) é o original: o
WebAssembly não tem FMA, então já não fundia.

## Como foi verificado

`test/determinism_test.dart` compara a "impressão digital" de 7 engenhocas
(posição e ângulo de todos os corpos em todos os passos). Compilando o Box2D
num x86 com `-mfma -ffp-contract=fast`, que reproduz o padrão do ARM, as 7
mudaram; com `-ffp-contract=off` as 7 voltaram a bater com o x86 normal e com
o WebAssembly no Chrome.

## Atualizar

Ao trocar de versão do forge2d, copie o pacote novo para cá e refaça as
mudanças acima (ou remova a cópia, se o forge2d passar a usar a opção).
