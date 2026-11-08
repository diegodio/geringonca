import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart';

import 'game/controller.dart';
import 'game/fx.dart';
import 'game/palette.dart';
import 'game/storage.dart';
import 'ui/game_page.dart';
import 'ui/menu_page.dart';
import 'ui/platform/link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // na web, carrega o Box2D em WebAssembly direto do lugar certo (sem tentativas)
  await initializeForge2D(wasmUri: kIsWeb ? Uri.parse('assets/packages/forge2d/lib/src/backend/wasm/box2d.wasm') : null);
  final store = await Store.open();
  final g = GameController(store)..fxOut = playFx;
  runApp(GeringoncaApp(controller: g));
  // aberto por um link de compartilhamento (#c=...): vai direto para a fase
  final code = takeLinkCode();
  if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openLink(g, code));
}

final _nav = GlobalKey<NavigatorState>();
final _messenger = GlobalKey<ScaffoldMessengerState>();

void _openLink(GameController g, String code) {
  if (g.importCode(code)) {
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => GamePage(g: g)));
  } else {
    // código quebrado ou fase ainda bloqueada: avisa no menu
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(g.hint), duration: const Duration(seconds: 6)));
  }
}

class GeringoncaApp extends StatelessWidget {
  final GameController controller;
  const GeringoncaApp({super.key, required this.controller});

  ThemeData _theme(Palette c, Brightness b) => ThemeData(
        brightness: b,
        useMaterial3: true,
        scaffoldBackgroundColor: c.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: c.accent, brightness: b, surface: c.paper),
      );

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Geringonça',
        navigatorKey: _nav,
        scaffoldMessengerKey: _messenger,
        debugShowCheckedModeBanner: false,
        theme: _theme(Palette.light, Brightness.light),
        darkTheme: _theme(Palette.dark, Brightness.dark),
        home: MenuPage(g: controller),
      );
}
