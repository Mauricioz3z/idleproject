import '../../core/constants/game_enums.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/hero.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/save_state.dart';

/// Uma correção aplicada na carga do save.
///
/// Toda correção é registrada. Correção silenciosa em massa é sinal de bug de
/// gravação e precisa ser visível — por isso isto não é `void`.
class SaveRepair {
  const SaveRepair(this.rule, this.detail);

  /// Identificador da invariante: `D-01` a `D-07`.
  final String rule;
  final String detail;

  @override
  String toString() => '$rule: $detail';
}

class ValidatedSave {
  const ValidatedSave(this.state, this.repairs);

  final SaveState state;
  final List<SaveRepair> repairs;

  bool get isClean => repairs.isEmpty;
}

/// Verifica e conserta o estado carregado **antes** que ele alcance o domínio,
/// conforme contracts/persistence-save-schema.md.
///
/// A filosofia aqui é reparar em vez de rejeitar: um save levemente
/// inconsistente não deve custar o progresso do jogador. Mas todo reparo é
/// reportado, para que o bug de origem apareça em analytics.
abstract final class SaveValidator {
  static ValidatedSave validate(SaveState raw, {Set<String>? knownRuneNodeIds}) {
    final repairs = <SaveRepair>[];

    var heroes = raw.heroes;
    var equipped = raw.equippedItems;
    var inventory = raw.inventory;
    var account = raw.account;

    // D-01: nenhum ID de item em mais de um lugar.
    final seenIds = <String>{};
    final duplicated = <String>{};
    for (final id in [
      ...equipped.map((i) => i.id),
      ...inventory.items.map((i) => i.id),
      ...inventory.pendingDrops.map((i) => i.id),
    ]) {
      if (!seenIds.add(id)) duplicated.add(id);
    }
    if (duplicated.isNotEmpty) {
      // O equipado vence: é o que o jogador vê em uso.
      final equippedIds = equipped.map((i) => i.id).toSet();
      inventory = inventory.copyWith(
        items: inventory.items
            .where((i) => !equippedIds.contains(i.id))
            .toList(),
        pendingDrops: inventory.pendingDrops
            .where((i) => !equippedIds.contains(i.id))
            .toList(),
      );
      inventory = inventory.copyWith(items: _dedupe(inventory.items));
      repairs.add(
        SaveRepair('D-01', 'IDs duplicados removidos: ${duplicated.join(", ")}'),
      );
    }

    // D-02: referência de equipamento órfã vira null.
    final equippedById = {for (final i in equipped) i.id: i};
    heroes = [
      for (final hero in heroes) _repairHeroEquipment(hero, equippedById, repairs),
    ];

    // Item em equippedItems que nenhum herói referencia volta ao inventário —
    // perder o item seria pior do que ocupar um slot.
    final referenced = heroes.expand((h) => h.equippedItemIds).toSet();
    final orphanEquipped = equipped
        .where((i) => !referenced.contains(i.id))
        .toList();
    if (orphanEquipped.isNotEmpty) {
      equipped = equipped.where((i) => referenced.contains(i.id)).toList();
      inventory = inventory.copyWith(
        items: [...inventory.items, ...orphanEquipped],
      );
      repairs.add(
        SaveRepair(
          'D-02',
          '${orphanEquipped.length} item(ns) equipado(s) sem dono devolvido(s) ao inventário',
        ),
      );
    }

    // D-04: formationIndex único e dentro do limite de slots.
    final result = _repairFormation(heroes, account.formationSlots, repairs);
    heroes = result;

    // D-05: excedente do limite de 50 vai para pendingDrops, nunca truncado.
    if (inventory.items.length > Inventory.capacity) {
      final overflow = inventory.items.sublist(Inventory.capacity);
      inventory = inventory.copyWith(
        items: inventory.items.sublist(0, Inventory.capacity),
        pendingDrops: [...inventory.pendingDrops, ...overflow],
      );
      repairs.add(
        SaveRepair('D-05', '${overflow.length} item(ns) movido(s) para pendentes'),
      );
    }

    // D-06: ID de runa desconhecido é descartado e o ponto devolvido.
    if (knownRuneNodeIds != null) {
      final unknown = account.unlockedRuneNodeIds
          .where((id) => !knownRuneNodeIds.contains(id))
          .toSet();
      if (unknown.isNotEmpty) {
        account = account.copyWith(
          unlockedRuneNodeIds: account.unlockedRuneNodeIds
              .where(knownRuneNodeIds.contains)
              .toSet(),
          runePoints: account.runePoints + unknown.length,
        );
        repairs.add(
          SaveRepair(
            'D-06',
            '${unknown.length} nó(s) de runa desconhecido(s); pontos devolvidos',
          ),
        );
      }
    }

    // D-03 e D-07 já são aplicados na desserialização, em SaveCodec.

    return ValidatedSave(
      raw.copyWith(
        account: account,
        heroes: heroes,
        equippedItems: equipped,
        inventory: inventory,
      ),
      repairs,
    );
  }

  static List<GameItem> _dedupe(List<GameItem> items) {
    final seen = <String>{};
    return items.where((i) => seen.add(i.id)).toList();
  }

  static Hero _repairHeroEquipment(
    Hero hero,
    Map<String, GameItem> equippedById,
    List<SaveRepair> repairs,
  ) {
    final cleaned = <ItemType, String?>{};
    var changed = false;
    for (final entry in hero.equipment.entries) {
      final id = entry.value;
      if (id != null && !equippedById.containsKey(id)) {
        cleaned[entry.key] = null;
        changed = true;
      } else {
        cleaned[entry.key] = id;
      }
    }
    if (!changed) return hero;
    repairs.add(
      SaveRepair('D-02', 'herói ${hero.id}: referência de item órfã limpa'),
    );
    return hero.copyWith(equipment: cleaned);
  }

  static List<Hero> _repairFormation(
    List<Hero> heroes,
    int formationSlots,
    List<SaveRepair> repairs,
  ) {
    final used = <int>{};
    return [
      for (final hero in heroes)
        if (hero.formationIndex == null)
          hero
        else if (hero.formationIndex! >= formationSlots ||
            hero.formationIndex! < 0 ||
            !used.add(hero.formationIndex!))
          () {
            repairs.add(
              SaveRepair(
                'D-04',
                'herói ${hero.id}: índice de formação inválido ou repetido',
              ),
            );
            return hero.copyWith(clearFormationIndex: true);
          }()
        else
          hero,
    ];
  }
}
