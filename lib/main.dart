import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:forge2d/forge2d.dart';

import 'game/account.dart';
import 'game/controller.dart';
import 'core/i18n.dart';
import 'game/fx.dart';
import 'game/palette.dart';
import 'game/storage.dart';
import 'ui/game_page.dart';
import 'ui/menu_page.dart';
import 'net/backend.dart';
import 'ui/account_sheet.dart';
import 'ui/platform/link.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // as fontes vêm de assets/fonts; sem buscar no Google ao abrir
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [('IBM Plex Sans', 'ibmplexsans'), ('IBM Plex Mono', 'ibmplexmono'), ('Chakra Petch', 'chakrapetch')]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/OFL-$file.txt'));
    }
    yield LicenseEntryWithLineBreaks(['Noto Sans Symbols 2', 'Noto Sans Ethiopic', 'Noto Color Emoji'], await rootBundle.loadString('assets/symbols/OFL-noto.txt'));
  });
  // na web, carrega o Box2D em WebAssembly direto do lugar certo (sem tentativas)
  await initializeForge2D(wasmUri: kIsWeb ? Uri.parse('assets/packages/forge2d/lib/src/backend/wasm/box2d.wasm') : null);
  final store = await Store.open();
  // ao ir para o fundo ou fechar, grava na hora o que estava esperando
  // (o próprio Flutter guarda o ouvinte enquanto o app vive)
  AppLifecycleListener(onHide: store.flush, onPause: store.flush, onDetach: store.flush);
  final g = GameController(store)..fxOut = playFx;
  // conta: só quando a publicação traz o endereço e a chave do Supabase
  Backend? backend;
  if (kBackendConfigured) {
    try {
      backend = await SupabaseBackend.start(redirectTo: pageUrl());
    } catch (_) {
      backend = null; // sem servidor: o jogo segue só no aparelho
    }
  }
  final account = Account(backend, g.progress);
  g.account = account;
  account.addListener(g.refresh);
  g.refresh();
  runApp(GeringoncaApp(controller: g));
  // chegou pelo link de "esqueci minha senha": pede a senha nova
  void askNewPassword() {
    final ctx = _nav.currentContext;
    if (account.recovering && ctx != null) showAccountSheet(ctx, g);
  }
  account.addListener(askNewPassword);
  WidgetsBinding.instance.addPostFrameCallback((_) => askNewPassword());
  // aberto por um link de compartilhamento (#c=...): vai direto para a fase
  final code = takeLinkCode();
  if (code != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openLink(g, code));
}

final _nav = GlobalKey<NavigatorState>();
final _messenger = GlobalKey<ScaffoldMessengerState>();

void _openLink(GameController g, String code) {
  // no editor ou testando uma fase, abrir outra fase perderia o que está sendo feito
  if (g.mode == Mode.edit || g.testing) return g.tell(tr('Salve ou cancele a fase antes de voltar ao menu.'));
  if (g.importCode(code)) {
    // uma bancada só: volta ao menu antes de abrir (o link pode chegar com o jogo aberto)
    _nav.currentState?.popUntil((r) => r.isFirst);
    _nav.currentState?.push(MaterialPageRoute(builder: (_) => GamePage(g: g)));
  } else {
    // código quebrado ou fase ainda bloqueada: avisa no menu
    _messenger.currentState?.showSnackBar(SnackBar(content: Text(g.hint), duration: const Duration(seconds: 6)));
  }
}

/// Link aberto com o jogo já aberto na aba: o navegador só troca o # do
/// endereço, e o Flutter entrega isso como uma rota (que o jogo não tem).
class _LinkRoutes with WidgetsBindingObserver {
  final GameController g;
  _LinkRoutes(this.g);

  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    final loc = info.uri.toString();
    final i = loc.indexOf('c=');
    if (i < 0) return false;
    _openLink(g, takeLinkCode() ?? '#c=${loc.substring(i + 2)}'); // importCode decodifica (e avisa se vier quebrado)
    return true;
  }
}

class GeringoncaApp extends StatefulWidget {
  final GameController controller;
  const GeringoncaApp({super.key, required this.controller});

  @override
  State<GeringoncaApp> createState() => _GeringoncaAppState();
}

class _GeringoncaAppState extends State<GeringoncaApp> {
  late final _links = _LinkRoutes(widget.controller);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_links); // antes do MaterialApp: vê a rota primeiro
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_links);
    super.dispose();
  }

  ThemeData _theme(Palette c, Brightness b) => ThemeData(
        brightness: b,
        useMaterial3: true,
        // símbolos que as fontes do jogo não têm, sem buscar fonte na internet (veja pubspec.yaml)
        fontFamilyFallback: kSymbolFonts,
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
        home: MenuPage(g: widget.controller),
      );
}
