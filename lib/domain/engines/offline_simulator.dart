import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../entities/entitlements.dart';
import '../entities/game_item.dart';
import '../entities/hero.dart';
import '../entities/hero_class_definition.dart';
import '../entities/hero_stats_resolver.dart';
import '../entities/inventory.dart';
import '../entities/offline_report.dart';
import '../entities/progress_position.dart';
import '../entities/save_state.dart';
import '../inventory/inventory_service.dart';
import '../progression/progression_service.dart';
import 'combat_engine.dart';
import 'loot_generator.dart';
import 'wave_director.dart';

/// Resultado da simulação: o que mostrar e o que adotar.
///
/// São dois objetos porque têm destinos diferentes — [report] é exibido uma vez
/// e descartado, [state] passa a ser o estado do jogo. Fundi-los faria o resumo
/// virar uma segunda fonte de verdade sobre o progresso.
class OfflineSimulation {
  const OfflineSimulation({required this.report, required this.state});

  final OfflineReport report;
  final SaveState state;
}

/// Simulação do tempo ausente (M09).
///
/// Nunca tick a tick (research.md R3): ouro sai de forma fechada e waves saem
/// por blocos amortizados, usando a **mesma** `timeToClearWave` do
/// [CombatEngine]. É esse compartilhamento que impede o jogo fechado de
/// discordar do jogo aberto — a classe de bug mais cara do gênero.
class OfflineSimulator {
  const OfflineSimulator({this.loot = const LootGenerator()});

  final LootGenerator loot;

  /// Teto de ausência considerada (R-M09-02). 8 horas.
  static const int maxOfflineSeconds = 8 * 60 * 60;

  /// Penalidade de R-M09-04: o jogo passivo rende 80% do ativo.
  static const double offlinePenalty = 0.8;

  /// Guarda contra laço descontrolado. Não é o limite esperado — o
  /// escalonamento de monstros por wave já faz o tempo por wave crescer até
  /// estourar o intervalo. Existe para que um erro de balanceamento vire um
  /// resumo pobre, e não um congelamento na abertura do app.
  static const int maxSimulatedWaves = 10000;

  OfflineSimulation simulate({
    required SaveState state,
    required DateTime now,
    required CombatEngine combat,
    required WaveDirector waves,
    required List<HeroClassDefinition> classes,
  }) {
    final elapsed = _elapsedSeconds(state, now);

    // CEN-M09-E02/E03: relógio atrasado ou primeira abertura. Nada é concedido
    // e, principalmente, nada é subtraído — só o último acesso avança, senão o
    // jogador ficaria preso num futuro que nunca chega.
    if (elapsed <= 0) {
      return OfflineSimulation(
        report: OfflineReport.empty,
        state: state.copyWith(
          account: state.account.copyWith(lastSaveAt: now),
        ),
      );
    }

    final wasCapped = elapsed > maxOfflineSeconds;
    final effective = wasCapped ? maxOfflineSeconds : elapsed;

    // R-M09-03: uma multiplicação resolve o ouro de 8 h — mais uma segunda
    // para a parte do intervalo em que o bônus de anúncio estava valendo.
    final gold = _goldFor(state: state, now: now, seconds: effective);

    final blocks = _simulateWaves(
      state: state,
      seconds: effective.toDouble(),
      combat: combat,
      waves: waves,
      classes: classes,
    );

    final progression = ProgressionService();
    final levelUps = <OfflineLevelUp>[];
    final heroes = <Hero>[];

    for (final hero in state.heroes) {
      // V-H-05: só a formação recebe XP, inclusive quem estava incapacitado.
      if (!progression.isEligibleForXp(hero) || blocks.xp.isZero) {
        heroes.add(hero);
        continue;
      }
      final definition = _classFor(classes, hero.classId);
      if (definition == null) {
        heroes.add(hero);
        continue;
      }

      final result = progression.grantHeroXp(hero, blocks.xp, definition);
      heroes.add(result.hero);
      if (result.levelsGained > 0) {
        levelUps.add(
          OfflineLevelUp(
            heroId: hero.id,
            from: hero.level,
            to: result.hero.level,
          ),
        );
      }
    }

    final report = OfflineReport(
      elapsedSeconds: effective,
      wasCapped: wasCapped,
      goldGained: gold,
      goldFromAutoSell: blocks.autoSellGold,
      xpGained: blocks.xp,
      wavesAdvanced: blocks.wavesAdvanced,
      itemsObtained: List.unmodifiable(blocks.items),
      rareHighlights: List.unmodifiable(
        blocks.items.where((i) => i.rarity.isRareHighlight),
      ),
      levelUps: List.unmodifiable(levelUps),
      inventoryBecameFull: blocks.inventory.hasPending,
    );

    return OfflineSimulation(
      report: report,
      state: state.copyWith(
        account: state.account.copyWith(
          gold: state.account.gold + gold + blocks.autoSellGold,
          currentPosition: blocks.position,
          highestWave: blocks.highestWave > state.account.highestWave
              ? blocks.highestWave
              : state.account.highestWave,
          highestAct: blocks.position.act > state.account.highestAct
              ? blocks.position.act
              : state.account.highestAct,
          highestDifficulty:
              blocks.position.difficulty > state.account.highestDifficulty
              ? blocks.position.difficulty
              : state.account.highestDifficulty,
          lastSaveAt: now,
        ),
        heroes: heroes,
        inventory: blocks.inventory,
      ),
    );
  }

