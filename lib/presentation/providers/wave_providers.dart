import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engines/wave_director.dart';
import '../../domain/entities/monster.dart';
import '../../domain/entities/progress_position.dart';
import 'game_dependencies.dart';

/// Diretor de waves, montado sobre os templates carregados do conteúdo.
final waveDirectorProvider = Provider<WaveDirector>(
  (ref) => WaveDirector(
    templates: ref.watch(combatDependenciesProvider).monsterTemplates,
  ),
);

/// Decide quando um drop é garantido (R-M04-11, CEN-M08-003, CEN-M04-010).
///
/// A regra mora aqui, e não dentro do `LootGenerator`, porque ela é sobre a
/// **wave** e não sobre o item: quem sabe que a wave é de boss é o
/// [WaveDirector]. O gerador apenas obedece ao sinalizador `guaranteed`.
class BossDropPolicy {
  const BossDropPolicy();

  /// Verdadeiro só quando o monstro derrotado é o boss **da** wave de boss.
  ///
  /// Exigir as duas condições evita que um template marcado como boss, colocado
  /// numa wave comum por erro de conteúdo, passe a conceder loot garantido a
  /// cada aparição.
  bool isGuaranteed(ProgressPosition position, Monster monster) =>
      monster.isBoss && WaveDirector.isBossWave(position.wave);
}

final bossDropPolicyProvider = Provider<BossDropPolicy>(
  (ref) => const BossDropPolicy(),
);
