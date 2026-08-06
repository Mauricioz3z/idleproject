import 'dart:math' as math;

import '../../core/constants/scaling.dart';
import '../../core/rng/rng_stream.dart';
import '../entities/monster.dart';
import '../entities/monster_template.dart';
import '../entities/player_account.dart';
import '../entities/progress_position.dart';

/// Resultado de concluir uma wave.
sealed class AdvanceResult {
  const AdvanceResult(this.position);

  /// Onde o jogador passa a estar.
  final ProgressPosition position;
}

/// Próxima wave do mesmo ato (R-M08-05).
class NextWave extends AdvanceResult {
  const NextWave(super.position);
}

/// Boss final do ato derrotado: ato seguinte, wave 1 (CEN-M08-005).
class NextAct extends AdvanceResult {
  const NextAct(super.position);
}

/// Wave 100 do Ato 3 concluída: dificuldade seguinte, ato 1, wave 1
/// (R-M08-07, R-M08-10).
class DifficultyUnlocked extends AdvanceResult {
  const DifficultyUnlocked(super.position);

  int get newDifficulty => position.difficulty;
}

/// Encadeia waves, atos e dificuldades (M08).
///
/// Dart puro e sem estado: a composição de uma wave é derivada da posição sob
/// demanda, nunca guardada. É o que permite ao simulador offline (M09) montar as
/// mesmas waves que o combate ao vivo montaria, e o que faz a wave parcial nunca
/// ser persistida (V-PP-03, CEN-M08-E03).
class WaveDirector {
  const WaveDirector({required this.templates});

  final List<MonsterTemplate> templates;

  /// Mínimo e máximo de monstros comuns por wave. O teto vem do orçamento de
  /// desempenho de plan.md: 30 FPS com 4 heróis e até 8 monstros.
  static const int minMonstersPerWave = 2;
  static const int maxMonstersPerWave = 8;

  /// R-M08-03: boss a cada 10 waves, sem exceção (SC-M08-03).
  static bool isBossWave(int wave) =>
      wave % ProgressPosition.bossInterval == 0;

  /// Monta os monstros da wave, já com os atributos escalados para a posição.
  List<Monster> spawnWave(ProgressPosition position, RngStream rng) {
    final doAto = templates.where((t) => t.act == position.act).toList();
    if (doAto.isEmpty) return const [];

    final bosses = doAto.where((t) => t.isBoss).toList();
    final comuns = doAto.where((t) => !t.isBoss).toList();

    if (isBossWave(position.wave) && bosses.isNotEmpty) {
      // Boss sozinho no campo: é o momento em que a wave muda de natureza, e
      // dividir a atenção com lacaios diluiria a leitura (CEN-M08-002).
      return [_spawn(bosses[rng.nextInt(bosses.length)], position, 0)];
    }

    final pool = comuns.isEmpty ? bosses : comuns;
    final count = _monsterCount(position, rng);

    return [
      for (var slot = 0; slot < count; slot++)
        _spawn(pool[rng.nextInt(pool.length)], position, slot),
    ];
  }

  /// Aplica a conclusão da wave atual.
  ///
  /// [account] entra para que a decisão possa considerar o progresso da conta;
  /// nada aqui a modifica — quem grava é [applyAdvance], e é essa separação que
  /// mantém o motor livre de efeito colateral (I-4 do contrato de domínio).
  AdvanceResult advance(ProgressPosition current, PlayerAccount account) {
    if (current.wave < ProgressPosition.maxWave) {
      return NextWave(current.copyWith(wave: current.wave + 1));
    }

    if (current.act < ProgressPosition.maxAct) {
      return NextAct(current.copyWith(act: current.act + 1, wave: 1));
    }

    // R-M08-10: dificuldade+1, ato 1, wave 1. Só a posição muda — heróis,
    // itens, níveis e runas seguem intocados (CEN-M08-009), o que aqui é
    // consequência de a conta só ter a posição reescrita.
    return DifficultyUnlocked(
      ProgressPosition(difficulty: current.difficulty + 1, act: 1, wave: 1),
    );
  }

  /// Grava o avanço na conta: nova posição e recordes, sempre monotônicos
  /// (V-PA-03, CEN-M08-012).
  static PlayerAccount applyAdvance(
    PlayerAccount account,
    AdvanceResult result,
  ) {
    final reached = account.currentPosition;
    return account.copyWith(
      currentPosition: result.position,
      // `globalWave` porque o recorde precisa ser comparável entre atos
      // (V-PP-04).
      highestWave: math.max(account.highestWave, reached.globalWave),
      highestAct: math.max(account.highestAct, result.position.act),
      highestDifficulty: math.max(
        account.highestDifficulty,
        result.position.difficulty,
      ),
    );
  }

  /// R-M08-11: o jogador pode voltar a atos e dificuldades já concluídos.
  static bool canSelect(PlayerAccount account, ProgressPosition target) =>
      target.isValid &&
      target.difficulty <= account.highestDifficulty &&
      (target.difficulty < account.highestDifficulty ||
          target.act <= account.highestAct);

  /// Move a posição para conteúdo já desbloqueado.
  ///
  /// Sempre no início do ato: a wave em andamento nunca é retomada (V-PP-03).
  /// Nenhum recorde é tocado — voltar para farmar não pode custar progresso
  /// (CEN-M08-011).
  static PlayerAccount select(PlayerAccount account, ProgressPosition target) {
    if (!canSelect(account, target)) return account;
    return account.copyWith(
      currentPosition: ProgressPosition(
        difficulty: target.difficulty,
        act: target.act,
        wave: 1,
      ),
    );
  }

  Monster _spawn(
    MonsterTemplate template,
    ProgressPosition position,
    int slot,
  ) => Monster.spawn(
    instanceId: '${position.difficulty}_${position.act}_${position.wave}_$slot',
    template: template,
    stats: MonsterScaling.statsFor(
      base: template.baseStats,
      position: position,
    ),
    slot: slot,
  );

  /// Quantidade de monstros comuns. Cresce devagar com a wave e nunca passa do
  /// teto de desempenho.
  int _monsterCount(ProgressPosition position, RngStream rng) {
    final byWave = minMonstersPerWave + position.wave ~/ 25;
    final jitter = rng.nextInt(2);
    final total = byWave + jitter;
    return total > maxMonstersPerWave ? maxMonstersPerWave : total;
  }
}
