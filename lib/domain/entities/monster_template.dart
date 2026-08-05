import '../../core/constants/game_enums.dart';
import 'stats.dart';

/// Template de monstro, carregado de `assets/content/monsters.json`.
///
/// Os atributos efetivos são derivados, nunca armazenados:
/// `baseStats × f(wave, act) × 1.5^(difficulty−1)` — R-M08-06, R-M08-08.
class MonsterTemplate {
  const MonsterTemplate({
    required this.id,
    required this.displayName,
    required this.act,
    required this.baseStats,
    required this.possibleRarities,
    required this.dropChanceModifier,
    required this.essenceChanceModifier,
    required this.isBoss,
  });

  final String id;
  final String displayName;

  /// Ato em que este monstro aparece (1 a 3).
  final int act;

  final Stats baseStats;

  /// Teto de raridade deste monstro. Nenhum drop dele excede esta lista
  /// (CEN-M04-008).
  final List<ItemRarity> possibleRarities;

  /// Modificador da chance de drop de item (CEN-M04-009).
  final double dropChanceModifier;

  /// Modificador da chance de Essência. Independente do de item (R-M04-13).
  final double essenceChanceModifier;

  final bool isBoss;
}
