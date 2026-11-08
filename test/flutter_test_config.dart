import 'dart:async';

import 'package:geringonca/game/controller.dart';

/// Os testes conferem as mensagens em português: o "aparelho" fala português,
/// qualquer que seja o idioma da máquina que roda os testes.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GameState.deviceLanguage = () => 'pt';
  await testMain();
}
