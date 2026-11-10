// Fora do navegador não há endereço da página nem compartilhamento do sistema.
String? takeLinkCode() => null;
String pageUrl() => 'https://diegodio.github.io/geringonca/';
Future<bool> systemShare(String url, String title) async => false;

// Tela cheia só existe no navegador.
bool canFullscreen() => false;
bool isFullscreen() => false;
Future<void> setFullscreen(bool on) async {}
