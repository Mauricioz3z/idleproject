import 'game_enums.dart';

/// Faixa de valores de um sufixo, já resolvida para uma raridade e um item
/// level.
class AffixRange {
  const AffixRange({required this.min, required this.max, required this.isPercent});

  final double min;
  final double max;

  /// Sufixos percentuais (crítico, velocidade, ouro, XP, resistências) não
  /// somam atributo bruto: entram como fração no resolvedor de atributos.
  final bool isPercent;

  double at(double t) => min + (max - min) * t;
}

/// Tabela de sufixos por raridade e item level (R-M04-04, R-M04-07).
///
/// Tabela de dados e não fórmula espalhada pelo gerador: o balanceamento de
/// loot muda muito mais que a mecânica, e concentrar os números aqui torna cada
/// ajuste uma edição de uma linha, verificável de fora.
abstract final class AffixTable {
  /// Quantidade mínima de sufixos por raridade (R-M04-07).
  static int minAffixes(ItemRarity rarity) => rarity.index ~/ 3;

  /// Quantidade máxima de sufixos por raridade, nunca acima do teto de 3
  /// imposto por V-GI-01.
  static int maxAffixes(ItemRarity rarity) {
    final byRarity = 1 + rarity.index ~/ 2;
    return byRarity > 3 ? 3 : byRarity;
  }

  /// Faixa de valor de [type] num item de raridade e item level dados.
  ///
  /// Sufixos percentuais crescem devagar e têm teto próprio: um `+% crítico`
  /// que escalasse com o item level como o atributo bruto passaria de 100% em
  /// poucos atos e transformaria o crítico em constante.
  static AffixRange rangeFor({
    required AffixType type,
    required ItemRarity rarity,
    required int itemLevel,
  }) {
    final tier = 1.0 + 0.25 * rarity.index;

    return switch (type) {
      AffixType.critChance => AffixRange(
        min: 0.005 * tier,
        max: 0.02 * tier,
        isPercent: true,
      ),
      AffixType.critDamage => AffixRange(
        min: 0.05 * tier,
        max: 0.25 * tier,
        isPercent: true,
      ),
      AffixType.attackSpeed => AffixRange(
        min: 0.01 * tier,
        max: 0.06 * tier,
        isPercent: true,
      ),
      AffixType.goldFind => AffixRange(
        min: 0.02 * tier,
        max: 0.10 * tier,
        isPercent: true,
      ),
      AffixType.xpGain => AffixRange(
        min: 0.02 * tier,
        max: 0.10 * tier,
        isPercent: true,
      ),
      AffixType.fireResist ||
      AffixType.iceResist ||
      AffixType.lightningResist => AffixRange(
        min: 0.01 * tier,
        max: 0.05 * tier,
        isPercent: true,
      ),
      // Prefixos principais aparecem aqui apenas quando um sufixo repete um
      // atributo bruto — caso do Cubo com Essência de ataque, por exemplo.
      AffixType.attack ||
      AffixType.defense ||
      AffixType.health => AffixRange(
        min: 0.5 * itemLevel * tier,
        max: 1.5 * itemLevel * tier,
        isPercent: false,
      ),
    };
  }
}
