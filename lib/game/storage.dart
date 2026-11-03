import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guarda o progresso no aparelho, com as mesmas chaves da versão HTML (prefixo "og-").
class Store {
  final SharedPreferences? _p;
  Store(this._p);

  static Future<Store> open() async {
    try {
      return Store(await SharedPreferences.getInstance());
    } catch (_) {
      return Store(null); // sem armazenamento, o jogo funciona sem salvar
    }
  }

  T get<T>(String k, T d) {
    try {
      final v = _p?.getString('og-$k');
      if (v == null) return d;
      final o = jsonDecode(v);
      return o is T ? o : d;
    } catch (_) {
      return d;
    }
  }

  void set(String k, Object? v) {
    try {
      _p?.setString('og-$k', jsonEncode(v));
    } catch (_) {}
  }
}
