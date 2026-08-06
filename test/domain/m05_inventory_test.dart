import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/entities/essence.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/inventory/inventory_service.dart';
import 'package:test/test.dart';

/// M05 — Inventário e Equipamento.
/// Cenários CEN-M05-001 a 012, E01 a E03, mais a drenagem de V-INV-04.
void main() {
  final service = InventoryService();
  final now = DateTime.utc(2026, 1, 1);

  GameItem item(
    String id, {
    ItemType type = ItemType.weapon,
    ItemRarity rarity = ItemRarity.ouro,
    double baseStat = 50,
    bool favorited = false,
  }) => GameItem(
    id: id,
    type: type,
    rarity: rarity,
    itemLevel: 20,
    baseStat: GameNumber.fromDouble(baseStat),
    affixes: const [],
    droppedAt: now,
    isFavorited: favorited,
  );

  Inventory inv({
    List<GameItem> items = const [],
    List<GameItem> pending = const [],
    List<Essence> essences = const [],
  }) => Inventory(
    items: items,
    pendingDrops: pending,
    essences: essences,
    blueprints: const [],
  );

  Hero hero([String id = 'h1']) => Hero.fresh(id: id, classId: 'c');

  group('CEN-M05-001 — entrada de item', () {
    test('drop entra no inventário', () {
      final r = service.intake(item('i1'), inv(), const []);
      expect(r, isA<IntakeStored>());
      expect(r.inventory.items.single.id, 'i1');
    });

    test('a contagem de slots sobe de um em um', () {
      var inventory = inv();
      for (var i = 0; i < 10; i++) {
        inventory = service.intake(item('i$i'), inventory, const []).inventory;
      }
      expect(inventory.items, hasLength(10));
    });
  });

  group('CEN-M05-002/003/005 — equipar e desequipar', () {
    test('CEN-M05-002: equipar em slot vazio ocupa o slot', () {
      final r = service.equip(hero(), item('arma'), inv(items: [item('arma')]));
      expect(r.hero.equipment[ItemType.weapon], 'arma');
      expect(r.inventory.items, isEmpty);
      expect(r.replacedItemId, isNull);
    });

    test('CEN-M05-003: substituir devolve o anterior e mantém a contagem', () {
      final inicial = inv(items: [item('velha'), item('nova')]);
      final passo1 = service.equip(hero(), item('velha'), inicial);
      final passo2 = service.equip(passo1.hero, item('nova'), passo1.inventory);

      expect(passo2.hero.equipment[ItemType.weapon], 'nova');
      expect(passo2.replacedItemId, 'velha');
      expect(passo2.inventory.items.map((i) => i.id), ['velha']);
      expect(passo2.inventory.items, hasLength(1),
          reason: 'contagem de slots inalterada');
    });

    test('CEN-M05-005: desequipar devolve o item ao inventário', () {
      final equipado = service.equip(hero(), item('arma'), inv());
      final r = service.unequip(
        equipado.hero,
        ItemType.weapon,
        equipado.inventory,
        item('arma'),
      );
      expect(r.hero.equipment[ItemType.weapon], isNull);
      expect(r.inventory.items.single.id, 'arma');
    });

    test('desequipar slot vazio não faz nada', () {
      final r = service.unequip(hero(), ItemType.ring, inv(), null);
      expect(r.inventory.items, isEmpty);
    });
  });

  group('CEN-M05-007/008/009/010 — venda automática', () {
    List<GameItem> lotar({required ItemRarity rarity, int quantidade = 50}) => [
      for (var i = 0; i < quantidade; i++) item('i$i', rarity: rarity),
    ];

    test('CEN-M05-007: a 50 slots, bronze e prata são vendidos', () {
      final cheio = inv(items: lotar(rarity: ItemRarity.prata));
      final r = service.intake(item('novo'), cheio, const []);

      expect(r, isA<IntakeAutoSold>());
      final vendido = r as IntakeAutoSold;
      expect(vendido.soldItems, isNotEmpty);
      expect(vendido.goldGained > GameNumber.zero, isTrue);
      expect(r.inventory.items.map((i) => i.id), contains('novo'));
      expect(r.inventory.items.length, lessThanOrEqualTo(Inventory.capacity));
    });

    test('CEN-M05-008: itens épicos não são vendidos', () {
      final cheio = inv(
        items: [
          ...lotar(rarity: ItemRarity.prata, quantidade: 45),
          for (var i = 0; i < 5; i++)
            item('epico$i', rarity: ItemRarity.epico),
        ],
      );
      final r = service.intake(item('novo'), cheio, const []) as IntakeAutoSold;

      expect(
        r.soldItems.every((i) => i.rarity.isAutoSellable),
        isTrue,
        reason: 'vendeu algo acima de prata',
      );
      expect(
        r.inventory.items.where((i) => i.rarity == ItemRarity.epico),
        hasLength(5),
      );
    });

    test('CEN-M05-009: favorito é protegido', () {
      final cheio = inv(
        items: [
          ...lotar(rarity: ItemRarity.prata, quantidade: 49),
          item('querido', rarity: ItemRarity.prata, favorited: true),
        ],
      );
      final r = service.intake(item('novo'), cheio, const []);

      expect(r.inventory.items.map((i) => i.id), contains('querido'));
    });

    test('CEN-M05-010: item equipado nunca é vendido', () {
      // Itens equipados nem chegam ao inventário — a lista de equipados é
      // passada à parte justamente para que a auto-venda não os alcance.
      final cheio = inv(items: lotar(rarity: ItemRarity.bronze));
      final r = service.intake(item('novo'), cheio, [item('equipada')]);

      expect(
        (r as IntakeAutoSold).soldItems.map((i) => i.id),
        isNot(contains('equipada')),
      );
    });
  });

  group('CEN-M05-011/012 — venda manual e um item por slot', () {
    test('CEN-M05-011: venda manual remove e concede ouro', () {
      final r = service.sell(item('i1'), inv(items: [item('i1')]));
      expect(r.inventory.items, isEmpty);
      expect(r.goldGained > GameNumber.zero, isTrue);
    });

    test('o valor de venda cresce com raridade e item level', () {
      final bronze = service.sell(
        item('a', rarity: ItemRarity.bronze),
        inv(items: [item('a', rarity: ItemRarity.bronze)]),
      );
      final lendario = service.sell(
        item('b', rarity: ItemRarity.lendario),
        inv(items: [item('b', rarity: ItemRarity.lendario)]),
      );
      expect(lendario.goldGained > bronze.goldGained, isTrue);
    });

    test('CEN-M05-012: segundo anel devolve o primeiro', () {
      final a = item('anel1', type: ItemType.ring);
      final b = item('anel2', type: ItemType.ring);
      final passo1 = service.equip(hero(), a, inv(items: [a, b]));
      final passo2 = service.equip(passo1.hero, b, passo1.inventory);

      expect(passo2.hero.equipment[ItemType.ring], 'anel2');
      expect(passo2.replacedItemId, 'anel1');
      expect(
        passo2.hero.equipment.values.where((v) => v != null),
        hasLength(1),
      );
    });
  });

  group('CEN-M05-E01 e V-INV-03/04 — lotação e drenagem', () {
    test('CEN-M05-E01: sem candidatos, o drop é retido, não descartado', () {
      final cheio = inv(
        items: [
          for (var i = 0; i < 50; i++) item('i$i', rarity: ItemRarity.epico),
        ],
      );
      final r = service.intake(item('novo'), cheio, const []);

      expect(r, isA<IntakePending>());
      expect(r.inventory.pendingDrops.single.id, 'novo');
      expect(r.inventory.items, hasLength(50), reason: 'nada foi perdido');
    });

    test('V-INV-04: liberar espaço drena o pendente', () {
      final cheio = inv(
        items: [
          for (var i = 0; i < 50; i++) item('i$i', rarity: ItemRarity.epico),
        ],
        pending: [item('retido')],
      );

      final aposVenda = service.sell(item('i0'), cheio);

      expect(aposVenda.inventory.pendingDrops, isEmpty,
          reason: 'o retido deveria ter entrado');
      expect(
        aposVenda.inventory.items.map((i) => i.id),
        contains('retido'),
      );
    });

    test('equipar também drena o pendente', () {
      final cheio = inv(
        items: [
          for (var i = 0; i < 50; i++) item('i$i', rarity: ItemRarity.epico),
        ],
        pending: [item('retido')],
      );
      final r = service.equip(hero(), item('i0'), cheio);

      expect(r.inventory.pendingDrops, isEmpty);
      expect(r.inventory.items.map((i) => i.id), contains('retido'));
    });

    test('sem espaço, o pendente permanece pendente', () {
      final cheio = inv(
        items: [
          for (var i = 0; i < 50; i++) item('i$i', rarity: ItemRarity.epico),
        ],
        pending: [item('retido')],
      );
      final r = service.drainPending(cheio);
      expect(r.pendingDrops, hasLength(1));
    });
  });

  group('CEN-M05-E02 — transferência entre heróis', () {
    test('equipar item de outro herói o transfere', () {
      final a = service.equip(hero('A'), item('arma'), inv());
      final b = service.equipFrom(
        from: a.hero,
        to: hero('B'),
        item: item('arma'),
        inventory: a.inventory,
      );

      expect(b.from.equipment[ItemType.weapon], isNull);
      expect(b.to.equipment[ItemType.weapon], 'arma');
    });
  });

  group('V-ES-01 — Essências fora do limite', () {
    Essence essencia(String id) => Essence(
      id: id,
      guaranteedAffixType: AffixType.critChance,
      droppedAt: now,
    );

    test('Essência entra mesmo com inventário cheio', () {
      final cheio = inv(
        items: [
          for (var i = 0; i < 50; i++) item('i$i', rarity: ItemRarity.epico),
        ],
      );
      final r = service.intakeEssence(essencia('e1'), cheio);

      expect(r.essences.single.id, 'e1');
      expect(r.items, hasLength(50), reason: 'não consumiu slot de item');
    });

    test('Essências não contam para a capacidade', () {
      var inventory = inv();
      for (var i = 0; i < 100; i++) {
        inventory = service.intakeEssence(essencia('e$i'), inventory);
      }
      expect(inventory.essences, hasLength(100));
      expect(inventory.isFull, isFalse);
    });
  });

  group('CEN-M05-006 — favoritar', () {
    test('favoritar marca o item e protege da auto-venda', () {
      final marcado = service.toggleFavorite(
        item('i1', rarity: ItemRarity.bronze),
        inv(items: [item('i1', rarity: ItemRarity.bronze)]),
      );
      expect(marcado.items.single.isFavorited, isTrue);
      expect(marcado.items.single.isAutoSellCandidate, isFalse);
    });

    test('desfavoritar volta a expor à auto-venda', () {
      final protegido = inv(
        items: [item('i1', rarity: ItemRarity.bronze, favorited: true)],
      );
      final r = service.toggleFavorite(protegido.items.single, protegido);
      expect(r.items.single.isFavorited, isFalse);
      expect(r.items.single.isAutoSellCandidate, isTrue);
    });
  });
}
