import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/flame.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/presentation/game/components/background_component.dart';
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

    // Quem é boss sai do conteúdo do jogo, não de uma lista escrita à mão aqui.
    // A primeira versão deste teste trazia `cave_hulk` como boss e `cave_maw`
    // como comum — o contrário do que `monsters.json` diz — e passava, porque
    // `SpriteAnimation.fromFrameData` não valida se a grade cabe na imagem:
    // recortava quadros de 32×32 de uma folha de 64×48 e devolvia recortes
    // fora dos limites. Verde, e mentindo.
    final monsters = JsonContentRepository.fromJson(
      heroClassesJson: File('assets/content/hero_classes.json').readAsStringSync(),
      monstersJson: File('assets/content/monsters.json').readAsStringSync(),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    ).monsters();

    expect(monsters.length, 12);
    expect(monsters.where((m) => m.isBoss).length, 3, reason: 'um boss por ato');

    for (final monster in monsters) {
      expect(
        await real(
          tester,
          () => catalog.monster(monster.id, isBoss: monster.isBoss),
        ),
        isNotNull,
        reason: 'sprite de ${monster.id} não carregou',
      );
    }
  });

  testWidgets('a folha de cada sprite tem o tamanho do contrato', (
    tester,
  ) async {
    // O complemento do teste acima, e a razão de ele não bastar: grade errada
    // não lança. Só comparar as dimensões do arquivo com
    // `contracts/assets-sprites.md` pega uma folha entregue no tamanho de outra.
    await real(tester, SpriteCatalog.load);

    /// Folha de personagem: 4 colunas do quadro, e 3 ou 4 linhas — a 4ª é a
    /// caminhada de R-M08-13, opcional por contrato.
    Future<void> expectSheet(String path, int frameW, int frameH) async {
      final image = await real(tester, () => Flame.images.load('sprites/$path'));
      expect(
        image.width,
        frameW * 4,
        reason: 'sprites/$path não tem as 4 colunas do contrato',
      );
      expect(
        image.height,
        anyOf(frameH * 3, frameH * 4),
        reason:
            'sprites/$path tem ${image.height} px de altura: esperado '
            '${frameH * 3} (sem caminhada) ou ${frameH * 4} (com)',
      );
    }

    Future<void> expectSize(String path, int w, int h) async {
      final image = await real(tester, () => Flame.images.load('sprites/$path'));
      expect(
        '${image.width}x${image.height}',
        '${w}x$h',
        reason: 'sprites/$path fora do contrato',
      );
    }

    final content = JsonContentRepository.fromJson(
      heroClassesJson: File('assets/content/hero_classes.json').readAsStringSync(),
      monstersJson: File('assets/content/monsters.json').readAsStringSync(),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );

    // Heróis: quadro 16×24.
    for (final hero in content.heroClasses()) {
      await expectSheet('heroes/${hero.id}.png', 16, 24);
    }
    // Monstros: 16×16 comuns, 32×32 bosses.
    for (final monster in content.monsters()) {
      final frame = monster.isBoss ? 32 : 16;
      await expectSheet('monsters/${monster.id}.png', frame, frame);
    }
    // Ícones de item e cenários de ato.
    for (final slot in const [
      'weapon',
      'armor',
      'helmet',
      'gloves',
      'boots',
      'amulet',
      'ring',
      'essence',
    ]) {
      await expectSize('items/$slot.png', 16, 16);
    }
    for (final act in const ['forest', 'cave', 'citadel']) {
      await expectSize(
        'backgrounds/$act.png',
        BackgroundComponent.artWidth.toInt(),
        BackgroundComponent.artHeight.toInt(),
      );
    }
  });

  testWidgets('a faixa de chão tem textura, senão a rolagem não aparece', (
    tester,
  ) async {
    // A queixa era "parece que estamos sempre no mesmo lugar". O cenário rolava
    // de verdade — só que o chão era uma cor chapada, 320 pixels idênticos por
    // linha, do horizonte até a base. Campo uniforme não mostra deslocamento
    // nenhum por mais rápido que role, e nenhum teste de posição pega isso:
    // tudo estava no lugar certo, movendo-se na velocidade certa, e invisível.
    await real(tester, SpriteCatalog.load);

    for (final act in const ['forest', 'cave', 'citadel']) {
      final image = await real(
        tester,
        () => Flame.images.load('sprites/backgrounds/$act.png'),
      );
      final data = await real(
        tester,
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      );
      final pixels = data!.buffer.asUint32List();

      final groundTop =
          image.height - BackgroundComponent.groundHeight.toInt();
      // Linhas amostradas ao longo da faixa, pulando as duas do horizonte.
      for (var y = groundTop + 4; y < image.height; y += 8) {
        final distintas = <int>{};
        for (var x = 0; x < image.width; x++) {
          distintas.add(pixels[y * image.width + x]);
        }
        expect(
          distintas.length,
          greaterThan(2),
          reason:
              'a linha $y do chão de $act tem ${distintas.length} cor(es): o '
              'chão voltou a ser chapado e a caminhada some',
        );
      }
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
