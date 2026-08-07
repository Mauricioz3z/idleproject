import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_idle_quest/app.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero_stats_resolver.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/rune_providers.dart';
import 'package:pixel_idle_quest/presentation/screens/combat_screen.dart';
import 'package:pixel_idle_quest/presentation/screens/inventory_screen.dart';

/// A parte automatizável de T148 — V1 e V2 de [quickstart.md] §4.
///
/// Os cenários V1 a V7 são de validação manual em aparelho, e a maioria continua
/// sendo: widget na tela inicial, relógio do sistema adiantado, compra em
/// ambiente de teste. Dois deles, porém, não têm nada de manual além do dedo:
///
/// - **V1** afirma que o laço idle roda **sem nenhum toque**. Testar isso é abrir
///   o app, deixar os quadros passarem e não emitir gesto nenhum — o que um
///   teste faz melhor que um humano, que pode tocar na tela sem perceber.
/// - **SC-007** afirma que equipar um item custa **no máximo 3 interações** a
///   partir do combate. Isso é uma contagem, e contagem em teste não regride sem
///   avisar: se alguém inserir um diálogo de confirmação no caminho, a quarta
///   interação falha aqui, e não numa sessão de QA seis semanas depois.
///
/// Os dois montam [PixelIdleQuestApp], a raiz de verdade, e não a tela de
/// combate solta. O motivo é o gate: `OfflineState.blocksCombat` começa ligado e
/// só cai quando `boot()` roda, e `boot()` mora na raiz. Montar apenas
/// `CombatScreen` produz um jogo **congelado** que não lança exceção nenhuma —
/// foi exatamente o que aconteceu na primeira versão deste teste.
///
/// O que continua exigindo aparelho está registrado em tasks.md: V3 (relógio),
/// V4 (encerramento forçado), V5 (widget), V6 (compra) e a medição de FPS.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String name) => File('assets/content/$name').readAsStringSync();

  late JsonContentRepository content;

  setUp(() {
    content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: read('rune_tree.json'),
    );

    // `home_widget` é plugin de plataforma: sem aparelho, responde nada. A raiz
    // consulta o lançamento por widget no primeiro quadro (M11) e um
    // `MissingPluginException` ali derrubaria o teste por um motivo que não é o
    // que se está medindo.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('home_widget'),
          (call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('home_widget'), null);
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      combatDependenciesProvider.overrideWithValue(
        CombatDependencies(
          classes: content.heroClasses(),
          monsterTemplates: content.monsters(),
          seed: 20260806,
        ),
      ),
      runeTreeProvider.overrideWithValue(content.runeTree()),
    ],
  );

  /// Abre o jogo como o jogador abre: a raiz, na rota inicial.
  Future<void> openApp(WidgetTester tester, ProviderContainer c) async {
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const PixelIdleQuestApp(),
      ),
    );
    // O boot roda num post-frame callback: sem um quadro extra, o gate do
    // combate continua fechado.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Deixa o jogo rodar sozinho.
  ///
  /// Cada quadro entrega ao acumulador da arena um pouco menos que o teto de
  /// `maxStepsPerFrame`, que é como o jogo se comporta num aparelho que segura
  /// os 30 FPS de `specification.md` §8.
  Future<void> idle(WidgetTester tester, {required int frames}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  /// O equivalente a `pumpAndSettle` aqui.
  ///
  /// `pumpAndSettle` **não serve** nesta tela: o `GameWidget` agenda quadro
  /// atrás de quadro para sempre, então a árvore nunca fica quieta e a espera
  /// estoura o tempo limite. Um número fixo de quadros cobre a transição de rota
  /// e a abertura da folha de detalhe.
  Future<void> settleOverGameLoop(WidgetTester tester) =>
      idle(tester, frames: 8);

  GameNumber attackOf(ProviderContainer c, String heroId) {
    final session = c.read(combatControllerProvider);
    final deps = c.read(combatDependenciesProvider);
    final hero = session.heroes.firstWhere((h) => h.id == heroId);
    return HeroStatsResolver.resolve(
      definition: deps.classes.firstWhere((cl) => cl.id == hero.classId),
      level: hero.level,
      equipped: c.read(lootControllerProvider.notifier).equippedOf(hero),
    ).stats.attack;
  }

  GameItem weapon(String id, double attack, int itemLevel) => GameItem(
    id: id,
    type: ItemType.weapon,
    rarity: ItemRarity.ouro,
    itemLevel: itemLevel,
    baseStat: GameNumber.fromDouble(attack),
    affixes: const [],
    droppedAt: DateTime.utc(2026),
  );

  testWidgets('V1: o laço idle progride sem um único toque na tela', (
    tester,
  ) async {
    final c = container();
    addTearDown(c.dispose);
    await openApp(tester, c);

    final waveInicial = c
        .read(combatControllerProvider)
        .account
        .currentPosition
        .globalWave;

    // ~80 s de jogo. Nenhum `tap`, `drag` ou `fling` neste teste — a ausência de
    // gesto é a afirmação de V1, e é o que se está provando.
    await idle(tester, frames: 600);

    expect(tester.takeException(), isNull);

    final session = c.read(combatControllerProvider);
    final loot = c.read(lootControllerProvider);

    expect(
      session.account.gold > GameNumber.zero,
      isTrue,
      reason: 'V1: ouro não subiu sozinho — o laço idle não está rodando',
    );
    expect(
      session.account.currentPosition.globalWave,
      greaterThan(waveInicial),
      reason: 'SC-M01-02: nenhuma wave avançou em ~80 s de jogo sozinho',
    );
    expect(
      loot.inventory.items,
      isNotEmpty,
      reason: 'V1: nenhum item no inventário — drops não chegam ao jogador',
    );
    // A tela continua sendo a de combate: nada abriu uma decisão no caminho
    // (SC-008, na fatia que cabe num teste).
    expect(find.byType(CombatScreen), findsOneWidget);
  });

  testWidgets(
    'SC-007: da tela de combate até o item equipado em 3 toques',
    (tester) async {
      final c = container();
      addTearDown(c.dispose);

      final heroId = c.read(combatControllerProvider).heroes.first.id;

      // Situação de V2: o herói já usa uma arma e uma melhor espera no
      // inventário. Preparar isso não conta como interação — a contagem de
      // SC-007 começa na tela de combate.
      c.read(combatControllerProvider.notifier).equipItem(
        heroId,
        weapon('arma_fraca', 40, 11),
      );
      c.read(lootControllerProvider.notifier).replaceInventory(
        Inventory(
          items: [weapon('arma_forte', 400, 99)],
          pendingDrops: const [],
          essences: const [],
          blueprints: const [],
        ),
      );

      await openApp(tester, c);
      final ataqueAntes = attackOf(c, heroId);

      var toques = 0;
      Future<void> tocar(Finder alvo) async {
        toques++;
        await tester.tap(alvo);
        await settleOverGameLoop(tester);
      }

      // 1 — a barra de inventário da tela de combate.
      await tocar(find.textContaining('Inventário'));
      expect(find.byType(InventoryScreen), findsOneWidget);

      // 2 — o item na grade. `iLv99` identifica a arma forte entre os drops que
      // o combate pode ter somado enquanto a tela subia.
      await tocar(find.text('iLv99'));

      // 3 — equipar, na comparação que já abre pronta.
      await tocar(find.widgetWithText(ElevatedButton, 'Equipar').first);

      expect(
        toques,
        lessThanOrEqualTo(3),
        reason:
            'SC-007: equipar passou de 3 interações — o fluxo de inventário '
            'precisa encurtar, é critério de sucesso da spec',
      );
      expect(
        attackOf(c, heroId) > ataqueAntes,
        isTrue,
        reason: 'V2: equipar pela interface não aumentou o ATK efetivo',
      );
      expect(
        c.read(lootControllerProvider).inventory.items.map((i) => i.id),
        contains('arma_fraca'),
        reason: 'CEN-M05-003: a arma anterior tem de voltar ao inventário',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('V2: a comparação distingue ganho de perda antes de equipar', (
    tester,
  ) async {
    final c = container();
    addTearDown(c.dispose);

    final heroId = c.read(combatControllerProvider).heroes.first.id;
    // A arma equipada tem menos ataque e um sufixo de crítico que a candidata
    // não tem: a troca é ganho num atributo e perda em outro, que é a decisão
    // real que V2 pede para ver na tela.
    c.read(combatControllerProvider.notifier).equipItem(
      heroId,
      GameItem(
        id: 'arma_equipada',
        type: ItemType.weapon,
        rarity: ItemRarity.ouro,
        itemLevel: 11,
        baseStat: GameNumber.fromDouble(120),
        affixes: [
          ItemAffix(
            affixType: AffixType.critChance,
            value: GameNumber.fromDouble(0.12),
          ),
        ],
        droppedAt: DateTime.utc(2026),
      ),
    );
    c.read(lootControllerProvider.notifier).replaceInventory(
      Inventory(
        items: [weapon('arma_candidata', 400, 99)],
        pendingDrops: const [],
        essences: const [],
        blueprints: const [],
      ),
    );

    await openApp(tester, c);
    await tester.tap(find.textContaining('Inventário'));
    await settleOverGameLoop(tester);
    await tester.tap(find.text('iLv99'));
    await settleOverGameLoop(tester);

    // SC-M05-01: a diferença é por atributo e distinguível. A distinção é a cor
    // — verde de ganho e vermelho de perda na mesma folha —, e é ela que o
    // jogador lê antes do número.
    Finder deltaColorido(Color cor) => find.byWidgetPredicate(
      (w) => w is Text && w.style?.color == cor && w.style?.fontSize == 12,
    );

    expect(
      deltaColorido(const Color(0xFF5FBF60)),
      findsWidgets,
      reason: 'nenhuma linha de ganho: +280 de Ataque tinha de aparecer',
    );
    expect(
      deltaColorido(const Color(0xFFD24B4B)),
      findsWidgets,
      reason: 'nenhuma linha de perda: o crítico perdido tinha de aparecer',
    );
    expect(find.text('Ataque'), findsWidgets);
    expect(find.text('Crítico'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
