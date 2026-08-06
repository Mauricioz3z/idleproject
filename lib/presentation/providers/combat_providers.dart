import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/hero.dart';
import '../../domain/entities/hero_class_definition.dart';
import '../../domain/entities/hero_stats_resolver.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/monster_template.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/entities/progress_position.dart';
import '../../domain/progression/formation_slots.dart';
import '../../domain/progression/progression_service.dart';
import 'loot_providers.dart';

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
  });

  final CombatState combat;
  final PlayerAccount account;
  final List<Hero> heroes;

  /// Eventos do último tick, consumidos pela camada visual para disparar
  /// números flutuantes e popups.
  final CombatTickResult? lastEvents;

  CombatSession copyWith({
    CombatState? combat,
    PlayerAccount? account,
    List<Hero>? heroes,
    CombatTickResult? lastEvents,
  }) => CombatSession(
    combat: combat ?? this.combat,
    account: account ?? this.account,
    heroes: heroes ?? this.heroes,
    lastEvents: lastEvents ?? this.lastEvents,
  );
}

/// Dependências injetáveis do controlador, para permitir teste sem plataforma.
class CombatDependencies {
  const CombatDependencies({
    required this.classes,
    required this.monsterTemplates,
    required this.seed,
    this.onProgressChanged,
  });

  final List<HeroClassDefinition> classes;
  final List<MonsterTemplate> monsterTemplates;
  final int seed;

  /// Notificado quando há progresso digno de gravação. É o gancho do auto-save
  /// de 30 s (T031) — o controlador não conhece Hive.
  final void Function()? onProgressChanged;
}

final combatDependenciesProvider = Provider<CombatDependencies>((ref) {
  throw UnimplementedError(
    'Sobrescreva combatDependenciesProvider no ProviderScope com o conteúdo '
    'carregado do ContentRepository.',
  );
});

/// Conduz o combate: avança o motor em passo fixo e converte os eventos do tick
/// em progresso persistente (T056).
class CombatController extends Notifier<CombatSession> {
  late final ProgressionService _progression;
  late final CombatEngine _engine;
  late final CombatDependencies _deps;
  int _monsterCounter = 0;

  @override
  CombatSession build() {
    _deps = ref.watch(combatDependenciesProvider);
    _progression = ProgressionService();
    _engine = CombatEngine(rng: RngStream(seed: _deps.seed));

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
    final result = _engine.tick(state.combat, fixedDt);

    var account = state.account;
    var heroes = state.heroes;

    if (result.defeats.isNotEmpty) {
      var gold = account.gold;
      var xpTotal = GameNumber.zero;
      for (final d in result.defeats) {
        gold = gold + d.goldAwarded;
        xpTotal = xpTotal + d.xpAwarded;
      }

      // T069: as mesmas derrotas que pagam ouro e XP avaliam o drop. Um único
      // ponto de origem mantém combate e loot na mesma linha do tempo.
      final loot = ref.read(lootControllerProvider.notifier).onDefeats(
        defeats: result.defeats,
        position: account.currentPosition,
        now: DateTime.now(),
      );
      gold = gold + loot.goldFromAutoSell;

      account = account.copyWith(gold: gold);
      heroes = _grantXp(heroes, xpTotal);
      _deps.onProgressChanged?.call();
    }

    if (result.waveCleared) {
      final next = _advancePosition(account.currentPosition);
      account = _progression
          .recordProgress(account, account.currentPosition)
          .copyWith(currentPosition: next);
      _deps.onProgressChanged?.call();

      state = state.copyWith(
        combat: _startWave(next, heroes),
        account: account,
        heroes: heroes,
        lastEvents: result,
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

  /// Geração provisória de wave. `WaveDirector` (T076, US3) assume esta
  /// responsabilidade com escalonamento completo por wave e dificuldade.
  List<Monster> _spawnFor(ProgressPosition position) {
    final doAto = _deps.monsterTemplates
        .where((m) => m.act == position.act)
        .toList();
    if (doAto.isEmpty) return const [];

    final boss = doAto.where((m) => m.isBoss).toList();
    final comuns = doAto.where((m) => !m.isBoss).toList();

    if (position.isBossWave && boss.isNotEmpty) {
      return [
        Monster.spawn(
          instanceId: 'm${_monsterCounter++}',
          template: boss.first,
          stats: boss.first.baseStats,
          slot: 0,
        ),
      ];
    }

    final quantidade = 2 + (position.wave % 3);
    return [
      for (var i = 0; i < quantidade; i++)
        Monster.spawn(
          instanceId: 'm${_monsterCounter++}',
          template: comuns[i % comuns.length],
          stats: comuns[i % comuns.length].baseStats,
          slot: i,
        ),
    ];
  }

  ProgressPosition _advancePosition(ProgressPosition current) {
    if (current.wave < ProgressPosition.maxWave) {
      return current.copyWith(wave: current.wave + 1);
    }
    if (current.act < ProgressPosition.maxAct) {
      return current.copyWith(act: current.act + 1, wave: 1);
    }
    // Dificuldade seguinte é responsabilidade de WaveDirector (T078, US3).
    return current.copyWith(difficulty: current.difficulty + 1, act: 1, wave: 1);
  }

  /// Reavalia o 4º slot após subida de nível de conta. Único caminho
  /// autorizado a alterar `formationSlots` (V-PA-02).
  void refreshFormationSlots() {
    final result = FormationSlots.evaluate(state.account);
    if (result is! SlotNoChange) {
      state = state.copyWith(account: result.account);
    }
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
