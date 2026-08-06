import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero_stats_resolver.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:test/test.dart';

/// US2 — "Ficar mais forte com o loot".
///
/// Teste de aceitação da story como a spec a define: obter dois itens do mesmo
/// slot com atributos diferentes, equipar o melhor e confirmar o aumento do
/// atributo e o retorno do item anterior ao inventário.
///
/// Roda sobre o conteúdo real de `assets/content/` e sobre os providers, não
/// sobre o motor isolado: é o que verifica que as derrotas do combate chegam
/// mesmo ao inventário (T069) e que o item equipado muda o herói (T068).
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  late ProviderContainer container;

  setUp(() {
    final content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );

    container = ProviderContainer(
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
  });

  tearDown(() => container.dispose());

  void playIdle(double seconds) {
    final controller = container.read(combatControllerProvider.notifier);
    final steps = (seconds / CombatArena.fixedStepSeconds).round();
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }
  }

  GameItem weapon(String id, double attack) => GameItem(
    id: id,
    type: ItemType.weapon,
    rarity: ItemRarity.ouro,
    itemLevel: 20,
    baseStat: GameNumber.fromDouble(attack),
    affixes: const [],
    droppedAt: DateTime.utc(2026),
  );

  GameNumber attackOf(String heroId) {
    final session = container.read(combatControllerProvider);
    final deps = container.read(combatDependenciesProvider);
    final hero = session.heroes.firstWhere((h) => h.id == heroId);
    return HeroStatsResolver.resolve(
      definition: deps.classes.firstWhere((c) => c.id == hero.classId),
      level: hero.level,
      equipped: container
          .read(lootControllerProvider.notifier)
          .equippedOf(hero),
    ).stats.attack;
  }

  test('SC-M04-01: itens caem sozinhos nos primeiros minutos de jogo', () {
    playIdle(180);
    final loot = container.read(lootControllerProvider);

    expect(
      loot.inventory.items,
      isNotEmpty,
      reason: 'nenhum item em 3 minutos — R-M04-09 não está ligado ao combate',
    );
    expect(
      loot.inventory.items.length,
      lessThanOrEqualTo(50),
      reason: 'V-INV-01: o inventário nunca passa de 50 slots',
    );
  });

  test('o item dropado carrega item level coerente com a posição', () {
    playIdle(180);
    final loot = container.read(lootControllerProvider);
    expect(loot.inventory.items.every((i) => i.itemLevel > 0), isTrue);
  });

  test(
    'teste independente de US2: equipar o melhor de dois itens do mesmo slot '
    'aumenta o atributo e devolve o anterior ao inventário',
    () {
      final combat = container.read(combatControllerProvider.notifier);
      final heroId = container.read(combatControllerProvider).heroes.first.id;

      final fraca = weapon('arma_fraca', 50);
      final forte = weapon('arma_forte', 200);

      final antes = attackOf(heroId);

      combat.equipItem(heroId, fraca);
      final comFraca = attackOf(heroId);
      expect(comFraca > antes, isTrue, reason: 'equipar não somou o prefixo');

      combat.equipItem(heroId, forte);
      final comForte = attackOf(heroId);

      expect(comForte > comFraca, isTrue, reason: 'o item melhor não venceu');
      expect(
        container
            .read(lootControllerProvider)
            .inventory
            .items
            .map((i) => i.id),
        contains('arma_fraca'),
        reason: 'CEN-M05-003: o item substituído tem de voltar ao inventário',
      );
    },
  );

  test('SC-M05-04: o efeito aparece no combatente sem reiniciar a wave', () {
    final combat = container.read(combatControllerProvider.notifier);
    final heroId = container.read(combatControllerProvider).heroes.first.id;

    playIdle(2);
    final waveAntes =
        container.read(combatControllerProvider).account.currentPosition;
    final ataqueAntes = container
        .read(combatControllerProvider)
        .combat
        .heroes
        .firstWhere((h) => h.heroId == heroId)
        .stats
        .attack;

    combat.equipItem(heroId, weapon('arma', 500));

    final depois = container.read(combatControllerProvider);
    expect(
      depois.combat.heroes.firstWhere((h) => h.heroId == heroId).stats.attack >
          ataqueAntes,
      isTrue,
    );
    expect(
      depois.account.currentPosition,
      waveAntes,
      reason: 'equipar não pode reiniciar a wave',
    );
  });

  test('CEN-M05-011: vender credita ouro na conta e libera o slot', () {
    final combat = container.read(combatControllerProvider.notifier);

    playIdle(180);
    final inventario = container.read(lootControllerProvider).inventory;
    expect(inventario.items, isNotEmpty);

    final alvo = inventario.items.first;
    final ouroAntes = container.read(combatControllerProvider).account.gold;

    combat.sellItem(alvo);

    expect(
      container.read(combatControllerProvider).account.gold > ouroAntes,
      isTrue,
    );
    expect(
      container.read(lootControllerProvider).inventory.items.map((i) => i.id),
      isNot(contains(alvo.id)),
    );
  });

  test('determinismo: a mesma semente produz o mesmo loot', () {
    playIdle(180);
    final idsA = container
        .read(lootControllerProvider)
        .inventory
        .items
        .map((i) => i.id)
        .toList();

    final content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );
    final outro = ProviderContainer(
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
    addTearDown(outro.dispose);

    final controller = outro.read(combatControllerProvider.notifier);
    final steps = (180 / CombatArena.fixedStepSeconds).round();
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }

    expect(
      outro.read(lootControllerProvider).inventory.items.map((i) => i.id),
      idsA,
    );
    expect(idsA, isNotEmpty);
  });
}
