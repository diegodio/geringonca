// Idiomas do jogo. O texto em português é a própria chave: tr() devolve a
// tradução do idioma atual (ou o original, se não houver) e preenche os
// marcadores {nome} com [args]. As traduções ficam em i18n_en.dart.
import 'i18n_en.dart';

enum Lang { pt, en }

/// Idioma em uso (o controlador escolhe pela opção salva ou pelo aparelho).
Lang lang = Lang.pt;

/// Idioma de um código de localidade do aparelho: português fica em português, o resto em inglês.
Lang langFor(String languageCode) => languageCode.toLowerCase() == 'pt' ? Lang.pt : Lang.en;

String tr(String pt, [Map<String, Object?> args = const {}]) {
  var s = lang == Lang.en ? (kEn[pt] ?? pt) : pt;
  for (final MapEntry(:key, :value) in args.entries) {
    s = s.replaceAll('{$key}', '$value');
  }
  return s;
}

/// Singular ou plural: [one] quando n == 1, [many] nos outros casos ({n} é o número).
String trN(int n, String one, String many, [Map<String, Object?> args = const {}]) =>
    tr(n == 1 ? one : many, {'n': n, ...args});
