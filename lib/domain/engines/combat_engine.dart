import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../entities/hero_class_definition.dart';
import '../entities/monster.dart';
import '../entities/progress_position.dart';
import '../entities/rune_node.dart';
import '../entities/stats.dart';
import 'class_mechanics.dart';
import 'rune_effects.dart';

/// Visão de combate de um herói. Separada de `Hero` porque estes campos são
/// transitórios: HP corrente, cooldown de ataque e temporizador de revive nunca
/// são persistidos (contracts/persistence-save-schema.md).
class HeroCombatant {
  const HeroCombatant._({
    required this.heroId,
    required this.definition,
    required this.stats,
    required this.currentHp,
    required this.attackCooldown,
    required this.reviveRemaining,
    required this.bonusCritChance,
    required this.bonusCritDamage,
    required this.attackSpeedMultiplier,
  });

  factory HeroCombatant.fresh({
    required String heroId,
    required HeroClassDefinition definition,
    required Stats stats,
    double bonusCritChance = 0,
    double bonusCritDamage = 0,
    double attackSpeedMultiplier = 1,
  }) => HeroCombatant._(
    heroId: heroId,
    definition: definition,
    stats: stats,
    currentHp: stats.maxHp,
    // Começa pronto para atacar: o jogador vê ação imediata ao abrir o jogo,
    // o que sustenta SC-M01-01 (primeiro monstro morto em até 10 s).
    attackCooldown: 0,
    reviveRemaining: null,
    bonusCritChance: bonusCritChance,
    bonusCritDamage: bonusCritDamage,
    attackSpeedMultiplier: attackSpeedMultiplier,
  );

  final String heroId;
  final HeroClassDefinition definition;
  final Stats stats;
  final GameNumber currentHp;

  /// Sufixos percentuais dos itens equipados (R-M05-03, CEN-M05-004). Ficam
  /// fora de [stats] porque não são atributo bruto — ver `HeroStatsResolver`.
  final double bonusCritChance;
  final double bonusCritDamage;
  final double attackSpeedMultiplier;

  /// Segundos até o próximo golpe.
  final double attackCooldown;

  /// Segundos até reviver, ou `null` se ativo.
  final double? reviveRemaining;

  /// Incapacitado não ataca e não é alvo — mas não é estado terminal
  /// (CEN-M01-010).
  bool get isIncapacitated => reviveRemaining != null;
  bool get isActive => !isIncapacitated;

  double get hpFraction {
    if (stats.maxHp.isZero) return 0;
    final f = (currentHp / stats.maxHp).toDouble();
    return f.clamp(0.0, 1.0);
  }

  HeroCombatant withHp(GameNumber hp) => _copy(currentHp: hp);

  /// Reaplica os atributos sem interromper a wave (SC-M05-04).
  ///
  /// O HP corrente é preservado em **fração**, não em valor absoluto: equipar um
  /// item de +HP no meio da luta não pode curar o herói de graça, e desequipar
  /// não pode matá-lo por diferença de teto.
  HeroCombatant withStats(
    Stats next, {
    double bonusCritChance = 0,
    double bonusCritDamage = 0,
    double attackSpeedMultiplier = 1,
  }) {
    final fraction = hpFraction;
    return _copy(
      stats: next,
      currentHp: next.maxHp.scaled(fraction),
      bonusCritChance: bonusCritChance,
      bonusCritDamage: bonusCritDamage,
      attackSpeedMultiplier: attackSpeedMultiplier,
    );
  }

  HeroCombatant _copy({
    Stats? stats,
    GameNumber? currentHp,
    double? attackCooldown,
    double? reviveRemaining,
    bool clearRevive = false,
    double? bonusCritChance,
    double? bonusCritDamage,
    double? attackSpeedMultiplier,
  }) => HeroCombatant._(
    heroId: heroId,
    definition: definition,
    stats: stats ?? this.stats,
    currentHp: currentHp ?? this.currentHp,
    attackCooldown: attackCooldown ?? this.attackCooldown,
    reviveRemaining: clearRevive
        ? null
        : (reviveRemaining ?? this.reviveRemaining),
    bonusCritChance: bonusCritChance ?? this.bonusCritChance,
    bonusCritDamage: bonusCritDamage ?? this.bonusCritDamage,
    attackSpeedMultiplier: attackSpeedMultiplier ?? this.attackSpeedMultiplier,
  );
}

