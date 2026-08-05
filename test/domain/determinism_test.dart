import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
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
}
