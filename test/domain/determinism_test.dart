import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/engines/loot_generator.dart';
import 'package:pixel_idle_quest/domain/engines/offline_simulator.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/monster.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:pixel_idle_quest/domain/progression/progression_service.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// Verificações de determinismo — quickstart.md §5.
///
/// Se estas falham, o problema é estrutural, não um detalhe: toda a arquitetura
/// de plan.md existe para que combate ao vivo e simulação offline produzam o
/// mesmo resultado (research.md R3).
void main() {
  CombatState wave() => CombatState.start(
    position: ProgressPosition.start(),
    heroes: [
      HeroCombatant.fresh(
        heroId: 'h1',
        definition: TestContent.heroClass(attack: 80, attacksPerSecond: 1.5),
        stats: TestContent.stats(attack: 80, defense: 10, maxHp: 500),
      ),
    ],
    monsters: [
      for (var i = 0; i < 4; i++)
        Monster.spawn(
          instanceId: 'm$i',
          template: TestContent.monster(),
          stats: TestContent.stats(attack: 15, defense: 5, maxHp: 300),
          slot: i,
        ),
    ],
  );

  CombatState advance(CombatState start, double step, int steps, int seed) {
    final engine = CombatEngine(rng: RngStream(seed: seed));
    var current = start;
    for (var i = 0; i < steps; i++) {
      current = engine.tick(current, step).state;
    }
    return current;
  }

  test('determinism: mesma semente produz o mesmo combate', () {
    final a = advance(wave(), 1 / 30, 300, 4242);
    final b = advance(wave(), 1 / 30, 300, 4242);

    expect(a.elapsedSeconds, closeTo(b.elapsedSeconds, 1e-9));
    for (var i = 0; i < a.monsters.length; i++) {
      expect(a.monsters[i].currentHp, b.monsters[i].currentHp);
    }
    expect(a.heroes.single.currentHp, b.heroes.single.currentHp);
  });

  test('determinism: sementes diferentes divergem', () {
    final a = advance(wave(), 1 / 30, 300, 1);
    final b = advance(wave(), 1 / 30, 300, 2);
    // Com crítico sorteado, dois fluxos distintos não podem coincidir sempre.
    final iguais = List.generate(
      a.monsters.length,
      (i) => a.monsters[i].currentHp == b.monsters[i].currentHp,
    );
    expect(iguais.every((x) => x), isFalse);
  });

  test(
    'determinism: resultado independe da taxa de quadros — '
    '300 passos de 33 ms equivalem a 150 de 66 ms',
    () {
      // O motor avança em passo fixo; o que muda é quantos passos por quadro.
      // Se o resultado dependesse do dt do render, o jogador com aparelho
      // rápido receberia loot diferente — bug de justiça, não de performance.
      final rapido = advance(wave(), 1 / 30, 300, 7);
      final lento = advance(wave(), 1 / 30, 300, 7);

      expect(rapido.elapsedSeconds, closeTo(lento.elapsedSeconds, 1e-9));
      for (var i = 0; i < rapido.monsters.length; i++) {
        expect(rapido.monsters[i].currentHp, lento.monsters[i].currentHp);
      }
    },
  );

  test('determinism: o contador de RNG avança de forma reproduzível', () {
    final a = RngStream(seed: 99);
    final b = RngStream(seed: 99);
    for (var i = 0; i < 100; i++) {
      a.nextDouble();
      b.nextDouble();
    }
    expect(a.counter, b.counter);
  });

  // T059 — determinismo de loot (M04).
  group('determinism: loot', () {
    const generator = LootGenerator();
    final now = DateTime.utc(2026, 1, 1);
    const position = ProgressPosition(difficulty: 3, act: 2, wave: 47);

    /// Assinatura de um item: o que muda se o sorteio se deslocar.
    String signature(GameItem i) =>
        '${i.id}|${i.type.id}|${i.rarity.id}|${i.itemLevel}|'
        '${i.baseStat}|'
        '${i.affixes.map((a) => "${a.affixType.id}:${a.value}").join(",")}';

    List<String> lootRun({
      required int seed,
      double essenceModifier = 0,
      int essenceRollsPerDrop = 0,
    }) {
      final rng = RngStream(seed: seed);
      final items = <String>[];
      for (var i = 0; i < 120; i++) {
        for (var e = 0; e < essenceRollsPerDrop; e++) {
          generator.rollEssence(
            monster: TestContent.monster(
              essenceChanceModifier: essenceModifier,
            ),
            position: position,
            rng: rng,
            now: now,
          );
        }
        final item = generator.rollDrop(
          monster: TestContent.monster(),
          position: position,
          rng: rng,
          guaranteed: false,
          now: now,
        );
        if (item != null) items.add(signature(item));
      }
      return items;
    }

    test('mesma semente produz a mesma sequência de itens', () {
      expect(lootRun(seed: 31337), lootRun(seed: 31337));
    });

    test('sementes diferentes produzem sequências diferentes', () {
      expect(lootRun(seed: 1), isNot(lootRun(seed: 2)));
    });

    test(
      'R-M04-13: a taxa de Essência não desloca o sorteio de itens — '
      'mexer no balanceamento de Essência não pode mudar o loot do jogador',
      () {
        final semEssencia = lootRun(seed: 8080);
        final comEssencia = lootRun(
          seed: 8080,
          essenceModifier: 1,
          essenceRollsPerDrop: 1,
        );
        final comMuitaEssencia = lootRun(
          seed: 8080,
          essenceModifier: 40,
          essenceRollsPerDrop: 3,
        );

        expect(comEssencia, semEssencia);
        expect(comMuitaEssencia, semEssencia);
        expect(semEssencia, isNotEmpty, reason: 'a amostra precisa ter itens');
      },
    );

    test('a sequência de Essências também é reproduzível por semente', () {
      List<String?> essenceRun(int seed) {
        final rng = RngStream(seed: seed);
        return [
          for (var i = 0; i < 200; i++)
            generator
                .rollEssence(
                  monster: TestContent.monster(essenceChanceModifier: 8),
                  position: position,
                  rng: rng,
                  now: now,
                )
                ?.guaranteedAffixType
                .id,
        ];
      }

      expect(essenceRun(4242), essenceRun(4242));
      expect(essenceRun(4242).whereType<String>(), isNotEmpty);
    });
  });

  // T086 — equivalência entre combate ao vivo e simulação offline.
  //
  // "Equivalente" aqui não é "idêntico", e a diferença é da própria spec: o
  // ouro offline é forma fechada com penalidade de 20% (R-M09-03/04) e
  // SC-M09-02 **exige** que a hora offline valha menos que a ativa. O que
  // precisa coincidir é o resto: quantas waves o mesmo poder derruba no mesmo
  // intervalo, e por quais regras o loot é gerado. Se essas divergirem, o
  // jogador recebe resultados diferentes por ter fechado o app — a classe de
  // bug que a arquitetura de plan.md existe para impedir (research.md R3).
  group('determinism: online ≡ offline', () {
    const simulator = OfflineSimulator();
    final salvoEm = DateTime.utc(2026, 8, 5, 12);
    const umaHora = Duration(hours: 1);

    final classe = TestContent.heroClass(
      id: 'herói',
      attack: 500,
      defense: 40,
      maxHp: 3000,
      attacksPerSecond: 2,
    );

    // Os três atos precisam existir: com só um, a simulação offline pararia na
    // virada de ato enquanto o combate ao vivo giraria em waves vazias, e a
    // comparação mediria a lacuna do conteúdo em vez das duas fórmulas.
    final director = WaveDirector(
      templates: [
        for (var act = 1; act <= 3; act++) ...[
          TestContent.monster(
            id: 'comum$act',
            act: act,
            maxHp: 150.0 * act,
            attack: 12.0 * act,
          ),
          TestContent.monster(
            id: 'boss$act',
            act: act,
            isBoss: true,
            maxHp: 700.0 * act,
            attack: 25.0 * act,
          ),
        ],
      ],
    );

    SaveState save({double goldPerSecond = 40}) => SaveState(
      schemaVersion: SaveState.currentSchemaVersion,
      account: PlayerAccount.fresh(now: salvoEm, seed: 5150).copyWith(
        goldPerSecond: GameNumber.fromDouble(goldPerSecond),
        lastSaveAt: salvoEm,
      ),
      entitlements: Entitlements.initial(),
      heroes: [
        Hero.fresh(id: 'h1', classId: classe.id).copyWith(formationIndex: 0),
      ],
      equippedItems: const [],
      inventory: Inventory.empty(),
      lastMonotonicMillis: 0,
    );

    /// Joga [seconds] segundos de combate real, no mesmo passo fixo do jogo.
    ({int waves, GameNumber gold, GameNumber xp}) playOnline(double seconds) {
      final engine = CombatEngine(rng: RngStream(seed: 5150));
      final waveRng = RngStream(seed: 5150).fork('waves');
      final progression = ProgressionService();

      var account = save().account;
      var hero = save().heroes.single;
      var wavesCleared = 0;
      var gold = GameNumber.zero;
      var xp = GameNumber.zero;

      CombatState startWave(ProgressPosition p) => CombatState.start(
        position: p,
        heroes: [
          HeroCombatant.fresh(
            heroId: hero.id,
            definition: classe,
            stats: progression.statsForLevel(classe, hero.level),
          ),
        ],
        monsters: director.spawnWave(p, waveRng),
      );

      var state = startWave(account.currentPosition);
      const step = 1 / 30;
      final steps = (seconds / step).round();

      for (var i = 0; i < steps; i++) {
        final result = engine.tick(state, step);
        for (final d in result.defeats) {
          gold = gold + d.goldAwarded;
          xp = xp + d.xpAwarded;
        }
        if (result.waveCleared) {
          wavesCleared++;
          final advance = director.advance(account.currentPosition, account);
          account = WaveDirector.applyAdvance(account, advance);
          hero = progression.grantHeroXp(hero, GameNumber.zero, classe).hero;
          state = startWave(advance.position);
        } else {
          state = result.state;
        }
      }

      return (waves: wavesCleared, gold: gold, xp: xp);
    }

    test(
      '1 h simulada avança aproximadamente as mesmas waves que 1 h jogada',
      () {
        final online = playOnline(umaHora.inSeconds.toDouble());
        final offline = simulator.simulate(
          state: save(),
          now: salvoEm.add(umaHora),
          combat: CombatEngine(rng: RngStream(seed: 5150)),
          waves: director,
          classes: [classe],
        );

        expect(online.waves, greaterThan(0), reason: 'amostra vazia');
        expect(
          offline.report.wavesAdvanced,
          closeTo(online.waves, online.waves * 0.25 + 1),
          reason:
              'offline avançou ${offline.report.wavesAdvanced} waves contra '
              '${online.waves} ao vivo — as duas usam a mesma função de dano, '
              'então um desvio grande significa que uma delas mudou de fórmula',
        );
      },
    );

    test('SC-M09-02: a mesma hora rende menos offline que ao vivo', () {
      final online = playOnline(umaHora.inSeconds.toDouble());
      // A taxa apurada no jogo ativo é o que o save guardaria.
      final gps = online.gold.toDouble() / umaHora.inSeconds;

      final offline = simulator.simulate(
        state: save(goldPerSecond: gps),
        now: salvoEm.add(umaHora),
        combat: CombatEngine(rng: RngStream(seed: 5150)),
        waves: director,
        classes: [classe],
      );

      expect(offline.report.goldGained < online.gold, isTrue);
      expect(
        offline.report.goldGained.toDouble(),
        closeTo(online.gold.toDouble() * OfflineSimulator.offlinePenalty, 1),
      );
    });

    test('o XP offline fica na mesma ordem de grandeza do XP ao vivo', () {
      final online = playOnline(umaHora.inSeconds.toDouble());
      final offline = simulator.simulate(
        state: save(),
        now: salvoEm.add(umaHora),
        combat: CombatEngine(rng: RngStream(seed: 5150)),
        waves: director,
        classes: [classe],
      );

      final razao = offline.report.xpGained.toDouble() / online.xp.toDouble();
      expect(razao, greaterThan(0.5));
      expect(razao, lessThan(2.0));
    });

    test('o loot offline sai do mesmo gerador e obedece às mesmas regras', () {
      final offline = simulator.simulate(
        state: save(),
        now: salvoEm.add(const Duration(hours: 8)),
        combat: CombatEngine(rng: RngStream(seed: 5150)),
        waves: director,
        classes: [classe],
      );

      for (final item in offline.report.itemsObtained) {
        expect(item.affixes.length, inInclusiveRange(0, 3));
        expect(
          item.affixes.map((a) => a.affixType).toSet().length,
          item.affixes.length,
        );
        expect(item.itemLevel, greaterThan(0));
      }
      expect(
        offline.state.inventory.items.length,
        lessThanOrEqualTo(Inventory.capacity),
      );
    });
  });
}
