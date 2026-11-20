// Link de compartilhamento aberto com o jogo já aberto na aba: o navegador só
// troca o # do endereço, e o Flutter entrega isso como uma rota nova.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forge2d/forge2d.dart';
import 'package:geringonca/core/levels.dart';
import 'package:geringonca/core/share.dart';
import 'package:geringonca/game/controller.dart';
import 'package:geringonca/game/storage.dart';
import 'package:geringonca/main.dart';
import 'package:geringonca/ui/game_page.dart';

Future<void> _frames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

/// O que o Flutter na web manda quando o # do endereço muda.
Future<void> _hashChange(WidgetTester t, String hash) async {
  final msg = const JSONMethodCodec().encodeMethodCall(MethodCall('pushRouteInformation', {'location': hash, 'state': null}));
  await t.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/navigation', msg, (_) {});
}

void main() {
  setUpAll(() async => initializeForge2D());

  testWidgets('link aberto com o jogo já aberto leva à fase com a engenhoca', (t) async {
    t.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final g = GameController(Store(null));
    await t.pumpWidget(GeringoncaApp(controller: g));
    await _frames(t, 10);
    final lv = kBuiltin.first;
    final parts = sampleFor(lv, lv.ball)!;
    await _hashChange(t, 'c=${linkCode(lv, parts, lv.ball)}');
    await _frames(t, 30);
    expect(t.takeException(), isNull);
    expect(find.byType(GamePage), findsOneWidget);
    expect(g.level.id, lv.id);
    expect(g.parts, hasLength(parts.length));
    // outro link com a fase já aberta: continua uma tela só
    await _hashChange(t, 'c=${linkCode(lv, parts.take(1).toList(), lv.ball)}');
    await _frames(t, 30);
    expect(t.takeException(), isNull);
    expect(find.byType(GamePage), findsOneWidget);
    expect(g.parts, hasLength(1));
  });
}
