import 'package:pixel_idle_quest/core/constants/scaling.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M08 — Atos, Waves e Dificuldades.
/// Cenários CEN-M08-001 a 012, E01 a E03.
void main() {
  final director = WaveDirector(
    templates: [
      for (var act = 1; act <= 3; act++) ...[
        TestContent.monster(id: 'comum${act}a', act: act),
        TestContent.monster(id: 'comum${act}b', act: act),
        TestContent.monster(id: 'boss$act', act: act, isBoss: true, maxHp: 900),
      ],
    ],
  );

  RngStream rng([int seed = 11]) => RngStream(seed: seed);

  PlayerAccount account({
    ProgressPosition? position,
    int highestAct = 1,
    int highestDifficulty = 1,
  }) => PlayerAccount.fresh(now: DateTime.utc(2026), seed: 1).copyWith(
    currentPosition: position ?? ProgressPosition.start(),
    highestAct: highestAct,
    highestDifficulty: highestDifficulty,
  );

  group('CEN-M08-001/002 — encadeamento de waves', () {
    test('CEN-M08-001: concluir a wave leva à seguinte, sem ação do jogador', () {
      final result = director.advance(
        const ProgressPosition(difficulty: 1, act: 1, wave: 4),
        account(),
      );

      expect(result, isA<NextWave>());
      expect(result.position.wave, 5);
      expect(result.position.act, 1);
    });

    test('CEN-M08-002: a wave 10 é de boss', () {
      expect(WaveDirector.isBossWave(10), isTrue);
      expect(WaveDirector.isBossWave(9), isFalse);
      expect(WaveDirector.isBossWave(100), isTrue);

      final wave10 = director.advance(
        const ProgressPosition(difficulty: 1, act: 1, wave: 9),
        account(),
      );
      expect(wave10.position.isBossWave, isTrue);
    });

    test('SC-M08-03: toda wave múltipla de 10 apresenta boss, em todo ato', () {
      for (var act = 1; act <= 3; act++) {
        for (var wave = 10; wave <= 100; wave += 10) {
          final monstros = director.spawnWave(
            ProgressPosition(difficulty: 1, act: act, wave: wave),
            rng(),
          );
          expect(
            monstros.any((m) => m.isBoss),
            isTrue,
            reason: 'ato $act wave $wave sem boss',
          );
        }
      }
    });

    test('wave comum não traz boss e cabe no orçamento de 8 monstros', () {
      for (var wave = 1; wave <= 100; wave++) {
        if (wave % 10 == 0) continue;
        final monstros = director.spawnWave(
          ProgressPosition(difficulty: 1, act: 1, wave: wave),
          rng(),
        );
        expect(monstros.any((m) => m.isBoss), isFalse);
        expect(monstros, isNotEmpty);
        expect(monstros.length, lessThanOrEqualTo(8));
      }
    });

    test('os monstros nascem com HP cheio e slots distintos', () {
      final monstros = director.spawnWave(
        const ProgressPosition(difficulty: 1, act: 1, wave: 3),
        rng(),
      );
      expect(monstros.map((m) => m.slot).toSet(), hasLength(monstros.length));
      expect(
        monstros.map((m) => m.instanceId).toSet(),
        hasLength(monstros.length),
      );
      for (final m in monstros) {
        expect(m.currentHp, m.stats.maxHp);
        expect(m.isAlive, isTrue);
      }
    });
  });

  group('CEN-M08-004/007 — escalonamento', () {
    test('CEN-M08-004: monstro da wave 95 é mais forte que o da wave 5', () {
      final fraco = director
          .spawnWave(
            const ProgressPosition(difficulty: 1, act: 1, wave: 5),
            rng(),
          )
          .first;
      final forte = director
          .spawnWave(
            const ProgressPosition(difficulty: 1, act: 1, wave: 95),
            rng(),
          )
          .first;

      expect(forte.stats.maxHp > fraco.stats.maxHp, isTrue);
      expect(forte.stats.attack > fraco.stats.attack, isTrue);
      expect(forte.stats.defense > fraco.stats.defense, isTrue);
    });

    test('CEN-M08-007: a dificuldade 2 multiplica todos os atributos por 1,5', () {
      const d1 = ProgressPosition(difficulty: 1, act: 1, wave: 10);
      const d2 = ProgressPosition(difficulty: 2, act: 1, wave: 10);

      final base = TestContent.stats(attack: 20, defense: 10, maxHp: 100);
      final na1 = MonsterScaling.statsFor(base: base, position: d1);
      final na2 = MonsterScaling.statsFor(base: base, position: d2);

      expect(
        (na2.maxHp / na1.maxHp).toDouble(),
        closeTo(MonsterScaling.difficultyMultiplier, 1e-6),
      );
      expect(
        (na2.attack / na1.attack).toDouble(),
        closeTo(MonsterScaling.difficultyMultiplier, 1e-6),
      );
      expect(
        (na2.defense / na1.defense).toDouble(),
        closeTo(MonsterScaling.difficultyMultiplier, 1e-6),
      );
    });

    test('CEN-M08-010: o escalonamento é cumulativo sobre a anterior', () {
      final base = TestContent.stats(maxHp: 100);
      GameNumber hp(int difficulty) => MonsterScaling.statsFor(
        base: base,
        position: ProgressPosition(difficulty: difficulty, act: 1, wave: 1),
      ).maxHp;

      for (var d = 1; d < 12; d++) {
        expect(
          (hp(d + 1) / hp(d)).toDouble(),
          closeTo(MonsterScaling.difficultyMultiplier, 1e-6),
          reason: 'o degrau da dificuldade $d para ${d + 1} saiu da regra',
        );
      }
    });
  });

  group('CEN-M08-005/006 — transição de ato e dificuldade', () {
    test('CEN-M08-005: a wave 100 do Ato 1 abre o Ato 2 na wave 1', () {
      final result = director.advance(
        const ProgressPosition(difficulty: 1, act: 1, wave: 100),
        account(),
      );

      expect(result, isA<NextAct>());
      expect(result.position.act, 2);
      expect(result.position.wave, 1);
      expect(result.position.difficulty, 1);
    });

    test('CEN-M08-006: a wave 100 do Ato 3 desbloqueia a dificuldade 2', () {
      final result = director.advance(
        const ProgressPosition(difficulty: 1, act: 3, wave: 100),
        account(highestAct: 3),
      );

      expect(result, isA<DifficultyUnlocked>());
      expect((result as DifficultyUnlocked).newDifficulty, 2);
      expect(result.position.difficulty, 2);
      expect(result.position.act, 1);
      expect(result.position.wave, 1);
    });

    test('R-M08-09: não existe teto de dificuldade', () {
      final result = director.advance(
        const ProgressPosition(difficulty: 999, act: 3, wave: 100),
        account(highestDifficulty: 999, highestAct: 3),
      );
      expect((result as DifficultyUnlocked).newDifficulty, 1000);
    });
  });

  group('CEN-M08-009/012 — o que a conta guarda', () {
    test('CEN-M08-009: entrar na dificuldade 2 preserva o progresso da conta', () {
      final antes = account(
        position: const ProgressPosition(difficulty: 1, act: 3, wave: 100),
      ).copyWith(
        gold: GameNumber.fromInt(50000),
        runePoints: 12,
        unlockedRuneNodeIds: {'r1', 'r2'},
        accountLevel: 30,
        highestAct: 3,
      );

      final result = director.advance(antes.currentPosition, antes);
      final depois = WaveDirector.applyAdvance(antes, result);

      expect(depois.currentPosition.difficulty, 2);
      expect(depois.gold, antes.gold);
      expect(depois.runePoints, antes.runePoints);
      expect(depois.unlockedRuneNodeIds, antes.unlockedRuneNodeIds);
      expect(depois.accountLevel, antes.accountLevel);
      expect(depois.formationSlots, antes.formationSlots);
    });

    test('CEN-M08-012: o recorde de maior wave acompanha o avanço', () {
      var acc = account();
      for (var i = 0; i < 15; i++) {
        acc = WaveDirector.applyAdvance(
          acc,
          director.advance(acc.currentPosition, acc),
        );
      }
      expect(acc.currentPosition.wave, 16);
      expect(acc.highestWave, greaterThanOrEqualTo(15));
    });

    test('V-PA-03: o recorde nunca regride ao voltar para conteúdo antigo', () {
      final veterano = account(
        position: const ProgressPosition(difficulty: 2, act: 3, wave: 40),
        highestAct: 3,
        highestDifficulty: 2,
      ).copyWith(highestWave: 340);

      final depois = WaveDirector.applyAdvance(
        veterano,
        director.advance(
          const ProgressPosition(difficulty: 1, act: 1, wave: 2),
          veterano,
        ),
      );

      expect(depois.highestWave, 340);
      expect(depois.highestAct, 3);
      expect(depois.highestDifficulty, 2);
    });
  });

  group('CEN-M08-011 — retorno a conteúdo concluído', () {
    final veterano = PlayerAccount.fresh(
      now: DateTime.utc(2026),
      seed: 1,
    ).copyWith(
      currentPosition: const ProgressPosition(difficulty: 2, act: 2, wave: 30),
      highestAct: 3,
      highestDifficulty: 2,
      highestWave: 300,
    );

    test('escolher ato e dificuldade já concluídos é permitido', () {
      expect(
        WaveDirector.canSelect(
          veterano,
          const ProgressPosition(difficulty: 1, act: 1, wave: 1),
        ),
        isTrue,
      );
    });

    test('escolher além do desbloqueado é recusado', () {
      expect(
        WaveDirector.canSelect(
          veterano,
          const ProgressPosition(difficulty: 3, act: 1, wave: 1),
        ),
        isFalse,
      );
    });

    test('a seleção move a posição sem regredir nenhum recorde', () {
      final depois = WaveDirector.select(
        veterano,
        const ProgressPosition(difficulty: 1, act: 1, wave: 1),
      );

      expect(depois.currentPosition.difficulty, 1);
      expect(depois.currentPosition.act, 1);
      expect(depois.highestAct, 3);
      expect(depois.highestDifficulty, 2);
      expect(depois.highestWave, 300);
    });

    test('seleção inválida devolve a conta intocada', () {
      final depois = WaveDirector.select(
        veterano,
        const ProgressPosition(difficulty: 9, act: 1, wave: 1),
      );
      expect(depois.currentPosition, veterano.currentPosition);
    });

    test('a seleção sempre começa no início do ato escolhido (V-PP-03)', () {
      final depois = WaveDirector.select(
        veterano,
        const ProgressPosition(difficulty: 1, act: 3, wave: 57),
      );
      expect(depois.currentPosition.wave, 1);
      expect(depois.currentPosition.act, 3);
    });
  });

  group('bordas', () {
    test(
      'CEN-M08-E01: DEF acima do ATK do time não trava — o piso de 1 de dano '
      'mantém progresso lento em vez de bloqueio permanente',
      () {
        final position = ProgressPosition.start();
        final monstro = director
            .spawnWave(position, rng())
            .first;

        // Um herói fraquíssimo contra a defesa do monstro ainda causa 1.
        final dano = TestContent.stats(attack: 1).attack;
        expect(dano < monstro.stats.defense, isTrue, reason: 'cenário inválido');

        var hp = monstro.stats.maxHp;
        for (var i = 0; i < 5; i++) {
          hp = hp - GameNumber.one;
        }
        expect(hp < monstro.stats.maxHp, isTrue, reason: 'progresso travou');
      },
    );

    test('CEN-M08-E03: a posição salva aponta para o início da wave', () {
      // A wave em andamento nunca é persistida (V-PP-03); reabrir recomeça a
      // wave, mas ato e dificuldade permanecem.
      final acc = account(
        position: const ProgressPosition(difficulty: 2, act: 2, wave: 37),
        highestAct: 2,
        highestDifficulty: 2,
      );
      final monstros = director.spawnWave(acc.currentPosition, rng());

      expect(monstros.every((m) => m.currentHp == m.stats.maxHp), isTrue);
      expect(acc.currentPosition.act, 2);
      expect(acc.currentPosition.difficulty, 2);
    });

    test('ato sem monstros no conteúdo devolve wave vazia em vez de lançar', () {
      const vazio = WaveDirector(templates: []);
      expect(
        vazio.spawnWave(ProgressPosition.start(), rng()),
        isEmpty,
      );
    });
  });
}
