import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:test/test.dart';

/// Testes de [RngStream] — research.md R5.
///
/// Dois requisitos da spec dependem deste determinismo: a simulação offline
/// precisa gerar exatamente o mesmo loot que o combate ao vivo geraria
/// (CEN-M09-*), e reprocessar o mesmo intervalo não pode duplicar itens
/// (CEN-M10-E03). Como efeito colateral, fecha a porta do save-scumming.
void main() {
  group('reprodutibilidade por semente', () {
    test('mesma semente produz a mesma sequência', () {
      final a = RngStream(seed: 12345);
      final b = RngStream(seed: 12345);
      final seqA = List.generate(50, (_) => a.nextDouble());
      final seqB = List.generate(50, (_) => b.nextDouble());
      expect(seqA, seqB);
    });

    test('sementes diferentes produzem sequências diferentes', () {
      final a = RngStream(seed: 1);
      final b = RngStream(seed: 2);
      final seqA = List.generate(20, (_) => a.nextDouble());
      final seqB = List.generate(20, (_) => b.nextDouble());
      expect(seqA, isNot(seqB));
    });

    test('restaurar semente e contador retoma exatamente do mesmo ponto', () {
      final original = RngStream(seed: 999);
      for (var i = 0; i < 37; i++) {
        original.nextDouble();
      }
      final restored = RngStream(seed: 999, counter: original.counter);
      final continuedOriginal = List.generate(10, (_) => original.nextDouble());
      final continuedRestored = List.generate(10, (_) => restored.nextDouble());
      expect(continuedRestored, continuedOriginal);
    });

    test('contador avança a cada consumo', () {
      final rng = RngStream(seed: 7);
      expect(rng.counter, 0);
      rng.nextDouble();
      expect(rng.counter, 1);
      rng.nextInt(100);
      expect(rng.counter, 2);
    });
  });

  group('faixa de saída', () {
    test('nextDouble fica em [0,1)', () {
      final rng = RngStream(seed: 42);
      for (var i = 0; i < 1000; i++) {
        final v = rng.nextDouble();
        expect(v, greaterThanOrEqualTo(0.0));
        expect(v, lessThan(1.0));
      }
    });

    test('nextInt respeita o limite exclusivo', () {
      final rng = RngStream(seed: 42);
      for (var i = 0; i < 1000; i++) {
        final v = rng.nextInt(8);
        expect(v, greaterThanOrEqualTo(0));
        expect(v, lessThan(8));
      }
    });

    test('nextInt cobre toda a faixa ao longo de muitas amostras', () {
      final rng = RngStream(seed: 3);
      final seen = <int>{};
      for (var i = 0; i < 500; i++) {
        seen.add(rng.nextInt(6));
      }
      expect(seen, {0, 1, 2, 3, 4, 5});
    });
  });

  group('isolamento de fork — o que impede o loot de se deslocar', () {
    test('fork não avança o contador do pai', () {
      final parent = RngStream(seed: 555);
      final before = parent.counter;
      final child = parent.fork('loot');
      for (var i = 0; i < 20; i++) {
        child.nextDouble();
      }
      expect(parent.counter, before);
    });

    test('forks com rótulos diferentes produzem sequências diferentes', () {
      final parent = RngStream(seed: 555);
      final loot = parent.fork('loot');
      final essence = parent.fork('essence');
      final seqLoot = List.generate(20, (_) => loot.nextDouble());
      final seqEssence = List.generate(20, (_) => essence.nextDouble());
      expect(seqLoot, isNot(seqEssence));
    });

    test('mesmo rótulo e mesmo estado do pai produzem o mesmo fork', () {
      final a = RngStream(seed: 777).fork('loot');
      final b = RngStream(seed: 777).fork('loot');
      expect(
        List.generate(20, (_) => a.nextDouble()),
        List.generate(20, (_) => b.nextDouble()),
      );
    });

    test(
      'consumir muito de um fork não altera o que outro fork produz — '
      'é isto que permite mudar a taxa de Essência sem mexer no loot (R-M04-13)',
      () {
        final parent = RngStream(seed: 2024);
        final essenceHeavy = parent.fork('essence');
        for (var i = 0; i < 500; i++) {
          essenceHeavy.nextDouble();
        }
        final lootAfter = parent.fork('loot');

        final parent2 = RngStream(seed: 2024);
        final lootClean = parent2.fork('loot');

        expect(
          List.generate(30, (_) => lootAfter.nextDouble()),
          List.generate(30, (_) => lootClean.nextDouble()),
        );
      },
    );
  });
}