/// Estado transitório de uma wave em andamento. Nunca persistido (V-PP-03).
class CombatState {
  const CombatState._({
    required this.position,
    required this.heroes,
    required this.monsters,
    required this.elapsedSeconds,
    required this.firstAttackDone,
  });

  factory CombatState.start({
    required ProgressPosition position,
    required List<HeroCombatant> heroes,
    required List<Monster> monsters,
  }) => CombatState._(
    position: position,
    heroes: List.unmodifiable(heroes),
    monsters: List.unmodifiable(monsters),
    elapsedSeconds: 0,
    firstAttackDone: false,
  );

  final ProgressPosition position;
  final List<HeroCombatant> heroes;
  final List<Monster> monsters;
  final double elapsedSeconds;

  /// Usado pelo nó de runa "primeiro ataque de cada wave é crítico"
  /// (CEN-M07-007).
  final bool firstAttackDone;

  Iterable<HeroCombatant> get activeHeroes => heroes.where((h) => h.isActive);
  Iterable<Monster> get aliveMonsters => monsters.where((m) => m.isAlive);

  bool get isWaveCleared => aliveMonsters.isEmpty;
  bool get needsFormation => heroes.isEmpty;

  /// Não existe derrota permanente: a formação inteira caída apenas pausa o
  /// avanço até o revive automático (CEN-M01-010).
  bool get isDefeatState => false;

  /// Substitui os combatentes preservando a wave em andamento. É o caminho de
  /// equipar um item sem reiniciar a luta (SC-M05-04).
  CombatState withHeroes(List<HeroCombatant> next) => _copy(heroes: next);

  CombatState _copy({
    List<HeroCombatant>? heroes,
    List<Monster>? monsters,
    double? elapsedSeconds,
    bool? firstAttackDone,
  }) => CombatState._(
    position: position,
    heroes: heroes ?? this.heroes,
    monsters: monsters ?? this.monsters,
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    firstAttackDone: firstAttackDone ?? this.firstAttackDone,
  );
}

class CombatHit {
  const CombatHit({
    required this.heroId,
    required this.monsterId,
    required this.damage,
    required this.isCritical,
  });

  final String heroId;
  final String monsterId;
  final GameNumber damage;
  final bool isCritical;
}

class MonsterDefeated {
  const MonsterDefeated({
    required this.monster,
    required this.goldAwarded,
    required this.xpAwarded,
  });

  final Monster monster;
  final GameNumber goldAwarded;
  final GameNumber xpAwarded;
}

class CombatTickResult {
  const CombatTickResult({
    required this.state,
    required this.hits,
    required this.defeats,
    required this.downs,
    required this.revives,
    required this.waveCleared,
  });

  final CombatState state;
  final List<CombatHit> hits;
  final List<MonsterDefeated> defeats;
  final List<String> downs;
  final List<String> revives;
  final bool waveCleared;
}

/// Motor de combate automático (M01, M02).
///
/// Dart puro e determinístico: dado o mesmo estado, a mesma semente e o mesmo
/// passo, a saída é idêntica. É o que permite a [timeToClearWave] servir de base
/// para a simulação offline sem reimplementar as regras (research.md R3).
class CombatEngine {
  CombatEngine({required RngStream rng, this.runes = RuneModifiers.none})
    : _rng = rng.fork('combat');

  /// Chance base de crítico (R-M01-04).
  static const double baseCritChance = 0.05;

  /// Multiplicador de dano crítico (R-M01-05).
  static const double criticalMultiplier = 2.0;

  /// Tempo de revive automático (R-M01-06).
  static const double reviveSeconds = 30;

  final RngStream _rng;

