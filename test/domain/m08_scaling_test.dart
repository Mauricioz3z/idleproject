import 'package:pixel_idle_quest/core/constants/scaling.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// Escalonamento por dificuldade acima de 1e18 — research.md R6.
///
/// R-M08-08 multiplica todos os atributos por 1,5 a cada dificuldade e R-M08-09
/// não impõe teto. Em `int64` isso transborda em algum ponto entre a dificuldade
/// 74 e 108, e em Dart nativo o transbordo é **silencioso**: o HP do monstro
/// viraria negativo e a wave seria vencida com um golpe. Estes testes existem
/// para que essa regressão apareça aqui e não no aparelho do jogador.
void main() {
  final base = TestContent.stats(attack: 20, defense: 10, maxHp: 100);

  GameNumber hpAt(int difficulty) => MonsterScaling.statsFor(
    base: base,
    position: ProgressPosition(difficulty: difficulty, act: 1, wave: 1),
  ).maxHp;

  test('a dificuldade 200 passa de 1e18 sem transbordar', () {
    final hp = hpAt(200);

    expect(hp.isFinite, isTrue);
    expect(hp.exponent, greaterThan(18), reason: 'o teste não saiu da faixa');
    expect(hp > GameNumber.fromDouble(1e18), isTrue);
  });

  test('o crescimento continua monotônico muito além do limite de int64', () {
    var anterior = hpAt(100);
    for (var d = 101; d <= 300; d++) {
      final atual = hpAt(d);
      expect(
        atual > anterior,
        isTrue,
        reason: 'a dificuldade $d não superou a anterior — sinal de transbordo',
      );
      anterior = atual;
    }
  });

  test('nenhum atributo vira zero ou negativo em dificuldade extrema', () {
    final stats = MonsterScaling.statsFor(
      base: base,
      position: const ProgressPosition(difficulty: 500, act: 3, wave: 100),
    );

    for (final value in [
      stats.attack,
      stats.defense,
      stats.maxHp,
      stats.str,
      stats.vit,
    ]) {
      expect(value.isZero, isFalse);
      expect(value.isFinite, isTrue);
      expect(value > GameNumber.zero, isTrue);
    }
  });

  test('a razão entre dificuldades consecutivas continua exatamente 1,5', () {
    for (final d in [1, 50, 120, 250, 400]) {
      expect(
        (hpAt(d + 1) / hpAt(d)).toDouble(),
        closeTo(MonsterScaling.difficultyMultiplier, 1e-6),
        reason: 'a razão se degradou na dificuldade $d',
      );
    }
  });

  test('int64 realmente não daria conta — a razão do GameNumber existir', () {
    // 100 × 1,5^108 ≈ 6e21, muito acima do máximo de int64 (~9,22e18).
    final hp = hpAt(109);
    expect(hp.toInt(), 9223372036854775807, reason: 'toInt satura, não estoura');
    expect(hp.exponent, greaterThan(18));
  });

  test('o item level acompanha a dificuldade sem depender de GameNumber', () {
    // Contadores discretos continuam int (V-GN-03): +10 por dificuldade.
    const wave = ProgressPosition(difficulty: 1, act: 1, wave: 10);
    const wave300 = ProgressPosition(difficulty: 300, act: 1, wave: 10);

    expect(
      ItemScaling.itemLevelFor(wave300) - ItemScaling.itemLevelFor(wave),
      ItemScaling.itemLevelPerDifficulty * 299,
    );
  });
}
