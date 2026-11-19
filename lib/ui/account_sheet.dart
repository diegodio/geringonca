// Tela da conta: entrar, criar conta, esqueci a senha, senha nova e, já
// conectado, quem está conectado, a sincronização e sair.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/i18n.dart';
import '../game/account.dart';
import '../game/controller.dart';
import '../game/palette.dart';
import '../game/progress.dart';
import 'widgets.dart';

bool _open = false;

/// Abre a conta numa folha de baixo. Não abre duas ao mesmo tempo.
Future<void> showAccountSheet(BuildContext context, GameController g) async {
  final a = g.account;
  if (a == null || !a.enabled || _open) return;
  _open = true;
  final c = Palette.of(context);
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.paper,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: AccountPanel(account: a, c: c),
          ),
        ),
      ),
    );
  } finally {
    _open = false;
  }
}

class AccountPanel extends StatefulWidget {
  final Account account;
  final Palette c;
  const AccountPanel({super.key, required this.account, required this.c});
  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  Account get a => widget.account;
  Palette get c => widget.c;

  bool _create = false; // aba: entrar ou criar conta
  bool _busy = false;
  String? _error, _info;
  final _name = TextEditingController(), _email = TextEditingController(), _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    await f();
    if (mounted) setState(() => _busy = false);
  }

  bool _validEmail() => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  Future<void> _submit() => _run(() async {
    if (!_validEmail()) {
      _error = tr('Esse e-mail não parece válido.');
      return;
    }
    if (_pass.text.length < 6) {
      _error = tr('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (_create) {
      if (_name.text.trim().isEmpty) {
        _error = tr('Escolha um nome para aparecer no jogo.');
        return;
      }
      final r = await a.signUp(_email.text, _pass.text, _name.text);
      if (r.error != null) {
        _error = tr(r.error!);
        return;
      }
      if (r.needsConfirm) {
        _info = tr('Conta criada! Abra o link que enviamos para {e} e depois entre aqui.', {'e': _email.text.trim()});
        _create = false;
      }
    } else {
      final e = await a.signIn(_email.text, _pass.text);
      if (e != null) _error = tr(e);
    }
  });

  Future<void> _forgot() => _run(() async {
    if (!_validEmail()) {
      _error = tr('Escreva o seu e-mail acima e toque de novo em "Esqueci minha senha".');
      return;
    }
    final e = await a.sendPasswordReset(_email.text);
    if (e != null) {
      _error = tr(e);
      return;
    }
    _info = tr('Se houver uma conta com esse e-mail, chega um link para criar uma senha nova.');
  });

  Future<void> _newPassword() => _run(() async {
    if (_pass.text.length < 6) {
      _error = tr('A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    final e = await a.setNewPassword(_pass.text);
    if (e != null) {
      _error = tr(e);
      return;
    }
    _info = tr('Senha nova salva.');
    _pass.clear();
  });

  InputDecoration _deco(String label, IconData icon) => InputDecoration(
    labelText: tr(label),
    prefixIcon: Icon(icon, color: c.muted),
    border: const OutlineInputBorder(),
    isDense: true,
  );

  Widget _field(TextEditingController ctl, String label, IconData icon, {bool password = false, TextInputType? type, List<String>? hints}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctl,
      obscureText: password,
      keyboardType: type,
      autofillHints: hints,
      enabled: !_busy,
      decoration: _deco(label, icon),
      onSubmitted: (_) => _submit(),
    ),
  );

  Widget _message() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: c.goal)),
        ),
      if (_info != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_info!, style: GoogleFonts.ibmPlexSans(fontSize: 13.5, color: c.zone)),
        ),
    ],
  );

  Widget _title(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      tr(s),
      style: GoogleFonts.chakraPetch(fontSize: 22, fontWeight: FontWeight.w700, color: c.ink),
    ),
  );

  Widget _sub(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Text(s, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.muted)),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: a, builder: (context, _) => _body());

  Widget _body() {
    // chegou pelo link de "esqueci minha senha"
    if (a.recovering) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title('Senha nova'),
          _sub(tr('Escolha a senha nova da sua conta.')),
          _field(_pass, 'Senha nova', Icons.lock_outline, password: true, hints: const [AutofillHints.newPassword]),
          TB(c: c, primary: true, label: 'Salvar senha', onTap: _busy ? null : _newPassword),
          _message(),
        ],
      );
    }
    final u = a.user;
    if (u != null) {
      final when = a.syncedAt;
      final status = a.syncing
          ? tr('Sincronizando…')
          : a.syncError != null
          ? tr(a.syncError!)
          : when != null
          ? tr('Progresso salvo na nuvem às {h}.', {'h': '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'})
          : tr('Progresso salvo na nuvem.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _title(u.name.isEmpty ? 'Sua conta' : u.name),
          _sub(u.email),
          Row(
            children: [
              Icon(a.syncError != null ? Icons.cloud_off_outlined : Icons.cloud_done_outlined, color: a.syncError != null ? c.goal : c.zone, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(status, style: GoogleFonts.ibmPlexSans(fontSize: 14, color: c.ink)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr('Todas as fases liberadas. O progresso e as fases que você cria ficam iguais em qualquer aparelho em que entrar.'),
            style: GoogleFonts.ibmPlexSans(fontSize: 13, color: c.muted),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              TB(c: c, icon: Icons.sync, label: 'Sincronizar agora', onTap: a.syncing ? null : () => a.sync()),
              TB(
                c: c,
                icon: Icons.logout,
                label: 'Sair',
                onTap: _busy
                    ? null
                    : () => _run(() async {
                        final e = await a.signOut();
                        if (e != null) _error = tr(e);
                      }),
              ),
            ],
          ),
          _message(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _title(_create ? 'Criar conta' : 'Entrar'),
        _sub(tr('Com uma conta você joga todas as fases (sem conta, só as {n} primeiras) e guarda o progresso e as suas fases na nuvem.', {'n': kGuestLevels})),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(tr('Entrar'))),
            ButtonSegment(value: true, label: Text(tr('Criar conta'))),
          ],
          selected: {_create},
          onSelectionChanged: _busy
              ? null
              : (v) => setState(() {
                  _create = v.first;
                  _error = null;
                  _info = null;
                }),
        ),
        const SizedBox(height: 14),
        if (_create) _field(_name, 'Nome', Icons.person_outline, hints: const [AutofillHints.nickname]),
        _field(_email, 'E-mail', Icons.mail_outline, type: TextInputType.emailAddress, hints: const [AutofillHints.email]),
        _field(_pass, 'Senha', Icons.lock_outline, password: true, hints: [_create ? AutofillHints.newPassword : AutofillHints.password]),
        TB(c: c, primary: true, label: _create ? 'Criar conta' : 'Entrar', onTap: _busy ? null : _submit),
        if (!_create)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _busy ? null : _forgot, child: Text(tr('Esqueci minha senha'))),
          ),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
        _message(),
      ],
    );
  }
}
