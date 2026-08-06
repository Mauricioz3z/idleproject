import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:pixel_idle_quest/domain/ports/save_repository.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/offline_providers.dart';
import 'package:pixel_idle_quest/services/clock_guard.dart';
import 'package:test/test.dart';

import '../support/fake_clock.dart';

/// US4 — "Continuar progredindo com o app fechado".
///
/// Teste independente da story, como a spec a define: salvar, fechar, avançar o
/// relógio em 2 h, reabrir e conferir ouro ≈ `gps × 7200 × 0,8` com resumo
/// exibido **antes** do retorno ao combate.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  final salvoEm = DateTime.utc(2026, 8, 5, 12);

  late JsonContentRepository content;

  setUp(() {
    content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );
  });

  SaveState savedGame({double goldPerSecond = 25}) => SaveState(
    schemaVersion: SaveState.currentSchemaVersion,
    account: PlayerAccount.fresh(now: salvoEm, seed: 4242).copyWith(
      gold: GameNumber.fromDouble(1000),
      goldPerSecond: GameNumber.fromDouble(goldPerSecond),
      lastSaveAt: salvoEm,
    ),
    entitlements: Entitlements.initial(),
    heroes: [
      for (var i = 0; i < 3; i++)
        Hero.fresh(id: 'hero_$i', classId: content.heroClasses()[i].id)
            .copyWith(formationIndex: i),
    ],
    equippedItems: const [],
    inventory: Inventory.empty(),
    lastMonotonicMillis: 0,
  );

  ProviderContainer containerWith({
    SaveState? saved,
    required DateTime now,
  }) => ProviderContainer(
    overrides: [
      combatDependenciesProvider.overrideWithValue(
        CombatDependencies(
          classes: content.heroClasses(),
          monsterTemplates: content.monsters(),
          seed: 4242,
        ),
      ),
      saveRepositoryProvider.overrideWithValue(_FakeRepository(saved)),
      clockProvider.overrideWithValue(FakeClock(start: now)),
    ],
  );

  test(
    'teste independente de US4: 2 h de ausência rendem gps × 7200 × 0,8 e o '
    'resumo aparece antes do combate voltar',
    () async {
      final container = containerWith(
        saved: savedGame(),
        now: salvoEm.add(const Duration(hours: 2)),
      );
      addTearDown(container.dispose);

      // Antes do boot o combate já está bloqueado: nada roda enquanto a
      // ausência não é resolvida.
      expect(container.read(offlineControllerProvider).blocksCombat, isTrue);

      await container.read(offlineControllerProvider.notifier).boot();

      final offline = container.read(offlineControllerProvider);
      expect(offline.isBooting, isFalse);
      expect(offline.report, isNotNull, reason: 'nenhum resumo gerado');

      final report = offline.report!;
      expect(report.elapsedSeconds, 7200);
      expect(report.goldGained.toDouble(), closeTo(25 * 7200 * 0.8, 1));
      expect(report.wasCapped, isFalse);

      // CEN-M09-005: o combate só retoma depois de dispensar o resumo.
      expect(offline.blocksCombat, isTrue);
      container.read(offlineControllerProvider.notifier).dismissReport();
      expect(container.read(offlineControllerProvider).blocksCombat, isFalse);

      // E o ouro chegou à conta.
      final account = container.read(combatControllerProvider).account;
      expect(
        account.gold.toDouble(),
        greaterThanOrEqualTo(1000 + 25 * 7200 * 0.8),
      );
    },
  );

  test('o estado carregado substitui o jogo novo — heróis, posição e ouro', () async {
    final saved = savedGame();
    final container = containerWith(
      saved: saved,
      now: salvoEm.add(const Duration(minutes: 30)),
    );
    addTearDown(container.dispose);

    await container.read(offlineControllerProvider.notifier).boot();

    final session = container.read(combatControllerProvider);
    expect(session.heroes.map((h) => h.id), saved.heroes.map((h) => h.id));
    expect(session.account.rngSeed, 4242);
    expect(session.combat.monsters, isNotEmpty, reason: 'wave não recomeçou');
  });

  test('CEN-M09-E03: sem save, nenhum resumo e nenhuma simulação', () async {
    final container = containerWith(saved: null, now: salvoEm);
    addTearDown(container.dispose);

    await container.read(offlineControllerProvider.notifier).boot();

    final offline = container.read(offlineControllerProvider);
    expect(offline.report, isNull);
    expect(offline.blocksCombat, isFalse);
  });

  test('CEN-M09-003: 12 h de ausência rendem exatamente 8 h', () async {
    final container = containerWith(
      saved: savedGame(),
      now: salvoEm.add(const Duration(hours: 12)),
    );
    addTearDown(container.dispose);

    await container.read(offlineControllerProvider.notifier).boot();

    final report = container.read(offlineControllerProvider).report!;
    expect(report.elapsedSeconds, 8 * 3600);
    expect(report.wasCapped, isTrue);
  });

  test('CEN-M09-E02: relógio atrasado não gera resumo nem subtrai ouro', () async {
    final container = containerWith(
      saved: savedGame(),
      now: salvoEm.subtract(const Duration(hours: 5)),
    );
    addTearDown(container.dispose);

    await container.read(offlineControllerProvider.notifier).boot();

    final offline = container.read(offlineControllerProvider);
    expect(offline.report, isNull, reason: 'nada aconteceu, nada a mostrar');
    expect(offline.anomaly, ClockAnomaly.movedBackwards);
    expect(
      container.read(combatControllerProvider).account.gold.toDouble(),
      1000,
    );
  });

  test('os itens da ausência estão no inventário quando o resumo abre', () async {
    final container = containerWith(
      saved: savedGame(),
      now: salvoEm.add(const Duration(hours: 8)),
    );
    addTearDown(container.dispose);

    await container.read(offlineControllerProvider.notifier).boot();

    final report = container.read(offlineControllerProvider).report!;
    final inventory = container.read(lootControllerProvider).inventory;

    expect(report.wavesAdvanced, greaterThan(0));
    if (report.itemsObtained.isNotEmpty) {
      // SC-M09-04: o que sobreviveu à capacidade está disponível de imediato.
      expect(
        inventory.items.length + inventory.pendingDrops.length,
        greaterThan(0),
      );
    }
  });

  test('a taxa de ouro é apurada com o jogo aberto e vai para o save', () {
    final container = containerWith(saved: null, now: salvoEm);
    addTearDown(container.dispose);

    final controller = container.read(combatControllerProvider.notifier);
    final steps = (120 / CombatArena.fixedStepSeconds).round();
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }

    final snapshot = controller.snapshot(now: salvoEm);
    expect(
      snapshot.account.goldPerSecond > GameNumber.zero,
      isTrue,
      reason: 'sem taxa apurada, a ausência não renderia nada',
    );
    // A taxa é ouro por segundo, não o total acumulado.
    expect(
      snapshot.account.goldPerSecond < snapshot.account.gold,
      isTrue,
    );
  });
}

/// Repositório de teste: devolve o save dado e registra o que foi gravado.
class _FakeRepository implements SaveRepository {
  _FakeRepository(this._state);

  SaveState? _state;

  @override
  Future<SaveState?> load() async => _state;

  @override
  Future<void> save(SaveState state) async => _state = state;

  @override
  Future<void> clear() async => _state = null;
}
