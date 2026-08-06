import '../../core/constants/game_enums.dart';
import 'essence.dart';
import 'game_item.dart';

/// Molde salvo pela função "Imprimir" (R-M06-06).
///
/// É cópia dos atributos, não referência viva: sobrevive à venda do item de
/// origem (V-CB-01, CEN-M05-E03).
class CubeBlueprint {
  const CubeBlueprint({
    required this.id,
    required this.sourceItemId,
    required this.type,
    required this.targetAffixTypes,
  });

  final String id;

  /// Referência histórica: pode apontar para um item já vendido.
  final String sourceItemId;

  final ItemType type;
  final List<AffixType> targetAffixTypes;

  @override
  bool operator ==(Object other) => other is CubeBlueprint && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Agregado de inventário (M05).
///
/// Só contém itens **não equipados** — equipamentos vivem dentro do herói e
/// não contam para o limite de 50 slots (V-GI-04, R-M05-05).
class Inventory {
  Inventory({
    required List<GameItem> items,
    required List<GameItem> pendingDrops,
    required List<Essence> essences,
    required List<CubeBlueprint> blueprints,
  }) : items = List.unmodifiable(items),
       pendingDrops = List.unmodifiable(pendingDrops),
       essences = List.unmodifiable(essences),
       blueprints = List.unmodifiable(blueprints);

  factory Inventory.empty() => Inventory(
    items: const [],
    pendingDrops: const [],
    essences: const [],
    blueprints: const [],
  );

  /// Capacidade máxima (R-M05-01).
  static const int capacity = 50;

  final List<GameItem> items;

  /// Drops retidos por inventário cheio. Nunca descartados (V-INV-03).
  final List<GameItem> pendingDrops;

  /// Essências ficam **fora** do limite de 50 slots (V-ES-01).
  final List<Essence> essences;

  final List<CubeBlueprint> blueprints;

  bool get isFull => items.length >= capacity;
  int get freeSlots => capacity - items.length;
  bool get hasPending => pendingDrops.isNotEmpty;

  /// Itens que a venda automática pode consumir: bronze/prata, não favoritados.
  /// Itens equipados nunca chegam aqui, por construção (R-M05-06).
  List<GameItem> get autoSellCandidates =>
      items.where((i) => i.isAutoSellCandidate).toList();

  Inventory copyWith({
    List<GameItem>? items,
    List<GameItem>? pendingDrops,
    List<Essence>? essences,
    List<CubeBlueprint>? blueprints,
  }) => Inventory(
    items: items ?? this.items,
    pendingDrops: pendingDrops ?? this.pendingDrops,
    essences: essences ?? this.essences,
    blueprints: blueprints ?? this.blueprints,
  );
}
