// Sons e vibração do jogo. O controlador só diz o que aconteceu (Sfx);
// aqui isso vira um som curto sintetizado e uma vibração leve.
import 'package:flutter/services.dart';

import 'sound/sound_stub.dart' if (dart.library.js_interop) 'sound/sound_web.dart' as sound;

/// O que aconteceu, do ponto de vista de quem joga.
enum Sfx {
  tap, // trocar de ferramenta, ligar uma opção
  place, // peça posta na bancada
  remove, // peça apagada
  undo,
  start, // rodar
  stop, // parar
  win, // bola na meta
  medal, // vitória com medalha ou desafio novo
  error, // ação recusada
}

/// Toca o som e a vibração de [s], conforme as opções ligadas.
void playFx(Sfx s, {required bool sound, required bool vibe}) {
  if (sound) _sound(s);
  if (vibe) _vibe(s);
}

void _sound(Sfx s) {
  try {
    sound.play(s.name);
  } catch (_) {} // sem áudio no aparelho: segue em silêncio
}

void _vibe(Sfx s) {
  final Future<void> Function() f = switch (s) {
    Sfx.tap || Sfx.undo => HapticFeedback.selectionClick,
    Sfx.place || Sfx.remove || Sfx.stop => HapticFeedback.lightImpact,
    Sfx.start => HapticFeedback.mediumImpact,
    Sfx.error => HapticFeedback.heavyImpact,
    Sfx.win || Sfx.medal => HapticFeedback.vibrate,
  };
  f().catchError((_) {});
}
