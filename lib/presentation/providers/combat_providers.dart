import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/engines/rune_tree_service.dart';
import '../../domain/engines/wave_director.dart';
import '../../domain/entities/entitlements.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/hero.dart';
import '../../domain/entities/hero_class_definition.dart';
import '../../domain/entities/hero_stats_resolver.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/entities/progress_position.dart';
import '../../domain/entities/save_state.dart';
import '../../domain/entitlements/entitlement_service.dart';
import '../../domain/entitlements/gem_sink.dart';
import '../../domain/entitlements/gold_boost.dart';
import '../../domain/progression/formation_slots.dart';
import '../../domain/progression/gold_rate_tracker.dart';
import '../../domain/progression/progression_service.dart';
import 'game_dependencies.dart';
import 'loot_providers.dart';
import 'rune_providers.dart';
import 'wave_providers.dart';

// Reexportado para que quem já importava este arquivo continue enxergando as
// dependências do jogo sem mudar de import.
export 'game_dependencies.dart';

/// Estado observável de uma sessão de combate.
///
/// Reúne o que a HUD precisa: o estado transitório da wave, a conta e os heróis
/// persistentes. Separar isso do [CombatState] mantém o motor de domínio livre
/// de qualquer noção de conta ou de XP.
class CombatSession {
  const CombatSession({
    required this.combat,
    required this.account,
    required this.heroes,
    required this.lastEvents,
    this.travelRemaining = 0,
    this.entitlements = const Entitlements(
      adsRemoved: false,
      ownedDlcClassIds: {},
      goldBoostExpiresAt: null,
      extraCubeSlots: 0,
      actTransitionsSinceInterstitial: 0,
    ),
  });

  final CombatState combat;
  final PlayerAccount account;
  final List<Hero> heroes;

  /// Estado de monetização (M12). Vive na sessão porque o bônus de ouro
  /// multiplica o ouro de cada tick — deixá-lo fora obrigaria a consultar o
  /// save a cada derrota.
  final Entitlements entitlements;

  /// Eventos do último tick, consumidos pela camada visual para disparar
  /// números flutuantes e popups.
  final CombatTickResult? lastEvents;

  /// Segundos restantes da caminhada até o grupo seguinte (R-M08-13). Zero
  /// significa "em combate".
  ///
  /// Os monstros da wave nova já existem enquanto isto corre: eles entram pela
  /// direita enquanto o time anda, e o combate só começa quando chegam. É por
  /// isso que a fase congela o motor em vez de adiar o spawn — a arena precisa
  /// de alguém para fazer entrar.
  final double travelRemaining;

  bool get isTraveling => travelRemaining > 0;

  /// Andamento da caminhada, de 0 (acabou de sair) a 1 (chegou).
  double get travelProgress => travelRemaining <= 0
      ? 1
      : (1 - travelRemaining / CombatEngine.travelSeconds).clamp(0.0, 1.0);

  CombatSession copyWith({
    CombatState? combat,
    PlayerAccount? account,
    List<Hero>? heroes,
    CombatTickResult? lastEvents,
    // Necessário porque `lastEvents` é anulável: passar `null` no parâmetro
    // acima significa "não mexe", e a fase de caminhada precisa de "esquece os
    // eventos" — senão a arena repetiria os números de dano do último golpe a
    // cada quadro da caminhada.
    bool clearEvents = false,
    double? travelRemaining,
    Entitlements? entitlements,
  }) => CombatSession(
    combat: combat ?? this.combat,
    account: account ?? this.account,
    heroes: heroes ?? this.heroes,
    lastEvents: clearEvents ? null : (lastEvents ?? this.lastEvents),
    travelRemaining: travelRemaining ?? this.travelRemaining,
    entitlements: entitlements ?? this.entitlements,
  );
}

/// Conduz o combate: avança o motor em passo fixo e converte os eventos do tick
/// em progresso persistente (T056).
class CombatController extends Notifier<CombatSession> {
  late final ProgressionService _progression;
  late final CombatEngine _engine;
  late final WaveDirector _waves;
  late final RngStream _waveRng;
  late final CombatDependencies _deps;

  static const RuneTreeService _runes = RuneTreeService();
  static const EntitlementService _entitlementService = EntitlementService();

  /// Apura a taxa de ouro do jogo ativo, que é o que a simulação offline
  /// consome depois (M09).
  final GoldRateTracker _goldRate = GoldRateTracker();