  /// Bônus de runa em vigor (R-M07-06).
  ///
  /// Mutável de propósito: o respec pode acontecer no meio de uma wave
  /// (CEN-M07-E03), e recriar o motor para trocar os bônus reiniciaria o fluxo
  /// de RNG — o combate passaria a sortear críticos já sorteados. Trocar o
  /// agregado é seguro justamente porque ele é recalculado, nunca aplicado ao
  /// herói.
  RuneModifiers runes;

  /// Substitui os bônus sem interromper a wave nem tocar no RNG.
  void applyRunes(RuneModifiers next) => runes = next;

  static double effectiveCritChance({required double bonusFromItems}) =>
      baseCritChance + bonusFromItems;

  /// Dano de um golpe: `ATK + bônus − DEF`, com mínimo de 1 (R-M01-03).
  ///
  /// O mínimo não é detalhe de balanceamento: sem ele, uma wave com DEF maior
  /// que o ATK do time travaria a progressão para sempre (CEN-M01-003,
  /// CEN-M08-E01).
  GameNumber resolveDamage({
    required Stats attackerStats,
    required Stats defenderStats,
    required HeroClassDefinition attackerClass,
    required bool isCritical,
    double attackerHpFraction = 1.0,
    double critDamageBonus = 0.0,
  }) {
    final penetration = ClassMechanics.defenseFactor(attackerClass.mechanic);
    final effectiveDefense = defenderStats.defense.scaled(penetration);

    var damage = attackerStats.attack - effectiveDefense;
    if (damage < GameNumber.one) damage = GameNumber.one;

    damage = damage.scaled(
      ClassMechanics.damageMultiplier(
        attackerClass.mechanic,
        hpFraction: attackerHpFraction,
      ),
    );
    damage = runes.applyDamage(damage);
    if (isCritical) {
      damage = damage.scaled(criticalMultiplier + critDamageBonus);
    }

    return damage < GameNumber.one ? GameNumber.one : damage;
  }

  /// Alvo de um herói, pela regra de sua classe (R-M01-02).
  Monster? selectTarget(CombatState state, HeroCombatant hero) {
    final alive = state.aliveMonsters.toList();
    if (alive.isEmpty) return null;

    switch (hero.definition.targetingRule) {
      case TargetingRule.nearest:
        alive.sort((a, b) => a.slot.compareTo(b.slot));
      case TargetingRule.lowestHp:
        alive.sort((a, b) => a.currentHp.compareTo(b.currentHp));
    }
    return alive.first;
  }

  /// Alvo que os monstros escolhem. O Vanguard provoca e é priorizado
  /// (CEN-M02-002); heróis incapacitados não são alvo (CEN-M01-009).
  HeroCombatant? selectMonsterTarget(CombatState state) {
    final active = state.activeHeroes.toList();
    if (active.isEmpty) return null;

    for (final h in active) {
      if (ClassMechanics.taunts(h.definition.mechanic)) return h;
    }
    return active.first;
  }

