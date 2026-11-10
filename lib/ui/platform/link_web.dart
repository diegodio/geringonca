// Links de compartilhamento no navegador: ler o código do endereço (#c=...),
// montar o endereço da página e abrir o compartilhar do sistema.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

/// Código que veio no endereço (#c=...), tirado do endereço para não abrir de novo ao recarregar.
String? takeLinkCode() {
  final hash = web.window.location.hash;
  if (!hash.startsWith('#c=')) return null;
  final loc = web.window.location;
  web.window.history.replaceState(null, '', '${loc.pathname}${loc.search}');
  return Uri.decodeComponent(hash.substring(3));
}

/// Endereço da página, sem o # e sem parâmetros.
String pageUrl() {
  final loc = web.window.location;
  return '${loc.origin}${loc.pathname}';
}

/// Abre o compartilhar do sistema (celular); falso quando o navegador não tem.
Future<bool> systemShare(String url, String title) async {
  final nav = web.window.navigator;
  if (!nav.has('share')) return false;
  try {
    await nav.share(web.ShareData(title: title, url: url)).toDart;
    return true;
  } catch (_) {
    return false; // cancelado ou bloqueado: quem chamou copia o link
  }
}

/// O navegador deixa a página ocupar a tela inteira? (No iPhone, não: lá o jogo
/// já ocupa toda a área da página.)
bool canFullscreen() => web.document.fullscreenEnabled && (web.document.documentElement?.has('requestFullscreen') ?? false);

bool isFullscreen() => web.document.fullscreenElement != null;

Future<void> setFullscreen(bool on) async {
  try {
    if (on) {
      await web.document.documentElement?.requestFullscreen().toDart;
    } else if (isFullscreen()) {
      await web.document.exitFullscreen().toDart;
    }
  } catch (_) {
    // recusado pelo navegador: fica como estava
  }
}