  @override
  CombatSession build() {
    _deps = ref.watch(combatDependenciesProvider);
    _progression = ProgressionService();
    _engine = CombatEngine(rng: RngStream(seed: _deps.seed));
    _waves = ref.watch(waveDirectorProvider);
    // Fluxo próprio: a composição da wave não pode deslocar o sorteio de
    // crítico nem o de loot, que têm os seus (research.md R5).
    _waveRng = RngStream(seed: _deps.seed).fork('waves');

    final account = PlayerAccount.fresh(
      now: DateTime.now(),
      seed: _deps.seed,
    );
    final heroes = _initialFormation();

    return CombatSession(
      combat: _startWave(account.currentPosition, heroes),
      account: account,
      heroes: heroes,
      lastEvents: null,
    );
  }

  /// Avança um passo fixo. Chamado pelo acumulador de [IdleRpgGame], nunca com
  /// o `dt` bruto do render (research.md R10).
  void tick(double fixedDt) {
    // Caminhando: o motor não anda (R-M08-13). A taxa de ouro continua sendo
    // medida, com zero de ganho — é o que mantém o número do widget e o cálculo
    // offline no ritmo real do jogo, e não no ritmo só das lutas.
    if (state.isTraveling) {
      final remaining = state.travelRemaining - fixedDt;
      _goldRate.record(GameNumber.zero, fixedDt);
      state = state.copyWith(
        account: state.account.copyWith(
          goldPerSecond: _goldRate.ratePerSecond,
        ),
        travelRemaining: remaining <= 0 ? 0 : remaining,
        clearEvents: true,
      );
      return;
    }

    final result = _engine.tick(state.combat, fixedDt);

    var account = state.account;
    var heroes = state.heroes;

    // A taxa é medida a cada passo, com ouro ou sem ele: os segundos em que
    // nada caiu também contam, senão a taxa mediria o pico e não o ritmo.
    var goldThisTick = GameNumber.zero;

    if (result.defeats.isNotEmpty) {
      final now = DateTime.now();
      var gold = account.gold;
      var xpTotal = GameNumber.zero;
      for (final d in result.defeats) {
        // T139: o bônus de anúncio multiplica o ouro do combate pela mesma
        // função que o offline usa (GoldBoost), para os dois nunca discordarem.
        final awarded = GoldBoost.apply(
          d.goldAwarded,
          state.entitlements,
          now,
        );
        gold = gold + awarded;
        xpTotal = xpTotal + d.xpAwarded;
        goldThisTick = goldThisTick + awarded;
      }

      // T069: as mesmas derrotas que pagam ouro e XP avaliam o drop. Um único
      // ponto de origem mantém combate e loot na mesma linha do tempo.
      final loot = ref.read(lootControllerProvider.notifier).onDefeats(
        defeats: result.defeats,
        position: account.currentPosition,
        now: now,
      );
      gold = gold + loot.goldFromAutoSell;
      goldThisTick = goldThisTick + loot.goldFromAutoSell;

      account = account.copyWith(gold: gold);
      heroes = _grantXp(heroes, xpTotal);
      account = _grantAccountXp(account, xpTotal);
      _deps.onProgressChanged?.call();
    }

    _goldRate.record(goldThisTick, fixedDt);
    account = account.copyWith(goldPerSecond: _goldRate.ratePerSecond);

    if (result.waveCleared) {
      // T078: quem decide se a wave concluída leva à seguinte, ao ato seguinte
      // ou a uma dificuldade nova é o `WaveDirector`.
      final advance = _waves.advance(account.currentPosition, account);
      account = WaveDirector.applyAdvance(account, advance);
      _deps.onProgressChanged?.call();

      // Os monstros novos já nascem aqui, mas o combate espera a caminhada
      // acabar: é ela que os traz para a tela (R-M08-13).
      state = state.copyWith(
        combat: _startWave(advance.position, heroes),
        account: account,
        heroes: heroes,
        lastEvents: result,
        travelRemaining: CombatEngine.travelSeconds,
      );
      return;
    }

    state = state.copyWith(
      combat: result.state,
      account: account,
      heroes: heroes,
      lastEvents: result,
    );
  }

