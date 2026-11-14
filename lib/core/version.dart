/// Versão do jogo, posta pela publicação (veja .github/workflows/deploy.yml):
/// 0.<número da publicação>: o número sobe a cada publicação e a data é a do dia em que ela saiu.
/// Rodando localmente, sem a publicação, aparece "dev".
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
const kAppDate = String.fromEnvironment('APP_DATE');

/// Fase do jogo: beta enquanto as fases e as regras ainda estão sendo acertadas
/// com quem joga. Na versão 1.0, troque para '' (e a publicação para 1.x).
const kAppStage = 'beta';

/// Texto curto para mostrar num canto: "v0.20 beta · 2026-11-14".
String get versionLabel {
  final v = kAppStage.isEmpty ? 'v$kAppVersion' : 'v$kAppVersion $kAppStage';
  return kAppDate.isEmpty ? v : '$v · $kAppDate';
}
