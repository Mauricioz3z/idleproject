import '../../core/constants/game_enums.dart';
import '../../core/rng/rng_stream.dart';
import '../entities/essence.dart';
import '../entities/game_item.dart';
import '../entities/inventory.dart';
import '../inventory/inventory_service.dart';
import 'loot_generator.dart';

/// Por que uma fusão foi recusada (contrato de domínio).
enum FusionRejection {
  notThreeItems,
  mixedRarities,
  maxRarity,
  itemEquipped,
  materialNotInInventory,

  /// O Cubo ainda está em descanso depois da fusão anterior. Recusa de
  /// **cadência**, não de validade: os materiais continuam bons, é só cedo
  /// demais (ver `CubeController.fusionCooldown`).
  cubeResting,
}

/// Resultado de uma fusão. Recusa **também** devolve o inventário, intacto:
/// quem chama não precisa lembrar de preservar o estado anterior (SC-M06-01).
sealed class FusionResult {
  const FusionResult(this.inventory);
  final Inventory inventory;
}

class FusionSuccess extends FusionResult {
  const FusionSuccess(
    super.inventory, {
    required this.item,
    required this.recreatedBlueprint,
  });

  final GameItem item;

  /// Verdadeiro quando o molde foi reproduzido (CEN-M06-008).
  final bool recreatedBlueprint;
}

class FusionRejected extends FusionResult {
  const FusionRejected(super.inventory, this.reason);
  final FusionRejection reason;
}

/// O que o jogador vê **antes** de confirmar (R-M06-09, SC-M06-03).
class FusionPreview {
  const FusionPreview({
    required this.isValid,
    required this.resultingRarity,
    required this.recreationChance,
    required this.rejection,
    required this.consumesEssence,
  });

  final bool isValid;
  final ItemRarity? resultingRarity;

  /// Probabilidade de recriar o molde, em `[0,1]`. Zero sem molde.
  final double recreationChance;

  final FusionRejection? rejection;
  final bool consumesEssence;
}

/// Cubo de crafting (M06).
///
/// Duas propriedades sustentam quase tudo aqui:
///
/// - **Atômica**: [fuse] devolve um inventário novo já com os 3 materiais fora e
///   o resultado dentro. Não existe estado intermediário para o app ser
///   encerrado no meio (CEN-M06-E03) — o save grava o valor inteiro ou nenhum.
/// - **O sorteio acontece na confirmação**, nunca no [preview]. É o que permite
///   acelerar a operação com gemas sem alterar o resultado (V-ENT-04): não há
///   resultado sorteado esperando para ser revelado.
class CubeService {
  const CubeService({
    this.loot = const LootGenerator(),
    this.inventoryService,
  });

  final LootGenerator loot;

  /// Injetável para reaproveitar o catálogo de equipados do jogo; nulo cria um
  /// serviço local, suficiente porque a fusão não mexe em equipamento.
  final InventoryService? inventoryService;

  static const int materialsRequired = 3;

  /// Chance base de o molde ser reproduzido.
  ///
  /// Probabilística, não garantida: o documento de origem fala em "tentar
  /// recriar" (R-M06-07). Cada sufixo pedido pelo molde reduz a chance, senão
  /// um molde de três sufixos valeria o mesmo que um de um.
  static const double blueprintBaseChance = 0.45;
  static const double blueprintPenaltyPerAffix = 0.10;

  /// Avalia a fusão sem consumir nada — nem itens, nem RNG.
  FusionPreview preview({
    required List<GameItem> materials,
    Essence? essence,
    CubeBlueprint? blueprint,
    Set<String> equippedItemIds = const {},
  }) {
    final rejection = _validate(materials, equippedItemIds);
    if (rejection != null) {
      return FusionPreview(
        isValid: false,
        resultingRarity: null,
        recreationChance: 0,
        rejection: rejection,
        consumesEssence: essence != null,
      );
    }

    return FusionPreview(
      isValid: true,
      resultingRarity: materials.first.rarity.next,
      recreationChance: blueprint == null ? 0 : _chanceFor(blueprint),
      rejection: null,
      consumesEssence: essence != null,
    );
  }

