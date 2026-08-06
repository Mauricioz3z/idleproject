import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/engines/loot_generator.dart';
import '../../domain/entities/essence.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/hero.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entities/progress_position.dart';
import '../../domain/inventory/inventory_service.dart';
import 'combat_providers.dart';

/// Serviço de inventário compartilhado.
///
/// Vive num provider próprio porque guarda o catálogo de itens equipados
/// (`id → item`) que tanto o loot quanto o combate consultam — duas instâncias
/// significariam dois catálogos, e um item substituído sumiria dependendo de
/// quem processou a troca.
final inventoryServiceProvider = Provider<InventoryService>(
  (ref) => InventoryService(),
);

final lootGeneratorProvider = Provider<LootGenerator>(
  (ref) => const LootGenerator(),
);

/// Estado observável do inventário e dos drops recentes.
class LootState {
  const LootState({
    required this.inventory,
    required this.recentDrops,
    required this.dropSequence,
    required this.lastRareDrop,
    required this.inventoryFull,
  });

  factory LootState.initial() => LootState(
    inventory: Inventory.empty(),
    recentDrops: const [],
    dropSequence: 0,
    lastRareDrop: null,
    inventoryFull: false,
  );

  final Inventory inventory;

  /// Itens do último lote de drops, consumidos pela arena para o popup
  /// (CEN-M04-011).
  final List<GameItem> recentDrops;

  /// Contador de lotes. A camada visual compara este número para saber que há
  /// um lote novo, em vez de comparar listas de itens.
  final int dropSequence;

  /// Último item lendário ou superior — o que o widget de tela inicial exibe
  /// (CEN-M04-011, M11).
  final GameItem? lastRareDrop;

  /// Inventário cheio com drop retido (V-INV-03, CEN-M05-E01).
  final bool inventoryFull;

  LootState copyWith({
    Inventory? inventory,
    List<GameItem>? recentDrops,
    int? dropSequence,
    GameItem? lastRareDrop,
    bool? inventoryFull,
  }) => LootState(
    inventory: inventory ?? this.inventory,
    recentDrops: recentDrops ?? this.recentDrops,
    dropSequence: dropSequence ?? this.dropSequence,
    lastRareDrop: lastRareDrop ?? this.lastRareDrop,
    inventoryFull: inventoryFull ?? this.inventoryFull,
  );
}

/// Ouro e itens produzidos por um lote de derrotas, devolvidos a quem detém a
/// conta — o inventário não credita ouro sozinho.
class LootOutcome {
  const LootOutcome({
    required this.drops,
    required this.essences,
    required this.goldFromAutoSell,
  });

  static const LootOutcome none = LootOutcome(
    drops: [],
    essences: [],
    goldFromAutoSell: GameNumber.zero,
  );

  final List<GameItem> drops;
  final List<Essence> essences;
  final GameNumber goldFromAutoSell;

  bool get isEmpty => drops.isEmpty && essences.isEmpty;
}

/// Liga as derrotas do combate ao loot e ao inventário (T069).
class LootController extends Notifier<LootState> {
  late final LootGenerator _generator;
  late final InventoryService _inventory;
  late final RngStream _rng;

  @override
  LootState build() {
    final deps = ref.watch(combatDependenciesProvider);
    _generator = ref.watch(lootGeneratorProvider);
    _inventory = ref.watch(inventoryServiceProvider);
    // Fluxo próprio, forkado uma vez: o loot não pode se deslocar quando o
    // combate consome um sorteio a mais de crítico (research.md R5).
    _rng = RngStream(seed: deps.seed).fork('loot');
    return LootState.initial();
  }

  /// Avalia drop de item e de Essência para cada monstro derrotado
  /// (R-M04-09, R-M04-12) e faz a entrada automática no inventário.
  LootOutcome onDefeats({
    required List<MonsterDefeated> defeats,
    required ProgressPosition position,
    required DateTime now,
  }) {
    if (defeats.isEmpty) return LootOutcome.none;

    var inventory = state.inventory;
    final drops = <GameItem>[];
    final essences = <Essence>[];
    var gold = GameNumber.zero;
    var full = false;

    for (final defeat in defeats) {
      final template = defeat.monster.template;

      final item = _generator.rollDrop(
        monster: template,
        position: position,
        rng: _rng,
        // Boss concede item independentemente do sorteio (R-M04-11).
        guaranteed: defeat.monster.isBoss,
        now: now,
      );

      if (item != null) {
        final result = _inventory.intake(
          item,
          inventory,
          _inventory.equippedItems.toList(),
        );
        inventory = result.inventory;
        drops.add(item);
        if (result is IntakeAutoSold) gold = gold + result.goldGained;
        if (result is IntakePending) full = true;
      }

      final essence = _generator.rollEssence(
        monster: template,
        position: position,
        rng: _rng,
        now: now,
      );
      if (essence != null) {
        inventory = _inventory.intakeEssence(essence, inventory);
        essences.add(essence);
      }
    }

    final rare = drops.where((i) => i.rarity.isRareHighlight).toList();

    state = state.copyWith(
      inventory: inventory,
      recentDrops: drops,
      dropSequence: state.dropSequence + (drops.isEmpty ? 0 : 1),
      lastRareDrop: rare.isEmpty ? state.lastRareDrop : rare.last,
      inventoryFull: full,
    );

    return LootOutcome(
      drops: drops,
      essences: essences,
      goldFromAutoSell: gold,
    );
  }

  /// Equipa e devolve o herói atualizado. Quem detém a lista de heróis é o
  /// controlador de combate; aqui só muda o inventário.
  EquipResult equip(Hero hero, GameItem item) {
    final result = _inventory.equip(hero, item, state.inventory);
    _publish(result.inventory);
    return result;
  }

  UnequipResult unequip(Hero hero, ItemType slot) {
    final itemId = hero.equipment[slot];
    final result = _inventory.unequip(
      hero,
      slot,
      state.inventory,
      itemId == null ? null : _inventory.equippedById(itemId),
    );
    _publish(result.inventory);
    return result;
  }

  /// Venda manual. O ouro volta para quem detém a conta (CEN-M05-011).
  GameNumber sell(GameItem item) {
    final result = _inventory.sell(item, state.inventory);
    _publish(result.inventory);
    return result.goldGained;
  }

  void toggleFavorite(GameItem item) {
    _publish(_inventory.toggleFavorite(item, state.inventory));
  }

  /// Itens equipados de um herói, resolvidos pelo catálogo.
  List<GameItem> equippedOf(Hero hero) => [
    for (final id in hero.equippedItemIds)
      if (_inventory.equippedById(id) != null) _inventory.equippedById(id)!,
  ];

  GameItem? equippedInSlot(Hero hero, ItemType slot) {
    final id = hero.equipment[slot];
    return id == null ? null : _inventory.equippedById(id);
  }

  void _publish(Inventory inventory) {
    state = state.copyWith(
      inventory: inventory,
      // Abrir espaço encerra o aviso de lotação: o pendente já foi drenado por
      // `InventoryService` (V-INV-04).
      inventoryFull: inventory.hasPending,
    );
  }
}

final lootControllerProvider = NotifierProvider<LootController, LootState>(
  LootController.new,
);
