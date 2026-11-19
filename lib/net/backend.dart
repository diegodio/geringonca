// Conta e nuvem do jogo. A interface [Backend] esconde o Supabase do resto do
// código (e deixa os testes usarem uma versão falsa, sem internet).
//
// O endereço e a chave pública do projeto vêm da publicação (--dart-define;
// veja docs/SUPABASE.md). Sem eles, o jogo funciona como sempre funcionou:
// tudo no aparelho, sem conta e sem limite de fases.
import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

const kSupabaseUrl = String.fromEnvironment('SUPABASE_URL');
// chave pública do projeto ("publishable", sb_publishable_...; a antiga "anon" também serve)
const kSupabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
bool get kBackendConfigured => kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;

/// Quem está conectado.
class AccountUser {
  final String id, email, name;
  const AccountUser(this.id, this.email, this.name);
}

/// Uma fase guardada na nuvem.
typedef RemoteLevel = ({String id, Map<String, dynamic> data, bool verified});

/// Erro com uma mensagem já pronta para mostrar (em português; a tela traduz).
class BackendError implements Exception {
  final String message;
  const BackendError(this.message);
  @override
  String toString() => message;
}

abstract class Backend {
  AccountUser? get user;

  /// Mudanças de quem está conectado. `recovery` é verdadeiro quando a pessoa
  /// chegou pelo link de "esqueci minha senha" e precisa escolher uma nova.
  Stream<({AccountUser? user, bool recovery})> get changes;

  /// Cria a conta. Devolve verdadeiro se já entrou; falso se precisa confirmar o e-mail.
  Future<bool> signUp(String email, String password, String name);
  Future<void> signIn(String email, String password);
  Future<void> signOut();
  Future<void> sendPasswordReset(String email);
  Future<void> setNewPassword(String password);

  Future<Map<String, dynamic>?> loadProgress();
  Future<void> saveProgress(Map<String, dynamic> data);
  Future<List<RemoteLevel>> loadLevels();

  /// Cria (id nulo) ou atualiza uma fase; devolve o id dela na nuvem.
  Future<String> saveLevel(String? id, String name, Map<String, dynamic> data, bool verified);
  Future<void> deleteLevel(String id);
}

/// Supabase de verdade.
class SupabaseBackend implements Backend {
  final String redirectTo;
  SupabaseBackend({required this.redirectTo});

  static Future<SupabaseBackend> start({required String redirectTo}) async {
    await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
    return SupabaseBackend(redirectTo: redirectTo);
  }

  SupabaseClient get _db => Supabase.instance.client;

  static AccountUser? _user(User? u) => u == null ? null : AccountUser(u.id, u.email ?? '', (u.userMetadata?['display_name'] as String?)?.trim() ?? '');

  @override
  AccountUser? get user => _user(_db.auth.currentUser);

  @override
  Stream<({AccountUser? user, bool recovery})> get changes =>
      _db.auth.onAuthStateChange.map((s) => (user: _user(s.session?.user), recovery: s.event == AuthChangeEvent.passwordRecovery));

  Future<T> _run<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on AuthException catch (e) {
      throw BackendError(_authMessage(e));
    } on PostgrestException catch (e) {
      throw BackendError('Erro ao falar com o servidor: ${e.message}');
    } on BackendError {
      rethrow;
    } catch (_) {
      throw const BackendError('Sem conexão com o servidor. Confira a internet e tente de novo.');
    }
  }

  static String _authMessage(AuthException e) {
    final m = e.message.toLowerCase();
    if (m.contains('invalid login')) return 'E-mail ou senha incorretos.';
    if (m.contains('not confirmed')) return 'Confirme o e-mail antes de entrar: abra o link que enviamos.';
    if (m.contains('already registered') || m.contains('already been registered')) return 'Já existe uma conta com esse e-mail.';
    if (m.contains('password') && (m.contains('6') || m.contains('short') || m.contains('weak'))) {
      return 'A senha precisa ter pelo menos 6 caracteres.';
    }
    if (m.contains('rate limit') || m.contains('too many') || e.statusCode == '429') return 'Muitas tentativas seguidas. Espere um pouco e tente de novo.';
    if (m.contains('invalid') && m.contains('email')) return 'Esse e-mail não parece válido.';
    return 'Não deu certo: ${e.message}';
  }

  @override
  Future<bool> signUp(String email, String password, String name) => _run(() async {
    final r = await _db.auth.signUp(email: email, password: password, data: {'display_name': name}, emailRedirectTo: redirectTo);
    return r.session != null;
  });

  @override
  Future<void> signIn(String email, String password) => _run(() => _db.auth.signInWithPassword(email: email, password: password));

  @override
  Future<void> signOut() => _run(() => _db.auth.signOut());

  @override
  Future<void> sendPasswordReset(String email) => _run(() => _db.auth.resetPasswordForEmail(email, redirectTo: redirectTo));

  @override
  Future<void> setNewPassword(String password) => _run(() => _db.auth.updateUser(UserAttributes(password: password)));

  String get _uid {
    final u = _db.auth.currentUser;
    if (u == null) throw const BackendError('Entre na sua conta primeiro.');
    return u.id;
  }

  @override
  Future<Map<String, dynamic>?> loadProgress() => _run(() async {
    final row = await _db.from('progress').select('data').eq('user_id', _uid).maybeSingle();
    final d = row?['data'];
    return d is Map ? Map<String, dynamic>.from(d) : null;
  });

  @override
  Future<void> saveProgress(Map<String, dynamic> data) => _run(() => _db.from('progress').upsert({'user_id': _uid, 'data': data}));

  @override
  Future<List<RemoteLevel>> loadLevels() => _run(() async {
    final rows = await _db.from('levels').select('id, data, verified').eq('owner', _uid).order('created_at');
    return [
      for (final r in rows)
        if (r['data'] is Map) (id: r['id'] as String, data: Map<String, dynamic>.from(r['data'] as Map), verified: r['verified'] == true),
    ];
  });

  @override
  Future<String> saveLevel(String? id, String name, Map<String, dynamic> data, bool verified) => _run(() async {
    final row = {'name': name.length > 40 ? name.substring(0, 40) : name, 'data': data, 'verified': verified};
    if (id != null) {
      final up = await _db.from('levels').update(row).eq('id', id).select('id');
      if (up.isNotEmpty) return id;
    }
    final ins = await _db.from('levels').insert({...row, 'owner': _uid}).select('id').single();
    return ins['id'] as String;
  });

  @override
  Future<void> deleteLevel(String id) => _run(() => _db.from('levels').delete().eq('id', id));
}
