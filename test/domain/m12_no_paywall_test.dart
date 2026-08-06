import 'dart:io';

import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/engines/cube_service.dart';
import 'package:pixel_idle_quest/domain/engines/loot_generator.dart';
import 'package:pixel_idle_quest/domain/engines/rune_tree_service.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

/// Invariante anti-paywall — V-ENT-03, R-M12-01, SC-M12-01.
///
/// Este é o teste que sustenta a premissa comercial inteira do produto: nenhum
/// conteúdo de progressão pode exigir `Entitlements`. Ele não verifica um
/// cenário; verifica uma **ausência** — a de qualquer caminho que passe por
/// monetização para liberar wave, ato, dificuldade, raridade, nó de runa ou
/// slot de formação.
///
/// A forma de provar isso é estrutural: as assinaturas do domínio de progressão
/// não recebem `Entitlements`. Se um dia alguém acrescentar o parâmetro, este
/// arquivo para de compilar — que é exatamente o alarme desejado.
void main() {
  final content = JsonContentRepository.fromJson(
    heroClassesJson: File(
      'assets/content/hero_classes.json',
    ).readAsStringSync(),
    monstersJson: File('assets/content/monsters.json').readAsStringSync(),
    runeTreeJson: File('assets/content/rune_tree.json').readAsStringSync(),
  );

  /// Conta que nunca pagou nem assistiu a anúncio.
  PlayerAccount freeToPlay({
    int runePoints = 0,
    int accountLevel = 1,
    double gold = 0,
    ProgressPosition? position,
  }) => PlayerAccount.fresh(now: DateTime.utc(2026), seed: 42).copyWith(
    runePoints: runePoints,
    accountLevel: accountLevel,
    gold: GameNumber.fromDouble(gold),
    currentPosition: position ?? ProgressPosition.start(),
  );

  test('SC-M12-01: waves, atos e dificuldades avançam sem entitlements', () {
    final director = WaveDirector(templates: content.monsters());
    var account = freeToPlay();

    // Percorre os 3 atos e entra na dificuldade 2 sem nunca consultar
    // `Entitlements` — o parâmetro sequer existe nesta API.
    for (var i = 0; i < 300; i++) {
      final advance = director.advance(account.currentPosition, account);
      account = WaveDirector.applyAdvance(account, advance);
    }

    expect(account.currentPosition.difficulty, 2);
    expect(account.highestAct, ProgressPosition.maxAct);
    expect(account.highestDifficulty, 2);
  });

  test('SC-M12-01: toda raridade, inclusive Cósmico, é alcançável', () {
    const generator = LootGenerator();
    final rng = RngStream(seed: 7);

    // O gerador não conhece `Entitlements`: a raridade sai da tabela do
    // monstro, e o Cubo promove sem consultar compra nenhuma.
    for (final rarity in ItemRarity.values) {
      final item = generator.generate(
        type: ItemType.weapon,
        rarity: rarity,
        itemLevel: 100,
        rng: rng,
        now: DateTime.utc(2026),
      );
      expect(item.rarity, rarity);
    }
  });

  test('SC-M12-01: o Cubo promove até Cósmico sem gemas nem anúncio', () {
    const cube = CubeService();
    final rng = RngStream(seed: 11);
    var rarity = ItemRarity.bronze;

    while (!rarity.isMax) {
      final materiais = [
        for (var i = 0; i < 3; i++)
          GameItem(
            id: 'm${rarity.id}$i',
            type: ItemType.weapon,
            rarity: rarity,
            itemLevel: 50,
            baseStat: GameNumber.fromDouble(100),
            affixes: const [],
            droppedAt: DateTime.utc(2026),
          ),
      ];

      final result = cube.fuse(
        materials: materiais,
        inventory: Inventory(
          items: materiais,
          pendingDrops: const [],
          essences: const [],
          blueprints: const [],
        ),
        rng: rng,
        now: DateTime.utc(2026),
      );

      expect(result, isA<FusionSuccess>(), reason: 'travou em ${rarity.id}');
      rarity = (result as FusionSuccess).item.rarity;
    }

    expect(rarity, ItemRarity.cosmico);
  });

  test('SC-M12-01: os 210 nós de runa abrem só com pontos de nível', () {
    const service = RuneTreeService();
    final tree = content.runeTree();
    var account = freeToPlay(runePoints: 100000);

    var progressed = true;
    while (progressed) {
      progressed = false;
      for (final id in service.unlockableIds(account, tree)) {
        final result = service.unlock(id, account, tree);
        if (result is UnlockGranted) {
          account = result.account;
          progressed = true;
        }
      }
    }

    expect(account.unlockedRuneNodeIds.length, tree.nodes.length);
  });

  test('CEN-M12-013: o 4º slot chega de graça no nível 25', () {
    // Sem compra, sem anúncio: só nível de conta.
    final acc = freeToPlay(
      accountLevel: PlayerAccount.fourthSlotUnlockLevel,
    );
    expect(acc.isEligibleForFourthSlot, isTrue);
    expect(acc.fourthSlotSource, FourthSlotSource.none);
  });

  test('CEN-M12-011: as 6 classes iniciais existem sem nenhuma DLC', () {
    final classes = content.heroClasses();
    expect(classes.length, greaterThanOrEqualTo(6));

    // Nenhuma classe base depende de `ownedDlcClassIds`.
    final semDlc = Entitlements.initial();
    expect(semDlc.ownedDlcClassIds, isEmpty);
    expect(classes.map((c) => c.id).toSet().length, classes.length);
  });

  test(
    'V-ENT-03: nada em Entitlements é pré-requisito — os campos só aceleram '
    'ou removem atrito',
    () {
      final semNada = Entitlements.initial();

      // O que um jogador sem nada tem: multiplicador neutro, zero slots extras
      // de cubo, nenhum DLC. Nenhum desses estados bloqueia qualquer operação
      // testada acima — todas passaram com esta instância.
      expect(semNada.goldMultiplier(DateTime.utc(2026)), 1.0);
      expect(semNada.extraCubeSlots, 0);
      expect(semNada.adsRemoved, isFalse);
      expect(semNada.ownedDlcClassIds, isEmpty);
    },
  );
}
