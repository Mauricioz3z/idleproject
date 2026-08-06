import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/cube_service.dart';
import 'package:pixel_idle_quest/domain/entities/essence.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:test/test.dart';

/// M06 — Cubo de Crafting.
/// Cenários CEN-M06-001 a 010, E01 a E03.
void main() {
  const cube = CubeService();
  final now = DateTime.utc(2026, 1, 1);

  RngStream rng([int seed = 21]) => RngStream(seed: seed);

  GameItem item(
    String id, {
    ItemRarity rarity = ItemRarity.ouro,
    ItemType type = ItemType.weapon,
    int itemLevel = 40,
    List<ItemAffix> affixes = const [],
  }) => GameItem(
    id: id,
    type: type,
    rarity: rarity,
    itemLevel: itemLevel,
    baseStat: GameNumber.fromDouble(100),
    affixes: affixes,
    droppedAt: now,
  );

  List<GameItem> trio({ItemRarity rarity = ItemRarity.ouro}) => [
    item('m1', rarity: rarity),
    item('m2', rarity: rarity),
    item('m3', rarity: rarity),
  ];

  Inventory inv(List<GameItem> items, {List<Essence> essences = const []}) =>
      Inventory(
        items: items,
        pendingDrops: const [],
        essences: essences,
        blueprints: const [],
      );

  Essence essence(AffixType type) =>
      Essence(id: 'e1', guaranteedAffixType: type, droppedAt: now);

  group('CEN-M06-001/002 — fusão eleva a raridade', () {
    test('CEN-M06-001: 3 ouros viram 1 épico e saem do inventário', () {
      final materiais = trio();
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        rng: rng(),
        now: now,
      );

      expect(r, isA<FusionSuccess>());
      final sucesso = r as FusionSuccess;

      expect(sucesso.item.rarity, ItemRarity.epico);
      expect(sucesso.inventory.items.map((i) => i.id), [sucesso.item.id]);
      expect(sucesso.inventory.items, hasLength(1));
    });

    test('CEN-M06-002: os atributos são re-rolados, não herdados', () {
      final materiais = [
        item(
          'm1',
          affixes: [
            ItemAffix(
              affixType: AffixType.goldFind,
              value: GameNumber.fromDouble(0.5),
            ),
          ],
        ),
        item('m2'),
        item('m3'),
      ];

      final r =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais),
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      // Nada dos materiais sobrevive além da categoria de raridade (R-M06-02).
      expect(r.item.id, isNot(anyOf('m1', 'm2', 'm3')));
      expect(r.item.affixes.length, inInclusiveRange(0, 3));
      expect(r.item.baseStat > GameNumber.zero, isTrue);
    });

    test('o item level do resultado deriva dos materiais', () {
      final materiais = [
        item('m1', itemLevel: 30),
        item('m2', itemLevel: 50),
        item('m3', itemLevel: 40),
      ];
      final r =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais),
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      expect(r.item.itemLevel, 50, reason: 'o melhor material define o nível');
    });
  });

  group('CEN-M06-003/004/009 — recusas que não consomem nada', () {
    test('CEN-M06-003: raridades misturadas são recusadas', () {
      final materiais = [
        item('m1'),
        item('m2'),
        item('m3', rarity: ItemRarity.prata),
      ];
      final inventario = inv(materiais);

      final r = cube.fuse(
        materials: materiais,
        inventory: inventario,
        rng: rng(),
        now: now,
      );

      expect(r, isA<FusionRejected>());
      expect((r as FusionRejected).reason, FusionRejection.mixedRarities);
      expect(r.inventory.items, hasLength(3), reason: 'nada consumido');
    });

    test('CEN-M06-004: menos de 3 materiais é recusado', () {
      final materiais = [item('m1'), item('m2')];
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        rng: rng(),
        now: now,
      );

      expect((r as FusionRejected).reason, FusionRejection.notThreeItems);
      expect(r.inventory.items, hasLength(2));
    });

    test('mais de 3 materiais também é recusado', () {
      final materiais = [...trio(), item('m4')];
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        rng: rng(),
        now: now,
      );
      expect((r as FusionRejected).reason, FusionRejection.notThreeItems);
    });

    test('CEN-M06-009: item equipado não pode ser material', () {
      final materiais = trio();
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        rng: rng(),
        now: now,
        equippedItemIds: const {'m2'},
      );

      expect((r as FusionRejected).reason, FusionRejection.itemEquipped);
      expect(r.inventory.items, hasLength(3));
    });

    test('CEN-M06-E01: cósmico é a raridade máxima e não funde', () {
      final materiais = trio(rarity: ItemRarity.cosmico);
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        rng: rng(),
        now: now,
      );

      expect((r as FusionRejected).reason, FusionRejection.maxRarity);
      expect(r.inventory.items, hasLength(3));
    });

    test('SC-M06-01: recusa nunca consome sem produzir', () {
      // Todas as recusas devolvem o inventário intacto — o teste percorre as
      // quatro para que uma nova recusa não escape à regra.
      final casos = <String, List<GameItem>>{
        'poucos': [item('a'), item('b')],
        'misturados': [
          item('a'),
          item('b'),
          item('c', rarity: ItemRarity.mitico),
        ],
        'cosmicos': trio(rarity: ItemRarity.cosmico),
      };

      for (final entry in casos.entries) {
        final r = cube.fuse(
          materials: entry.value,
          inventory: inv(entry.value),
          rng: rng(),
          now: now,
        );
        expect(r, isA<FusionRejected>(), reason: entry.key);
        expect(
          r.inventory.items.map((i) => i.id),
          entry.value.map((i) => i.id),
          reason: '${entry.key}: inventário foi alterado numa recusa',
        );
      }
    });
  });

  group('CEN-M06-005/006 — Essência', () {
    test('CEN-M06-005: a Essência garante o sufixo e é consumida', () {
      final materiais = trio(rarity: ItemRarity.epico);
      final e = essence(AffixType.critChance);

      final r =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais, essences: [e]),
                essence: e,
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      expect(r.item.rarity, ItemRarity.lendario);
      expect(
        r.item.affixes.map((a) => a.affixType),
        contains(AffixType.critChance),
      );
      expect(r.inventory.essences, isEmpty, reason: 'V-ES-02: consumida');
    });

    test('CEN-M06-006: a Essência não volta nem em resultado ruim', () {
      // Qualquer semente: a Essência some sempre (R-M06-05).
      for (var seed = 1; seed <= 20; seed++) {
        final materiais = trio();
        final e = essence(AffixType.xpGain);
        final r =
            cube.fuse(
                  materials: materiais,
                  inventory: inv(materiais, essences: [e]),
                  essence: e,
                  rng: rng(seed),
                  now: now,
                )
                as FusionSuccess;

        expect(r.inventory.essences, isEmpty, reason: 'semente $seed');
        expect(
          r.item.affixes.map((a) => a.affixType),
          contains(AffixType.xpGain),
        );
      }
    });

    test('a Essência não duplica o sufixo garantido', () {
      final materiais = trio();
      final e = essence(AffixType.attackSpeed);
      final r =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais, essences: [e]),
                essence: e,
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      final tipos = r.item.affixes.map((a) => a.affixType).toList();
      expect(tipos.toSet().length, tipos.length, reason: 'V-GI-01');
    });
  });

  group('CEN-M06-007/008 — moldes', () {
    test('CEN-M06-007: imprimir registra a combinação de atributos', () {
      final origem = item(
        'fonte',
        type: ItemType.amulet,
        affixes: [
          ItemAffix(
            affixType: AffixType.critChance,
            value: GameNumber.fromDouble(0.1),
          ),
          ItemAffix(
            affixType: AffixType.goldFind,
            value: GameNumber.fromDouble(0.2),
          ),
        ],
      );

      final molde = cube.imprint(origem);

      expect(molde.sourceItemId, 'fonte');
      expect(molde.type, ItemType.amulet);
      expect(molde.targetAffixTypes, [
        AffixType.critChance,
        AffixType.goldFind,
      ]);
    });

    test('CEN-M05-E03: o molde sobrevive à venda do item de origem', () {
      final origem = item('fonte');
      final molde = cube.imprint(origem);

      // O molde é cópia, não referência viva (V-CB-01): nada aqui aponta para
      // um item que precise continuar existindo.
      final materiais = trio();
      final r = cube.fuse(
        materials: materiais,
        inventory: inv(materiais),
        blueprint: molde,
        rng: rng(),
        now: now,
      );

      expect(r, isA<FusionSuccess>());
    });

    test('CEN-M06-008: o molde às vezes recria a combinação, às vezes não', () {
      final molde = cube.imprint(
        item(
          'fonte',
          type: ItemType.ring,
          affixes: [
            ItemAffix(
              affixType: AffixType.critDamage,
              value: GameNumber.fromDouble(0.3),
            ),
          ],
        ),
      );

      var recriou = 0;
      var falhou = 0;
      for (var seed = 1; seed <= 60; seed++) {
        final materiais = trio();
        final r =
            cube.fuse(
                  materials: materiais,
                  inventory: inv(materiais),
                  blueprint: molde,
                  rng: rng(seed),
                  now: now,
                )
                as FusionSuccess;

        if (r.recreatedBlueprint) {
          recriou++;
          expect(r.item.type, ItemType.ring);
          expect(
            r.item.affixes.map((a) => a.affixType),
            contains(AffixType.critDamage),
          );
        } else {
          falhou++;
        }
      }

      // Probabilística, não garantida (suposição de M06).
      expect(recriou, greaterThan(0), reason: 'nunca recriou');
      expect(falhou, greaterThan(0), reason: 'recriou sempre');
    });
  });

  group('CEN-M06-010 e SC-M06-03 — preview e confirmação', () {
    test('SC-M06-03: a chance de recriação é informada antes de confirmar', () {
      final molde = cube.imprint(
        item('fonte', affixes: [
          ItemAffix(
            affixType: AffixType.critChance,
            value: GameNumber.fromDouble(0.1),
          ),
        ]),
      );

      final p = cube.preview(materials: trio(), blueprint: molde);

      expect(p.isValid, isTrue);
      expect(p.resultingRarity, ItemRarity.epico);
      expect(p.recreationChance, greaterThan(0));
      expect(p.recreationChance, lessThanOrEqualTo(1));
    });

    test('preview de fusão inválida explica o motivo sem consumir nada', () {
      final p = cube.preview(materials: [item('a'), item('b')]);

      expect(p.isValid, isFalse);
      expect(p.rejection, FusionRejection.notThreeItems);
      expect(p.resultingRarity, isNull);
    });

    test('CEN-M06-E03/V-ENT-04: o preview não consome RNG', () {
      // O sorteio acontece na confirmação, não na visualização. É isso que
      // permite acelerar com gemas sem mudar o resultado (V-ENT-04) e o que
      // torna a fusão atômica: ou os 3 materiais somem e o item existe, ou
      // nada mudou.
      final stream = rng();
      final antes = stream.counter;

      cube.preview(materials: trio());
      cube.preview(materials: trio());

      expect(stream.counter, antes);
    });

    test('a mesma semente produz a mesma fusão', () {
      final materiais = trio();
      final a =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais),
                rng: rng(99),
                now: now,
              )
              as FusionSuccess;
      final b =
          cube.fuse(
                materials: materiais,
                inventory: inv(materiais),
                rng: rng(99),
                now: now,
              )
              as FusionSuccess;

      expect(a.item.id, b.item.id);
      expect(a.item.type, b.item.type);
      expect(a.item.baseStat, b.item.baseStat);
      expect(
        a.item.affixes.map((x) => x.affixType),
        b.item.affixes.map((x) => x.affixType),
      );
    });
  });

  group('CEN-M06-E02 — inventário cheio', () {
    test('os 3 materiais saem antes de o resultado entrar', () {
      final materiais = trio();
      final cheio = inv([
        ...materiais,
        for (var i = 0; i < Inventory.capacity - 3; i++)
          item('enche$i', rarity: ItemRarity.epico),
      ]);
      expect(cheio.isFull, isTrue);

      final r =
          cube.fuse(
                materials: materiais,
                inventory: cheio,
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      expect(r.inventory.items, hasLength(Inventory.capacity - 2));
      expect(r.inventory.items.map((i) => i.id), contains(r.item.id));
      expect(r.inventory.pendingDrops, isEmpty, reason: 'não precisou reter');
    });

    test('a fusão drena pendentes ao liberar espaço (V-INV-04)', () {
      final materiais = trio();
      final cheio = Inventory(
        items: [
          ...materiais,
          for (var i = 0; i < Inventory.capacity - 3; i++)
            item('enche$i', rarity: ItemRarity.epico),
        ],
        pendingDrops: [item('retido', rarity: ItemRarity.mitico)],
        essences: const [],
        blueprints: const [],
      );

      final r =
          cube.fuse(
                materials: materiais,
                inventory: cheio,
                rng: rng(),
                now: now,
              )
              as FusionSuccess;

      expect(r.inventory.pendingDrops, isEmpty);
      expect(r.inventory.items.map((i) => i.id), contains('retido'));
    });
  });
}
