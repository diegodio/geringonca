import 'package:flutter_test/flutter_test.dart';
import 'package:geringonca/game/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('várias mudanças viram uma gravação só, meio segundo depois', () async {
    final p = await SharedPreferences.getInstance();
    final s = Store(p);
    final builds = <String, Object?>{'l1': 1};
    s.set('builds', builds);
    builds['l2'] = 2; // muda o mesmo objeto antes de gravar
    s.set('builds', builds);
    expect(p.getString('og-builds'), isNull); // ainda não gravou
    await Future<void>.delayed(const Duration(milliseconds: 700));
    expect(p.getString('og-builds'), '{"l1":1,"l2":2}');
  });

  test('ler um valor pendente grava antes e devolve o novo', () async {
    final p = await SharedPreferences.getInstance();
    final s = Store(p)..set('snap', false);
    expect(s.get<bool>('snap', true), isFalse);
    expect(p.getString('og-snap'), 'false');
  });

  test('flush grava na hora (app indo para o fundo)', () async {
    final p = await SharedPreferences.getInstance();
    final s = Store(p)..set('cur', 'l7');
    s.flush();
    expect(p.getString('og-cur'), '"l7"');
  });

  test('sem armazenamento, nada quebra', () {
    final s = Store(null)..set('x', 1);
    s.flush();
    expect(s.get<int>('x', 5), 5);
  });
}