  /// Trilha de conta, alimentada pelo mesmo progresso de combate (M03,
  /// suposição declarada) e independente da trilha de herói (CEN-M03-007).
  ///
  /// As duas recebem o mesmo XP e ainda assim andam em ritmos diferentes,
  /// porque as curvas diferem: a de conta parte de 500 e cresce 20% por nível,
  /// contra 100 e 15% da de herói. É daqui que saem os pontos de runa
  /// (R-M03-06) — sem esta chamada a árvore de M07 seria conteúdo inalcançável.
  PlayerAccount _grantAccountXp(PlayerAccount account, GameNumber xp) {
    if (xp.isZero) return account;

    final result = _progression.grantAccountXp(account, xp);
    if (result.levelsGained == 0) return result.account;

    // V-PA-02: subiu de nível, então o 4º slot é reavaliado pelo **único**
    // caminho autorizado a mexer em `formationSlots` (T051).
    final slots = FormationSlots.evaluate(result.account);
    return slots is SlotNoChange ? result.account : slots.account;
  }

  List<Hero> _grantXp(List<Hero> heroes, GameNumber xp) => [
    for (final h in heroes)
      if (!_progression.isEligibleForXp(h))
        h
      else
        _progression
            .grantHeroXp(h, xp, _classFor(h.classId))
            .hero,
  ];

  /// Formação inicial: os três primeiros heróis disponíveis.
  ///
  /// O limite vem de `account.formationSlots`, não de uma constante — é o que
  /// faz o 4º slot funcionar sem tocar nesta função (FR-028).
  List<Hero> _initialFormation() {
    const slots = PlayerAccount.baseFormationSlots;
    return [
      for (var i = 0; i < _deps.classes.length && i < slots; i++)
        Hero.fresh(id: 'hero_$i', classId: _deps.classes[i].id)
            .copyWith(formationIndex: i),
    ];
  }

  HeroClassDefinition _classFor(String id) =>
      _deps.classes.firstWhere((c) => c.id == id);

  CombatState _startWave(ProgressPosition position, List<Hero> heroes) {
    final combatants = [
      for (final h in heroes)
        if (h.isInFormation) _combatantFor(h),
    ];

    return CombatState.start(
      position: position,
      heroes: combatants,
      monsters: _spawnFor(position),
    );
  }

  /// Combatente com os atributos efetivos do herói — base, nível e itens
  /// equipados (R-M05-03).
  HeroCombatant _combatantFor(Hero hero) {
    final effective = _effectiveStats(hero);
    return HeroCombatant.fresh(
      heroId: hero.id,
      definition: _classFor(hero.classId),
      stats: effective.stats,
      bonusCritChance: effective.bonusCritChance,
      bonusCritDamage: effective.bonusCritDamage,
      attackSpeedMultiplier: effective.attackSpeedMultiplier,
    );
  }

  HeroEffectiveStats _effectiveStats(Hero hero) => HeroStatsResolver.resolve(
    definition: _classFor(hero.classId),
    level: hero.level,
    equipped: ref.read(lootControllerProvider.notifier).equippedOf(hero),
  );

  /// Monstros da wave, escalados por wave, ato e dificuldade (T076).
  ///
  /// O `instanceId` sai do próprio `WaveDirector` e é derivado da posição, o
  /// que mantém a composição da wave reproduzível a partir do save.
  List<Monster> _spawnFor(ProgressPosition position) =>
      _waves.spawnWave(position, _waveRng);

  /// Reavalia o 4º slot após subida de nível de conta. Único caminho
  /// autorizado a alterar `formationSlots` (V-PA-02).
  void refreshFormationSlots() {
    final result = FormationSlots.evaluate(state.account);
    if (result is! SlotNoChange) {
      state = state.copyWith(account: result.account);
    }
  }

  // ----------------------------------------------------------- monetização
  //
  // Tudo aqui é opcional por construção (R-M12-01): nenhuma destas funções é
  // chamada por qualquer caminho de progressão.

  /// Concede a recompensa de um anúncio **assistido por inteiro** (R-M12-08).
  ///
  /// Chamar isto fora do callback de visualização completa seria conceder por
  /// um anúncio fechado no meio, contra CEN-M12-004.
  void grantAdReward(AdReward reward) {
    final now = DateTime.now();
    state = state.copyWith(
      entitlements: _entitlementService.applyAdReward(
        state.entitlements,
        reward,
        now,
      ),
    );

    // T138: o revive não é estado persistente — age no combate em curso,
    // cancelando o temporizador de 30 s (CEN-M12-002).
    if (reward == AdReward.instantRevive) _reviveFallenHero();

    _deps.onProgressChanged?.call();
  }

