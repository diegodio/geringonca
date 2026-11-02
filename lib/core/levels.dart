import 'model.dart';

Seg _s(double ax, double ay, double bx, double by) => Seg(Pt(ax, ay), Pt(bx, by));

/// As sete fases prontas, iguais às da versão HTML.
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
        targets: Targets(t: 4.0, n: 2, c: 35),
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
