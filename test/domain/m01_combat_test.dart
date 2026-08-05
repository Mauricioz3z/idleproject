import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/entities/monster.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M01 — Combate Automático.
/// Cenários CEN-M01-001 a 013, E01 e E02.
void main() {
  CombatEngine engine({int seed = 1}) =>
      CombatEngine(rng: RngStream(seed: seed));

  HeroCombatant hero({
    String id = 'h1',
    double attack = 100,
    double defense = 10,
    double maxHp = 500,
    double attacksPerSecond = 1,
    TargetingRule targeting = TargetingRule.nearest,
    ClassMechanic mechanic = ClassMechanic.bleed,
  }) => HeroCombatant.fresh(
    heroId: id,
    definition: TestContent.heroClass(
      id: 'c_$id',
      attack: attack,
      defense: defense,
      maxHp: maxHp,
      attacksPerSecond: attacksPerSecond,
      targetingRule: targeting,
      mechanic: mechanic,
    ),
    stats: TestContent.stats(
      attack: attack,
      defense: defense,
      maxHp: maxHp,
    ),
  );

  Monster monster({
    String id = 'm1',
    double attack = 20,
    double defense = 10,
    double maxHp = 100,
    int slot = 0,
  }) => Monster.spawn(
    instanceId: id,
    template: TestContent.monster(),
    stats: TestContent.stats(attack: attack, defense: defense, maxHp: maxHp),
    slot: slot,
  );

  CombatState wave({
    List<HeroCombatant>? heroes,
    List<Monster>? monsters,
  }) => CombatState.start(
    position: ProgressPosition.start(),
    heroes: heroes ?? [hero()],
    monsters: monsters ?? [monster()],
  );

  /// Avança o combate por [seconds] em passo fixo de 30 Hz, como o game loop.
  (CombatState, List<CombatTickResult>) run(
    CombatEngine e,
    CombatState state,
    double seconds,
  ) {
    const step = 1 / 30;
    final results = <CombatTickResult>[];
    var current = state;
    for (var t = 0.0; t < seconds; t += step) {
      final r = e.tick(current, step);
      current = r.state;
      results.add(r);
    }
    return (current, results);
  }

  group('CEN-M01-001 — combate inicia sozinho', () {
    test('heróis atacam sem nenhuma entrada do jogador', () {
      final (after, results) = run(engine(), wave(), 2);

      expect(
        results.any((r) => r.hits.isNotEmpty),
        isTrue,
        reason: 'nenhum golpe ocorreu sem input',
      );
      expect(after.monsters.first.currentHp < GameNumber.fromInt(100), isTrue);
    });
  });

  group('CEN-M01-002/003/004/005 — fórmula de dano', () {
    test('CEN-M01-002: ATK 100 contra DEF 30 causa exatamente 70', () {
      final dano = engine().resolveDamage(
        attackerStats: TestContent.stats(attack: 100),
        defenderStats: TestContent.stats(defense: 30),
        attackerClass: TestContent.heroClass(),
        isCritical: false,
      );
      expect(dano, GameNumber.fromInt(70));
    });

    test('CEN-M01-003: ATK 20 contra DEF 50 causa 1, não zero nem negativo', () {
      final dano = engine().resolveDamage(
        attackerStats: TestContent.stats(attack: 20),
        defenderStats: TestContent.stats(defense: 50),
        attackerClass: TestContent.heroClass(),
        isCritical: false,
      );
      expect(dano, GameNumber.fromInt(1));
    });

    test('CEN-M01-004: crítico dobra o dano — 70 vira 140', () {
      final dano = engine().resolveDamage(
        attackerStats: TestContent.stats(attack: 100),
        defenderStats: TestContent.stats(defense: 30),
        attackerClass: TestContent.heroClass(),
        isCritical: true,
      );
      expect(dano, GameNumber.fromInt(140));
    });

    test('CEN-M01-005: base 5% mais 15% de itens resulta em 20%', () {
      expect(
        CombatEngine.effectiveCritChance(bonusFromItems: 0.15),
        closeTo(0.20, 1e-9),
      );
    });

    test('sem bônus, a chance de crítico é a base de 5%', () {
      expect(
        CombatEngine.effectiveCritChance(bonusFromItems: 0),
        closeTo(CombatEngine.baseCritChance, 1e-9),
      );
    });
  });

  group('CEN-M01-006/007/008 — seleção de alvo', () {
    test('CEN-M01-006: regra nearest ataca o monstro mais próximo', () {
      final perto = monster(id: 'perto', slot: 0);
      final longe = monster(id: 'longe', slot: 3);
      final state = wave(
        heroes: [hero(targeting: TargetingRule.nearest)],
        monsters: [longe, perto],
      );

      expect(engine().selectTarget(state, state.heroes.first)?.instanceId,
          'perto');
    });

    test('CEN-M01-007: regra lowestHp ataca o de menor HP atual', () {
      final cheio = monster(id: 'cheio', maxHp: 100, slot: 0);
      final ferido = Monster.spawn(
        instanceId: 'ferido',
        template: TestContent.monster(),
        stats: TestContent.stats(maxHp: 100),
        slot: 3,
      ).damaged(GameNumber.fromInt(80));

      final state = wave(
        heroes: [hero(targeting: TargetingRule.lowestHp)],
        monsters: [cheio, ferido],
      );

      expect(engine().selectTarget(state, state.heroes.first)?.instanceId,
          'ferido');
    });

    test('CEN-M01-008: alvo morto faz o herói escolher outro no golpe seguinte',
        () {
      final state = wave(
        heroes: [hero(attack: 1000, attacksPerSecond: 4)],
        monsters: [
          monster(id: 'a', maxHp: 50, slot: 0),
          monster(id: 'b', maxHp: 50, slot: 1),
        ],
      );
      final (after, _) = run(engine(), state, 2);
      expect(after.monsters.where((m) => m.isAlive), isEmpty);
    });
  });

  group('CEN-M01-009/010 — incapacitação e revive', () {
    test('CEN-M01-009: herói revive com HP cheio após 30 s', () {
      // Monstro que mata em ~2 s: o herói cai, revive e sobrevive ao tick.
      final frouxo = hero(maxHp: 100, defense: 0);
      final state = wave(
        heroes: [frouxo],
        monsters: [monster(attack: 50, maxHp: 1e9)],
      );

      final (caido, _) = run(engine(), state, 3);
      expect(caido.heroes.single.isIncapacitated, isTrue,
          reason: 'deveria ter caído');

      final (_, results) = run(engine(), caido, 31);
      final indice = results.indexWhere((r) => r.revives.contains('h1'));
      expect(indice, greaterThanOrEqualTo(0),
          reason: 'o revive automático não ocorreu');

      final noMomento = results[indice].state.heroes.single;
      expect(noMomento.isIncapacitated, isFalse);
      // HP cheio menos, no máximo, um passo de dano recebido no mesmo tick.
      expect(noMomento.currentHp > noMomento.stats.maxHp.scaled(0.9), isTrue);
    });

    test('herói com defesa suficiente não sofre dano', () {
      // O piso de 1 de dano vale só para herói -> monstro (R-M01-03). Aplicá-lo
      // também no sentido inverso faria um herói bem equipado morrer aos poucos
      // para monstros triviais.
      final blindado = hero(maxHp: 100, defense: 500);
      final state = wave(
        heroes: [blindado],
        monsters: [monster(attack: 20, maxHp: 1e9)],
      );
      final (depois, _) = run(engine(), state, 10);

      expect(depois.heroes.single.currentHp, depois.heroes.single.stats.maxHp);
      expect(depois.heroes.single.isIncapacitated, isFalse);
    });

    test('o revive leva exatamente 30 s, não menos', () {
      final frouxo = hero(maxHp: 10, defense: 0);
      final state = wave(
        heroes: [frouxo],
        monsters: [monster(attack: 1000, maxHp: 1e9)],
      );
      final (caido, _) = run(engine(), state, 3);
      final (quase, _) = run(engine(), caido, 25);
      expect(quase.heroes.single.isIncapacitated, isTrue);
    });

    test('CEN-M01-010: formação inteira caída não avança a wave', () {
      final state = wave(
        heroes: [hero(id: 'a', maxHp: 10, defense: 0)],
        monsters: [monster(attack: 1000, maxHp: 1e9)],
      );
      final (caido, results) = run(engine(), state, 5);

      expect(caido.heroes.every((h) => h.isIncapacitated), isTrue);
      expect(results.any((r) => r.waveCleared), isFalse);
      expect(caido.monsters.single.isAlive, isTrue,
          reason: 'monstros permanecem vivos');
      expect(caido.isDefeatState, isFalse,
          reason: 'não existe derrota permanente');
    });

    test('herói incapacitado não é escolhido como alvo pelos monstros', () {
      final state = wave(
        heroes: [hero(id: 'a', maxHp: 10, defense: 0)],
        monsters: [monster(attack: 1000, maxHp: 1e9)],
      );
      final (caido, _) = run(engine(), state, 5);
      expect(engine().selectMonsterTarget(caido), isNull);
    });
  });

  group('CEN-M01-011 — recompensas por monstro derrotado', () {
    test('derrotar um monstro emite o evento com ouro e XP', () {
      final state = wave(
        heroes: [hero(attack: 1000)],
        monsters: [monster(maxHp: 50)],
      );
      final (_, results) = run(engine(), state, 3);

      final defeats = results.expand((r) => r.defeats).toList();
      expect(defeats, hasLength(1));
      expect(defeats.single.goldAwarded > GameNumber.zero, isTrue);
      expect(defeats.single.xpAwarded > GameNumber.zero, isTrue);
    });

    test('limpar todos os monstros marca a wave como concluída', () {
      final state = wave(
        heroes: [hero(attack: 1000)],
        monsters: [monster(maxHp: 50)],
      );
      final (_, results) = run(engine(), state, 3);
      expect(results.any((r) => r.waveCleared), isTrue);
    });
  });

  group('CEN-M01-013 — combate não roda com o app fechado', () {
    test('sem chamadas a tick, o estado não muda', () {
      final state = wave();
      // Nada acontece sem alguém bombear o loop: é o que garante que o
      // progresso com o app fechado seja resolvido por M09, não aqui.
      expect(state.monsters.single.currentHp, state.monsters.single.stats.maxHp);
      expect(state.elapsedSeconds, 0);
    });
  });

  group('bordas', () {
    test('CEN-M01-E01: último monstro e herói caem juntos — wave conclui', () {
      final state = wave(
        heroes: [hero(attack: 1000, maxHp: 10, defense: 0)],
        monsters: [monster(maxHp: 50, attack: 1000)],
      );
      final (after, results) = run(engine(), state, 3);

      expect(results.any((r) => r.waveCleared), isTrue,
          reason: 'a wave conclui mesmo com o herói caindo');
      expect(after.isDefeatState, isFalse);
    });

    test('CEN-M01-E02: formação vazia não ataca e não quebra', () {
      final state = wave(heroes: const []);
      final (after, results) = run(engine(), state, 2);

      expect(results.every((r) => r.hits.isEmpty), isTrue);
      expect(after.monsters.single.isAlive, isTrue);
      expect(after.needsFormation, isTrue);
    });

    test('wave sem monstros é imediatamente concluída', () {
      final state = wave(monsters: const []);
      final r = engine().tick(state, 1 / 30);
      expect(r.waveCleared, isTrue);
    });
  });
}
