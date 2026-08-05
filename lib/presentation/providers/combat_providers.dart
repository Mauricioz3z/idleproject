import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/entities/hero.dart';
import '../../domain/entities/hero_class_definition.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/monster_template.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/entities/progress_position.dart';
import '../../domain/progression/formation_slots.dart';
import '../../domain/progression/progression_service.dart';

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
        if (h.isInFormation)
          HeroCombatant.fresh(
            heroId: h.id,
            definition: _classFor(h.classId),
            stats: _progression.statsForLevel(_classFor(h.classId), h.level),
          ),
    ];

    return CombatState.start(
      position: position,
      heroes: combatants,
      monsters: _spawnFor(position),
    );
  }

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
}

final combatControllerProvider =
    NotifierProvider<CombatController, CombatSession>(CombatController.new);
