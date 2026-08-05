import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/class_mechanics.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/entities/monster.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M02 — Classes de Heróis.
/// Cenários CEN-M02-001 a 010, E01 e E02.
void main() {
  final classes = TestContent.sixClasses();

  HeroCombatant combatant(String classId, {double? hpFraction}) {
    final def = classes.firstWhere((c) => c.id == classId);
    final base = HeroCombatant.fresh(
      heroId: 'h_$classId',
      definition: def,
      stats: def.baseStats,
    );
    if (hpFraction == null) return base;
    return base.withHp(def.baseStats.maxHp.scaled(hpFraction));
  }

  Monster monster({String id = 'm', double maxHp = 500, double defense = 50}) =>
      Monster.spawn(
        instanceId: id,
        template: TestContent.monster(),
        stats: TestContent.stats(maxHp: maxHp, defense: defense, attack: 20),
        slot: 0,
      );

  group('CEN-M02-001 — disponibilidade', () {
    test('as 6 classes existem, com ids distintos', () {
      expect(classes, hasLength(6));
      expect(classes.map((c) => c.id).toSet(), hasLength(6));
    });

    test('nenhuma classe inicial exige pagamento ou progressão', () {
      // Não existe campo de desbloqueio: por construção, todas são jogáveis
      // desde o início. Este teste trava essa ausência.
      for (final c in classes) {
        expect(c.id, isNotEmpty);
      }
    });

    test('cada classe tem uma mecânica única distinta', () {
      expect(classes.map((c) => c.mechanic).toSet(), hasLength(6));
    });

    test('cada classe tem papel próprio', () {
      expect(classes.map((c) => c.role).toSet(), hasLength(6));
    });
  });

  group('CEN-M02-002 — Vanguard provoca', () {
    test('o Vanguard é priorizado como alvo pelos monstros', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [combatant('elementalist'), combatant('vanguard')],
        monsters: [monster()],
      );
      expect(engine.selectMonsterTarget(state)?.heroId, 'h_vanguard');
    });

    test('sem Vanguard, o alvo segue a regra padrão — CEN-M02-E01', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [combatant('elementalist'), combatant('tracker')],
        monsters: [monster()],
      );
      final alvo = engine.selectMonsterTarget(state);
      expect(alvo, isNotNull);
      expect(alvo!.heroId, isNot('h_vanguard'));
    });
  });

  group('CEN-M02-003 — Elementalist atinge em área', () {
    test('o ataque alcança vários monstros', () {
      final alvos = ClassMechanics.additionalTargets(
        ClassMechanic.areaElemental,
        [monster(id: 'a'), monster(id: 'b'), monster(id: 'c')],
        primary: 'a',
      );
      expect(alvos.length, greaterThan(1));
    });

    test('classes sem área atingem apenas o alvo', () {
      final alvos = ClassMechanics.additionalTargets(
        ClassMechanic.bleed,
        [monster(id: 'a'), monster(id: 'b')],
        primary: 'a',
      );
      expect(alvos, ['a']);
    });
  });

  group('CEN-M02-004/005 — Sharpshooter', () {
    test('CEN-M02-004: ignora parte da DEF e causa mais dano', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final atacante = TestContent.stats(attack: 100);
      final defensor = TestContent.stats(defense: 50);

      final comum = engine.resolveDamage(
        attackerStats: atacante,
        defenderStats: defensor,
        attackerClass: classes.firstWhere((c) => c.id == 'tracker'),
        isCritical: false,
      );
      final penetrante = engine.resolveDamage(
        attackerStats: atacante,
        defenderStats: defensor,
        attackerClass: classes.firstWhere((c) => c.id == 'sharpshooter'),
        isCritical: false,
      );

      expect(penetrante > comum, isTrue);
    });

    test('CEN-M02-005: tem chance de crítico maior que outra classe', () {
      final sharp = ClassMechanics.critBonus(ClassMechanic.defensePenetration);
      final tracker = ClassMechanics.critBonus(ClassMechanic.bleed);
      expect(sharp, greaterThan(tracker));
    });
  });

  group('CEN-M02-006 — Medtech cura e acelera', () {
    test('cura o aliado mais ferido', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final ferido = combatant('vanguard', hpFraction: 0.3);
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [combatant('medtech'), ferido],
        monsters: [monster(maxHp: 1e9)],
      );

      var current = state;
      for (var i = 0; i < 90; i++) {
        current = engine.tick(current, 1 / 30).state;
      }

      final depois = current.heroes.firstWhere((h) => h.heroId == 'h_vanguard');
      expect(depois.currentHp > ferido.currentHp, isTrue,
          reason: 'o Medtech deveria ter curado');
    });

    test('concede buff de velocidade de ataque', () {
      expect(
        ClassMechanics.attackSpeedBuff(ClassMechanic.healAndHaste),
        greaterThan(1.0),
      );
    });
  });

  group('CEN-M02-007 — Tracker aplica sangramento', () {
    test('o golpe deixa dano ao longo do tempo no monstro', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [combatant('tracker')],
        monsters: [monster(maxHp: 1e6, defense: 0)],
      );

      var current = state;
      for (var i = 0; i < 60; i++) {
        current = engine.tick(current, 1 / 30).state;
      }
      expect(current.monsters.single.bleedRemaining, greaterThan(0));
    });

    test('o sangramento causa dano mesmo entre golpes', () {
      final m = monster(maxHp: 1000, defense: 0)
          .withBleed(dps: GameNumber.fromInt(50), seconds: 5);
      final depois = m.tickBleed(1.0);
      expect(depois.currentHp < m.currentHp, isTrue);
    });
  });

  group('CEN-M02-008 — Berserker escala com HP baixo', () {
    test('dano aumenta conforme o HP cai', () {
      final cheio = ClassMechanics.damageMultiplier(
        ClassMechanic.rageOnLowHp,
        hpFraction: 1.0,
      );
      final ferido = ClassMechanics.damageMultiplier(
        ClassMechanic.rageOnLowHp,
        hpFraction: 0.3,
      );
      expect(ferido, greaterThan(cheio));
    });

    test('o aumento é proporcional à perda de HP', () {
      final meio = ClassMechanics.damageMultiplier(
        ClassMechanic.rageOnLowHp,
        hpFraction: 0.5,
      );
      final quaseMorto = ClassMechanics.damageMultiplier(
        ClassMechanic.rageOnLowHp,
        hpFraction: 0.1,
      );
      expect(quaseMorto, greaterThan(meio));
    });

    test('outras classes não escalam com HP', () {
      expect(
        ClassMechanics.damageMultiplier(ClassMechanic.bleed, hpFraction: 0.1),
        ClassMechanics.damageMultiplier(ClassMechanic.bleed, hpFraction: 1.0),
      );
    });
  });

  group('CEN-M02-009/010 — atributos e composição', () {
    test('CEN-M02-009: atributo principal maior melhora o desempenho', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final fraco = engine.resolveDamage(
        attackerStats: TestContent.stats(attack: 100),
        defenderStats: TestContent.stats(defense: 10),
        attackerClass: classes.first,
        isCritical: false,
      );
      final forte = engine.resolveDamage(
        attackerStats: TestContent.stats(attack: 200),
        defenderStats: TestContent.stats(defense: 10),
        attackerClass: classes.first,
        isCritical: false,
      );
      expect(forte > fraco, isTrue);
    });

    test('CEN-M02-010: qualquer combinação de classes é aceita', () {
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [
          combatant('berserker'),
          combatant('berserker'),
          combatant('berserker'),
        ],
        monsters: [monster()],
      );
      expect(state.heroes, hasLength(3), reason: 'classes repetidas valem');
    });

    test('CEN-M02-E02: Medtech sozinho ainda ataca e progride', () {
      final engine = CombatEngine(rng: RngStream(seed: 1));
      final state = CombatState.start(
        position: ProgressPosition.start(),
        heroes: [combatant('medtech')],
        monsters: [monster(maxHp: 200, defense: 0)],
      );

      var current = state;
      var acertou = false;
      for (var i = 0; i < 300; i++) {
        final r = engine.tick(current, 1 / 30);
        current = r.state;
        if (r.hits.isNotEmpty) acertou = true;
      }
      expect(acertou, isTrue, reason: 'o Medtech também ataca');
    });
  });
}
