import 'changelog.dart';

/// Versão do jogo: a entrada mais nova do histórico (changelog.dart). Uma
/// publicação só muda a versão quando ganha uma entrada nova lá; ajustes que não
/// acrescentam entrada saem com a mesma versão. Datas em GMT-3.
final String kAppVersion = kChangelog.first.version;
final String kAppDate = kChangelog.first.date;

/// Fase do jogo: beta enquanto as fases e as regras ainda estão sendo acertadas
/// com quem joga. Na versão 1.0, troque para ''.
const kAppStage = 'beta';

/// Texto curto para mostrar num canto: "v0.21.01 beta · 2026-11-14".
String get versionLabel {
  final v = kAppStage.isEmpty ? 'v$kAppVersion' : 'v$kAppVersion $kAppStage';
  return '$v · $kAppDate';
}
