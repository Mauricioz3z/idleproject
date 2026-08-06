import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/rng/rng_stream.dart';
import '../../domain/engines/cube_service.dart';
import '../../domain/entities/essence.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/inventory.dart';
import '../../domain/entitlements/gem_sink.dart';
import 'combat_providers.dart';
import 'loot_providers.dart';

/// Seleção corrente do Cubo, antes da confirmação.
///
/// Vive num controlador e não na tela para sobreviver a uma navegação: sair do
/// Cubo para conferir o inventário não pode desfazer a seleção.
class CubeSelection {
  const CubeSelection({
    required this.materials,
    required this.essence,
    required this.blueprint,
    required this.lastResult,
  });

  factory CubeSelection.empty() => const CubeSelection(
    materials: [],
    essence: null,
    blueprint: null,
    lastResult: null,
  );

  final List<GameItem> materials;
  final Essence? essence;
  final CubeBlueprint? blueprint;

  /// Resultado da última fusão confirmada, para a tela mostrar o que saiu.
  final FusionSuccess? lastResult;

  CubeSelection copyWith({
    List<GameItem>? materials,
    Essence? essence,
    bool clearEssence = false,
    CubeBlueprint? blueprint,
    bool clearBlueprint = false,
    FusionSuccess? lastResult,
    bool clearResult = false,
  }) => CubeSelection(
    materials: materials ?? this.materials,
    essence: clearEssence ? null : (essence ?? this.essence),
    blueprint: clearBlueprint ? null : (blueprint ?? this.blueprint),
    lastResult: clearResult ? null : (lastResult ?? this.lastResult),
  );
}

class CubeController extends Notifier<CubeSelection> {
  late final CubeService _cube;
  late final RngStream _rng;

  /// Descanso do Cubo entre fusões.
  ///
  /// CEN-M12-008 pressupõe "uma operação de cubo em andamento" que gemas
  /// aceleram; sem nenhuma espera, não haveria o que acelerar. O descanso vem
  /// **depois** da fusão, e não antes do resultado, de propósito: o item já foi
  /// sorteado e entregue na confirmação, então acelerar não pode mudar o que
  /// saiu (V-ENT-04).
  static const Duration fusionCooldown = Duration(minutes: 3);

  DateTime? _readyAt;

  /// Quanto falta para o Cubo aceitar outra fusão.
  Duration cooldownRemaining(DateTime now) {
    final readyAt = _readyAt;
    if (readyAt == null || !readyAt.isAfter(now)) return Duration.zero;
    return readyAt.difference(now);
  }

  bool isResting(DateTime now) => cooldownRemaining(now) > Duration.zero;

  /// Gasta gemas para encerrar o descanso (CEN-M12-008).
  GemSpendResult rushCooldown() {
    final result = ref
        .read(combatControllerProvider.notifier)
        .spendGems(RushTarget.cubeOperation);
    if (result is GemSpendApplied) _readyAt = null;
    return result;
  }

  @override
  CubeSelection build() {
    final deps = ref.watch(combatDependenciesProvider);
    _cube = CubeService(inventoryService: ref.watch(inventoryServiceProvider));
    // Fluxo próprio: fundir não pode deslocar o loot nem o crítico
    // (research.md R5).
    _rng = RngStream(seed: deps.seed).fork('cube');
    return CubeSelection.empty();
  }

  void toggleMaterial(GameItem item) {
    final selected = state.materials.any((m) => m.id == item.id);
    if (selected) {
      state = state.copyWith(
        materials: [
          for (final m in state.materials)
            if (m.id != item.id) m,
        ],
        clearResult: true,
      );
      return;
    }
    if (state.materials.length >= CubeService.materialsRequired) return;
    state = state.copyWith(
      materials: [...state.materials, item],
      clearResult: true,
    );
  }

  void chooseEssence(Essence? essence) => state = essence == null
      ? state.copyWith(clearEssence: true)
      : state.copyWith(essence: essence);

  void chooseBlueprint(CubeBlueprint? blueprint) => state = blueprint == null
      ? state.copyWith(clearBlueprint: true)
      : state.copyWith(blueprint: blueprint);

  void clear() => state = CubeSelection.empty();

  /// Salva o item como molde (R-M06-06).
  void imprint(GameItem source) {
    final blueprint = _cube.imprint(source);
    final inventory = ref.read(lootControllerProvider).inventory;
    ref
        .read(lootControllerProvider.notifier)
        .replaceInventory(
          inventory.copyWith(
            blueprints: [
              for (final b in inventory.blueprints)
                if (b.id != blueprint.id) b,
              blueprint,
            ],
          ),
        );
    state = state.copyWith(blueprint: blueprint);
  }

  /// O que a tela mostra antes da confirmação. Não consome nada.
  FusionPreview get preview => _cube.preview(
    materials: state.materials,
    essence: state.essence,
    blueprint: state.blueprint,
    equippedItemIds: _equippedIds,
  );

  /// Confirma a fusão (R-M06-09). É aqui, e só aqui, que o RNG é consumido.
  FusionResult confirm() {
    final now = DateTime.now();
    if (isResting(now)) {
      return FusionRejected(
        ref.read(lootControllerProvider).inventory,
        FusionRejection.cubeResting,
      );
    }

    final result = _cube.fuse(
      materials: state.materials,
      inventory: ref.read(lootControllerProvider).inventory,
      rng: _rng,
      now: DateTime.now(),
      essence: state.essence,
      blueprint: state.blueprint,
      equippedItemIds: _equippedIds,
    );

    if (result is FusionSuccess) {
      ref
          .read(lootControllerProvider.notifier)
          .replaceInventory(result.inventory);
      state = CubeSelection.empty().copyWith(lastResult: result);
      _readyAt = now.add(fusionCooldown);
    }
    return result;
  }

  Set<String> get _equippedIds => {
    for (final item in ref.read(lootControllerProvider.notifier).allEquippedItems)
      item.id,
  };
}

final cubeControllerProvider =
    NotifierProvider<CubeController, CubeSelection>(CubeController.new);
