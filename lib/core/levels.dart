import 'model.dart';

Seg _s(double ax, double ay, double bx, double by) => Seg(Pt(ax, ay), Pt(bx, by));

/// Peças sem motor, para as fases em que tudo se move por gravidade ou ímã.
const _noMotor = ['rod', 'water', 'free', 'magN', 'magS'];

/// Capítulos: nome, subtítulo e quantas fases têm, na ordem de [kBuiltin].
const kChapters = [
  ('Oficina', 'Aprender cada peça', 10),
  ('Sem carregar', 'Empurrar e usar a gravidade', 10),
  ('Estruturas', 'Pontes, chassis e terreno', 10),
  ('Cenário em movimento', 'Elevadores, gangorras e botões', 10),
  ('Ímãs e mecanismos', 'Atração, repulsão e guindastes', 10),
];

/// As 50 fases prontas, em ordem crescente de dificuldade, divididas em 5
/// capítulos de 10. As ids não seguem a ordem porque as fases mais antigas
/// mantêm a id original (o progresso salvo usa a id). Cada fase tem uma
/// solução de referência em test/levels_test.dart, que confere que ela vence,
/// que as três medalhas são alcançáveis e que os truques simples não bastam.
List<Level> buildBuiltinLevels() => [
      // ---------- capítulo: Oficina ----------
      // 1
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
      // 2
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
      // 3
      Level(
        id: 'l8',
        name: 'Marcha à ré',
        tip: 'A meta ficou para trás. Qual roda gira para o outro lado?',
        zone: R(650, 270, 310, 220),
        goal: R(30, 360, 180, 140),
        ball: Pt(830, 478),
        targets: Targets(t: 1.6, n: 1, c: 25),
      ),
      // 4
      Level(
        id: 'l14',
        name: 'Degrau',
        tip: 'Um degrau antes da meta. Qual tamanho de roda sobe?',
        zone: zone0(),
        goal: R(800, 330, 190, 130),
        ball: Pt(170, 440),
        blocks: [R(600, 460, 400, 40)],
        targets: Targets(t: 2.4, n: 1, c: 25),
      ),
      // 5
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
      // 6
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
      // 7
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
      // 8
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
      // 9
      Level(
        id: 'l5',
        name: 'Elevador',
        tip: 'Suba no elevador e espere ele chegar ao topo do bloco.',
        zone: zone0(),
        goal: R(790, 170, 190, 130),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 3)],
        targets: Targets(t: 4.5, n: 2, c: 35),
      ),
      // 10
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
      // ---------- capítulo: Sem carregar ----------
      // 11
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
        // o motor só liga com o eixo preso: a solução mais simples tem roda + barra
        targets: Targets(t: 6.0, n: 2, c: 30),
      ),
      // 12
      Level(
        id: 'l13',
        name: 'Ladeira',
        tip: 'Nesta fase não há motor. Use a rampa: o que rola lá de cima empurra a bola.',
        zone: R(40, 140, 400, 190),
        goal: R(520, 360, 220, 140),
        ball: Pt(390, 312),
        plats: [_s(40, 220, 330, 340), _s(330, 340, 430, 340)],
        allowed: ['rod', 'water', 'free', 'magN', 'magS'],
        targets: Targets(t: 4.6, n: 1, c: 15),
      ),
      // 13
      Level(
        id: 'l15',
        name: 'Dominó',
        tip: 'Sem motor. A bola está fora da área verde: derrube algo em cima dela.',
        ground: false,
        zone: R(40, 150, 220, 340),
        goal: R(470, 400, 420, 155),
        ball: Pt(300, 478),
        plats: [_s(0, 508, 330, 508), _s(330, 508, 560, 545), _s(560, 545, 1000, 556)],
        allowed: _noMotor,
        targets: Targets(t: 4.6, n: 2, c: 25),
      ),
      // 14
      Level(
        id: 'l16',
        name: 'Freio',
        tip: 'A bola desce rápido demais e passa por cima do buraco. Construa algo para ela bater.',
        ground: false,
        zone: R(660, 260, 200, 230),
        goal: R(600, 500, 50, 60),
        ball: Pt(64, 106),
        plats: [_s(40, 130, 420, 508), _s(420, 508, 592, 508), _s(658, 508, 860, 508)],
        blocks: [R(590, 560, 70, 40)],
        allowed: _noMotor,
        targets: Targets(t: 3.6, n: 3, c: 30),
      ),
      // 15
      Level(
        id: 'l17',
        name: 'Defletor',
        tip: 'A bola voa para a direita, mas a meta fica embaixo, à esquerda. Faça um anteparo.',
        ground: false,
        zone: R(480, 220, 220, 270),
        goal: R(30, 400, 200, 140),
        ball: Pt(64, 126),
        plats: [_s(40, 150, 420, 300), _s(0, 548, 720, 508)],
        allowed: _noMotor,
        targets: Targets(t: 8.2, n: 3, c: 30),
      ),
      // 16
      Level(
        id: 'l18',
        name: 'Braço comprido',
        tip: 'A bola está numa prateleira fora do alcance das rodas. Um braço firme empurra de longe.',
        zone: R(40, 250, 250, 240),
        goal: R(420, 380, 200, 120),
        ball: Pt(390, 398),
        blocks: [R(330, 420, 90, 80)],
        targets: Targets(t: 1.2, n: 5, c: 80),
      ),
      // 17
      Level(
        id: 'l19',
        name: 'Bola solta',
        tip: 'Nada pode ser preso à bola. Leve-a numa gaiola por cima do vão.',
        ground: false,
        looseBall: true,
        zone: zone0(),
        goal: R(790, 360, 180, 140),
        ball: Pt(170, 440),
        plats: [_s(0, 508, 500, 508), _s(580, 508, 1000, 508)],
        targets: Targets(t: 3.4, n: 6, c: 90),
      ),
      // 18
      Level(
        id: 'l20',
        name: 'Gaiola na subida',
        tip: 'Bola solta e uma rampa forte: a gaiola precisa segurar a bola na subida.',
        looseBall: true,
        zone: zone0(),
        goal: R(780, 210, 200, 150),
        ball: Pt(170, 440),
        blocks: [R(720, 360, 280, 140)],
        plats: [_s(520, 508, 726, 368)],
        targets: Targets(t: 2.6, n: 6, c: 90),
      ),
      // 19
      Level(
        id: 'l21',
        name: 'Catapulta',
        tip: 'Sem motor. Algo pesado caindo na ponta alta da gangorra lança a bola para a prateleira.',
        zone: R(200, 40, 220, 220),
        goal: R(850, 210, 140, 130),
        ball: Pt(670, 462),
        blocks: [R(850, 340, 150, 160)],
        seesaws: [_s(300, 400, 700, 490)],
        allowed: _noMotor,
        targets: Targets(t: 2.0, n: 3, c: 40),
      ),
      // 20
      Level(
        id: 'l22',
        name: 'Carga no vale',
        tip: 'Bola solta e um vão no caminho: a gaiola também precisa atravessar.',
        ground: false,
        looseBall: true,
        zone: R(40, 270, 330, 220),
        goal: R(790, 360, 180, 140),
        ball: Pt(190, 440),
        plats: [_s(0, 508, 430, 508), _s(570, 508, 1000, 508)],
        targets: Targets(t: 3.2, n: 5, c: 80),
      ),
      // ---------- capítulo: Estruturas ----------
      // 21
      Level(
        id: 'l23',
        name: 'Ponte',
        tip: 'Nenhum carro atravessa este vão. A área verde alcança as duas bordas: construa uma ponte.',
        ground: false,
        zone: R(40, 300, 720, 190),
        goal: R(800, 360, 180, 140),
        ball: Pt(120, 440),
        plats: [_s(0, 508, 400, 508), _s(700, 508, 1000, 508)],
        targets: Targets(t: 2.7, n: 2, c: 35),
      ),
      // 22
      Level(
        id: 'l24',
        name: 'Rampa improvisada',
        tip: 'A meta está em cima de um bloco sem rampa. Apoie uma barra nele e suba por ela.',
        zone: R(40, 250, 620, 240),
        goal: R(800, 250, 190, 130),
        ball: Pt(150, 440),
        blocks: [R(600, 380, 400, 120)],
        targets: Targets(t: 2.7, n: 2, c: 35),
      ),
      // 23
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
      // 24
      Level(
        id: 'l25',
        name: 'Escada',
        tip: 'Degraus altos demais para uma roda sozinha. Duas rodas ligadas se ajudam a subir.',
        zone: zone0(),
        goal: R(800, 200, 190, 135),
        ball: Pt(170, 440),
        blocks: [R(480, 445, 520, 55), R(620, 390, 380, 55), R(760, 335, 240, 55)],
        targets: Targets(t: 4.0, n: 5, c: 80),
      ),
      // 25
      Level(
        id: 'l26',
        name: 'Lombadas',
        tip: 'Bola solta em terreno ondulado: uma gaiola aberta em cima deixa a bola pular fora.',
        looseBall: true,
        zone: zone0(),
        goal: R(800, 360, 180, 140),
        ball: Pt(170, 440),
        plats: [
          _s(430, 508, 470, 478), _s(470, 478, 510, 508),
          _s(560, 508, 600, 478), _s(600, 478, 640, 508),
          _s(690, 508, 730, 478), _s(730, 478, 770, 508),
        ],
        targets: Targets(t: 2.9, n: 6, c: 90),
      ),
      // 26
      Level(
        id: 'l27',
        name: 'Ladeira íngreme',
        tip: 'Bola solta numa rampa muito inclinada. Gaiola curta e rodas fortes.',
        looseBall: true,
        zone: zone0(),
        goal: R(800, 230, 190, 140),
        ball: Pt(170, 440),
        blocks: [R(760, 370, 240, 130)],
        plats: [_s(660, 508, 766, 378)],
        targets: Targets(t: 3.0, n: 6, c: 90),
      ),
      // 27
      Level(
        id: 'l28',
        name: 'Ponte de carga',
        tip: 'Um vão largo e a bola solta: ponte e gaiola na mesma fase.',
        ground: false,
        looseBall: true,
        zone: R(40, 300, 720, 190),
        goal: R(800, 360, 180, 140),
        ball: Pt(150, 440),
        plats: [_s(0, 508, 400, 508), _s(700, 508, 1000, 508)],
        targets: Targets(t: 3.3, n: 7, c: 100),
      ),
      // 28
      Level(
        id: 'l29',
        name: 'Ponte levadiça',
        tip: 'Sem motor. A porta segura a bola por 2 s: faça algo tombar sobre o vão antes.',
        ground: false,
        zone: R(330, 120, 140, 370),
        goal: R(640, 360, 340, 140),
        ball: Pt(80, 376),
        plats: [_s(40, 400, 420, 508), _s(420, 508, 450, 508), _s(650, 508, 1000, 508)],
        doors: [R(150, 300, 20, 110)],
        allowed: _noMotor,
        targets: Targets(t: 13.8, n: 1, c: 10),
      ),
      // 29
      Level(
        id: 'l30',
        name: 'Orçamento curto',
        tip: 'Dois vãos largos e só \$60 para gastar.',
        ground: false,
        budget: 60,
        zone: R(40, 300, 780, 190),
        goal: R(840, 360, 150, 140),
        ball: Pt(120, 440),
        plats: [_s(0, 508, 250, 508), _s(480, 508, 560, 508), _s(790, 508, 1000, 508)],
        targets: Targets(t: 2.9, n: 3, c: 45),
      ),
      // 30
      Level(
        id: 'l12',
        name: 'Travessia',
        tip: 'Túnel, fosso e uma porta que só abre com o botão.',
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
      // ---------- capítulo: Cenário em movimento ----------
      // 31
      Level(
        id: 'l31',
        name: 'Elevador e túnel',
        tip: 'No alto do bloco o teto é baixo: só passa uma engenhoca pequena.',
        zone: zone0(),
        goal: R(790, 215, 200, 85),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 240, 200), R(700, 0, 300, 215)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 3)],
        targets: Targets(t: 4.5, n: 1, c: 25),
      ),
      // 32
      Level(
        id: 'l32',
        name: 'Gangorra dupla',
        tip: 'Duas gangorras seguidas sobre o vazio. Devagar, elas não viram a tempo.',
        ground: false,
        zone: R(40, 270, 260, 220),
        goal: R(840, 300, 150, 140),
        ball: Pt(150, 440),
        plats: [_s(0, 508, 320, 508)],
        blocks: [R(830, 440, 170, 60)],
        seesaws: [_s(300, 493, 600, 430), _s(600, 470, 860, 440)],
        targets: Targets(t: 5.0, n: 1, c: 25),
      ),
      // 33
      Level(
        id: 'l33',
        name: 'Na hora certa',
        tip: 'O elevador tem seu ritmo. Chegue quando ele estiver embaixo: o tamanho da roda muda a velocidade.',
        zone: zone0(),
        goal: R(790, 170, 190, 130),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 2.4)],
        targets: Targets(t: 5.2, n: 1, c: 25),
      ),
      // 34
      Level(
        id: 'l34',
        name: 'Dois elevadores',
        tip: 'Um elevador leva ao primeiro degrau, o outro ao segundo. Eles não andam juntos.',
        zone: zone0(),
        goal: R(870, 110, 120, 140),
        ball: Pt(170, 440),
        blocks: [R(600, 400, 120, 100), R(860, 250, 140, 250)],
        lifts: [Lift(Pt(510, 508), Pt(510, 408), 180, 3), Lift(Pt(790, 408), Pt(790, 258), 140, 4.5)],
        targets: Targets(t: 4.6, n: 1, c: 25),
      ),
      // 35
      Level(
        id: 'l35',
        name: 'Elevador e vale',
        tip: 'Lá em cima ainda há um vão para atravessar.',
        zone: zone0(),
        goal: R(870, 170, 120, 130),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 60, 200), R(940, 300, 60, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 3)],
        targets: Targets(t: 4.7, n: 1, c: 25),
      ),
      // 36
      Level(
        id: 'l36',
        name: 'Botão distante',
        tip: 'O botão fica atrás da área verde. Uma engenhoca vai apertá-lo enquanto outra leva a bola.',
        zone: R(150, 270, 250, 220),
        goal: R(790, 360, 180, 140),
        ball: Pt(330, 440),
        doors: [R(620, 300, 30, 200)],
        buttons: [Pt(60, 500)],
        targets: Targets(t: 1.8, n: 3, c: 55),
      ),
      // 37
      Level(
        id: 'l37',
        name: 'Elevador com carga',
        tip: 'Bola solta no elevador: a gaiola precisa caber nele.',
        looseBall: true,
        zone: zone0(),
        goal: R(790, 170, 190, 130),
        ball: Pt(170, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 3)],
        targets: Targets(t: 4.6, n: 6, c: 90),
      ),
      // 38
      Level(
        id: 'l38',
        name: 'Carga na gangorra',
        tip: 'Bola solta na gangorra: passe do eixo sem deixar a bola cair.',
        looseBall: true,
        zone: zone0(),
        goal: R(800, 300, 190, 140),
        ball: Pt(170, 440),
        blocks: [R(780, 440, 220, 60)],
        seesaws: [_s(400, 493, 800, 385)],
        targets: Targets(t: 2.6, n: 6, c: 90),
      ),
      // 39
      Level(
        id: 'l39',
        name: 'Botão e elevador',
        tip: 'A porta no alto só abre com o botão lá atrás, e o elevador tem seu ritmo.',
        zone: R(150, 270, 250, 220),
        goal: R(870, 170, 120, 130),
        ball: Pt(330, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(640, 508), Pt(640, 308), 220, 2.6)],
        doors: [R(840, 150, 25, 150)],
        buttons: [Pt(60, 500)],
        targets: Targets(t: 10.4, n: 3, c: 55),
      ),
      // 40
      Level(
        id: 'l40',
        name: 'Hora do rush',
        tip: 'Botão atrás, elevador, porta e bola solta: tudo ao mesmo tempo.',
        looseBall: true,
        zone: R(150, 270, 250, 220),
        goal: R(870, 170, 120, 130),
        ball: Pt(300, 440),
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(630, 508), Pt(630, 308), 260, 3.2)],
        doors: [R(840, 150, 25, 150)],
        buttons: [Pt(60, 500)],
        targets: Targets(t: 5.0, n: 8, c: 120),
      ),
      // ---------- capítulo: Ímãs e mecanismos ----------
      // 41
      Level(
        id: 'l41',
        name: 'Atração',
        tip: 'Sem motor. O ímã fixo é sul: um ímã norte na engenhoca é puxado até ele.',
        zone: R(300, 300, 250, 190),
        goal: R(480, 360, 200, 140),
        ball: Pt(420, 478),
        magnets: [FixedMag(700, 478, 'S')],
        allowed: _noMotor,
        targets: Targets(t: 5.1, n: 3, c: 55),
      ),
      // 42
      Level(
        id: 'l42',
        name: 'Repulsão',
        tip: 'Sem motor. O ímã fixo atrás é norte: norte empurra norte.',
        zone: R(80, 300, 250, 190),
        goal: R(380, 360, 220, 140),
        ball: Pt(200, 478),
        magnets: [FixedMag(40, 478, 'N')],
        allowed: _noMotor,
        targets: Targets(t: 4.4, n: 3, c: 55),
      ),
      // 43
      Level(
        id: 'l43',
        name: 'Corrida de ímãs',
        tip: 'Sem motor. Um ímã atrás empurra, outro na frente puxa: use os dois.',
        zone: R(80, 300, 200, 190),
        goal: R(520, 360, 200, 140),
        ball: Pt(180, 478),
        magnets: [FixedMag(40, 478, 'N'), FixedMag(740, 478, 'S')],
        allowed: _noMotor,
        targets: Targets(t: 10.7, n: 5, c: 95),
      ),
      // 44
      Level(
        id: 'l44',
        name: 'Ímã e gaiola',
        tip: 'Sem motor e com a bola solta: uma gaiola puxada pelo ímã.',
        looseBall: true,
        zone: R(300, 300, 250, 190),
        goal: R(440, 360, 200, 140),
        ball: Pt(420, 478),
        magnets: [FixedMag(660, 470, 'S')],
        allowed: _noMotor,
        targets: Targets(t: 2.1, n: 7, c: 100),
      ),
      // 45
      Level(
        id: 'l45',
        name: 'Guindaste',
        tip: 'A meta fica numa prateleira. Uma roda com motor presa numa armação gira um braço com a bola na ponta.',
        zone: R(40, 200, 360, 290),
        goal: R(380, 150, 120, 130),
        ball: Pt(150, 230),
        blocks: [R(380, 280, 200, 220)],
        targets: Targets(t: 0.9, n: 6, c: 75),
      ),
      // 46
      Level(
        id: 'l46',
        name: 'Guindaste à esquerda',
        tip: 'Agora a prateleira fica do outro lado. Para que lado o braço precisa girar?',
        zone: R(600, 200, 360, 290),
        goal: R(500, 150, 120, 130),
        ball: Pt(850, 230),
        blocks: [R(420, 280, 200, 220)],
        targets: Targets(t: 0.9, n: 6, c: 75),
      ),
      // 47
      Level(
        id: 'l47',
        name: 'Guindaste alto',
        tip: 'Prateleira mais alta: o guindaste precisa de uma armação mais alta.',
        zone: R(40, 120, 360, 370),
        goal: R(400, 40, 140, 140),
        ball: Pt(120, 150),
        blocks: [R(400, 180, 200, 320)],
        targets: Targets(t: 1.1, n: 6, c: 75),
      ),
      // 48
      Level(
        id: 'l48',
        name: 'Guindaste e botão',
        tip: 'Uma porta fica no caminho do braço. O botão lá atrás abre.',
        zone: R(100, 200, 300, 290),
        goal: R(380, 150, 120, 130),
        ball: Pt(150, 230),
        blocks: [R(380, 280, 200, 220)],
        doors: [R(355, 40, 20, 170)],
        buttons: [Pt(40, 500)],
        targets: Targets(t: 0.9, n: 8, c: 105),
      ),
      // 49
      Level(
        id: 'l49',
        name: 'Mestre de obras',
        tip: 'Ponte, elevador e uma porta com botão atrás: junte tudo.',
        ground: false,
        zone: R(100, 300, 470, 190),
        goal: R(870, 170, 120, 130),
        ball: Pt(330, 440),
        plats: [_s(0, 508, 440, 508)],
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(650, 508), Pt(650, 308), 200, 3.2)],
        doors: [R(840, 150, 25, 150)],
        buttons: [Pt(40, 500)],
        targets: Targets(t: 4.5, n: 4, c: 65),
      ),
      // 50
      Level(
        id: 'l50',
        name: 'Grande final',
        tip: 'Ponte, elevador, porta com botão, bola solta e orçamento curto. Boa sorte!',
        ground: false,
        looseBall: true,
        budget: 160,
        zone: R(100, 300, 470, 190),
        goal: R(870, 170, 120, 130),
        ball: Pt(330, 440),
        plats: [_s(0, 508, 440, 508)],
        blocks: [R(760, 300, 240, 200)],
        lifts: [Lift(Pt(650, 508), Pt(650, 308), 200, 3.6)],
        doors: [R(840, 150, 25, 150)],
        buttons: [Pt(40, 500)],
        targets: Targets(t: 6.5, n: 9, c: 130),
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
