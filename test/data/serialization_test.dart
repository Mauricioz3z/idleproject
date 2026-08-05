import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/dto/save_codec.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/essence.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:test/test.dart';

/// Round-trip de serialização — contracts/persistence-save-schema.md.
void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1785600000000);

  GameItem sampleItem(String id, {ItemRarity rarity = ItemRarity.epico}) =>
      GameItem(
        id: id,
        type: ItemType.weapon,
        rarity: rarity,
        itemLevel: 143,
        baseStat: GameNumber(3.4, 4),
        affixes: [
          ItemAffix(affixType: AffixType.critChance, value: GameNumber(1.2, 1)),
        ],
        droppedAt: now,
        isFavorited: true,
      );

  group('codificação de GameNumber', () {
    test('grava mantissa e expoente, nunca um inteiro', () {
      final encoded = SaveCodec.encodeNumber(GameNumber(8.31, 14));
      expect(encoded['m'], closeTo(8.31, 1e-9));
      expect(encoded['e'], 14);
    });

    test('round-trip preserva o valor', () {
      final original = GameNumber(1.234567890123, 21);
      final restored = SaveCodec.decodeNumber(SaveCodec.encodeNumber(original));
      expect(restored, original);
    });

    test('grandeza acima de int64 sobrevive ao round-trip', () {
      final huge = GameNumber(5.5, 40);
      expect(
        SaveCodec.decodeNumber(SaveCodec.encodeNumber(huge)),
        huge,
      );
    });

    test('número JSON simples é tolerado como {m: valor, e: 0}', () {
      // Tolerância declarada no contrato para saves anteriores à migração.
      expect(SaveCodec.decodeNumber(4200), GameNumber.fromInt(4200));
    });

    test('null vira zero em vez de explodir', () {
      expect(SaveCodec.decodeNumber(null), GameNumber.zero);
    });
  });

  group('round-trip de item', () {
    test('preserva todos os campos', () {
      final restored = SaveCodec.decodeItem(
        SaveCodec.encodeItem(sampleItem('i-4a11')),
      );
      expect(restored.id, 'i-4a11');
      expect(restored.type, ItemType.weapon);
      expect(restored.rarity, ItemRarity.epico);
      expect(restored.itemLevel, 143);
      expect(restored.baseStat, GameNumber(3.4, 4));
      expect(restored.affixes.single.affixType, AffixType.critChance);
      expect(restored.isFavorited, isTrue);
      expect(restored.droppedAt, now);
    });

    test('V-GI-01: sufixo repetido em save adulterado é descartado', () {
      final tampered = {
        'id': 'i-x',
        'type': 'weapon',
        'rarity': 'ouro',
        'itemLevel': 10,
        'baseStat': {'m': 1.0, 'e': 1},
        'affixes': [
          {
            'affixType': 'critChance',
            'value': {'m': 1.0, 'e': 0},
          },
          {
            'affixType': 'critChance',
            'value': {'m': 9.0, 'e': 0},
          },
        ],
        'isFavorited': false,
        'droppedAt': 0,
      };
      expect(SaveCodec.decodeItem(tampered).affixes.length, 1);
    });

    test('V-GI-01: mais de 3 sufixos é truncado', () {
      final tampered = {
        'id': 'i-y',
        'type': 'armor',
        'rarity': 'ouro',
        'itemLevel': 10,
        'baseStat': {'m': 1.0, 'e': 1},
        'affixes': [
          for (final t in [
            'critChance',
            'critDamage',
            'attackSpeed',
            'goldFind',
            'xpGain',
          ])
            {
              'affixType': t,
              'value': {'m': 1.0, 'e': 0},
            },
        ],
        'isFavorited': false,
        'droppedAt': 0,
      };
      expect(SaveCodec.decodeItem(tampered).affixes.length, 3);
    });
  });

  group('round-trip de Essência', () {
    test('preserva o sufixo garantido', () {
      final e = Essence(
        id: 'e-2f70',
        guaranteedAffixType: AffixType.critChance,
        droppedAt: now,
      );
      final restored = SaveCodec.decodeEssence(SaveCodec.encodeEssence(e));
      expect(restored.id, 'e-2f70');
      expect(restored.guaranteedAffixType, AffixType.critChance);
    });
  });

  group('round-trip do documento raiz', () {
    test('preserva conta, heróis, inventário e essências', () {
      final hero = Hero.fresh(id: 'h-9f2c', classId: 'vanguard').copyWith(
        level: 31,
        xp: GameNumber(2.7, 5),
        formationIndex: 0,
      );
      final state = SaveState(
        schemaVersion: 1,
        account: PlayerAccount.fresh(now: now, seed: 8412739481273).copyWith(
          accountLevel: 24,
          gold: GameNumber(8.31, 14),
          gems: 500,
          runePoints: 3,
          unlockedRuneNodeIds: {'root_atk', 'atk_02'},
          respecCount: 2,
          highestWave: 143,
        ),
        entitlements: Entitlements.initial(),
        heroes: [hero],
        equippedItems: [sampleItem('i-4a11')],
        inventory: Inventory(
          items: [sampleItem('i-8b30', rarity: ItemRarity.prata)],
          pendingDrops: const [],
          essences: [
            Essence(
              id: 'e-1',
              guaranteedAffixType: AffixType.goldFind,
              droppedAt: now,
            ),
          ],
          blueprints: const [],
        ),
        lastMonotonicMillis: 84321000,
      );

      final restored = SaveCodec.decodeSave(SaveCodec.encodeSave(state));

      expect(restored.account.accountLevel, 24);
      expect(restored.account.gold, GameNumber(8.31, 14));
      expect(restored.account.gems, 500);
      expect(restored.account.unlockedRuneNodeIds, {'root_atk', 'atk_02'});
      expect(restored.account.respecCount, 2);
      expect(restored.account.highestWave, 143);
      expect(restored.heroes.single.level, 31);
      expect(restored.heroes.single.formationIndex, 0);
      expect(restored.equippedItems.single.id, 'i-4a11');
      expect(restored.inventory.items.single.id, 'i-8b30');
      expect(restored.inventory.essences.single.guaranteedAffixType,
          AffixType.goldFind);
      expect(restored.lastMonotonicMillis, 84321000);
    });

    test('itens equipados ficam fora de items — V-GI-04', () {
      final state = SaveState(
        schemaVersion: 1,
        account: PlayerAccount.fresh(now: now, seed: 1),
        entitlements: Entitlements.initial(),
        heroes: const [],
        equippedItems: [sampleItem('i-equipped')],
        inventory: Inventory(
          items: [sampleItem('i-free')],
          pendingDrops: const [],
          essences: const [],
          blueprints: const [],
        ),
        lastMonotonicMillis: 0,
      );
      final encoded = SaveCodec.encodeSave(state);
      final equippedIds = (encoded['equippedItems'] as List)
          .map((e) => (e as Map)['id'])
          .toSet();
      final freeIds =
          (encoded['items'] as List).map((e) => (e as Map)['id']).toSet();
      expect(equippedIds.intersection(freeIds), isEmpty);
    });
  });
}
