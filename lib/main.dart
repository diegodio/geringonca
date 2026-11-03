import 'package:flutter/material.dart';
import 'package:forge2d/forge2d.dart';

import 'game/controller.dart';
import 'game/palette.dart';
import 'game/storage.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeForge2D(); // na web, carrega o Box2D em WebAssembly
  final store = await Store.open();
  runApp(GeringoncaApp(controller: GameController(store)));
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
        debugShowCheckedModeBanner: false,
        theme: _theme(Palette.light, Brightness.light),
        darkTheme: _theme(Palette.dark, Brightness.dark),
        home: HomePage(g: controller),
      );
}
