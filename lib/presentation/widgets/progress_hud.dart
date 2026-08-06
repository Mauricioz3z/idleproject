import 'package:flutter/material.dart';

import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/entities/progress_position.dart';
import '../game/components/background_component.dart';

/// HUD superior: ato, wave, dificuldade, ouro e heróis em combate.
///
/// SC-M08-02 exige que o jogador identifique ato, wave atual **e** dificuldade
/// numa única tela, sem navegação — por isso os três estão sempre visíveis, e
/// não só quando saem do valor inicial. Um jogador na dificuldade 1 que não
/// enxerga o campo "dificuldade" não sabe que ele existe.
class ProgressHud extends StatelessWidget {
  const ProgressHud({
    required this.position,
    required this.gold,
    required this.heroesInCombat,
    this.onTapProgress,
    super.key,
  });

  final ProgressPosition position;
  final GameNumber gold;
  final int heroesInCombat;

  /// Abre a seleção de atos e dificuldades (R-M08-11). Nulo quando não há para
  /// onde voltar.
  final VoidCallback? onTapProgress;

  @override
  Widget build(BuildContext context) {
    final scenery = ActScenery.forAct(position.act);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E1B2E),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTapProgress,
              child: Row(
                children: [
                  Container(width: 4, height: 34, color: scenery.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              // Numeração acumulada, que é a que o jogador vê
                              // (V-PP-04).
                              'Wave ${position.globalWave}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (position.isBossWave) ...[
                              const SizedBox(width: 6),
                              const _BossBadge(),
                            ],
                          ],
                        ),
                        Text(
                          'Ato ${position.act} · ${scenery.name}'
                          '  ·  Dif. ${position.difficulty}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB4AAC6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                NumberFormat.compact(gold),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE8B44A),
                ),
              ),
              Text(
                '$heroesInCombat em combate',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFB4AAC6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Marca a wave de boss no próprio HUD, e não só na arena: o jogador que abre o
/// app no meio de uma wave de boss precisa saber disso sem contar monstros
/// (SC-M08-03).
class _BossBadge extends StatelessWidget {
  const _BossBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      color: const Color(0xFF9B3FBF),
      child: const Text(
        'BOSS',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