  /// Executa a fusão. Só aqui o RNG é consumido.
  FusionResult fuse({
    required List<GameItem> materials,
    required Inventory inventory,
    required RngStream rng,
    required DateTime now,
    Essence? essence,
    CubeBlueprint? blueprint,
    Set<String> equippedItemIds = const {},
  }) {
    final rejection = _validate(materials, equippedItemIds);
    if (rejection != null) return FusionRejected(inventory, rejection);

    final rarity = materials.first.rarity.next!;
    final consumedIds = materials.map((m) => m.id).toSet();

    // Ordem deliberada dos sorteios: recriação, tipo, e só então o item. Mudar
    // a ordem mudaria todo o resultado para uma mesma semente.
    final recreated =
        blueprint != null && rng.chance(_chanceFor(blueprint));

    final type = recreated
        ? blueprint.type
        : ItemType.values[rng.nextInt(ItemType.values.length)];

    // R-M06-04: a Essência tem precedência sobre o molde no sufixo garantido —
    // ela é o recurso raro, e foi consumida de qualquer forma (R-M06-05).
    final guaranteed = essence?.guaranteedAffixType ??
        (recreated && blueprint.targetAffixTypes.isNotEmpty
            ? blueprint.targetAffixTypes.first
            : null);

    final item = loot.generate(
      type: type,
      rarity: rarity,
      // O melhor material define o nível do resultado. A fórmula não consta do
      // documento de origem (suposição de M06); a média puniria quem fundisse
      // um item bom com dois de reposição, que é o uso natural do Cubo.
      itemLevel: materials
          .map((m) => m.itemLevel)
          .reduce((a, b) => a > b ? a : b),
      rng: rng,
      now: now,
      guaranteedAffix: guaranteed,
    );

    final service = inventoryService ?? InventoryService();
    var next = inventory.copyWith(
      items: [
        for (final i in inventory.items)
          if (!consumedIds.contains(i.id)) i,
        item,
      ],
      // V-ES-02: consumida independentemente do resultado.
      essences: essence == null
          ? inventory.essences
          : [
              for (final e in inventory.essences)
                if (e.id != essence.id) e,
            ],
    );

    // V-INV-04: a fusão libera dois slots líquidos, então a drenagem é
    // avaliada aqui como em qualquer mudança de ocupação.
    next = service.drainPending(next);

    return FusionSuccess(next, item: item, recreatedBlueprint: recreated);
  }

  /// Salva um item como molde (R-M06-06).
  ///
  /// Cópia dos atributos, não referência viva: o molde sobrevive à venda do
  /// item de origem (V-CB-01, CEN-M05-E03).
  CubeBlueprint imprint(GameItem source) => CubeBlueprint(
    id: 'bp_${source.id}',
    sourceItemId: source.id,
    type: source.type,
    targetAffixTypes: [for (final a in source.affixes) a.affixType],
  );

  double _chanceFor(CubeBlueprint blueprint) {
    final chance =
        blueprintBaseChance -
        blueprintPenaltyPerAffix * blueprint.targetAffixTypes.length;
    return chance < 0.05 ? 0.05 : chance;
  }

  FusionRejection? _validate(
    List<GameItem> materials,
    Set<String> equippedItemIds,
  ) {
    if (materials.length != materialsRequired) {
      return FusionRejection.notThreeItems;
    }
    if (materials.any((m) => equippedItemIds.contains(m.id))) {
      // R-M06-08: item em uso não é material. Recusar é melhor que desequipar
      // por conta própria — o jogador perderia atributos sem pedir.
      return FusionRejection.itemEquipped;
    }
    final rarity = materials.first.rarity;
    if (materials.any((m) => m.rarity != rarity)) {
      return FusionRejection.mixedRarities;
    }
    if (rarity.isMax) return FusionRejection.maxRarity;
    return null;
  }
}
