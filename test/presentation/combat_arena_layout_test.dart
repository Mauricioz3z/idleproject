import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
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
  ///
  /// [prefix] distingue as instâncias de uma wave das da seguinte — é o que a
  /// arena usa para saber que um monstro é novo e tem de entrar andando.
  /// [dead] marca os slots já derrotados.
  CombatState fullArena({String prefix = 'm', Set<int> dead = const {}}) =>
      CombatState.start(
    position: const ProgressPosition(difficulty: 1, act: 1, wave: 3),
    heroes: [
      // As definições de verdade, com o papel de cada classe: é o papel que
      // decide quem fica na frente da linha de batalha.
      for (final classId in const [
        'vanguard',
        'elementalist',
        'sharpshooter',
        'berserker',
      ])
        HeroCombatant.fresh(
          heroId: 'hero_$classId',
          definition: TestContent.sixClasses().firstWhere(
            (c) => c.id == classId,
          ),
          stats: TestContent.stats(attack: 100, maxHp: 500),
        ),
    ],
    monsters: [
      for (var slot = 0; slot < 8; slot++)
        if (dead.contains(slot))
          Monster.spawn(
            instanceId: '$prefix$slot',
            template: TestContent.monster(id: 'forest_bramble'),
            stats: TestContent.stats(maxHp: 100),
            slot: slot,
          ).damaged(GameNumber.fromInt(999))
        else
          Monster.spawn(
            instanceId: '$prefix$slot',
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

  /// Onde cada um para, medido no próprio jogo depois de a caminhada terminar.
  ///
  /// O teste compara a arena com ela mesma parada, e não com uma cópia das
  /// constantes de layout. Precisa de tempo porque ninguém é teleportado: o
  /// combatente **anda** até o seu lugar, que é o ponto desta mudança.
  Future<Map<String, double>> restingX(
    WidgetTester tester,
    CombatArena arena,
    CombatState state,
  ) async {
    for (var i = 0; i < 20; i++) {
      arena.sync(state, null);
      await tester.pump(const Duration(milliseconds: 100));
    }
    return {for (final v in combatants(arena)) v.entityId: v.position.x};
  }

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

  testWidgets('os dois lados lutam a distância de golpe, não cada um no seu '
      'canto', (tester) async {
    // Este é o defeito que o print de tela mostrava: o time plantado na
    // esquerda, o grupo inimigo na direita e 130 px de chão vazio entre eles.
    // Ninguém encostava em ninguém, e a luta lia como dois grupos parados em
    // telas diferentes.
    final state = fullArena();
    final arena = await mount(tester, state: state);
    await restingX(tester, arena, state);

    final herois = combatants(arena).where((v) => v.entityId.startsWith('hero_'));
    final monstros = combatants(arena).where((v) => v.entityId.startsWith('m'));

    final frenteDoTime = herois
        .map((v) => v.position.x + v.size.x / 2)
        .reduce((a, b) => a > b ? a : b);
    final monstroMaisPerto = monstros
        .map((v) => v.position.x - v.size.x / 2)
        .reduce((a, b) => a < b ? a : b);

    final vao = monstroMaisPerto - frenteDoTime;
    expect(
      vao,
      greaterThanOrEqualTo(0),
      reason: 'o time e os monstros estão sobrepostos',
    );
    expect(
      vao,
      lessThanOrEqualTo(16),
      reason:
          'sobraram ${vao.toStringAsFixed(0)} px de chão vazio entre o herói '
          'da frente e o monstro mais próximo — os dois lados batem no ar',
    );
  });

  testWidgets('quem luta corpo a corpo fica à frente do time', (tester) async {
    final state = fullArena();
    final arena = await mount(tester, state: state);
    final parados = await restingX(tester, arena, state);

    // `vanguard` é tanque e `berserker` é bruto; `elementalist` e
    // `sharpshooter` atacam de longe. Os dois primeiros vão à frente.
    for (final corpoACorpo in const ['hero_vanguard', 'hero_berserker']) {
      for (final aDistancia in const ['hero_elementalist', 'hero_sharpshooter']) {
        expect(
          parados[corpoACorpo],
          greaterThan(parados[aDistancia]!),
          reason: '$corpoACorpo devia estar à frente de $aDistancia',
        );
      }
    }
  });

  testWidgets('R-M08-13: o grupo seguinte entra andando pela direita', (
    tester,
  ) async {
    final state = fullArena();
    final arena = await mount(tester, state: state);
    final alvo = await restingX(tester, arena, state);

    // Wave concluída: instâncias novas chegam enquanto o time ainda caminha.
    // O lugar de cada uma é o da instância de mesmo slot da wave anterior.
    double lugarDe(String entityId) =>
        alvo[entityId.startsWith('n') ? 'm${entityId.substring(1)}' : entityId]!;

    final proxima = fullArena(prefix: 'n');
    arena.sync(proxima, null, travelProgress: 0);
    await tester.pump();

    final monstros = combatants(arena)
        .where((v) => v.entityId.startsWith('n'))
        .toList();
    expect(monstros.length, 8);
    for (final view in monstros) {
      expect(
        view.position.x,
        greaterThan(lugarDe(view.entityId)),
        reason: '${view.entityId} já nasceu no lugar, sem entrar',
      );
      expect(view.isWalking, isTrue);
    }

    // O time não muda de lugar na caminhada — quem passa é o cenário —, mas as
    // pernas andam.
    for (final view in combatants(arena).where(
      (v) => v.entityId.startsWith('hero_'),
    )) {
      expect(view.position.x, alvo[view.entityId]);
      expect(view.isWalking, isTrue);
    }

    // Meio do caminho: mais perto do que estava, e ainda não chegou.
    final naSaida = {for (final v in monstros) v.entityId: v.position.x};
    arena.sync(proxima, null, travelProgress: 0.4);
    await tester.pump(const Duration(milliseconds: 400));
    for (final view in monstros) {
      expect(view.position.x, lessThan(naSaida[view.entityId]!));
      expect(
        view.position.x,
        greaterThan(lugarDe(view.entityId)),
        reason: '${view.entityId} chegou antes da hora',
      );
    }

    // O grupo chega ao seu lugar dentro da caminhada: quem ainda estivesse
    // entrando quando o motor volta a correr apanharia fora da tela.
    arena.sync(proxima, null);
    await tester.pump(
      Duration(milliseconds: (CombatEngine.travelSeconds * 1000).round() - 400),
    );
    for (final view in combatants(arena)) {
      expect(view.isWalking, isFalse, reason: '${view.entityId} não chegou');
      expect(
        view.position.x,
        lugarDe(view.entityId),
        reason: '${view.entityId} parou fora do lugar',
      );
    }
  });

  testWidgets('quando o da frente cai, o de trás dá um passo à frente', (
    tester,
  ) async {
    final state = fullArena();
    final arena = await mount(tester, state: state);
    final antes = await restingX(tester, arena, state);

    // Slot 0 derrotado: a fileira da frente aperta.
    final depois = await restingX(tester, arena, fullArena(dead: {0}));

    expect(
      depois['m1'],
      lessThan(antes['m1']!),
      reason: 'm1 ficou no lugar com o m0 caído na frente dele',
    );
    expect(
      depois['m1'],
      antes['m0'],
      reason: 'm1 devia ter assumido o lugar do m0',
    );
    expect(
      depois['m0'],
      antes['m0'],
      reason: 'o corpo do m0 andou — cadáver não muda de lugar',
    );
    // A fileira de trás não se mexe: quem caiu era da da frente.
    expect(depois['m4'], antes['m4']);
  });

  testWidgets('o cenário rola enquanto o time anda, e para quando chega', (
    tester,
  ) async {
    final state = fullArena();
    final arena = await mount(tester, state: state);
    final background = arena.world.children
        .whereType<BackgroundComponent>()
        .single;

    arena.sync(state, null, travelProgress: 0.2);
    final antes = background.scrollX;
    await tester.pump(const Duration(milliseconds: 300));
    final andando = background.scrollX;
    expect(
      andando,
      greaterThan(antes),
      reason: 'o cenário ficou parado durante a caminhada',
    );

    arena.sync(state, null, travelProgress: 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      background.scrollX,
      andando,
      reason: 'o cenário continuou rolando depois de o time chegar',
    );
  });

  testWidgets('na caminhada o time toca a passada desenhada, não o idle', (
    tester,
  ) async {
    // A queixa que originou esta mudança foi "o personagem não anda". Ele
    // andava, no sentido de que o cenário passava — mas as 6 folhas de herói
    // tinham 3 linhas, sem caminhada, e o carregador cai no idle quando ela
    // falta. O time cruzava a floresta em pose de sentido.
    final state = fullArena();
    final arena = await mount(tester, state: state);
    await settleSprites(tester, arena, state);

    final herois = combatants(arena).where((v) => v.entityId.startsWith('hero_'));

    arena.sync(state, null, travelProgress: 0.5);
    await tester.pump(const Duration(milliseconds: 30));
    for (final view in herois) {
      expect(
        view.isPlayingWalkAnimation,
        isTrue,
        reason: '${view.entityId} atravessa a caminhada parado',
      );
    }

    arena.sync(state, null);
    await tester.pump(const Duration(milliseconds: 30));
    for (final view in herois) {
      expect(
        view.isPlayingWalkAnimation,
        isFalse,
        reason: '${view.entityId} continua andando depois de chegar',
      );
    }
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
