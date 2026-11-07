// Sons sintetizados com Web Audio: nenhum arquivo para baixar, e funciona offline.
import 'dart:js_interop';

import 'package:web/web.dart' as web;

web.AudioContext? _ctx;

/// Contexto de áudio criado no primeiro som (depois de um toque, como o navegador exige).
web.AudioContext? get _ac {
  _ctx ??= web.AudioContext();
  if (_ctx!.state == 'suspended') _ctx!.resume().toDart.catchError((_) => null);
  return _ctx;
}

/// Um tom: forma de onda, frequência inicial e final, duração, volume e atraso.
void _tone(String type, double f0, double f1, double dur, double vol, [double delay = 0, double? cutoff]) {
  final ac = _ac;
  if (ac == null) return;
  final t = ac.currentTime + delay;
  final osc = ac.createOscillator()..type = type;
  osc.frequency.setValueAtTime(f0, t);
  osc.frequency.exponentialRampToValueAtTime(f1, t + dur);
  final g = ac.createGain();
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(vol, t + 0.008);
  g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
  web.AudioNode out = g;
  if (cutoff != null) {
    final lp = ac.createBiquadFilter()..type = 'lowpass';
    lp.frequency.value = cutoff;
    g.connect(lp);
    out = lp;
  }
  osc.connect(g);
  out.connect(ac.destination);
  osc.start(t);
  osc.stop(t + dur + 0.02);
}

void play(String name) {
  switch (name) {
    case 'tap':
      _tone('sine', 1400, 1100, 0.04, 0.05);
    case 'place': // batida de madeira
      _tone('triangle', 320, 140, 0.09, 0.28);
      _tone('square', 900, 500, 0.025, 0.03, 0, 2000);
    case 'remove':
      _tone('triangle', 520, 180, 0.13, 0.18);
    case 'undo':
      _tone('triangle', 300, 520, 0.1, 0.14);
    case 'start': // motor ligando
      _tone('sawtooth', 70, 180, 0.32, 0.09, 0, 900);
    case 'stop':
      _tone('sawtooth', 170, 60, 0.22, 0.08, 0, 700);
    case 'error':
      _tone('square', 160, 150, 0.07, 0.06, 0, 1200);
      _tone('square', 160, 150, 0.07, 0.06, 0.1, 1200);
    case 'win':
      for (final (i, f) in [523.25, 659.25, 783.99, 1046.5].indexed) {
        _tone('triangle', f, f, 0.22, 0.16, i * 0.09);
      }
    case 'medal':
      for (final (i, f) in [523.25, 659.25, 783.99, 1046.5, 1318.5].indexed) {
        _tone('triangle', f, f, 0.24, 0.16, i * 0.08);
      }
      _tone('sine', 2093, 2093, 0.5, 0.06, 0.42);
  }
}
