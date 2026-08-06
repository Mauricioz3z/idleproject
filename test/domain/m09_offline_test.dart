import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/engines/offline_simulator.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M09 — Progressão Offline.
/// Cenários CEN-M09-001 a 011, E01 a E04.
void main() {
  const simulator = OfflineSimulator();
  final salvoEm = DateTime.utc(2026, 8, 5, 12);

  final classe = TestContent.heroClass(
    id: 'herói',
    attack: 400,
    defense: 30,
    maxHp: 2000,
    attacksPerSecond: 2,
  );

  final director = WaveDirector(
    templates: [
      TestContent.monster(id: 'comum', act: 1, maxHp: 120, attack: 10),
      TestContent.monster(
        id: 'boss',
        act: 1,
        isBoss: true,
        maxHp: 600,
        attack: 20,
      ),
    ],
  );

  CombatEngine engine([int seed = 4242]) =>
      CombatEngine(rng: RngStream(seed: seed));

  SaveState save({
    double goldPerSecond = 10,
    GameNumber? gold,
    DateTime? lastSaveAt,
    List<Hero>? heroes,
    Inventory? inventory,
    ProgressPosition? position,
  }) => SaveState(
    schemaVersion: SaveState.currentSchemaVersion,
    account: PlayerAccount.fresh(now: salvoEm, seed: 99).copyWith(
      gold: gold ?? GameNumber.zero,
      goldPerSecond: GameNumber.fromDouble(goldPerSecond),
      lastSaveAt: lastSaveAt ?? salvoEm,
      currentPosition: position ?? ProgressPosition.start(),
    ),
    entitlements: Entitlements.initial(),
    heroes:
        heroes ??
        [Hero.fresh(id: 'h1', classId: classe.id).copyWith(formationIndex: 0)],
    equippedItems: const [],
    inventory: inventory ?? Inventory.empty(),
    lastMonotonicMillis: 0,
  );

  OfflineSimulation run({
    required SaveState state,
    required DateTime now,
    int seed = 4242,
  }) => simulator.simulate(
    state: state,
    now: now,
    combat: engine(seed),
    waves: director,
    classes: [classe],
  );

  group('CEN-M09-001/002/003/004 — ouro por forma fechada', () {
    test('CEN-M09-001: 10 de ouro por segundo por 2 h rende 57.600', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 2)),
      );

      expect(r.report.goldGained.toDouble(), closeTo(57600, 1));
      expect(r.report.elapsedSeconds, 7200);
      expect(r.report.wasCapped, isFalse);
    });

    test('CEN-M09-001: o ouro é somado ao que o jogador já tinha', () {
      final r = run(
        state: save(gold: GameNumber.fromDouble(1000)),
        now: salvoEm.add(const Duration(hours: 2)),
      );

      // A conta recebe a fórmula fechada **mais** a venda automática disparada
      // pelos drops da ausência. As duas entram separadas no resumo justamente
      // para que a fórmula de R-M09-03 continue conferível sozinha.
      expect(
        r.state.account.gold.toDouble(),
        closeTo(
          1000 + 57600 + r.report.goldFromAutoSell.toDouble(),
          1,
        ),
      );
      expect(r.report.goldGained.toDouble(), closeTo(57600, 1));
    });

    test('CEN-M09-002: a penalidade de 20% é aplicada', () {
      // Bruto de 100.000 = 12,5 por segundo durante 8.000 s.
      final r = run(
        state: save(goldPerSecond: 12.5),
        now: salvoEm.add(const Duration(seconds: 8000)),
      );
      expect(r.report.goldGained.toDouble(), closeTo(80000, 1));
      expect(OfflineSimulator.offlinePenalty, 0.8);
    });

    test('CEN-M09-003: 12 h de ausência valem exatamente 8 h', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 12)),
      );

      expect(r.report.elapsedSeconds, OfflineSimulator.maxOfflineSeconds);
      expect(r.report.wasCapped, isTrue);
      expect(
        r.report.goldGained.toDouble(),
        closeTo(10 * OfflineSimulator.maxOfflineSeconds * 0.8, 1),
      );
    });

    test('CEN-M09-004: 45 s rendem exatamente o proporcional', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(seconds: 45)),
      );
      expect(r.report.goldGained.toDouble(), closeTo(10 * 45 * 0.8, 0.001));
      expect(r.report.elapsedSeconds, 45);
    });

    test('SC-M09-02: a hora offline vale menos que a hora ativa', () {
      // A taxa apurada vem do jogo ativo; offline entrega 80% dela.
      const gps = 10.0;
      final r = run(
        state: save(goldPerSecond: gps),
        now: salvoEm.add(const Duration(hours: 1)),
      );
      expect(r.report.goldGained.toDouble(), lessThan(gps * 3600));
    });

    test('sem taxa apurada não há ouro offline, e nada quebra', () {
      final r = run(
        state: save(goldPerSecond: 0),
        now: salvoEm.add(const Duration(hours: 3)),
      );
      expect(r.report.goldGained, GameNumber.zero);
    });
  });

  group('CEN-M09-005/006 — resumo, XP e níveis', () {
    test('CEN-M09-005: o resumo traz ouro, XP, waves e itens', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 4)),
      );

      expect(r.report.goldGained > GameNumber.zero, isTrue);
      expect(r.report.xpGained > GameNumber.zero, isTrue);
      expect(r.report.wavesAdvanced, greaterThan(0));
      expect(r.report.isEmpty, isFalse);
    });

    test('CEN-M09-006: os níveis ganhos são aplicados e constam do resumo', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 8)),
      );

      final heroi = r.state.heroes.single;
      expect(heroi.level, greaterThan(1), reason: 'nenhum nível aplicado');
      expect(r.report.levelUps, isNotEmpty);
      expect(r.report.levelUps.single.heroId, 'h1');
      expect(r.report.levelUps.single.from, 1);
      expect(r.report.levelUps.single.to, heroi.level);
    });

    test('herói fora da formação não recebe XP offline (V-H-05)', () {
      final r = run(
        state: save(
          heroes: [
            Hero.fresh(id: 'h1', classId: classe.id).copyWith(formationIndex: 0),
            Hero.fresh(id: 'banco', classId: classe.id),
          ],
        ),
        now: salvoEm.add(const Duration(hours: 2)),
      );

      final banco = r.state.heroes.firstWhere((h) => h.id == 'banco');
      expect(banco.xp, GameNumber.zero);
      expect(banco.level, 1);
    });
  });

  group('CEN-M09-007 — itens', () {
    test('os itens obtidos estão no inventário depois do resumo', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 6)),
      );

      expect(r.report.itemsObtained, isNotEmpty);
      expect(
        r.state.inventory.items.length +
            r.state.inventory.pendingDrops.length,
        greaterThan(0),
      );
      // SC-M05-03: a capacidade continua valendo offline.
      expect(
        r.state.inventory.items.length,
        lessThanOrEqualTo(Inventory.capacity),
      );
    });

    test('lendário ou superior aparece destacado no resumo', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(hours: 8)),
      );

      expect(
        r.report.rareHighlights.every((i) => i.rarity.isRareHighlight),
        isTrue,
      );
      expect(
        r.report.rareHighlights.every(r.report.itemsObtained.contains),
        isTrue,
      );
    });

    test('inventário cheio retém em vez de descartar (V-INV-03)', () {
      final cheio = Inventory(
        items: [
          for (var i = 0; i < Inventory.capacity; i++)
            GameItem(
              id: 'epico$i',
              type: ItemType.ring,
              rarity: ItemRarity.epico,
              itemLevel: 30,
              baseStat: GameNumber.fromDouble(100),
              affixes: const [],
              droppedAt: salvoEm,
            ),
        ],
        pendingDrops: const [],
        essences: const [],
        blueprints: const [],
      );

      final r = run(
        state: save(inventory: cheio),
        now: salvoEm.add(const Duration(hours: 8)),
      );

      expect(r.state.inventory.items, hasLength(Inventory.capacity));
      expect(r.state.inventory.pendingDrops, isNotEmpty);
      expect(
        r.report.inventoryBecameFull,
        isTrue,
        reason: 'CEN-M09-009 precisa desta bandeira para notificar',
      );
    });
  });

  group('CEN-M09-011 — sem morte permanente', () {
    test('monstros fortes demais estagnam o avanço, sem perder herói', () {
      final duro = WaveDirector(
        templates: [
          TestContent.monster(
            id: 'muralha',
            act: 1,
            maxHp: 1e9,
            defense: 1e6,
            attack: 1e6,
          ),
        ],
      );

      final r = simulator.simulate(
        state: save(),
        now: salvoEm.add(const Duration(hours: 8)),
        combat: engine(),
        waves: duro,
        classes: [classe],
      );

      expect(r.report.wavesAdvanced, 0, reason: 'não deveria avançar');
      expect(r.state.heroes, hasLength(1), reason: 'nenhum herói é perdido');
      expect(r.state.heroes.single.level, greaterThanOrEqualTo(1));
      // O ouro por forma fechada continua sendo concedido: a taxa foi apurada
      // com o jogo aberto e não depende de vencer a wave seguinte.
      expect(r.report.goldGained > GameNumber.zero, isTrue);
    });

    test('a posição não regride durante a estagnação', () {
      final duro = WaveDirector(
        templates: [
          TestContent.monster(id: 'muralha', act: 1, maxHp: 1e9, defense: 1e6),
        ],
      );
      const inicio = ProgressPosition(difficulty: 1, act: 1, wave: 42);

      final r = simulator.simulate(
        state: save(position: inicio),
        now: salvoEm.add(const Duration(hours: 8)),
        combat: engine(),
        waves: duro,
        classes: [classe],
      );

      expect(r.state.account.currentPosition, inicio);
    });
  });

  group('bordas', () {
    test('CEN-M09-E01: adiantar o relógio em 30 dias rende 8 h', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(days: 30)),
      );
      expect(r.report.elapsedSeconds, OfflineSimulator.maxOfflineSeconds);
      expect(r.report.wasCapped, isTrue);
    });

    test('CEN-M09-E02: atrasar o relógio não concede nem subtrai nada', () {
      final antes = save(gold: GameNumber.fromDouble(5000));
      final r = run(
        state: antes,
        now: salvoEm.subtract(const Duration(hours: 3)),
      );

      expect(r.report.isEmpty, isTrue);
      expect(r.report.goldGained, GameNumber.zero);
      expect(r.report.elapsedSeconds, 0);
      expect(r.state.account.gold, antes.account.gold);
      expect(r.state.account.currentPosition, antes.account.currentPosition);
      // O último acesso passa a ser agora, senão o jogador ficaria preso num
      // futuro que nunca chega.
      expect(r.state.account.lastSaveAt, salvoEm.subtract(
        const Duration(hours: 3),
      ));
    });

    test('CEN-M09-E03: primeira abertura não simula nada', () {
      final novo = SaveState.fresh(now: salvoEm, seed: 1);
      final r = simulator.simulate(
        state: novo,
        now: salvoEm,
        combat: engine(),
        waves: director,
        classes: [classe],
      );

      expect(r.report.isEmpty, isTrue);
      expect(r.report.wavesAdvanced, 0);
      expect(r.report.itemsObtained, isEmpty);
    });

    test('CEN-M09-E04: os segundos entre o último save e o fechamento contam', () {
      final r = run(
        state: save(),
        now: salvoEm.add(const Duration(seconds: 20)),
      );
      expect(r.report.elapsedSeconds, 20);
      expect(r.report.goldGained.toDouble(), closeTo(10 * 20 * 0.8, 0.001));
    });

    test('sem heróis na formação, nada avança e nada quebra', () {
      final r = run(
        state: save(heroes: const []),
        now: salvoEm.add(const Duration(hours: 8)),
      );
      expect(r.report.wavesAdvanced, 0);
      expect(r.report.goldGained > GameNumber.zero, isTrue);
    });
  });

  group('determinismo', () {
    test('a mesma semente e o mesmo intervalo dão o mesmo resultado', () {
      final a = run(state: save(), now: salvoEm.add(const Duration(hours: 5)));
      final b = run(state: save(), now: salvoEm.add(const Duration(hours: 5)));

      expect(a.report.wavesAdvanced, b.report.wavesAdvanced);
      expect(a.report.goldGained, b.report.goldGained);
      expect(a.report.xpGained, b.report.xpGained);
      expect(
        a.report.itemsObtained.map((i) => i.id),
        b.report.itemsObtained.map((i) => i.id),
      );
    });

    test('a simulação não muta o estado de entrada (I-4)', () {
      final entrada = save(gold: GameNumber.fromDouble(100));
      final ouroAntes = entrada.account.gold;
      final itensAntes = entrada.inventory.items.length;

      run(state: entrada, now: salvoEm.add(const Duration(hours: 8)));

      expect(entrada.account.gold, ouroAntes);
      expect(entrada.inventory.items.length, itensAntes);
      expect(entrada.heroes.single.level, 1);
    });
  });
}
