// Conta do jogador: entrar, criar conta, sair, trocar a senha e manter o
// progresso e as fases próprias iguais em todos os aparelhos.
//
// Sincronização: ao entrar, o progresso da nuvem e o deste aparelho se juntam
// (fica o melhor de cada um) e as fases próprias vão e vêm. Depois, cada
// mudança é mandada alguns segundos depois (várias mudanças viram um envio só).
// Sem internet, tudo continua funcionando no aparelho e vai na próxima vez.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/model.dart';
import '../net/backend.dart';
import 'progress.dart';

class Account extends ChangeNotifier {
  /// Nulo: o jogo não tem servidor configurado (sem conta e sem limite de fases).
  final Backend? backend;
  final Progress progress;
  final Duration pushDelay;

  AccountUser? user;

  /// Chegou pelo link de "esqueci minha senha": falta escolher a senha nova.
  bool recovering = false;

  /// Sincronizando agora.
  bool syncing = false;

  /// Última sincronização certa, ou o erro da última tentativa (texto pronto).
  DateTime? syncedAt;
  String? syncError;

  StreamSubscription<({AccountUser? user, bool recovery})>? _sub;
  Timer? _push;

  Account(this.backend, this.progress, {this.pushDelay = const Duration(seconds: 4)}) {
    final b = backend;
    if (b == null) return;
    user = b.user;
    _applyLimit();
    progress.onChanged = _schedulePush;
    _sub = b.changes.listen(_onAuth);
    if (user != null) unawaited(sync());
  }

  bool get enabled => backend != null;
  bool get signedIn => user != null;

  void _applyLimit() => progress.guestLimit = enabled && user == null ? kGuestLevels : null;

  void _onAuth(({AccountUser? user, bool recovery}) e) {
    final before = user?.id;
    user = e.user;
    if (e.recovery) recovering = true;
    _applyLimit();
    notifyListeners();
    if (user != null && user!.id != before) unawaited(sync());
  }

  // ---------- entrar, criar conta, sair ----------
  /// Cada ação devolve nulo se deu certo, ou a mensagem do que deu errado.
  Future<String?> _do(Future<void> Function() f) async {
    try {
      await f();
      return null;
    } on BackendError catch (e) {
      return e.message;
    } catch (_) {
      return 'Não deu certo. Tente de novo.';
    }
  }

  /// Cria a conta. Mensagem nula + [needsConfirm] verdadeiro: falta abrir o link do e-mail.
  Future<({String? error, bool needsConfirm})> signUp(String email, String password, String name) async {
    var entered = false;
    final err = await _do(() async => entered = await backend!.signUp(email.trim(), password, name.trim()));
    if (err == null && entered) _refreshUser();
    return (error: err, needsConfirm: err == null && !entered);
  }

  Future<String?> signIn(String email, String password) async {
    final err = await _do(() => backend!.signIn(email.trim(), password));
    if (err == null) _refreshUser();
    return err;
  }

  Future<String?> signOut() async {
    await _flushPush();
    final err = await _do(() => backend!.signOut());
    if (err == null) {
      user = null;
      _applyLimit();
      notifyListeners();
    }
    return err;
  }

  Future<String?> sendPasswordReset(String email) => _do(() => backend!.sendPasswordReset(email.trim()));

  Future<String?> setNewPassword(String password) async {
    final err = await _do(() => backend!.setNewPassword(password));
    if (err == null) {
      recovering = false;
      notifyListeners();
    }
    return err;
  }

  /// O Supabase avisa pelo [Backend.changes]; aqui só garante que a tela já veja a conta.
  void _refreshUser() {
    final u = backend!.user;
    if (u == null || u.id == user?.id) return;
    _onAuth((user: u, recovery: false));
  }

  // ---------- sincronização ----------
  void _schedulePush() {
    if (!signedIn) return;
    _push?.cancel();
    _push = Timer(pushDelay, () => unawaited(push()));
  }

  Future<void> _flushPush() async {
    if (_push?.isActive ?? false) {
      _push!.cancel();
      await push();
    }
  }

  /// Junta o progresso e as fases deste aparelho com os da nuvem, nos dois sentidos.
  Future<void> sync() async {
    final b = backend;
    if (b == null || !signedIn || syncing) return;
    syncing = true;
    notifyListeners();
    try {
      final remote = await b.loadProgress();
      final merged = progress.mergeFrom(remote ?? {});
      // fases da nuvem que este aparelho ainda não tem (ou que mudaram em outro)
      for (final r in await b.loadLevels()) {
        final lv = Level.fromJson(r.data)..verified = r.verified;
        progress.putRemoteLevel(r.id, lv);
        _sent[r.id] = _sig(lv);
      }
      await b.saveProgress(merged);
      await _pushLevels();
      syncedAt = DateTime.now();
      syncError = null;
    } on BackendError catch (e) {
      syncError = e.message;
    } catch (_) {
      syncError = 'Não deu para sincronizar agora.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  /// Manda as mudanças deste aparelho (chamado alguns segundos depois de cada mudança).
  Future<void> push() async {
    final b = backend;
    if (b == null || !signedIn) return;
    try {
      await b.saveProgress(progress.syncData());
      await _pushLevels();
      syncedAt = DateTime.now();
      syncError = null;
    } on BackendError catch (e) {
      syncError = e.message;
    } catch (_) {
      syncError = 'Não deu para sincronizar agora.';
    }
    notifyListeners();
  }

  /// Assinatura de cada fase já enviada (id na nuvem -> conteúdo), para mandar só o que mudou.
  final Map<String, String> _sent = {};
  static String _sig(Level lv) => jsonEncode(lv.toJson(withId: false));

  Future<void> _pushLevels() async {
    final b = backend!;
    // novas ou alteradas
    for (final lv in List.of(progress.custom)) {
      final rid = progress.remoteIdOf(lv.id!);
      final sig = _sig(lv);
      if (rid != null && _sent[rid] == sig) continue;
      final id = await b.saveLevel(rid, lv.name, lv.toJson(withId: false), lv.verified);
      progress.setRemoteId(lv.id!, id);
      _sent[id] = sig;
    }
    // apagadas aqui: apaga na nuvem também
    final alive = {for (final c in progress.custom) c.id};
    for (final MapEntry(key: local, value: rid) in progress.remoteIds.entries) {
      if (alive.contains(local)) continue;
      await b.deleteLevel(rid);
      progress.setRemoteId(local, null);
      _sent.remove(rid);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _push?.cancel();
    super.dispose();
  }
}
