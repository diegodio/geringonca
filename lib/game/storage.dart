import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o progresso no aparelho, com as mesmas chaves da versão HTML (prefixo "og-").
///
/// As gravações são agrupadas: [set] só anota o valor, e [flush] grava tudo de uma
/// vez meio segundo depois da última mudança (ou na hora, quando o app vai para o
/// fundo). Assim, montar uma engenhoca peça por peça não regrava o progresso de
/// todas as fases a cada toque.
class Store {
  final SharedPreferences? _p;
  Store(this._p);

  static const _delay = Duration(milliseconds: 500);
  final _pending = <String, Object?>{};
  Timer? _timer;

  static Future<Store> open() async {
    try {
      return Store(await SharedPreferences.getInstance());
    } catch (_) {
      return Store(null); // sem armazenamento, o jogo funciona sem salvar
    }
  }

  T get<T>(String k, T d) {
    if (_pending.containsKey(k)) flush(); // lê o que acabou de mudar
    try {
      final v = _p?.getString('og-$k');
      if (v == null) return d;
      final o = jsonDecode(v);
      return o is T ? o : d;
    } catch (_) {
      return d;
    }
  }

  /// Anota [v] para gravar em seguida. O valor é convertido só na hora de gravar,
  /// então várias mudanças no mesmo objeto viram uma gravação só.
  void set(String k, Object? v) {
    if (_p == null) return;
    _pending[k] = v;
    _timer ??= Timer(_delay, flush);
  }

  /// Grava agora tudo o que está pendente.
  void flush() {
    _timer?.cancel();
    _timer = null;
    if (_pending.isEmpty) return;
    final items = Map.of(_pending);
    _pending.clear();
    for (final MapEntry(:key, :value) in items.entries) {
      try {
        _p?.setString('og-$key', jsonEncode(value));
      } catch (_) {}
    }
  }
}