  /// Ouro da ausência, com o bônus de anúncio aplicado **só ao trecho em que
  /// ele estava ativo**.
  ///
  /// Um bônus de 4 h não pode multiplicar 8 h de ausência: o jogador receberia
  /// o dobro do que receberia jogando, e o anúncio viraria a forma mais
  /// eficiente de progredir — o oposto de SC-M09-02.
  GameNumber _goldFor({
    required SaveState state,
    required DateTime now,
    required int seconds,
  }) {
    final perSecond = state.account.goldPerSecond;
    if (perSecond.isZero) return GameNumber.zero;

    final start = now.subtract(Duration(seconds: seconds));
    final expiry = state.entitlements.goldBoostExpiresAt;

    var boosted = 0;
    if (expiry != null && expiry.isAfter(start)) {
      final end = expiry.isBefore(now) ? expiry : now;
      boosted = end.difference(start).inSeconds.clamp(0, seconds);
    }
    final plain = seconds - boosted;

    final base = perSecond.scaled(plain.toDouble());
    final withBoost = perSecond
        .scaled(boosted.toDouble())
        .scaled(Entitlements.goldBoostMultiplier);

    return (base + withBoost).scaled(offlinePenalty);
  }

  /// R-M09-01 com as duas bordas de R-M09-02 e CEN-M09-E02.
  ///
  /// Save sem último acesso registrado (época zero) é primeira abertura, não
  /// uma ausência de 56 anos.
  int _elapsedSeconds(SaveState state, DateTime now) {
    final lastSaveAt = state.account.lastSaveAt;
    if (lastSaveAt.millisecondsSinceEpoch <= 0) return 0;
    final delta = now.difference(lastSaveAt).inSeconds;
    return delta <= 0 ? 0 : delta;
  }

  /// Avança waves por blocos, consumindo o tempo disponível.
  _WaveBlocks _simulateWaves({
    required SaveState state,
    required double seconds,
    required CombatEngine combat,
    required WaveDirector waves,
    required List<HeroClassDefinition> classes,
  }) {
    final inventoryService = InventoryService(equipped: state.equippedItems);
    // Mesmos rótulos de fluxo do jogo aberto: o loot offline sai da mesma
    // sequência que sairia com o app à frente (research.md R5).
    final base = RngStream(
      seed: state.account.rngSeed,
      counter: state.account.rngCounter,
    );
    final lootRng = base.fork('loot');
    final waveRng = base.fork('waves');

    var position = state.account.currentPosition;
    var inventory = state.inventory;
    var highestWave = state.account.highestWave;
    var remaining = seconds;
    var xp = GameNumber.zero;
    var autoSellGold = GameNumber.zero;
    var advanced = 0;
    final items = <GameItem>[];

    final combatants = [
      for (final hero in state.heroes)
        if (hero.isInFormation)
          if (_classFor(classes, hero.classId) case final definition?)
            HeroCombatant.fresh(
              heroId: hero.id,
              definition: definition,
              stats: HeroStatsResolver.resolve(
                definition: definition,
                level: hero.level,
                equipped: state.equippedItems.where(
                  (i) => hero.equippedItemIds.contains(i.id),
                ),
              ).stats,
            ),
    ];

    // Sem formação não há o que simular — e isso não é erro, é um save antigo
    // ou uma conta recém-criada.
    if (combatants.isEmpty) {
      return _WaveBlocks(
        position: position,
        inventory: inventory,
        items: items,
        xp: xp,
        autoSellGold: autoSellGold,
        wavesAdvanced: 0,
        highestWave: highestWave,
      );
    }

    final now = state.account.lastSaveAt;

    while (advanced < maxSimulatedWaves) {
      final monsters = waves.spawnWave(position, waveRng);
      if (monsters.isEmpty) break;

      final wave = CombatState.start(
        position: position,
        heroes: combatants,
        monsters: monsters,
      );

      final timeToClear = combat.timeToClearWave(wave);
      // CEN-M09-011: quando o poder não basta, o avanço estagna. Sem morte
      // permanente, sem punição — o jogador volta e vê que precisa de
      // equipamento melhor.
      if (timeToClear == null) break;

      final cost = timeToClear.inMilliseconds / 1000.0;
      if (cost <= 0 || cost > remaining) break;
      remaining -= cost;

      for (final monster in monsters) {
        xp = xp + combat.xpFor(monster);

        final item = loot.rollDrop(
          monster: monster.template,
          position: position,
          rng: lootRng,
          guaranteed: monster.isBoss && WaveDirector.isBossWave(position.wave),
          now: now,
        );
        if (item != null) {
          items.add(item);
          final intake = inventoryService.intake(
            item,
            inventory,
            state.equippedItems,
          );
          inventory = intake.inventory;
          if (intake is IntakeAutoSold) {
            autoSellGold = autoSellGold + intake.goldGained;
          }
        }

        final essence = loot.rollEssence(
          monster: monster.template,
          position: position,
          rng: lootRng,
          now: now,
        );
        if (essence != null) {
          inventory = inventoryService.intakeEssence(essence, inventory);
        }
      }

      final advance = waves.advance(position, state.account);
      if (position.globalWave > highestWave) highestWave = position.globalWave;
      position = advance.position;
      advanced++;
    }

    return _WaveBlocks(
      position: position,
      inventory: inventory,
      items: items,
      xp: xp,
      autoSellGold: autoSellGold,
      wavesAdvanced: advanced,
      highestWave: highestWave,
    );
  }

  static HeroClassDefinition? _classFor(
    List<HeroClassDefinition> classes,
    String id,
  ) {
    for (final c in classes) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Acumulado do avanço por blocos.
class _WaveBlocks {
  const _WaveBlocks({
    required this.position,
    required this.inventory,
    required this.items,
    required this.xp,
    required this.autoSellGold,
    required this.wavesAdvanced,
    required this.highestWave,
  });

  final ProgressPosition position;
  final Inventory inventory;
  final List<GameItem> items;
  final GameNumber xp;
  final GameNumber autoSellGold;
  final int wavesAdvanced;
  final int highestWave;
}
