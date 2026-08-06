import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/engines/loot_generator.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/wave_providers.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// US3 — "Avançar de wave, ato e dificuldade".
///
/// Teste independente da story, como a spec a define: progredir até a wave 10,
/// verificar o boss e o loot garantido, e confirmar a atualização do recorde de
/// maior wave. Roda sobre o conteúdo real de `assets/content/`.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  ProviderContainer newContainer() {
    final content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );
    return ProviderContainer(
      overrides: [
        combatDependenciesProvider.overrideWithValue(
          CombatDependencies(
            classes: content.heroClasses(),
            monsterTemplates: content.monsters(),
            seed: 20260805,
          ),
        ),
      ],
    );
  }

  late ProviderContainer container;

  setUp(() => container = newContainer());
  tearDown(() => container.dispose());

  test(
    'teste independente de US3: chegar à wave 10, enfrentar o boss, receber '
    'loot garantido e ver o recorde subir',
    () {
      final controller = container.read(combatControllerProvider.notifier);
      final steps = (900 / CombatArena.fixedStepSeconds).round();

      var viuBoss = false;
      var bossDerrotado = false;
      var bossRendeuLoot = false;

      for (var i = 0; i < steps; i++) {
        final sequenciaAntes = container.read(lootControllerProvider).dropSequence;
        controller.tick(CombatArena.fixedStepSeconds);

        final session = container.read(combatControllerProvider);
        if (session.combat.monsters.any((m) => m.isBoss)) viuBoss = true;

        final eventos = session.lastEvents;
        if (eventos == null) continue;
        if (!eventos.defeats.any((d) => d.monster.isBoss)) continue;

        bossDerrotado = true;
        // O drop do boss não passa pelo sorteio de chance (R-M04-11):
        // o lote de drops deste tick tem de existir.
        if (container.read(lootControllerProvider).dropSequence >
            sequenciaAntes) {
          bossRendeuLoot = true;
        } else {
          fail('boss derrotado sem loot — o drop garantido não foi aplicado');
        }
      }

      expect(viuBoss, isTrue, reason: 'nenhuma wave de boss em 15 min');
      expect(bossDerrotado, isTrue, reason: 'o boss nunca caiu');
      expect(bossRendeuLoot, isTrue);

      final account = container.read(combatControllerProvider).account;
      expect(account.currentPosition.globalWave, greaterThanOrEqualTo(10));
      expect(account.highestWave, greaterThanOrEqualTo(10));
    },
  );

  test('R-M04-11: o drop do boss dispensa o sorteio de chance', () {
    // Modificador zero: sem a garantia, este monstro nunca dropa nada.
    const generator = LootGenerator();
    const boss = ProgressPosition(difficulty: 1, act: 1, wave: 10);
    final rng = RngStream(seed: 3);

    for (var i = 0; i < 30; i++) {
      final item = generator.rollDrop(
        monster: TestContent.monster(isBoss: true, dropChanceModifier: 0),
        position: boss,
        rng: rng,
        guaranteed: true,
        now: DateTime.utc(2026),
      );
      expect(item, isNotNull);
    }
  });

  test('a garantia vale só para o boss da wave de boss', () {
    const policy = BossDropPolicy();
    final monstros = container
        .read(waveDirectorProvider)
        .spawnWave(
          const ProgressPosition(difficulty: 1, act: 1, wave: 10),
          RngStream(seed: 5),
        );
    final comuns = container
        .read(waveDirectorProvider)
        .spawnWave(
          const ProgressPosition(difficulty: 1, act: 1, wave: 9),
          RngStream(seed: 5),
        );

    expect(
      policy.isGuaranteed(
        const ProgressPosition(difficulty: 1, act: 1, wave: 10),
        monstros.first,
      ),
      isTrue,
    );
    expect(
      policy.isGuaranteed(
        const ProgressPosition(difficulty: 1, act: 1, wave: 9),
        comuns.first,
      ),
      isFalse,
      reason: 'monstro comum não pode ter drop garantido',
    );
  });

  test('CEN-M08-011: voltar a um ato concluído não regride recordes', () {
    final controller = container.read(combatControllerProvider.notifier);

    // Simula um veterano: o único caminho autorizado a mexer na posição é o
    // avanço de wave, então o estado é montado pelo próprio diretor.
    final director = container.read(waveDirectorProvider);
    var account = container.read(combatControllerProvider).account.copyWith(
      currentPosition: const ProgressPosition(difficulty: 2, act: 2, wave: 30),
      highestAct: 3,
      highestDifficulty: 2,
      highestWave: 300,
    );
    account = WaveDirector.select(
      account,
      const ProgressPosition(difficulty: 1, act: 1, wave: 1),
    );

    expect(account.currentPosition.act, 1);
    expect(account.currentPosition.difficulty, 1);
    expect(account.highestWave, 300);
    expect(account.highestAct, 3);
    expect(account.highestDifficulty, 2);
    expect(
      director.advance(account.currentPosition, account).position.wave,
      2,
      reason: 'o combate segue normalmente no conteúdo antigo',
    );

    // E o controlador recusa conteúdo não desbloqueado (V-PA-03 preservado).
    final antes = container.read(combatControllerProvider).account;
    controller.selectPosition(
      const ProgressPosition(difficulty: 9, act: 1, wave: 1),
    );
    expect(
      container.read(combatControllerProvider).account.currentPosition,
      antes.currentPosition,
    );
  });

  test('CEN-M08-004: a wave 95 é mais dura que a wave 5 no mesmo ato', () {
    final director = container.read(waveDirectorProvider);
    final cedo = director.spawnWave(
      const ProgressPosition(difficulty: 1, act: 1, wave: 5),
      RngStream(seed: 9),
    );
    final tarde = director.spawnWave(
      const ProgressPosition(difficulty: 1, act: 1, wave: 95),
      RngStream(seed: 9),
    );

    expect(tarde.first.stats.maxHp > cedo.first.stats.maxHp, isTrue);
    expect(
      tarde.length,
      greaterThanOrEqualTo(cedo.length),
      reason: 'a pressão da wave também cresce em quantidade',
    );
  });

  test('determinismo: a mesma semente produz a mesma sequência de waves', () {
    final a = container.read(waveDirectorProvider);
    final outro = newContainer();
    addTearDown(outro.dispose);
    final b = outro.read(waveDirectorProvider);

    for (var wave = 1; wave <= 30; wave++) {
      final position = ProgressPosition(difficulty: 1, act: 1, wave: wave);
      final ma = a.spawnWave(position, RngStream(seed: 77));
      final mb = b.spawnWave(position, RngStream(seed: 77));

      expect(ma.map((m) => m.template.id), mb.map((m) => m.template.id));
      expect(ma.map((m) => m.instanceId), mb.map((m) => m.instanceId));
    }
  });
}
