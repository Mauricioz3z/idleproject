import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/engines/offline_simulator.dart';
import 'package:pixel_idle_quest/domain/engines/state_projector.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:test/test.dart';

/// Projeção de estado para o widget — research.md R4, M11.
///
/// A projeção existe porque o Android impõe piso de ~15 min entre atualizações
/// fora de serviço em primeiro plano. Em vez de exibir um retrato congelado, o
/// widget calcula onde o jogador estaria **no instante em que desenha**. Para
/// isso ser honesto, a fórmula tem de ser exatamente a de M09: mesmo teto de
/// 8 h, mesma penalidade de 0,8. Um widget que prometesse mais do que o jogo
/// concede seria pior que um widget desatualizado.
void main() {
  final salvoEm = DateTime.utc(2026, 8, 5, 12);

  GameItem rare(String id, ItemRarity rarity) => GameItem(
    id: id,
    type: ItemType.helmet,
    rarity: rarity,
    itemLevel: 120,
    baseStat: GameNumber.fromDouble(500),
    affixes: const [],
    droppedAt: salvoEm,
  );

  SaveState save({
    double goldPerSecond = 10,
    double gold = 1000,
    ProgressPosition? position,
    List<Hero>? heroes,
    List<GameItem> items = const [],
    DateTime? lastSaveAt,
  }) => SaveState(
    schemaVersion: SaveState.currentSchemaVersion,
    account: PlayerAccount.fresh(now: salvoEm, seed: 7).copyWith(
      gold: GameNumber.fromDouble(gold),
      goldPerSecond: GameNumber.fromDouble(goldPerSecond),
      currentPosition:
          position ?? const ProgressPosition(difficulty: 1, act: 2, wave: 43),
      lastSaveAt: lastSaveAt ?? salvoEm,
    ),
    entitlements: Entitlements.initial(),
    heroes:
        heroes ??
        [
          Hero.fresh(id: 'h1', classId: 'vanguard')
              .copyWith(formationIndex: 0, level: 31),
          Hero.fresh(id: 'h2', classId: 'elementalist')
              .copyWith(formationIndex: 1, level: 28),
        ],
    equippedItems: const [],
    inventory: Inventory(
      items: items,
      pendingDrops: const [],
      essences: const [],
      blueprints: const [],
    ),
    lastMonotonicMillis: 0,
  );

  group('CEN-M11-001/003/009 — conteúdo projetado', () {
    test('CEN-M11-009: a posição vem do save, sem combate em tempo real', () {
      final p = StateProjector.project(
        state: save(),
        now: salvoEm.add(const Duration(minutes: 5)),
      );

      expect(p.position!.act, 2);
      expect(p.position!.wave, 43);
      expect(p.position!.globalWave, 143);
      // A wave **não** é projetada: avançá-la exigiria rodar combate, que é
      // exatamente o que R-M09-07 proíbe fora do app.
      expect(p.position, save().account.currentPosition);
    });

    test('CEN-M11-001: melhor herói é o de maior nível na formação', () {
      final p = StateProjector.project(state: save(), now: salvoEm);

      expect(p.bestHeroClassId, 'vanguard');
      expect(p.bestHeroLevel, 31);
      expect(p.heroesInFormation, 2);
    });

    test('herói fora da formação não concorre a melhor herói', () {
      final p = StateProjector.project(
        state: save(
          heroes: [
            Hero.fresh(id: 'h1', classId: 'vanguard')
                .copyWith(formationIndex: 0, level: 10),
            Hero.fresh(id: 'banco', classId: 'berserker').copyWith(level: 99),
          ],
        ),
        now: salvoEm,
      );

      expect(p.bestHeroClassId, 'vanguard');
      expect(p.bestHeroLevel, 10);
      expect(p.heroesInFormation, 1);
    });

    test('CEN-M11-001: o último lendário+ é exibido', () {
      final p = StateProjector.project(
        state: save(
          items: [
            rare('comum', ItemRarity.ouro),
            rare('lendario', ItemRarity.lendario),
            rare('mitico', ItemRarity.mitico),
          ],
        ),
        now: salvoEm,
      );

      expect(p.lastRare?.id, 'mitico');
      expect(p.lastRare?.rarity, ItemRarity.mitico);
    });

    test('sem nenhum item raro, o campo fica vazio em vez de mentir', () {
      final p = StateProjector.project(
        state: save(items: [rare('comum', ItemRarity.epico)]),
        now: salvoEm,
      );
      expect(p.lastRare, isNull);
    });
  });

  group('projeção de ouro — mesma fórmula de M09', () {
    test('o ouro projetado usa gps × elapsed × 0,8', () {
      final p = StateProjector.project(
        state: save(gold: 1000, goldPerSecond: 10),
        now: salvoEm.add(const Duration(hours: 2)),
      );

      expect(p.projectedGain.toDouble(), closeTo(10 * 7200 * 0.8, 1));
      expect(p.projectedGold.toDouble(), closeTo(1000 + 10 * 7200 * 0.8, 1));
    });

    test('o teto de 8 h vale igual ao de M09', () {
      final p = StateProjector.project(
        state: save(goldPerSecond: 10),
        now: salvoEm.add(const Duration(hours: 30)),
      );

      expect(p.elapsed.inSeconds, OfflineSimulator.maxOfflineSeconds);
      expect(
        p.projectedGain.toDouble(),
        closeTo(10 * OfflineSimulator.maxOfflineSeconds * 0.8, 1),
      );
    });

    test('a penalidade é a mesma constante, não uma cópia', () {
      expect(StateProjector.penalty, OfflineSimulator.offlinePenalty);
      expect(StateProjector.maxSeconds, OfflineSimulator.maxOfflineSeconds);
    });

    test('o widget nunca promete mais do que o jogo concede', () {
      // Qualquer intervalo: a projeção do widget é limitada pelo mesmo teto e
      // pela mesma penalidade que o resumo offline aplicará na reabertura.
      for (final horas in [1, 4, 8, 12, 48]) {
        final p = StateProjector.project(
          state: save(goldPerSecond: 25),
          now: salvoEm.add(Duration(hours: horas)),
        );
        final segundos = horas * 3600 > OfflineSimulator.maxOfflineSeconds
            ? OfflineSimulator.maxOfflineSeconds
            : horas * 3600;
        expect(
          p.projectedGain.toDouble(),
          closeTo(25 * segundos * 0.8, 1),
          reason: 'divergiu de M09 em $horas h',
        );
      }
    });

    test('relógio atrasado não projeta ganho negativo', () {
      final p = StateProjector.project(
        state: save(gold: 1000),
        now: salvoEm.subtract(const Duration(hours: 3)),
      );

      expect(p.elapsed, Duration.zero);
      expect(p.projectedGain, GameNumber.zero);
      expect(p.projectedGold.toDouble(), 1000);
    });

    test('ouro por minuto é o que a notificação exibe (R-M11-06)', () {
      final p = StateProjector.project(
        state: save(goldPerSecond: 20),
        now: salvoEm,
      );
      expect(p.goldPerMinute.toDouble(), closeTo(20 * 60, 0.001));
    });
  });

  group('CEN-M11-011 — sem estado salvo', () {
    test('a projeção vazia não inventa valores', () {
      const p = StateProjector.empty;

      expect(p.hasSave, isFalse);
      expect(p.projectedGold, GameNumber.zero);
      expect(p.goldPerSecond, GameNumber.zero);
      expect(p.bestHeroClassId, isNull);
      expect(p.lastRare, isNull);
    });

    test('save sem último acesso é tratado como ausência de save', () {
      final p = StateProjector.project(
        state: save(lastSaveAt: DateTime.fromMillisecondsSinceEpoch(0)),
        now: salvoEm,
      );
      expect(p.elapsed, Duration.zero);
      expect(p.projectedGain, GameNumber.zero);
    });
  });

  group('CEN-M11-E03 — consistência', () {
    test('duas projeções do mesmo instante são idênticas', () {
      final estado = save();
      final agora = salvoEm.add(const Duration(minutes: 37));

      final a = StateProjector.project(state: estado, now: agora);
      final b = StateProjector.project(state: estado, now: agora);

      expect(a.projectedGold, b.projectedGold);
      expect(a.position, b.position);
      expect(a.bestHeroLevel, b.bestHeroLevel);
    });

    test('a projeção é monotônica no tempo, até o teto', () {
      var anterior = GameNumber.zero;
      for (var minutos = 0; minutos <= 600; minutos += 30) {
        final p = StateProjector.project(
          state: save(),
          now: salvoEm.add(Duration(minutes: minutos)),
        );
        expect(p.projectedGold >= anterior, isTrue);
        anterior = p.projectedGold;
      }
    });
  });
}
