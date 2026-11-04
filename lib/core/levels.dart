import 'model.dart';

Seg _s(double ax, double ay, double bx, double by) => Seg(Pt(ax, ay), Pt(bx, by));

/// Fases prontas, em ordem crescente de dificuldade. As 7 primeiras vêm da
/// versão HTML; as seguintes exigem engenhocas mais elaboradas. Cada uma tem
/// uma solução de referência em test/levels_test.dart, que também confere
/// que as medalhas são alcançáveis e que os truques mais simples não bastam.
List<Level> buildBuiltinLevels() => [
      Level(
        id: 'l1',
        name: 'Primeiros passos',
        tip: 'Leve a bola até a área vermelha. Toque em Rodar para testar o exemplo.',
        zone: zone0(),
        goal: R(790, 360, 180, 140),
        ball: Pt(170, 440),
        plats: [_s(470, 508, 520, 480), _s(520, 480, 600, 480), _s(600, 480, 650, 508)],
        targets: Targets(t: 2.0, n: 2, c: 35),
      ),
      Level(
        id: 'l2',
        name: 'Rampa',
        tip: 'A meta fica no alto. Rodas maiores sobem melhor.',
        zone: zone0(),
        goal: R(780, 280, 200, 150),
        ball: Pt(170, 440),
        blocks: [R(700, 430, 300, 70)],
        plats: [_s(420, 508, 706, 438)],
        targets: Targets(t: 1.9, n: 2, c: 35),
      ),
      Level(
        id: 'l3',
        name: 'Vale',
        tip: 'Sem chão no meio. Faça uma engenhoca comprida o bastante para atravessar.',
        ground: false,
        zone: R(40, 270, 330, 220),
        goal: R(790, 360, 180, 140),
        ball: Pt(190, 440),
        plats: [_s(0, 508, 430, 508), _s(570, 508, 1000, 508)],
        targets: Targets(t: 2.3, n: 2, c: 35),
      ),
      Level(
        id: 'l4',
        name: 'Campo magnético',
        tip: 'O ímã fixo é sul. Um ímã norte na engenhoca é puxado por ele; um sul é empurrado.',
        zone: zone0(),
        goal: R(790, 360, 180, 140),
        ball: Pt(170, 440),
        blocks: [R(560, 460, 40, 40)],
        magnets: [FixedMag(700, 330, 'S')],
        targets: Targets(t: 2.5, n: 3, c: 60),
      ),
      Level(
        id: 'l5',
        name: 'Elevador',
        tip: 'Suba no elevador e espere ele chegar ao topo do bloco.',
        zone: zone0(),
        goal: R(790, 170, 190, 130),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220)],
        // 4,0 s vinha da versão em Matter.js; com o Box2D a melhor solução conhecida leva 6,8 s
        targets: Targets(t: 7.5, n: 2, c: 35),
      ),
      Level(
        id: 'l6',
        name: 'Gangorra',
        tip: 'Passe do eixo e a gangorra vira uma ponte até o degrau.',
        zone: zone0(),
        goal: R(800, 300, 190, 140),
        ball: Pt(170, 440),
        blocks: [R(780, 440, 220, 60)],
        seesaws: [_s(400, 493, 800, 385)],
        targets: Targets(t: 2.0, n: 2, c: 35),
      ),
      Level(
        id: 'l7',
        name: 'Porta e botão',
        tip: 'A porta só abre quando algo pisa no botão roxo.',
        zone: zone0(),
        goal: R(790, 360, 180, 140),
        ball: Pt(170, 440),
        doors: [R(620, 330, 30, 170)],
        buttons: [Pt(420, 500)],
        targets: Targets(t: 1.9, n: 2, c: 35),
      ),
      // ---------- novas: cada uma pede uma ideia a mais ----------
      Level(
        id: 'l8',
        name: 'Marcha à ré',
        tip: 'A meta ficou para trás. Qual roda gira para o outro lado?',
        zone: R(650, 270, 310, 220),
        goal: R(30, 360, 180, 140),
        ball: Pt(830, 478),
        targets: Targets(t: 1.6, n: 1, c: 25),
      ),
      Level(
        id: 'l9',
        name: 'Túnel',
        tip: 'O túnel é baixo: uma roda grande demais fica entalada.',
        zone: zone0(),
        goal: R(790, 360, 180, 140),
        ball: Pt(170, 440),
        blocks: [R(420, 0, 280, 410)], // parede que desce do teto: passagem de 90 px
        targets: Targets(t: 2.1, n: 1, c: 25),
      ),
      Level(
        id: 'l10',
        name: 'Entrega',
        tip: 'A bola tem que cair no buraco, mas nenhuma roda cabe nele. Empurre a bola em vez de carregá-la.',
        ground: false,
        zone: zone0(),
        goal: R(700, 500, 50, 60),
        ball: Pt(200, 478),
        plats: [_s(0, 508, 692, 508), _s(758, 508, 1000, 508)],
        blocks: [R(690, 560, 70, 40)],
        targets: Targets(t: 6.0, n: 1, c: 25),
      ),
      Level(
        id: 'l11',
        name: 'Túnel e fosso',
        tip: 'Rodas grandes não entram no túnel; uma roda pequena sozinha cai no fosso. Ligue duas rodas com barras em triângulo.',
        ground: false,
        zone: R(40, 270, 330, 220),
        goal: R(790, 360, 180, 140),
        ball: Pt(190, 440),
        plats: [_s(0, 508, 600, 508), _s(740, 508, 1000, 508)],
        blocks: [R(380, 0, 200, 410)], // passagem baixa de 90 px
        targets: Targets(t: 2.7, n: 5, c: 80),
      ),
      Level(
        id: 'l12',
        name: 'Grande final',
        tip: 'Túnel, fosso e uma porta que só abre com o botão. Junte tudo o que aprendeu.',
        ground: false,
        zone: R(40, 270, 330, 220),
        goal: R(790, 360, 180, 140),
        ball: Pt(190, 440),
        plats: [_s(0, 508, 600, 508), _s(740, 508, 1000, 508)],
        blocks: [R(380, 0, 200, 410)], // passagem baixa de 90 px
        buttons: [Pt(500, 500)],
        doors: [R(750, 300, 30, 200)],
        targets: Targets(t: 2.9, n: 5, c: 80),
      ),
    ];

final List<Level> kBuiltin = buildBuiltinLevels();
bool isBuiltin(String? id) => kBuiltin.any((l) => l.id == id);

Level blankLevel() => Level(name: 'Fase nova', zone: zone0(), goal: R(790, 360, 180, 140), ball: Pt(170, 440));

/// Carrinho com gaiola para a bola, o exemplo da fase 1.
List<Part>? sampleFor(Level lv, Pt ball) {
  final bx = ball.x, by = ball.y + 30;
  final p = [
    Part.rod('solid', Pt(bx - 80, by), Pt(bx + 80, by)),
    Part.rod('solid', Pt(bx - 80, by), Pt(bx - 40, by - 70)),
    Part.rod('solid', Pt(bx + 80, by), Pt(bx + 40, by - 70)),
    Part.rod('water', Pt(bx - 40, by - 70), Pt(bx + 40, by - 70)),
    Part.wheel('cw', Pt(bx - 80, by), 28),
    Part.wheel('cw', Pt(bx + 80, by), 28),
  ];
  return p.every((q) => q.points.every(lv.zone.contains)) ? p : null;
}
