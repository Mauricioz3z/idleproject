import 'package:flutter/material.dart';

import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/entities/progress_position.dart';

/// HUD superior: ato, wave, dificuldade, ouro e heróis em combate.
///
/// SC-M08-02 exige que o jogador identifique ato, wave e dificuldade numa única
/// tela, sem navegação — por isso tudo cabe aqui.
class ProgressHud extends StatelessWidget {
  const ProgressHud({
    required this.position,
    required this.gold,
    required this.heroesInCombat,
    super.key,
  });

  final ProgressPosition position;
  final GameNumber gold;
  final int heroesInCombat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1E1B2E),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  // Numeração acumulada, que é a que o jogador vê (V-PP-04).
                  'Wave ${position.globalWave}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Ato ${position.act}'
                  '${position.difficulty > 1 ? "  ·  Dif. ${position.difficulty}" : ""}'
                  '${position.isBossWave ? "  ·  BOSS" : ""}',
                  style: TextStyle(
                    fontSize: 11,
                    color: position.isBossWave
                        ? const Color(0xFF9B3FBF)
                        : const Color(0xFFB4AAC6),
                  ),
                ),
              ],
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