  /// Avança o combate em [dt] segundos de passo fixo.
  ///
  /// Nunca deve receber o `dt` do render: o passo fixo é o que garante que o
  /// resultado independa da taxa de quadros do aparelho (research.md R10).
  CombatTickResult tick(CombatState state, double dt) {
    if (state.isWaveCleared) {
      return CombatTickResult(
        state: state,
        hits: const [],
        defeats: const [],
        downs: const [],
        revives: const [],
        waveCleared: true,
      );
    }

    final hits = <CombatHit>[];
    final defeats = <MonsterDefeated>[];
    final downs = <String>[];
    final revives = <String>[];

    final monsters = [for (final m in state.monsters) m.tickBleed(dt)];
    final heroes = [...state.heroes];
    var firstAttackDone = state.firstAttackDone;

    // O buff do Medtech vale para todo o time enquanto ele estiver ativo.
    final haste = heroes.any(
      (h) => h.isActive && ClassMechanics.heals(h.definition.mechanic),
    )
        ? ClassMechanics.medtechHasteMultiplier
        : 1.0;

    for (var i = 0; i < heroes.length; i++) {
      final hero = heroes[i];

      if (hero.isIncapacitated) {
        final remaining = hero.reviveRemaining! - dt;
        if (remaining <= 0) {
          heroes[i] = hero._copy(
            currentHp: hero.stats.maxHp,
            attackCooldown: 0,
            clearRevive: true,
          );
          revives.add(hero.heroId);
        } else {
          heroes[i] = hero._copy(reviveRemaining: remaining);
        }
        continue;
      }

      final cooldown = hero.attackCooldown - dt;
      if (cooldown > 0) {
        heroes[i] = hero._copy(attackCooldown: cooldown);
        continue;
      }

      final interval =
          1.0 /
          (hero.definition.attacksPerSecond *
              haste *
              runes.attackSpeedMultiplier *
              hero.attackSpeedMultiplier);
      heroes[i] = hero._copy(attackCooldown: interval);

      // Medtech cura em vez de só bater quando há aliado ferido.
      if (ClassMechanics.heals(hero.definition.mechanic)) {
        final woundedIndex = _mostWoundedIndex(heroes);
        if (woundedIndex != null) {
          final wounded = heroes[woundedIndex];
          final heal = hero.stats.attack.scaled(
            ClassMechanics.medtechHealFraction,
          );
          var healed = wounded.currentHp + heal;
          if (healed > wounded.stats.maxHp) healed = wounded.stats.maxHp;
          heroes[woundedIndex] = wounded._copy(currentHp: healed);
        }
      }

      final target = _firstAlive(monsters, selectTarget(
        CombatState._(
          position: state.position,
          heroes: heroes,
          monsters: monsters,
          elapsedSeconds: state.elapsedSeconds,
          firstAttackDone: firstAttackDone,
        ),
        hero,
      ));
      if (target == null) continue;

      final critChance = effectiveCritChance(
        bonusFromItems:
            ClassMechanics.critBonus(hero.definition.mechanic) +
            runes.bonusCritChance +
            hero.bonusCritChance,
      );
      final isCritical =
          RuneEffects.forcesCritical(
            runes: runes,
            firstAttackDone: firstAttackDone,
          ) ||
          _rng.chance(critChance);
      firstAttackDone = true;

      final targetIds = ClassMechanics.additionalTargets(
        hero.definition.mechanic,
        monsters,
        primary: target.instanceId,
      );

      for (final id in targetIds) {
        final idx = monsters.indexWhere((m) => m.instanceId == id);
        if (idx < 0 || !monsters[idx].isAlive) continue;

        final damage = resolveDamage(
          attackerStats: hero.stats,
          defenderStats: monsters[idx].stats,
          attackerClass: hero.definition,
          isCritical: isCritical,
          attackerHpFraction: hero.hpFraction,
          critDamageBonus: hero.bonusCritDamage,
        );

        var hit = monsters[idx].damaged(damage);
        if (ClassMechanics.causesBleed(hero.definition.mechanic)) {
          hit = hit.withBleed(
            dps: damage.scaled(ClassMechanics.bleedDpsFraction),
            seconds: ClassMechanics.bleedDurationSeconds,
          );
        }
        monsters[idx] = hit;

        hits.add(
          CombatHit(
            heroId: hero.heroId,
            monsterId: id,
            damage: damage,
            isCritical: isCritical,
          ),
        );
      }
    }

    // Monstros atacam o alvo escolhido pela regra de provocação.
    final defender = selectMonsterTarget(
      CombatState._(
        position: state.position,
        heroes: heroes,
        monsters: monsters,
        elapsedSeconds: state.elapsedSeconds,
        firstAttackDone: firstAttackDone,
      ),
    );
    if (defender != null) {
      final idx = heroes.indexWhere((h) => h.heroId == defender.heroId);
      var incoming = GameNumber.zero;
      for (final m in monsters.where((m) => m.isAlive)) {
        // Sem piso de 1 aqui, ao contrário de resolveDamage.
        //
        // O piso existe para impedir que a *progressão* trave quando a DEF do
        // monstro supera o ATK do time (R-M01-03, CEN-M01-003). Do lado do
        // monstro não há progressão a proteger: aplicar o mesmo piso faria um
        // herói de nível alto ser lentamente morto por monstros triviais do
        // Ato 1, por mais defesa que acumulasse — o oposto do que a
        // progressão de equipamento deveria comprar.
        final dmg = m.stats.attack - heroes[idx].stats.defense;
        if (dmg.isZero) continue;
        incoming = incoming + dmg.scaled(dt);
      }
      final survivor = heroes[idx].currentHp - incoming;
      if (survivor.isZero) {
        heroes[idx] = heroes[idx]._copy(
          currentHp: GameNumber.zero,
          reviveRemaining: reviveSeconds,
        );
        downs.add(defender.heroId);
      } else {
        heroes[idx] = heroes[idx]._copy(currentHp: survivor);
      }
    }

    // Recompensas dos monstros que morreram neste passo.
    for (var i = 0; i < monsters.length; i++) {
      final before = state.monsters[i];
      final after = monsters[i];
      if (before.isAlive && !after.isAlive) {
        defeats.add(
          MonsterDefeated(
            monster: after,
            goldAwarded: goldFor(after),
            xpAwarded: xpFor(after),
          ),
        );
      }
    }

    final next = state._copy(
      heroes: heroes,
      monsters: monsters,
      elapsedSeconds: state.elapsedSeconds + dt,
      firstAttackDone: firstAttackDone,
    );

    return CombatTickResult(
      state: next,
      hits: hits,
      defeats: defeats,
      downs: downs,
      revives: revives,
      waveCleared: next.isWaveCleared,
    );
  }

