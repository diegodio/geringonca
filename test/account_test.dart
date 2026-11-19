// Conta e nuvem sem internet: um servidor falso, em memória, no lugar do Supabase.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/game/account.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/progress.dart';
import 'package:geringonca/game/progress_sync.dart';
import 'package:geringonca/game/storage.dart';
import 'package:geringonca/net/backend.dart';

class FakeBackend implements Backend {
  final _ctl = StreamController<({AccountUser? user, bool recovery})>.broadcast();
  final Map<String, ({String password, String name})> accounts = {};
  final Map<String, Map<String, dynamic>> progressOf = {};
  final Map<String, Map<String, RemoteLevel>> levelsOf = {};
  bool confirmEmail = false, offline = false;
  int _ids = 0;

  @override
  AccountUser? user;

  @override
  Stream<({AccountUser? user, bool recovery})> get changes => _ctl.stream;

  void _check() {
    if (offline) throw const BackendError('Sem conexão com o servidor. Confira a internet e tente de novo.');
  }

  @override
  Future<bool> signUp(String email, String password, String name) async {
    _check();
    if (accounts.containsKey(email)) throw const BackendError('Já existe uma conta com esse e-mail.');
    accounts[email] = (password: password, name: name);
    if (confirmEmail) return false;
    user = AccountUser('u-$email', email, name);
    _ctl.add((user: user, recovery: false));
    return true;
  }

  @override
  Future<void> signIn(String email, String password) async {
    _check();
    final a = accounts[email];
    if (a == null || a.password != password) throw const BackendError('E-mail ou senha incorretos.');
    user = AccountUser('u-$email', email, a.name);
    _ctl.add((user: user, recovery: false));
  }

  @override
  Future<void> signOut() async {
    user = null;
    _ctl.add((user: null, recovery: false));
  }

  @override
  Future<void> sendPasswordReset(String email) async => _check();
  @override
  Future<void> setNewPassword(String password) async => _check();

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    _check();
    return progressOf[user!.id];
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> data) async {
    _check();
    progressOf[user!.id] = Map.of(data);
  }

  @override
  Future<List<RemoteLevel>> loadLevels() async {
    _check();
    return (levelsOf[user!.id] ?? {}).values.toList();
  }

  @override
  Future<String> saveLevel(String? id, String name, Map<String, dynamic> data, bool verified) async {
    _check();
    final mine = levelsOf.putIfAbsent(user!.id, () => {});
    final rid = id != null && mine.containsKey(id) ? id : 'lv${++_ids}';
    mine[rid] = (id: rid, data: data, verified: verified);
    return rid;
  }

  @override
  Future<void> deleteLevel(String id) async {
    _check();
    levelsOf[user!.id]?.remove(id);
  }
}

