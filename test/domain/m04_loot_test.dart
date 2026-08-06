import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/constants/scaling.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/loot_generator.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M04 — Loot Procedural.
/// Cenários CEN-M04-001 a 013, E01 a E03.
void main() {
  const generator = LootGenerator();
  final now = DateTime.utc(2026, 1, 1);

  RngStream rng([int seed = 7]) => RngStream(seed: seed);

  group('CEN-M04-001/002 — geração de drop', () {
    test('CEN-M04-001: monstro com chance garantida gera item', () {
      final item = generator.rollDrop(
        monster: TestContent.monster(dropChanceModifier: 1),
        position: ProgressPosition.start(),
        rng: rng(),
        guaranteed: true,
        now: now,
      );
      expect(item, isNotNull);
    });

    test('CEN-M04-002: o item tem toda a estrutura mínima', () {
      final item = generator.rollDrop(
        monster: TestContent.monster(),
        position: ProgressPosition.start(),
        rng: rng(),
        guaranteed: true,
        now: now,
      )!;

      expect(item.id, isNotEmpty);
      expect(ItemType.values, contains(item.type));
      expect(ItemRarity.values, contains(item.rarity));
      expect(item.itemLevel, greaterThan(0));
      expect(item.baseStat > GameNumber.zero, isTrue);
      expect(item.droppedAt, now);
    });

    test('IDs de itens não se repetem', () {
      final stream = rng();
      final ids = <String>{};
      for (var i = 0; i < 200; i++) {
        final item = generator.rollDrop(
          monster: TestContent.monster(),
          position: ProgressPosition.start(),
          rng: stream,
          guaranteed: true,
          now: now,
        );
        expect(ids.add(item!.id), isTrue, reason: 'ID repetido: ${item.id}');
      }
    });
  });

  group('CEN-M04-003/004 — prefixo e sufixos', () {
    test('CEN-M04-003: arma gera prefixo de ataque, armadura de defesa', () {
      final arma = generator.generate(
        type: ItemType.weapon,
        rarity: ItemRarity.ouro,
        itemLevel: 20,
        rng: rng(),
        now: now,
      );
      final armadura = generator.generate(
        type: ItemType.armor,
        rarity: ItemRarity.ouro,
        itemLevel: 20,
        rng: rng(),
        now: now,
      );

      expect(arma.primaryAffixType, AffixType.attack);
      expect(armadura.primaryAffixType, AffixType.defense);
    });

    test('CEN-M04-004: 0 a 3 sufixos, sem repetir affixType', () {
      final stream = rng();
      for (var i = 0; i < 300; i++) {
        final item = generator.generate(
          type: ItemType.values[i % ItemType.values.length],
          rarity: ItemRarity.values[i % ItemRarity.values.length],
          itemLevel: 1 + i,
          rng: stream,
          now: now,
        );
        expect(item.affixes.length, inInclusiveRange(0, 3));
        expect(
          item.affixes.map((a) => a.affixType).toSet().length,
          item.affixes.length,
          reason: 'sufixo repetido em ${item.id}',
        );
      }
    });
  });

  group('CEN-M04-005/006 — item level e raridade', () {
    test('CEN-M04-005: item de wave alta é muito melhor', () {
      final baixo = generator.generate(
        type: ItemType.weapon,
        rarity: ItemRarity.ouro,
        itemLevel: ItemScaling.itemLevelFor(
          const ProgressPosition(difficulty: 1, act: 1, wave: 10),
        ),
        rng: rng(),
        now: now,
      );
      final alto = generator.generate(
        type: ItemType.weapon,
        rarity: ItemRarity.ouro,
        itemLevel: ItemScaling.itemLevelFor(
          const ProgressPosition(difficulty: 6, act: 3, wave: 100),
        ),
        rng: rng(),
        now: now,
      );

      expect(alto.itemLevel, greaterThan(baixo.itemLevel));
      expect(alto.baseStat > baixo.baseStat, isTrue);
    });

    test('a curva de item level é monotônica na wave', () {
      var anterior = 0;
      for (var wave = 1; wave <= 100; wave++) {
        final atual = ItemScaling.itemLevelFor(
          ProgressPosition(difficulty: 1, act: 1, wave: wave),
        );
        expect(atual, greaterThanOrEqualTo(anterior));
        anterior = atual;
      }
    });

    test('CEN-M04-006: raridade maior dá atributo base maior', () {
      final bronze = generator.generate(
        type: ItemType.weapon,
        rarity: ItemRarity.bronze,
        itemLevel: 50,
        rng: rng(),
        now: now,
      );
      final lendario = generator.generate(
        type: ItemType.weapon,
        rarity: ItemRarity.lendario,
        itemLevel: 50,
        rng: rng(),
        now: now,
      );
      expect(lendario.baseStat > bronze.baseStat, isTrue);
    });

    test('raridades altas tendem a ter mais sufixos', () {
      double media(ItemRarity r) {
        final stream = rng(99);
        var total = 0;
        for (var i = 0; i < 200; i++) {
          total += generator
              .generate(
                type: ItemType.weapon,
                rarity: r,
                itemLevel: 50,
                rng: stream,
                now: now,
              )
              .affixes
              .length;
        }
        return total / 200;
      }

      expect(media(ItemRarity.cosmico), greaterThan(media(ItemRarity.bronze)));
    });
  });

  group('CEN-M04-007 — ordem das raridades', () {
    test('a escala vai de Bronze a Cósmico, nesta ordem', () {
      expect(ItemRarity.values.map((r) => r.id).toList(), [
        'bronze',
        'prata',
        'ouro',
        'epico',
        'lendario',
        'mitico',
        'transcendental',
        'cosmico',
      ]);
    });

    test('cósmico é a máxima e não tem sucessora', () {
      expect(ItemRarity.cosmico.isMax, isTrue);
      expect(ItemRarity.cosmico.next, isNull);
      expect(ItemRarity.bronze.next, ItemRarity.prata);
    });
  });

  group('CEN-M04-008/009 — tabela do monstro', () {
    test('CEN-M04-008: nenhum drop excede as raridades possíveis', () {
      final monstro = TestContent.monster(
        rarities: const [ItemRarity.bronze, ItemRarity.prata, ItemRarity.ouro],
      );
      final stream = rng();
      for (var i = 0; i < 500; i++) {
        final item = generator.rollDrop(
          monster: monstro,
          position: ProgressPosition.start(),
          rng: stream,
          guaranteed: true,
          now: now,
        );
        expect(item!.rarity.index, lessThanOrEqualTo(ItemRarity.ouro.index));
      }
    });

    test('CEN-M04-009: modificador maior gera mais itens', () {
      int contar(double modificador) {
        final stream = rng(1234);
        var total = 0;
        for (var i = 0; i < 2000; i++) {
          final item = generator.rollDrop(
            monster: TestContent.monster(dropChanceModifier: modificador),
            position: ProgressPosition.start(),
            rng: stream,
            guaranteed: false,
            now: now,
          );
          if (item != null) total++;
        }
        return total;
      }

      expect(contar(3.0), greaterThan(contar(0.5)));
    });
  });

  group('CEN-M04-010/012 — boss e dificuldade', () {
    test('CEN-M04-010: boss concede drop garantido', () {
      final stream = rng();
      for (var i = 0; i < 50; i++) {
        final item = generator.rollDrop(
          monster: TestContent.monster(isBoss: true, dropChanceModifier: 0),
          position: const ProgressPosition(difficulty: 1, act: 1, wave: 10),
          rng: stream,
          guaranteed: true,
          now: now,
        );
        expect(item, isNotNull, reason: 'boss sempre concede item');
      }
    });

    test('CEN-M04-012: dificuldade soma +10 ao item level', () {
      const wave = ProgressPosition(difficulty: 1, act: 1, wave: 10);
      const wave2 = ProgressPosition(difficulty: 2, act: 1, wave: 10);
      expect(
        ItemScaling.itemLevelFor(wave2) - ItemScaling.itemLevelFor(wave),
        10,
      );
    });
  });

  group('CEN-M04-011/013 — raro e essência', () {
    test('CEN-M04-011: lendário ou superior é marcado como raro', () {
      expect(ItemRarity.lendario.isRareHighlight, isTrue);
      expect(ItemRarity.mitico.isRareHighlight, isTrue);
      expect(ItemRarity.epico.isRareHighlight, isFalse);
    });

    test('CEN-M04-013: monstro pode conceder Essência com sufixo definido', () {
      final stream = rng();
      var encontrou = false;
      for (var i = 0; i < 500 && !encontrou; i++) {
        final e = generator.rollEssence(
          monster: TestContent.monster(essenceChanceModifier: 5),
          position: ProgressPosition.start(),
          rng: stream,
          now: now,
        );
        if (e != null) {
          encontrou = true;
          expect(AffixType.suffixPool, contains(e.guaranteedAffixType));
        }
      }
      expect(encontrou, isTrue, reason: 'nenhuma Essência em 500 tentativas');
    });

    test('Essência é bem mais rara que item', () {
      final stream = rng(555);
      var itens = 0;
      var essencias = 0;
      for (var i = 0; i < 3000; i++) {
        final m = TestContent.monster();
        if (generator.rollDrop(
              monster: m,
              position: ProgressPosition.start(),
              rng: stream,
              guaranteed: false,
              now: now,
            ) !=
            null) {
          itens++;
        }
        if (generator.rollEssence(
              monster: m,
              position: ProgressPosition.start(),
              rng: stream,
              now: now,
            ) !=
            null) {
          essencias++;
        }
      }
      expect(essencias, lessThan(itens));
    });
  });

  group('bordas', () {
    test('CEN-M04-E01: chance falha e nenhum item é gerado', () {
      final item = generator.rollDrop(
        monster: TestContent.monster(dropChanceModifier: 0),
        position: ProgressPosition.start(),
        rng: rng(),
        guaranteed: false,
        now: now,
      );
      expect(item, isNull);
    });

    test('CEN-M04-E03: nada promove acima de Cósmico', () {
      final monstro = TestContent.monster(
        rarities: const [ItemRarity.cosmico],
      );
      final stream = rng();
      for (var i = 0; i < 100; i++) {
        final item = generator.rollDrop(
          monster: monstro,
          position: ProgressPosition.start(),
          rng: stream,
          guaranteed: true,
          now: now,
        );
        expect(item!.rarity, ItemRarity.cosmico);
      }
    });

    test('monstro sem raridades possíveis não gera item', () {
      final item = generator.rollDrop(
        monster: TestContent.monster(rarities: const []),
        position: ProgressPosition.start(),
        rng: rng(),
        guaranteed: true,
        now: now,
      );
      expect(item, isNull);
    });
  });
}
