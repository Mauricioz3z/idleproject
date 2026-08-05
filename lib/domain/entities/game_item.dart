import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';

/// Sufixo de um item: um tipo de atributo e seu valor.
class ItemAffix {
  const ItemAffix({required this.affixType, required this.value});

  final AffixType affixType;
  final GameNumber value;

  @override
  bool operator ==(Object other) =>
      other is ItemAffix &&
      other.affixType == affixType &&
      other.value == value;

  @override
  int get hashCode => Object.hash(affixType, value);
}

/// Item de equipamento obtido por drop (M04).
class GameItem {
  GameItem({
    required this.id,
    required this.type,
    required this.rarity,
    required this.itemLevel,
    required this.baseStat,
    required List<ItemAffix> affixes,
    required this.droppedAt,
    this.isFavorited = false,
  }) : affixes = List.unmodifiable(affixes) {
    assert(affixes.length <= maxAffixes, 'V-GI-01: máximo de 3 sufixos');
    assert(
      affixes.map((a) => a.affixType).toSet().length == affixes.length,
      'V-GI-01: sufixos não podem repetir affixType',
    );
  }

  static const int maxAffixes = 3;

  final String id;
  final ItemType type;
  final ItemRarity rarity;

  /// Escala com a wave em que o item foi obtido (R-M04-05).
  final int itemLevel;

  /// Prefixo principal, coerente com [type] (V-GI-02).
  final GameNumber baseStat;

  /// 0 a 3 sufixos, sem repetição de tipo (V-GI-01).
  final List<ItemAffix> affixes;

  /// Protege da venda automática (R-M05-07).
  final bool isFavorited;

  final DateTime droppedAt;

  AffixType get primaryAffixType => type.primaryStat;

  /// Elegível para venda automática ao lotar o inventário.
  /// Itens equipados são filtrados antes, na camada de inventário (V-GI-04).
  bool get isAutoSellCandidate => rarity.isAutoSellable && !isFavorited;

  /// Valor do sufixo do tipo dado, ou zero se ausente.
  GameNumber affixValue(AffixType type) {
    for (final a in affixes) {
      if (a.affixType == type) return a.value;
    }
    return GameNumber.zero;
  }

  GameItem copyWith({bool? isFavorited}) => GameItem(
    id: id,
    type: type,
    rarity: rarity,
    itemLevel: itemLevel,
    baseStat: baseStat,
    affixes: affixes,
    droppedAt: droppedAt,
    isFavorited: isFavorited ?? this.isFavorited,
  );

  @override
  bool operator ==(Object other) => other is GameItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => '${rarity.id} ${type.id} iLv$itemLevel';
}
