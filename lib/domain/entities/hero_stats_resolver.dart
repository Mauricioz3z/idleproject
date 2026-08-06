import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import 'game_item.dart';
import 'hero_class_definition.dart';
import 'rune_node.dart';
import 'stats.dart';

/// Atributos efetivos de um herói, já com nível, itens e runas aplicados.
///
/// Os percentuais ficam **fora** de [stats] de propósito: `+8% de crítico` não é
/// um atributo bruto, e somá-lo a `attack` faria a mesma peça valer coisas
/// diferentes conforme o slot. O motor de combate consome os dois campos
/// separadamente.
class HeroEffectiveStats {
  const HeroEffectiveStats({
    required this.stats,
    required this.bonusCritChance,
    required this.bonusCritDamage,
    required this.attackSpeedMultiplier,
    required this.goldFindBonus,
    required this.xpGainBonus,
    required this.resistances,
  });

  final Stats stats;
  final double bonusCritChance;
  final double bonusCritDamage;
  final double attackSpeedMultiplier;
  final double goldFindBonus;
  final double xpGainBonus;

  /// Resistência elemental por tipo de sufixo, em fração.
  final Map<AffixType, double> resistances;
}

/// Resolve `base + nível + itens + runas` (M05, R-M05-03).
///
/// Recalculado a cada mudança, nunca armazenado: é o que faz equipar um item
/// refletir nos atributos imediatamente, sem reiniciar a wave (SC-M05-04), e o
/// que torna o respec durante combate seguro (CEN-M07-E03).
abstract final class HeroStatsResolver {
  static HeroEffectiveStats resolve({
    required HeroClassDefinition definition,
    required int level,
    Iterable<GameItem> equipped = const [],
    RuneModifiers runes = RuneModifiers.none,
  }) {
    var stats = statsForLevel(definition, level);

    var critChance = 0.0;
    var critDamage = 0.0;
    var attackSpeed = 1.0;
    var goldFind = 0.0;
    var xpGain = 0.0;
    final resistances = <AffixType, double>{};

    for (final item in equipped) {
      // Prefixo principal: soma no atributo bruto que o tipo do item determina
      // (V-GI-02).
      stats = _applyPrimary(stats, item.primaryAffixType, item.baseStat);

      for (final affix in item.affixes) {
        final value = affix.value.toDouble();
        switch (affix.affixType) {
          case AffixType.attack:
          case AffixType.defense:
          case AffixType.health:
            stats = _applyPrimary(stats, affix.affixType, affix.value);
          case AffixType.critChance:
            critChance += value;
          case AffixType.critDamage:
            critDamage += value;
          case AffixType.attackSpeed:
            attackSpeed += value;
          case AffixType.goldFind:
            goldFind += value;
          case AffixType.xpGain:
            xpGain += value;
          case AffixType.fireResist:
          case AffixType.iceResist:
          case AffixType.lightningResist:
            resistances[affix.affixType] =
                (resistances[affix.affixType] ?? 0) + value;
        }
      }
    }

    return HeroEffectiveStats(
      stats: stats,
      bonusCritChance: critChance + runes.bonusCritChance,
      bonusCritDamage: critDamage,
      attackSpeedMultiplier: attackSpeed * runes.attackSpeedMultiplier,
      goldFindBonus: goldFind,
      xpGainBonus: xpGain,
      resistances: Map.unmodifiable(resistances),
    );
  }

  /// Atributos de classe no nível dado, sem itens.
  ///
  /// Fonte única da curva de nível: `ProgressionService.statsForLevel` delega
  /// para cá. Duas curvas paralelas fariam o mesmo herói valer coisas diferentes
  /// na tela de detalhe e no combate.
  static Stats statsForLevel(HeroClassDefinition definition, int level) {
    final growth = level - 1;
    if (growth <= 0) return definition.baseStats;
    return definition.baseStats +
        definition.statGrowthPerLevel.scaledBy(GameNumber.fromInt(growth));
  }

  static Stats _applyPrimary(Stats stats, AffixType type, GameNumber value) =>
      switch (type) {
        AffixType.attack => stats.copyWith(attack: stats.attack + value),
        AffixType.defense => stats.copyWith(defense: stats.defense + value),
        AffixType.health => stats.copyWith(maxHp: stats.maxHp + value),
        _ => stats,
      };
}