  /// Revive o primeiro herói caído, com HP cheio.
  ///
  /// Sem herói caído a oferta não deveria nem aparecer; se aparecer, não
  /// acontece nada — recusar ou desperdiçar um anúncio nunca pode custar
  /// progresso (R-M12-07).
  void _reviveFallenHero() {
    final heroes = [...state.combat.heroes];
    final index = heroes.indexWhere((h) => h.isIncapacitated);
    if (index < 0) return;

    heroes[index] = heroes[index].revivedNow();
    state = state.copyWith(combat: state.combat.withHeroes(heroes));
  }

  /// Aplica uma compra concluída (CEN-M12-012).
  PurchaseResult applyPurchase(PurchaseId id, {String? dlcClassId}) {
    final result = _entitlementService.applyPurchase(
      entitlements: state.entitlements,
      account: state.account,
      id: id,
      dlcClassId: dlcClassId,
    );

    state = state.copyWith(
      entitlements: result.entitlements,
      account: result.account,
    );
    _deps.onProgressChanged?.call();
    return result;
  }

  /// Reaplica compras não consumíveis no boot (CEN-M12-E04).
  void restorePurchases(List<PurchaseId> purchased) {
    final result = _entitlementService.restorePurchases(
      entitlements: state.entitlements,
      account: state.account,
      purchased: purchased,
    );
    state = state.copyWith(
      entitlements: result.entitlements,
      account: result.account,
    );
    _deps.onProgressChanged?.call();
  }

  /// Debita gemas para acelerar uma operação (FR-029).
  ///
  /// Devolve o resultado para quem chamou aplicar o efeito; o débito e o efeito
  /// são separados justamente porque o efeito nunca toca no sorteio (V-ENT-04).
  GemSpendResult spendGems(RushTarget target) {
    final result = const GemSink().spendToRush(state.account, target);
    if (result is GemSpendApplied) {
      state = state.copyWith(account: result.account);
      _deps.onProgressChanged?.call();
    }
    return result;
  }

  /// Registra uma transição de ato e diz se cabe um intersticial (R-M12-04).
  ///
  /// Nunca durante o combate ou entre waves comuns (CEN-M12-006): só é chamado
  /// na virada de ato.
  bool registerActTransition() {
    final next = _entitlementService.registerActTransition(state.entitlements);
    final show = _entitlementService.shouldShowInterstitial(next);

    state = state.copyWith(
      entitlements: show
          ? _entitlementService.markInterstitialShown(next)
          : next,
    );
    return show;
  }

  // ------------------------------------------------------------------ runas
  //
  // Passam por aqui porque mexem na conta — pontos, ouro e nós desbloqueados —
  // e porque o agregado precisa chegar ao motor de combate em vigor, sem
  // reiniciar a wave (CEN-M07-E03).

  /// Desbloqueia um nó e passa a valer no combate imediatamente (CEN-M07-002).
  UnlockResult unlockRuneNode(String nodeId) {
    final tree = ref.read(runeTreeProvider);
    final result = _runes.unlock(nodeId, state.account, tree);
    if (result is UnlockGranted) {
      state = state.copyWith(account: result.account);
      _syncRunes();
      _deps.onProgressChanged?.call();
    }
    return result;
  }

  /// Devolve os pontos e remove os bônus na hora (CEN-M07-009, CEN-M07-012).
  ///
  /// [discountedWithGems] aplica o desconto de CEN-M12-009. As gemas já foram
  /// debitadas por `spendGems` antes de chegar aqui; o que muda é só o preço em
  /// ouro, nunca os pontos devolvidos nem os nós disponíveis.
  RespecResult respecRunes({double goldCostMultiplier = 1.0}) {
    final tree = ref.read(runeTreeProvider);
    final result = _runes.respec(
      state.account,
      tree,
      goldCostMultiplier: goldCostMultiplier,
    );
    if (result is RespecDone) {
      state = state.copyWith(account: result.account);
      _syncRunes();
      _deps.onProgressChanged?.call();
    }
    return result;
  }

  /// Recalcula o agregado e o entrega ao motor.
  ///
  /// Só o agregado muda: os heróis em campo continuam com o HP e o cooldown que
  /// tinham, porque nenhum bônus fica gravado neles (CEN-M07-E03).
  void _syncRunes() {
    _engine.applyRunes(
      _runes.modifiersFor(
        state.account.unlockedRuneNodeIds,
        ref.read(runeTreeProvider),
      ),
    );
  }

