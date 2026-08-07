import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/presentation/game/sprite_catalog.dart';

/// Os sprites de T143 chegam mesmo à tela.
///
/// Este arquivo existe por causa de um defeito que nenhum dos 429 testes
/// anteriores podia pegar: o Flame resolve caminho de imagem contra
/// `assets/images/` por padrão, e a arte deste projeto vive em
/// `assets/sprites/`. Todo carregamento falhava, caía no `catch` de
/// `SpriteCatalog` — que devolve `null` de propósito, para a arte poder chegar
/// em levas — e o jogo desenhava retângulos coloridos.
///
/// Nada quebrava. `flutter analyze` passava, os testes passavam, o APK
/// compilava. Só a arte não aparecia, e o mecanismo que garante que a falta de
/// arte não derruba o jogo é justamente o que escondia a falha.
///
/// A moral está no formato deste teste: onde há fallback silencioso, alguém tem
/// de afirmar que o caminho bom funciona.
void main() {
  // O decode de imagem é assíncrono de verdade: precisa de `runAsync`, senão o
  // relógio falso do teste nunca deixa o codec terminar.
  Future<T> real<T>(WidgetTester tester, Future<T> Function() body) async {
    final result = await tester.runAsync(body);
    return result as T;
  }

  testWidgets('as 6 classes têm sprite carregável', (tester) async {
    final catalog = await real(tester, SpriteCatalog.load);

    for (final classId in const [
      'berserker',
      'elementalist',
      'medtech',
      'sharpshooter',
      'tracker',
      'vanguard',
    ]) {
      final animations = await real(tester, () => catalog.hero(classId));
      expect(
        animations,
        isNotNull,
        reason: 'sprite do herói $classId não carregou — caiu no retângulo',
      );
      // A grade 4×3 do contrato: idle, ataque e morte, 4 quadros cada.
      expect(animations!.idle.frames.length, 4);
      expect(animations.attack.frames.length, 4);
      expect(animations.death.frames.length, 4);
      expect(animations.idle.loop, isTrue);
      // A morte congela no último quadro: ela fica na tela os 30 s do revive
      // (R-M01-06).
      expect(animations.death.loop, isFalse);
    }
  });

  testWidgets('os 12 monstros têm sprite carregável, bosses incluídos', (
    tester,
  ) async {
    final catalog = await real(tester, SpriteCatalog.load);

    const comuns = [
      'forest_bramble',
      'forest_sprout',
      'forest_stalker',
      'cave_gnawer',
      'cave_shardling',
      'cave_maw',
      'citadel_sentry',
      'citadel_revenant',
      'citadel_warden',
    ];
    const bosses = ['forest_warden', 'cave_hulk', 'citadel_tyrant'];

    for (final id in comuns) {
      expect(
        await real(tester, () => catalog.monster(id)),
        isNotNull,
        reason: 'sprite do monstro $id não carregou',
      );
    }
    for (final id in bosses) {
      expect(
        await real(tester, () => catalog.monster(id, isBoss: true)),
        isNotNull,
        reason: 'sprite do boss $id não carregou — quadro de 32×32',
      );
    }
  });

  testWidgets('os 3 atos têm fundo carregável', (tester) async {
    final catalog = await real(tester, SpriteCatalog.load);

    for (final act in const ['forest', 'cave', 'citadel']) {
      expect(
        await real(tester, () => catalog.background(act)),
        isNotNull,
        reason: 'fundo do ato $act não carregou',
      );
    }
  });

  // Sobre o caminho ruim — asset ausente devolvendo `null` em vez de exceção:
  // não há teste aqui, e não é esquecimento. O cache de `Flame.images` guarda o
  // future que falhou e deriva dele um segundo future sem tratador de erro, o
  // que faz a zona do `flutter_test` reportar a falha de asset **depois** do
  // teste terminar, mesmo com o `catch` de `SpriteCatalog` funcionando. O
  // resultado seria um teste vermelho afirmando algo verdadeiro.
  //
  // O comportamento continua garantido pelo `catch` em `SpriteCatalog._image` e
  // pelos `errorBuilder` dos componentes. O efeito colateral disto, aliás, é
  // bem-vindo: se um sprite desaparecer da árvore de assets, os testes de
  // widget desta pasta passam a falhar com erro não tratado em vez de seguirem
  // verdes desenhando retângulos.
}
