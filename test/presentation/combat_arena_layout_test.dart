import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/entities/monster.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/game/components/background_component.dart';
import 'package:pixel_idle_quest/presentation/game/components/combatant_component.dart';

import '../support/test_content.dart';

/// Composição da arena: onde cada coisa é desenhada.
///
/// Este arquivo nasceu de um print de tela do jogo rodando no aparelho. Havia
/// dois defeitos, e nenhum dos 435 testes anteriores podia pegar — porque
/// nenhum deles olhava **posição**:
///
/// 1. Metade da arena estava preta. O padrão do Flame é `Anchor.center` no
///    viewfinder: o mundo (0,0) cai no centro da tela. Toda a composição desta
///    arena é medida a partir do canto, então tudo aparecia meia tela deslocado
///    e os monstros de slot alto ficavam fora da tela.
/// 2. Os heróis eram retângulos coloridos enquanto monstros e cenário já eram
///    pixel art. Os componentes de herói nascem no primeiro `sync` — que vem do
///    `build` da tela, antes de `onLoad` terminar —, o catálogo ainda era nulo,
///    e a vestimenta nunca era tentada de novo. Os monstros escapavam por
///    acidente: cada wave troca os componentes.
///
/// Teste de domínio não vê nada disso. O que faltava era afirmar geometria.
void main() {
  /// 4 heróis e 8 monstros: o pior caso de lotação da arena (R-M08-05).
  CombatState fullArena() => CombatState.start(
    position: const ProgressPosition(difficulty: 1, act: 1, wave: 3),
    heroes: [
      for (final classId in const [
        'vanguard',
        'elementalist',
        'sharpshooter',
        'berserker',
      ])
        HeroCombatant.fresh(
          heroId: 'hero_$classId',
          definition: TestContent.heroClass(id: classId),
          stats: TestContent.stats(attack: 100, maxHp: 500),
        ),
    ],
    monsters: [
      for (var slot = 0; slot < 8; slot++)
        Monster.spawn(
          instanceId: 'm$slot',
          template: TestContent.monster(id: 'forest_bramble'),
          stats: TestContent.stats(maxHp: 100),
          slot: slot,
        ),
    ],
  );

  /// Monta a arena num viewport de celular em retrato, com o `sync` chegando
  /// **antes** do layout — que é a ordem real: `CombatScreen.build` chama `sync`
  /// e só depois o `GameWidget` recebe tamanho.
  Future<CombatArena> mount(
    WidgetTester tester, {
    Size size = const Size(390, 640),
    CombatState? state,
  }) async {
    final arena = CombatArena(onFixedStep: (_) {});
    arena.sync(state ?? fullArena(), null);

    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: arena)));
    await tester.pump(const Duration(milliseconds: 100));
    return arena;
  }

  /// Deixa o carregamento de imagem terminar.
  ///
  /// Decodificar imagem é assíncrono de verdade: o relógio falso do teste
  /// sozinho nunca conclui o codec, daí o `runAsync`. E `sync` é chamado a cada
  /// volta porque é o que a tela faz — ela chama do `build`, a cada quadro, e é
  /// dessa repetição que sai a segunda chance de vestir quem nasceu antes de o
  /// catálogo existir.
  Future<void> settleSprites(
    WidgetTester tester,
    CombatArena arena,
    CombatState state,
  ) async {
    for (var i = 0; i < 15; i++) {
      arena.sync(state, null);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  List<CombatantComponent> combatants(CombatArena arena) =>
      arena.world.children.whereType<CombatantComponent>().toList();

  testWidgets('a origem do mundo é o canto da arena, não o centro', (
    tester,
  ) async {
    final arena = await mount(tester);

    // O defeito do print aparecia exatamente aqui: com `Anchor.center`, o
    // retângulo visível começava em (-195, -320).
    final visible = arena.camera.visibleWorldRect;
    expect(visible.left, 0);
    expect(visible.top, 0);

    // A largura do mundo é a nativa da arte, então o cenário sai 1:1.
    expect(visible.width, BackgroundComponent.artWidth);
  });

  testWidgets('o cenário cobre a arena inteira, sem faixa preta', (
    tester,
  ) async {
    final arena = await mount(tester);
    final background = arena.world.children
        .whereType<BackgroundComponent>()
        .single;
    final visible = arena.camera.visibleWorldRect;

    expect(background.position, Vector2.zero());
    expect(background.size.x, visible.width);
    expect(background.size.y, closeTo(visible.height, 0.01));
    // Em retrato a arena é bem mais alta que os 16:9 da arte: a faixa de chão
    // fica na base, e a sobra acima é céu.
    expect(background.size.y, greaterThan(BackgroundComponent.artHeight));
    expect(
      background.groundTopY,
      closeTo(background.size.y - BackgroundComponent.groundHeight, 0.01),
    );
  });

  testWidgets('4 heróis e 8 monstros cabem na arena e pisam no chão', (
    tester,
  ) async {
    final arena = await mount(tester);
    final visible = arena.camera.visibleWorldRect;
    final background = arena.world.children
        .whereType<BackgroundComponent>()
        .single;
    final views = combatants(arena);

    expect(views.length, 12, reason: '4 heróis + 8 monstros na arena');

    for (final view in views) {
      // Âncora é `bottomCenter`: x é o centro, y são os pés.
      final left = view.position.x - view.size.x / 2;
      final right = view.position.x + view.size.x / 2;
      expect(
        left,
        greaterThanOrEqualTo(0),
        reason: '${view.entityId} sai pela esquerda da arena',
      );
      expect(
        right,
        lessThanOrEqualTo(visible.width),
        reason: '${view.entityId} sai pela direita da arena — era o que '
            'acontecia com os monstros de slot 4 a 7',
      );
      // Os pés na faixa de chão: nem flutuando no céu, nem abaixo da tela.
      expect(
        view.position.y,
        greaterThanOrEqualTo(background.groundTopY),
        reason: '${view.entityId} flutua acima da linha do chão',
      );
      expect(
        view.position.y,
        lessThanOrEqualTo(visible.height),
        reason: '${view.entityId} está abaixo da base da arena',
      );
    }
  });

  testWidgets('girar o aparelho recoloca todo mundo no chão', (tester) async {
    final arena = await mount(tester);
    final antes = combatants(arena).first.position.y;

    await tester.binding.setSurfaceSize(const Size(640, 390));
    await tester.pump(const Duration(milliseconds: 100));

    final background = arena.world.children
        .whereType<BackgroundComponent>()
        .single;
    final visible = arena.camera.visibleWorldRect;

    expect(background.size.y, closeTo(visible.height, 0.01));
    for (final view in combatants(arena)) {
      expect(
        view.position.y,
        greaterThanOrEqualTo(background.groundTopY),
        reason: '${view.entityId} ficou no chão antigo depois do giro',
      );
      expect(view.position.x + view.size.x / 2, lessThanOrEqualTo(visible.width));
    }
    // A arena ficou mais baixa: a linha do chão subiu junto.
    expect(combatants(arena).first.position.y, lessThan(antes));
  });

  testWidgets(
    'os heróis ganham sprite mesmo nascendo antes de onLoad terminar',
    (tester) async {
      final state = fullArena();
      final arena = await mount(tester, state: state);
      await settleSprites(tester, arena, state);

      final views = combatants(arena);
      expect(views.length, 12);
      expect(
        views.where((v) => !v.hasSprite).map((v) => v.entityId),
        isEmpty,
        reason:
            'ficaram de retângulo — o sprite nunca foi aplicado depois que o '
            'catálogo apareceu',
      );
    },
  );
}
