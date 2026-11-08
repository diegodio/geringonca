import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/core/i18n.dart';
import 'package:geringonca/core/i18n_en.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/model.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/progress.dart';
import 'package:geringonca/game/storage.dart';

Set<String> _marks(String s) => RegExp(r'\{\w+\}').allMatches(s).map((m) => m[0]!).toSet();

/// Textos em português passados ao tradutor no código: tr('…'), trN(n, '…', '…') e os
/// parâmetros que os componentes traduzem sozinhos (label:, tooltip:, label(c, …), …).
Set<String> _sourceKeys() {
  const lit = r"'((?:[^'\\]|\\.)*)'";
  final pats = [
    RegExp(r'\btr\(\s*' + lit),
    RegExp(r'\btrN\([^,]+,\s*' + lit + r',\s*' + lit),
    RegExp(r'\b(?:label|tooltip):\s*' + lit),
    RegExp(r'\b(?:label|tooltip):\s*[\w.!= ]+\?\s*' + lit + r'\s*:\s*' + lit),
    RegExp(r'\btr\([\w.!= ]+\?\s*' + lit + r'\s*:\s*' + lit),
    RegExp(r'\blabel\(c,\s*' + lit),
    RegExp(r"\bitem\('\w+',\s*[\w.?: ]+?,\s*" + lit),
    RegExp(r"\bet\('\w+',\s*" + lit),
    RegExp(r'_sheet\(c,\s*' + lit),
    RegExp(r'\brow\(' + lit),
    RegExp(r"\b_num\(c,\s*'\w+',\s*" + lit),
    RegExp(r'\bstepper\(' + lit),
    RegExp(r'\blabel:\s*[^,()]*?\?\s*' + lit + r'\s*:\s*' + lit),
    RegExp(r"'(?:block|door|plat|seesaw|lift|magnet|button|zone|goal|ball)':\s*" + lit),
    RegExp(r"\(\s*'\w+',\s*" + lit + r",\s*'\\\$\d+',"),
  ];
  final keys = <String>{};
  for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final s = f.readAsStringSync();
    for (final p in pats) {
      for (final m in p.allMatches(s)) {
        for (var i = 1; i <= m.groupCount; i++) {
          final g = m[i];
          if (g != null) keys.add(g.replaceAll(r"\'", "'").replaceAll(r'\$', r'$'));
        }
      }
    }
  }
  // só texto de verdade (não ícones, números ou interpolações)
  return keys.where((k) => RegExp(r'[A-Za-zÀ-ú]{2}').hasMatch(k) && !k.contains(r'${')).toSet();
}

void main() {
  test('todo texto do código tem tradução para o inglês', () {
    final keys = _sourceKeys();
    // o levantamento enxerga cada forma de uso (sanidade do próprio teste)
    expect(keys, containsAll(['Tentar de novo', 'Barra', 'Opções…', 'Rodar', '1 peça', 'Regras', 'Fases', 'Tempo', 'Bloco']));
    final missing = keys.where((k) => !kEn.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'sem tradução em i18n_en.dart');
  });

  test('fases, capítulos, peças, dicas e desafios têm tradução', () {
    final need = <String>[
      for (final l in kBuiltin) ...[l.name, if (l.tip.isNotEmpty) l.tip],
      for (final (t, s, _) in kChapters) ...[t, s],
      ...kPieceNames.values,
      ...kHints.values,
      ...kEHints.values,
      for (final (_, n, d) in kChallenges) ...[n, d],
      blankLevel().name,
      for (final (_, n, d, _) in kTemplates) ...[n, d],
    ];
    expect(need.where((k) => !kEn.containsKey(k)).toList(), isEmpty);
  });

  test('a tradução usa os mesmos marcadores do original', () {
    for (final MapEntry(:key, :value) in kEn.entries) {
      expect(_marks(value), _marks(key), reason: key);
    }
  });

  test('tr troca o idioma e preenche os marcadores', () {
    addTearDown(() => lang = Lang.pt);
    lang = Lang.pt;
    expect(tr('Fase {n}', {'n': '03'}), 'Fase 03');
    lang = Lang.en;
    expect(tr('Fase {n}', {'n': '03'}), 'Level 03');
    expect(trN(1, '1 peça', '{n} peças'), '1 part');
    expect(trN(4, '1 peça', '{n} peças'), '4 parts');
    expect(tr('texto sem tradução'), 'texto sem tradução');
    expect(fmt(2.5), '2.50');
    lang = Lang.pt;
    expect(fmt(2.5), '2,50');
    lang = Lang.en;
    expect(langFor('pt'), Lang.pt);
    expect(langFor('en'), Lang.en);
    expect(langFor('es'), Lang.en);
  });

  test('a opção de idioma vale para as mensagens do jogo', () {
    addTearDown(() => lang = Lang.pt);
    final g = GameController(Store(null));
    g.setLang('en');
    expect(lang, Lang.en);
    g.setTool('del');
    expect(g.hint, 'Tap a part to delete it.');
    g.setLang('pt');
    expect(g.hint, 'Toque numa peça para apagar.');
    g.langPref = 'auto';
    g.applyLang('en');
    expect(lang, Lang.en);
    g.applyLang('pt');
    expect(lang, Lang.pt);
  });
}