  /// Tempo estimado para limpar a wave com o poder atual.
  ///
  /// **Este é o ponto de acoplamento intencional com [OfflineSimulator]**: usa a
  /// mesma [resolveDamage] do tick. Se a simulação offline tivesse fórmula
  /// própria, as duas divergiriam com o tempo e o jogador receberia resultados
  /// diferentes por ter fechado o app (research.md R3).
  ///
  /// Retorna `null` quando o time não consegue avançar — o caso de estagnação
  /// sem morte permanente de CEN-M09-011.
  ///
  /// Conta **golpes por monstro**, não HP total dividido por DPS. A diferença
  /// aparece justamente na situação mais comum de um idle: quando o time já
  /// mata cada monstro em um golpe, o excedente de dano se perde, e o modelo de
  /// HP/DPS estimaria a wave muito mais rápida do que ela é. Um jogador
  /// farmando um ato antigo veria o offline prometer o triplo das waves que o
  /// jogo aberto entregaria.
  Duration? timeToClearWave(CombatState state) {
    final heroes = state.heroes.where((h) => h.isActive).toList();
    if (heroes.isEmpty) return null;

    final alive = state.aliveMonsters.toList();
    if (alive.isEmpty) return Duration.zero;

    var dpsTotal = GameNumber.zero;
    var attacksPerSecond = 0.0;
    for (final hero in heroes) {
      final perHit = resolveDamage(
        attackerStats: hero.stats,
        defenderStats: alive.first.stats,
        attackerClass: hero.definition,
        isCritical: false,
        attackerHpFraction: hero.hpFraction,
        critDamageBonus: hero.bonusCritDamage,
      );
      final rate = hero.definition.attacksPerSecond * hero.attackSpeedMultiplier;
      dpsTotal = dpsTotal + perHit.scaled(rate);
      attacksPerSecond += rate;
    }
    if (dpsTotal.isZero || attacksPerSecond <= 0) return null;

    // Dano médio por golpe do time, ponderado pela cadência de cada herói.
    final averageHit = dpsTotal / GameNumber.fromDouble(attacksPerSecond);
    if (averageHit.isZero) return null;

    var hits = 0.0;
    for (final monster in alive) {
      final needed = (monster.currentHp / averageHit).toDouble();
      if (!needed.isFinite) return null;
      hits += needed <= 1 ? 1 : needed.ceilToDouble();
      // Wave que exige golpes demais já é estagnação; não vale continuar
      // somando para descobrir quão impossível ela é.
      if (hits / attacksPerSecond > _stagnationSeconds) return null;
    }

    final fighting = hits / attacksPerSecond;
    final seconds = fighting + _downtimeSeconds(heroes, alive, fighting);
    if (!seconds.isFinite || seconds <= 0) return null;
    if (seconds > _stagnationSeconds) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// Tempo perdido com heróis caídos durante a wave.
  ///
  /// Ignorar isto fazia a estimativa errar por quase 6× numa wave de boss: o
  /// boss derruba o alvo em poucos segundos e os 30 s de revive (R-M01-06)
  /// dominam o tempo da luta. Sem o termo, o resumo offline prometeria waves que
  /// o jogo aberto não entregaria — a divergência que research.md R3 existe
  /// para evitar.
  ///
  /// O modelo mira o herói que os monstros atacam, que é quem cai primeiro, e
  /// conta quantas vezes ele cai ao longo de [fightingSeconds]. Uma wave que
  /// termina antes da primeira queda não paga nada — que é o caso da esmagadora
  /// maioria delas. Com vários heróis, a queda de um custa a fração dele na
  /// cadência do time, porque os outros continuam batendo.
  double _downtimeSeconds(
    List<HeroCombatant> heroes,
    List<Monster> alive,
    double fightingSeconds,
  ) {
    final defender = heroes.firstWhere(
      (h) => ClassMechanics.taunts(h.definition.mechanic),
      orElse: () => heroes.first,
    );

    var incoming = GameNumber.zero;
    for (final monster in alive) {
      // Mesma regra do tick: sem piso de 1 do lado do monstro.
      final damage = monster.stats.attack - defender.stats.defense;
      if (damage.isZero) continue;
      incoming = incoming + damage;
    }
    if (incoming.isZero) return 0;

    final secondsToFall = (defender.currentHp / incoming).toDouble();
    if (!secondsToFall.isFinite || secondsToFall <= 0) {
      // Cai instantaneamente: a wave não anda.
      return _stagnationSeconds;
    }
    if (fightingSeconds <= secondsToFall) return 0;

    final falls = (fightingSeconds / secondsToFall).ceil() - 1;
    return falls * reviveSeconds / heroes.length;
  }

  /// Acima de uma hora por wave, o jogador precisa de equipamento melhor, não
  /// de esperar (CEN-M09-011).
  static const double _stagnationSeconds = 3600;

  static Monster? _firstAlive(List<Monster> monsters, Monster? candidate) {
    if (candidate == null) return null;
    final idx = monsters.indexWhere((m) => m.instanceId == candidate.instanceId);
    if (idx < 0 || !monsters[idx].isAlive) return null;
    return monsters[idx];
  }

  static int? _mostWoundedIndex(List<HeroCombatant> heroes) {
    int? found;
    var lowest = 1.0;
    for (var i = 0; i < heroes.length; i++) {
      final h = heroes[i];
      if (!h.isActive) continue;
      final f = h.hpFraction;
      if (f < lowest) {
        lowest = f;
        found = i;
      }
    }
    return found;
  }

  /// Ouro concedido por derrotar [m], com os bônus de runa já aplicados.
  ///
  /// Público porque [OfflineSimulator] precisa da **mesma** função: duas
  /// fórmulas de recompensa divergiriam com o tempo e o jogador receberia
  /// valores diferentes por ter fechado o app (research.md R3).
  GameNumber goldFor(Monster m) => runes.applyGold(_goldFor(m));

  GameNumber xpFor(Monster m) => runes.applyXp(_xpFor(m));

  static GameNumber _goldFor(Monster m) =>
      m.stats.maxHp.scaled(m.isBoss ? 0.5 : 0.1);

  static GameNumber _xpFor(Monster m) =>
      m.stats.maxHp.scaled(m.isBoss ? 0.3 : 0.05);
}
