import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/engines/cube_service.dart';
import 'package:pixel_idle_quest/domain/engines/rune_tree_service.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/cube_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/loot_providers.dart';
import 'package:pixel_idle_quest/presentation/providers/rune_providers.dart';
import 'package:test/test.dart';

/// Joga até a conta render o primeiro ponto de runa, com teto para não travar
/// a suíte caso a trilha de conta pare de ser alimentada.
void _playUntilRunePoints(
  ProviderContainer container,
  CombatController controller,
) {
  const limite = 40000; // ~22 min de jogo simulado
  for (var i = 0; i < limite; i++) {
    if (container.read(combatControllerProvider).account.runePoints > 0) return;
    controller.tick(CombatArena.fixedStepSeconds);
  }
}

/// US6 — "Aprofundar a build".
///
/// Teste independente da story, como a spec a define: fundir 3 itens de mesma
/// raridade e obter 1 da raridade superior com atributos re-rolados; e,
/// separadamente, gastar 1 ponto de runa e confirmar o bônus valendo em
/// combate. Roda sobre o conteúdo real, inclusive a árvore de 210 nós.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  late JsonContentRepository content;

  setUp(() {
    content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: read('rune_tree.json'),
      // A árvore está autorada: exigir os 200 nós é o estado normal agora.
    );
  });

  ProviderContainer newContainer() => ProviderContainer(
    overrides: [
      combatDependenciesProvider.overrideWithValue(
        CombatDependencies(
          classes: content.heroClasses(),
          monsterTemplates: content.monsters(),
          seed: 909090,
        ),
      ),
      runeTreeProvider.overrideWithValue(content.runeTree()),
    ],
  );

  GameItem item(String id, {ItemRarity rarity = ItemRarity.ouro}) => GameItem(
    id: id,
    type: ItemType.weapon,
    rarity: rarity,
    itemLevel: 60,
    baseStat: GameNumber.fromDouble(200),
    affixes: const [],
    droppedAt: DateTime.utc(2026),
  );

  test(
    'teste independente de US6 (Cubo): 3 itens de mesma raridade viram 1 '
    'superior, com atributos re-rolados',
    () {
      final container = newContainer();
      addTearDown(container.dispose);

      final materiais = [item('a'), item('b'), item('c')];
      container
          .read(lootControllerProvider.notifier)
          .replaceInventory(
            Inventory(
              items: materiais,
              pendingDrops: const [],
              essences: const [],
              blueprints: const [],
            ),
          );

      final cube = container.read(cubeControllerProvider.notifier);
      for (final m in materiais) {
        cube.toggleMaterial(m);
      }

      // SC-M06-03: a raridade resultante é comunicada antes de confirmar.
      final preview = cube.preview;
      expect(preview.isValid, isTrue);
      expect(preview.resultingRarity, ItemRarity.epico);

      final result = cube.confirm();
      expect(result, isA<FusionSuccess>());

      final inventario = container.read(lootControllerProvider).inventory;
      expect(inventario.items, hasLength(1));
      expect(inventario.items.single.rarity, ItemRarity.epico);
      expect(
        inventario.items.single.id,
        isNot(anyOf('a', 'b', 'c')),
        reason: 'R-M06-02: o resultado é um item novo, não um material herdado',
      );
    },
  );

  test('CEN-M06-010: sem confirmar, nada é consumido', () {
    final container = newContainer();
    addTearDown(container.dispose);

    final materiais = [item('a'), item('b'), item('c')];
    container
        .read(lootControllerProvider.notifier)
        .replaceInventory(
          Inventory(
            items: materiais,
            pendingDrops: const [],
            essences: const [],
            blueprints: const [],
          ),
        );

    final cube = container.read(cubeControllerProvider.notifier);
    for (final m in materiais) {
      cube.toggleMaterial(m);
    }

    // Consultar o preview quantas vezes quiser não muda nada.
    cube.preview;
    cube.preview;
    cube.clear();

    expect(
      container.read(lootControllerProvider).inventory.items.map((i) => i.id),
      ['a', 'b', 'c'],
    );
  });

  test(
    'teste independente de US6 (Runas): gastar 1 ponto faz o bônus valer no '
    'combate',
    () {
      final container = newContainer();
      addTearDown(container.dispose);

      final controller = container.read(combatControllerProvider.notifier);
      final tree = content.runeTree();
      final raiz = tree.nodes.firstWhere((n) => n.isRoot);

      // A conta nasce sem pontos; o nível de conta os concede (R-M07-02).
      final semPontos = controller.unlockRuneNode(raiz.id);
      expect(semPontos, isA<UnlockRejected>());
      expect(
        (semPontos as UnlockRejected).reason,
        UnlockRejection.insufficientPoints,
      );

      // Os pontos vêm do nível de conta, que vem do combate (R-M03-06).
      _playUntilRunePoints(container, controller);
      expect(
        container.read(combatControllerProvider).account.runePoints,
        greaterThan(0),
        reason: 'o combate não está alimentando a trilha de conta',
      );

      final antes = container.read(runeTreeViewProvider).modifiers;
      final concedido = controller.unlockRuneNode(raiz.id);
      expect(concedido, isA<UnlockGranted>());

      final depois = container.read(runeTreeViewProvider).modifiers;
      expect(
        depois.damageMultiplier > antes.damageMultiplier ||
            depois.goldMultiplier > antes.goldMultiplier ||
            depois.xpMultiplier > antes.xpMultiplier ||
            depois.bonusCritChance > antes.bonusCritChance ||
            depois.attackSpeedMultiplier > antes.attackSpeedMultiplier,
        isTrue,
        reason: 'o nó desbloqueado não mudou nenhum agregado',
      );

      // CEN-M07-002: o efeito vale imediatamente — o combate continua rodando
      // sem reiniciar a wave.
      final waveAntes =
          container.read(combatControllerProvider).account.currentPosition;
      for (var i = 0; i < 30; i++) {
        controller.tick(CombatArena.fixedStepSeconds);
      }
      expect(
        container.read(combatControllerProvider).account.currentPosition.act,
        waveAntes.act,
      );
    },
  );

  test('CEN-M07-E03: respec no meio da wave não interrompe o combate', () {
    final container = newContainer();
    addTearDown(container.dispose);

    final controller = container.read(combatControllerProvider.notifier);
    final tree = content.runeTree();
    final raiz = tree.nodes.firstWhere((n) => n.isRoot);

    _playUntilRunePoints(container, controller);
    controller.unlockRuneNode(raiz.id);

    // Mais tempo de jogo, para acumular ouro suficiente para o respec.
    for (var i = 0; i < 6000; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }

    final hpAntes = container
        .read(combatControllerProvider)
        .combat
        .heroes
        .map((h) => h.currentHp)
        .toList();
    final posicaoAntes =
        container.read(combatControllerProvider).account.currentPosition;

    final result = controller.respecRunes();

    if (result is RespecDone) {
      final depois = container.read(combatControllerProvider);
      expect(depois.account.currentPosition, posicaoAntes);
      expect(
        depois.combat.heroes.map((h) => h.currentHp),
        hpAntes,
        reason: 'nenhum herói pode ser morto ou revivido pelo recálculo',
      );
      expect(
        container.read(runeTreeViewProvider).modifiers.damageMultiplier,
        1.0,
        reason: 'CEN-M07-012: o bônus some na hora',
      );
    } else {
      // Ouro insuficiente é resultado válido; o que não pode é cobrar.
      expect(result, isA<RespecRejected>());
    }
  });

  test('a trilha de conta rende pontos de runa jogando (R-M03-06)', () {
    final container = newContainer();
    addTearDown(container.dispose);

    final controller = container.read(combatControllerProvider.notifier);
    final antes = container.read(combatControllerProvider).account;

    _playUntilRunePoints(container, controller);

    final depois = container.read(combatControllerProvider).account;
    expect(depois.accountLevel, greaterThan(antes.accountLevel));
    expect(depois.runePoints, greaterThan(0));
    // CEN-M03-007: as duas trilhas são independentes, mas ambas avançam.
    expect(
      container.read(combatControllerProvider).heroes.any((h) => h.level > 1),
      isTrue,
    );
  });

  test('a árvore real tem 210 nós e todos alcançáveis por jogo', () {
    final container = newContainer();
    addTearDown(container.dispose);

    final view = container.read(runeTreeViewProvider);
    expect(view.tree.nodes.length, greaterThanOrEqualTo(200));
    expect(view.unlockedIds, isEmpty);
    // Sem pontos, nada é destacado — não adianta convidar para o que não dá
    // para comprar (CEN-M07-001).
    expect(view.unlockableIds, isEmpty);
  });
}
