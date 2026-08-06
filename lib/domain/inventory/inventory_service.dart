import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../entities/essence.dart';
import '../entities/game_item.dart';
import '../entities/hero.dart';
import '../entities/inventory.dart';

/// Resultado de equipar um item.
class EquipResult {
  const EquipResult({
    required this.hero,
    required this.inventory,
    required this.replacedItemId,
  });

  final Hero hero;
  final Inventory inventory;

  /// Item que estava no slot e voltou ao inventário, ou `null` se estava vazio
  /// (CEN-M05-003).
  final String? replacedItemId;
}

class UnequipResult {
  const UnequipResult({required this.hero, required this.inventory});

  final Hero hero;
  final Inventory inventory;
}

/// Transferência de um item equipado entre heróis (CEN-M05-E02).
class TransferResult {
  const TransferResult({
    required this.from,
    required this.to,
    required this.inventory,
    required this.replacedItemId,
  });

  final Hero from;
  final Hero to;
  final Inventory inventory;
  final String? replacedItemId;
}

class SellResult {
  const SellResult({required this.inventory, required this.goldGained});

  final Inventory inventory;
  final GameNumber goldGained;
}

/// Resultado da entrada de um drop no inventário.
sealed class IntakeResult {
  const IntakeResult(this.inventory);
  final Inventory inventory;
}

/// Havia espaço: o item entrou direto.
class IntakeStored extends IntakeResult {
  const IntakeStored(super.inventory);
}

/// O inventário estava cheio e a venda automática abriu espaço (R-M05-06).
class IntakeAutoSold extends IntakeResult {
  const IntakeAutoSold(
    super.inventory, {
    required this.soldItems,
    required this.goldGained,
  });

  final List<GameItem> soldItems;
  final GameNumber goldGained;
}

/// Cheio e sem candidatos à venda: o item fica retido, **nunca** descartado
/// (V-INV-03, CEN-M05-E01, CEN-M04-E02).
class IntakePending extends IntakeResult {
  const IntakePending(super.inventory);
}

/// Operações de inventário e equipamento (M05).
///
/// Guarda um catálogo dos itens equipados por ID. A assinatura de
/// [equip] em contracts/domain-services.md não recebe o item que estava no slot,
/// mas CEN-M05-003 exige que ele volte ao inventário como objeto completo — e o
/// herói guarda apenas o ID (V-H-02). O catálogo é essa resolução `id → item`.
/// Quem carrega um save precisa semeá-lo com `registerEquipped`, senão o
/// primeiro item substituído após a reabertura se perderia.
class InventoryService {
  InventoryService({Iterable<GameItem> equipped = const []}) {
    for (final item in equipped) {
      _equipped[item.id] = item;
    }
  }

  final Map<String, GameItem> _equipped = {};

  /// Ouro por ponto de item level, antes do multiplicador de raridade.
  static const double goldPerItemLevel = 2.0;
  static const double goldBase = 10.0;

  /// Cada degrau de raridade dobra o valor de venda.
  static const double rarityValueMultiplier = 2.0;

  /// Semeia o catálogo a partir do save (`equippedItems` do contrato de
  /// persistência).
  void registerEquipped(Iterable<GameItem> items) {
    for (final item in items) {
      _equipped[item.id] = item;
    }
  }

  /// Itens atualmente equipados que o serviço conhece.
  Iterable<GameItem> get equippedItems => _equipped.values;

  GameItem? equippedById(String id) => _equipped[id];

  // ------------------------------------------------------------------ equipar

  /// Equipa [item] no slot correspondente ao seu tipo.
  ///
  /// O item sai do inventário, o que estava no slot volta para ele, e a
  /// contagem de slots ocupados não muda (CEN-M05-003, CEN-M05-012).
  EquipResult equip(Hero hero, GameItem item, Inventory inventory) {
    final (nextHero, replacedId) = hero.equipItem(item.type, item.id);
    _equipped[item.id] = item;

    final items = inventory.items.where((i) => i.id != item.id).toList();
    if (replacedId != null) {
      final replaced = _equipped.remove(replacedId);
      if (replaced != null) items.add(replaced);
    }

    // V-INV-04: equipar libera ocupação, então a drenagem é avaliada aqui e não
    // só no próximo drop — do contrário um item retido ficaria preso.
    return EquipResult(
      hero: nextHero,
      inventory: drainPending(inventory.copyWith(items: items)),
      replacedItemId: replacedId,
    );
  }

  /// Desequipa o slot, devolvendo o item ao inventário.
  ///
  /// [item] é o objeto correspondente ao ID guardado no herói; passar `null`
  /// para um slot vazio é operação legítima e não faz nada.
  UnequipResult unequip(
    Hero hero,
    ItemType slot,
    Inventory inventory,
    GameItem? item,
  ) {
    final (nextHero, removedId) = hero.unequipSlot(slot);
    if (removedId == null) {
      return UnequipResult(hero: hero, inventory: inventory);
    }

    final resolved = item ?? _equipped[removedId];
    _equipped.remove(removedId);
    if (resolved == null) {
      return UnequipResult(hero: nextHero, inventory: inventory);
    }

    // Sem espaço, o item volta como pendente em vez de estourar a capacidade
    // (V-INV-01) ou sumir (V-INV-03).
    if (inventory.isFull) {
      return UnequipResult(
        hero: nextHero,
        inventory: inventory.copyWith(
          pendingDrops: [...inventory.pendingDrops, resolved],
        ),
      );
    }

    return UnequipResult(
      hero: nextHero,
      inventory: inventory.copyWith(items: [...inventory.items, resolved]),
    );
  }

