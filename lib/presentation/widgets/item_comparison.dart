import 'package:flutter/material.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/entities/game_item.dart';
import '../game/components/loot_popup_component.dart';

/// Uma linha de diferença entre o item candidato e o equipado.
class StatDelta {
  const StatDelta({
    required this.label,
    required this.candidate,
    required this.equipped,
    required this.isPercent,
  });

  final String label;
  final double candidate;
  final double equipped;
  final bool isPercent;

  double get delta => candidate - equipped;
  bool get isGain => delta > 0;
  bool get isLoss => delta < 0;

  String format(double value) => isPercent
      ? '${(value * 100).toStringAsFixed(1)}%'
      : NumberFormat.compact(GameNumber.fromDouble(value));
}

/// Comparação entre um item do inventário e o equipado no mesmo slot
/// (R-M05-09, CEN-M05-006).
///
/// A comparação é por **atributo**, não por um número de poder agregado: um
/// score único esconderia que a arma nova troca dano por velocidade, que é
/// exatamente a decisão que o jogador precisa tomar.
class ItemComparison extends StatelessWidget {
  const ItemComparison({
    required this.candidate,
    required this.equipped,
    super.key,
  });

  final GameItem candidate;

  /// `null` quando o slot está vazio — tudo no item novo é ganho.
  final GameItem? equipped;

  static const Color _gain = Color(0xFF5FBF60);
  static const Color _loss = Color(0xFFD24B4B);
  static const Color _neutral = Color(0xFFB4AAC6);

  /// Diferenças entre os dois itens, prefixo principal incluído.
  static List<StatDelta> deltasBetween(GameItem candidate, GameItem? equipped) {
    final types = <AffixType>{
      candidate.primaryAffixType,
      ...candidate.affixes.map((a) => a.affixType),
      if (equipped != null) ...[
        equipped.primaryAffixType,
        ...equipped.affixes.map((a) => a.affixType),
      ],
    };

    double valueOf(GameItem? item, AffixType type) {
      if (item == null) return 0;
      var total = item.affixValue(type).toDouble();
      if (item.primaryAffixType == type) total += item.baseStat.toDouble();
      return total;
    }

    return [
      for (final type in types)
        StatDelta(
          label: _labels[type] ?? type.id,
          candidate: valueOf(candidate, type),
          equipped: valueOf(equipped, type),
          isPercent: _percentTypes.contains(type),
        ),
    ]..sort((a, b) => a.label.compareTo(b.label));
  }

  static const Set<AffixType> _percentTypes = {
    AffixType.critChance,
    AffixType.critDamage,
    AffixType.attackSpeed,
    AffixType.goldFind,
    AffixType.xpGain,
    AffixType.fireResist,
    AffixType.iceResist,
    AffixType.lightningResist,
  };

  static const Map<AffixType, String> _labels = {
    AffixType.attack: 'Ataque',
    AffixType.defense: 'Defesa',
    AffixType.health: 'Vida',
    AffixType.critChance: 'Crítico',
    AffixType.critDamage: 'Dano crítico',
    AffixType.attackSpeed: 'Vel. ataque',
    AffixType.goldFind: 'Ouro',
    AffixType.xpGain: 'XP',
    AffixType.fireResist: 'Res. fogo',
    AffixType.iceResist: 'Res. gelo',
    AffixType.lightningResist: 'Res. raio',
  };

  @override
  Widget build(BuildContext context) {
    final deltas = deltasBetween(candidate, equipped);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          equipped == null
              ? 'Slot vazio — tudo é ganho'
              : 'Comparado com ${equipped!.rarity.id} iLv${equipped!.itemLevel}',
          style: const TextStyle(fontSize: 11, color: _neutral),
        ),
        const SizedBox(height: 8),
        for (final d in deltas) _DeltaRow(delta: d),
      ],
    );
  }
}

class _DeltaRow extends StatelessWidget {
  const _DeltaRow({required this.delta});

  final StatDelta delta;

  @override
  Widget build(BuildContext context) {
    final color = delta.isGain
        ? ItemComparison._gain
        : delta.isLoss
        ? ItemComparison._loss
        : ItemComparison._neutral;

    final sign = delta.isGain ? '+' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              delta.label,
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
          ),
          Text(
            delta.format(delta.candidate),
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 76,
            child: Text(
              delta.delta == 0 ? '—' : '$sign${delta.format(delta.delta)}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabeçalho de item reutilizado pelas telas de inventário e de herói: nome,
/// raridade e cor.
class ItemHeadline extends StatelessWidget {
  const ItemHeadline({required this.item, this.trailing, super.key});

  final GameItem item;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = RarityPalette.of(item.rarity);
    return Row(
      children: [
        Container(width: 4, height: 28, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.type.id,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                '${item.rarity.id}  ·  iLv ${item.itemLevel}'
                '${item.isFavorited ? "  ·  ★" : ""}',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB4AAC6)),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}
