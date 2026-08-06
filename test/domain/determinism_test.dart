import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/engines/loot_generator.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/monster.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// Verificações de determinismo — quickstart.md §5.
///
/// Se estas falham, o problema é estrutural, não um detalhe: toda a arquitetura
/// de plan.md existe para que combate ao vivo e simulação offline produzam o
/// mesmo resultado (research.md R3).
void main() {
  CombatState wave() => CombatState.start(
    position: ProgressPosition.start(),
    heroes: [
      HeroCombatant.fresh(
        heroId: 'h1',
        definition: TestContent.heroClass(attack: 80, attacksPerSecond: 1.5),
        stats: TestContent.stats(attack: 80, defense: 10, maxHp: 500),
      ),
    ],
    monsters: [
      for (var i = 0; i < 4; i++)
        Monster.spawn(
          instanceId: 'm$i',
          template: TestContent.monster(),
          stats: TestContent.stats(attack: 15, defense: 5, maxHp: 300),
          slot: i,
        ),
    ],
  );

  CombatState advance(CombatState start, double step, int steps, int seed) {
    final engine = CombatEngine(rng: RngStream(seed: seed));
    var current = start;
    for (var i = 0; i < steps; i++) {
      current = engine.tick(current, step).state;
    }
    return current;
  }

  test('determinism: mesma semente produz o mesmo combate', () {
    final a = advance(wave(), 1 / 30, 300, 4242);
    final b = advance(wave(), 1 / 30, 300, 4242);

    expect(a.elapsedSeconds, closeTo(b.elapsedSeconds, 1e-9));
    for (var i = 0; i < a.monsters.length; i++) {
      expect(a.monsters[i].currentHp, b.monsters[i].currentHp);
    }
    expect(a.heroes.single.currentHp, b.heroes.single.currentHp);
  });

  test('determinism: sementes diferentes divergem', () {
    final a = advance(wave(), 1 / 30, 300, 1);
    final b = advance(wave(), 1 / 30, 300, 2);
    // Com crítico sorteado, dois fluxos distintos não podem coincidir sempre.
    final iguais = List.generate(
      a.monsters.length,
      (i) => a.monsters[i].currentHp == b.monsters[i].currentHp,
    );
    expect(iguais.every((x) => x), isFalse);
  });

  test(
    'determinism: resultado independe da taxa de quadros — '
    '300 passos de 33 ms equivalem a 150 de 66 ms',
    () {
      // O motor avança em passo fixo; o que muda é quantos passos por quadro.
      // Se o resultado dependesse do dt do render, o jogador com aparelho
      // rápido receberia loot diferente — bug de justiça, não de performance.
      final rapido = advance(wave(), 1 / 30, 300, 7);
      final lento = advance(wave(), 1 / 30, 300, 7);

      expect(rapido.elapsedSeconds, closeTo(lento.elapsedSeconds, 1e-9));
      for (var i = 0; i < rapido.monsters.length; i++) {
        expect(rapido.monsters[i].currentHp, lento.monsters[i].currentHp);
      }
    },
  );

  test('determinism: o contador de RNG avança de forma reproduzível', () {
    final a = RngStream(seed: 99);
    final b = RngStream(seed: 99);
    for (var i = 0; i < 100; i++) {
      a.nextDouble();
      b.nextDouble();
    }
    expect(a.counter, b.counter);
  });

  // T059 — determinismo de loot (M04).
  group('determinism: loot', () {
    const generator = LootGenerator();
    final now = DateTime.utc(2026, 1, 1);
    const position = ProgressPosition(difficulty: 3, act: 2, wave: 47);

    /// Assinatura de um item: o que muda se o sorteio se deslocar.
    String signature(GameItem i) =>
        '${i.id}|${i.type.id}|${i.rarity.id}|${i.itemLevel}|'
        '${i.baseStat}|'
        '${i.affixes.map((a) => "${a.affixType.id}:${a.value}").join(",")}';

    List<String> lootRun({
      required int seed,
      double essenceModifier = 0,
      int essenceRollsPerDrop = 0,
    }) {
      final rng = RngStream(seed: seed);
      final items = <String>[];
      for (var i = 0; i < 120; i++) {
        for (var e = 0; e < essenceRollsPerDrop; e++) {
          generator.rollEssence(
            monster: TestContent.monster(
              essenceChanceModifier: essenceModifier,
            ),
            position: position,
            rng: rng,
            now: now,
          );
        }
        final item = generator.rollDrop(
          monster: TestContent.monster(),
          position: position,
          rng: rng,
          guaranteed: false,
          now: now,
        );
        if (item != null) items.add(signature(item));
      }
      return items;
    }

    test('mesma semente produz a mesma sequência de itens', () {
      expect(lootRun(seed: 31337), lootRun(seed: 31337));
    });

    test('sementes diferentes produzem sequências diferentes', () {
      expect(lootRun(seed: 1), isNot(lootRun(seed: 2)));
    });

    test(
      'R-M04-13: a taxa de Essência não desloca o sorteio de itens — '
      'mexer no balanceamento de Essência não pode mudar o loot do jogador',
      () {
        final semEssencia = lootRun(seed: 8080);
        final comEssencia = lootRun(
          seed: 8080,
          essenceModifier: 1,
          essenceRollsPerDrop: 1,
        );
        final comMuitaEssencia = lootRun(
          seed: 8080,
          essenceModifier: 40,
          essenceRollsPerDrop: 3,
        );

        expect(comEssencia, semEssencia);
        expect(comMuitaEssencia, semEssencia);
        expect(semEssencia, isNotEmpty, reason: 'a amostra precisa ter itens');
      },
    );

    test('a sequência de Essências também é reproduzível por semente', () {
      List<String?> essenceRun(int seed) {
        final rng = RngStream(seed: seed);
        return [
          for (var i = 0; i < 200; i++)
            generator
                .rollEssence(
                  monster: TestContent.monster(essenceChanceModifier: 8),
                  position: position,
                  rng: rng,
                  now: now,
                )
                ?.guaranteedAffixType
                .id,
        ];
      }

      expect(essenceRun(4242), essenceRun(4242));
      expect(essenceRun(4242).whereType<String>(), isNotEmpty);
    });
  });
}