  /// Move um item equipado do herói [from] para o herói [to] (V-H-03,
  /// CEN-M05-E02). Os dois heróis voltam recalculados.
  TransferResult equipFrom({
    required Hero from,
    required Hero to,
    required GameItem item,
    required Inventory inventory,
  }) {
    final (strippedFrom, _) = from.unequipSlot(item.type);
    final result = equip(to, item, inventory);
    return TransferResult(
      from: strippedFrom,
      to: result.hero,
      inventory: result.inventory,
      replacedItemId: result.replacedItemId,
    );
  }

  // ------------------------------------------------------------------- entrada

  /// Entrada automática de um drop (R-M04-09).
  ///
  /// [equippedItems] é passado à parte justamente para que a venda automática
  /// nunca alcance o que está em uso (R-M05-05, CEN-M05-010).
  IntakeResult intake(
    GameItem dropped,
    Inventory inventory,
    List<GameItem> equippedItems,
  ) {
    if (!inventory.isFull) {
      return IntakeStored(
        drainPending(
          inventory.copyWith(items: [...inventory.items, dropped]),
        ),
      );
    }

    final equippedIds = equippedItems.map((i) => i.id).toSet();
    final sold = inventory.items
        .where((i) => i.isAutoSellCandidate && !equippedIds.contains(i.id))
        .toList();

    if (sold.isEmpty) {
      // CEN-M05-E01: nada elegível. O drop é retido e o jogador é notificado
      // pela camada de apresentação; descartar em silêncio é o único desfecho
      // proibido.
      return IntakePending(
        inventory.copyWith(
          pendingDrops: [...inventory.pendingDrops, dropped],
        ),
      );
    }

    final soldIds = sold.map((i) => i.id).toSet();
    var gold = GameNumber.zero;
    for (final item in sold) {
      gold = gold + sellValue(item);
    }

    final remaining = inventory.items
        .where((i) => !soldIds.contains(i.id))
        .toList()
      ..add(dropped);

    return IntakeAutoSold(
      drainPending(inventory.copyWith(items: remaining)),
      soldItems: sold,
      goldGained: gold,
    );
  }

  /// Essências não ocupam slot e por isso nunca são retidas (V-ES-01).
  Inventory intakeEssence(Essence essence, Inventory inventory) =>
      inventory.copyWith(essences: [...inventory.essences, essence]);

  /// Devolve itens retidos ao inventário enquanto houver espaço (V-INV-04).
  ///
  /// Chamado por toda operação que muda a ocupação — equipar, vender, auto-venda
  /// e consumo no Cubo. Amarrá-lo só ao próximo drop prenderia um item retido
  /// indefinidamente num inventário que o jogador acabou de esvaziar.
  Inventory drainPending(Inventory inventory) {
    if (inventory.pendingDrops.isEmpty || inventory.isFull) return inventory;

    final items = [...inventory.items];
    final pending = [...inventory.pendingDrops];
    while (pending.isNotEmpty && items.length < Inventory.capacity) {
      items.add(pending.removeAt(0));
    }
    return inventory.copyWith(items: items, pendingDrops: pending);
  }

  // -------------------------------------------------------------------- venda

  /// Venda manual (R-M05-08, CEN-M05-011).
  SellResult sell(GameItem item, Inventory inventory) {
    final remaining = inventory.items.where((i) => i.id != item.id).toList();
    return SellResult(
      inventory: drainPending(inventory.copyWith(items: remaining)),
      goldGained: sellValue(item),
    );
  }

  /// Valor de venda: cresce com item level e dobra a cada degrau de raridade.
  ///
  /// A fórmula não consta do documento de origem (suposição registrada em M05);
  /// o que importa para o jogo é a ordem, não a constante.
  GameNumber sellValue(GameItem item) {
    var value = goldBase + goldPerItemLevel * item.itemLevel;
    for (var i = 0; i < item.rarity.index; i++) {
      value *= rarityValueMultiplier;
    }
    return GameNumber.fromDouble(value);
  }

  /// Marca ou desmarca o item como favorito (R-M05-07).
  ///
  /// Favoritar é a única proteção do jogador contra a venda automática, então
  /// vale também para itens que já estão no inventário há tempo — não só para
  /// os recém-dropados.
  Inventory toggleFavorite(GameItem item, Inventory inventory) => inventory
      .copyWith(
        items: [
          for (final i in inventory.items)
            if (i.id == item.id) i.copyWith(isFavorited: !i.isFavorited) else i,
        ],
      );
}
