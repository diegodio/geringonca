/// Versão do jogo, posta pela publicação (veja .github/workflows/deploy.yml):
/// o número sobe a cada publicação e a data é a do dia em que ela saiu.
/// Rodando localmente, sem a publicação, aparece "dev".
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
const kAppDate = String.fromEnvironment('APP_DATE');

/// Texto curto para mostrar num canto: "v1.20 · 2026-11-14".
String get versionLabel => kAppDate.isEmpty ? 'v$kAppVersion' : 'v$kAppVersion · $kAppDate';