/// Espera as tarefas pendentes (sincronizações) terminarem.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  group('juntar o progresso de dois aparelhos', () {
    test('fica o melhor de cada lado', () {
      final a = {
        'done': ['l1', 'l8'],
        'medals': {
          'l1': {'t': true, 'n': false},
        },
        'recs': {
          'l1': {'t': 2.5, 'n': 3, 'c': 50},
        },
        'bests': {
          'l1': {'time': 2.5},
        },
        'badges': {
          'l1': ['first'],
        },
        'tries': {'l1': 4},
      };
      final b = {
        'done': ['l1', 'l14'],
        'medals': {
          'l1': {'n': true},
          'l14': {'c': true},
        },
        'recs': {
          'l1': {'t': 3.0, 'n': 1},
        },
        'bests': {
          'l1': {'time': 1.9},
        },
        'badges': {
          'l1': ['norod'],
        },
        'tries': {'l1': 2, 'l14': 7},
      };
      final m = mergeProgress(a, b);
      expect(m['done'], ['l1', 'l14', 'l8']);
      expect(m['medals']['l1'], {'t': true, 'n': true});
      expect(m['medals']['l14'], {'c': true});
      expect(m['recs']['l1'], {'t': 2.5, 'n': 1, 'c': 50});
      expect(m['bests']['l1']['time'], 1.9);
      expect((m['badges']['l1'] as List).toSet(), {'first', 'norod'});
      expect(m['tries'], {'l1': 4, 'l14': 7});
    });
  });

  group('conta', () {
    test('sem servidor: sem conta e sem limite de fases', () {
      final g = GameController(Store(null));
      final a = Account(null, g.progress);
      expect(a.enabled, isFalse);
      expect(g.progress.needsAccount(kBuiltin.last.id!), isFalse);
    });

    test('sem conta, só as 7 primeiras fases; ao entrar, todas', () async {
      final g = GameController(Store(null));
      final fb = FakeBackend()..accounts['ana@x.com'] = (password: 'segredo', name: 'Ana');
      final a = Account(fb, g.progress, pushDelay: Duration.zero)..addListener(g.refresh);
      expect(g.progress.needsAccount(kBuiltin[kGuestLevels - 1].id!), isFalse);
      expect(g.progress.needsAccount(kBuiltin[kGuestLevels].id!), isTrue);
      expect(g.progress.isUnlocked(kBuiltin[kGuestLevels].id!), isFalse);
      g.chooseLevel(kBuiltin[kGuestLevels].id!);
      expect(g.level.id, isNot(kBuiltin[kGuestLevels].id));
      expect(g.hint, contains('conta'));

      expect(await a.signIn('ana@x.com', 'errada'), contains('incorretos'));
      expect(a.signedIn, isFalse);
      expect(await a.signIn('ana@x.com', 'segredo'), isNull);
      await settle();
      expect(a.signedIn, isTrue);
      expect(g.progress.needsAccount(kBuiltin[kGuestLevels].id!), isFalse);

      await a.signOut();
      expect(g.progress.needsAccount(kBuiltin[kGuestLevels].id!), isTrue);
    });

    test('criar conta com confirmação por e-mail não entra ainda', () async {
      final g = GameController(Store(null));
      final fb = FakeBackend()..confirmEmail = true;
      final a = Account(fb, g.progress);
      final r = await a.signUp('bia@x.com', 'segredo', 'Bia');
      expect(r.error, isNull);
      expect(r.needsConfirm, isTrue);
      expect(a.signedIn, isFalse);
    });

    test('ao entrar, o progresso deste aparelho e o da nuvem se juntam', () async {
      final fb = FakeBackend()..accounts['ana@x.com'] = (password: 'segredo', name: 'Ana');
      fb.progressOf['u-ana@x.com'] = {
        'done': ['l8'],
      };
      final g = GameController(Store(null));
      g.progress.recordWin(kBuiltin.first, 2, sampleFor(kBuiltin.first, kBuiltin.first.ball)!, kBuiltin.first.ball);
      final a = Account(fb, g.progress, pushDelay: Duration.zero);
      await a.signIn('ana@x.com', 'segredo');
      await settle();
      expect(g.progress.isDone('l1'), isTrue);
      expect(g.progress.isDone('l8'), isTrue, reason: 'veio da nuvem');
      expect((fb.progressOf['u-ana@x.com']!['done'] as List).toSet(), {'l1', 'l8'}, reason: 'foi para a nuvem');
      expect(a.syncError, isNull);
    });

    test('fases próprias vão para a nuvem, voltam em outro aparelho e somem juntas', () async {
      final fb = FakeBackend()..accounts['ana@x.com'] = (password: 'segredo', name: 'Ana');
      // aparelho 1: cria uma fase e entra
      final g1 = GameController(Store(null));
      final id = g1.progress.saveLevel(blankLevel()..name = 'Minha');
      final a1 = Account(fb, g1.progress, pushDelay: Duration.zero);
      await a1.signIn('ana@x.com', 'segredo');
      await settle();
      expect(fb.levelsOf['u-ana@x.com'], hasLength(1));
      // aparelho 2: entra e recebe a fase
      fb.user = null;
      final g2 = GameController(Store(null));
      final a2 = Account(fb, g2.progress, pushDelay: Duration.zero);
      await a2.signIn('ana@x.com', 'segredo');
      await settle();
      expect(g2.progress.custom.map((l) => l.name), ['Minha']);
      // aparelho 1 apaga: some da nuvem
      g1.progress.deleteLevel(id);
      await settle();
      await a1.push();
      expect(fb.levelsOf['u-ana@x.com'], isEmpty);
    });

    test('sem internet, o jogo segue e avisa', () async {
      final fb = FakeBackend()..accounts['ana@x.com'] = (password: 'segredo', name: 'Ana');
      final g = GameController(Store(null));
      final a = Account(fb, g.progress, pushDelay: Duration.zero);
      await a.signIn('ana@x.com', 'segredo');
      await settle();
      fb.offline = true;
      await a.push();
      expect(a.syncError, isNotNull);
      g.progress.addTry('l1'); // continua gravando no aparelho
      expect(g.progress.triesOf('l1'), 1);
    });
  });
}