  /// Adota um estado carregado do disco ou devolvido pela simulação offline.
  ///
  /// A wave recomeça do início: estado de combate parcial nunca é persistido
  /// (V-PP-03, CEN-M08-E03, CEN-M10-E01).
  void restore(SaveState saved) {
    ref
        .read(lootControllerProvider.notifier)
        .restore(saved.inventory, saved.equippedItems);

    state = CombatSession(
      combat: _startWave(saved.account.currentPosition, saved.heroes),
      account: saved.account,
      heroes: saved.heroes,
      lastEvents: null,
      entitlements: saved.entitlements,
    );
    // Os nós do save voltam a valer: sem isto, reabrir o jogo zeraria os
    // bônus até o primeiro desbloqueio da sessão.
    _syncRunes();
  }

  /// Fotografia do estado persistível. É o que o auto-save de 30 s grava.
  ///
  /// A taxa de ouro entra aqui, e não é recalculada na volta: é a apuração
  /// **deste** momento que a simulação offline vai consumir (M09).
  ///
  /// [now] omitido preserva o `lastSaveAt` atual. É o que a retomada de segundo
  /// plano precisa: ela mede a ausência **a partir** do último save, e carimbar
  /// o instante atual apagaria justamente o intervalo a simular.
  SaveState snapshot({DateTime? now, int monotonicMillis = 0}) {
    final loot = ref.read(lootControllerProvider);
    final equipped = ref
        .read(lootControllerProvider.notifier)
        .allEquippedItems;

    return SaveState(
      schemaVersion: SaveState.currentSchemaVersion,
      account: state.account.copyWith(
        goldPerSecond: _goldRate.ratePerSecond,
        lastSaveAt: now ?? state.account.lastSaveAt,
      ),
      entitlements: state.entitlements,
      heroes: state.heroes,
      equippedItems: equipped,
      inventory: loot.inventory,
      lastMonotonicMillis: monotonicMillis,
    );
  }

  /// Move o jogador para um ato e dificuldade já concluídos (R-M08-11,
  /// CEN-M08-011).
  ///
  /// Recusa silenciosamente conteúdo não desbloqueado — a tela só oferece o que
  /// [WaveDirector.canSelect] aprova, e a checagem aqui é a que vale.
  void selectPosition(ProgressPosition target) {
    final account = WaveDirector.select(state.account, target);
    if (account.currentPosition == state.account.currentPosition) return;

    state = state.copyWith(
      account: account,
      combat: _startWave(account.currentPosition, state.heroes),
    );
    _deps.onProgressChanged?.call();
  }

  // ------------------------------------------------------------- inventário
  //
  // As ações de inventário passam por aqui, e não direto pelo `LootController`,
  // porque duas coisas precisam acontecer junto com a mudança de itens: o ouro
  // da venda entra na conta, e os atributos do herói em combate são reaplicados
  // sem reiniciar a wave (SC-M05-04).

  void equipItem(String heroId, GameItem item) {
    final hero = _heroById(heroId);
    if (hero == null) return;

    final result = ref.read(lootControllerProvider.notifier).equip(hero, item);
    _replaceHero(result.hero);
  }

  void unequipSlot(String heroId, ItemType slot) {
    final hero = _heroById(heroId);
    if (hero == null) return;

    final result = ref
        .read(lootControllerProvider.notifier)
        .unequip(hero, slot);
    _replaceHero(result.hero);
  }

  void sellItem(GameItem item) {
    final gold = ref.read(lootControllerProvider.notifier).sell(item);
    state = state.copyWith(
      account: state.account.copyWith(gold: state.account.gold + gold),
    );
    _deps.onProgressChanged?.call();
  }

  void toggleFavorite(GameItem item) {
    ref.read(lootControllerProvider.notifier).toggleFavorite(item);
  }

  Hero? _heroById(String id) {
    for (final h in state.heroes) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Troca o herói na lista persistente e reaplica seus atributos ao combatente
  /// correspondente, preservando a fração de HP e a wave em andamento.
  void _replaceHero(Hero updated) {
    final heroes = [
      for (final h in state.heroes)
        if (h.id == updated.id) updated else h,
    ];

    final effective = _effectiveStats(updated);
    final combatants = [
      for (final c in state.combat.heroes)
        if (c.heroId == updated.id)
          c.withStats(
            effective.stats,
            bonusCritChance: effective.bonusCritChance,
            bonusCritDamage: effective.bonusCritDamage,
            attackSpeedMultiplier: effective.attackSpeedMultiplier,
          )
        else
          c,
    ];

    state = state.copyWith(
      heroes: heroes,
      combat: state.combat.withHeroes(combatants),
    );
    _deps.onProgressChanged?.call();
  }
}

final combatControllerProvider =
    NotifierProvider<CombatController, CombatSession>(CombatController.new);
