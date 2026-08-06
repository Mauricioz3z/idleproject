import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_enums.dart';
import '../../domain/entities/essence.dart';
import '../../domain/entities/game_item.dart';
// Renomeado: `Hero` também é um widget do Flutter.
import '../../domain/entities/hero.dart' as domain;
import '../../domain/entities/inventory.dart';
import '../game/components/loot_popup_component.dart';
import '../providers/combat_providers.dart';
import '../providers/loot_providers.dart';
import '../widgets/item_comparison.dart';

/// Inventário: grade de 50 slots, cor por raridade e aba de Essências
/// (R-M05-01, SC-M04-03).
///
/// As Essências ficam numa aba separada porque não são equipamento e não
/// disputam os 50 slots (V-ES-01); misturá-las na mesma grade faria o jogador
/// ler "48/50" como se elas contassem.
class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loot = ref.watch(lootControllerProvider);
    final session = ref.watch(combatControllerProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Inventário  ${loot.inventory.items.length}/${Inventory.capacity}',
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Itens'),
              Tab(text: 'Essências'),
            ],
          ),
        ),
        body: Column(
          children: [
            if (loot.inventoryFull) const _FullInventoryBanner(),
            Expanded(
              child: TabBarView(
                children: [
                  _ItemGrid(
                    items: loot.inventory.items,
                    heroes: session.heroes,
                  ),
                  _EssenceList(essences: loot.inventory.essences),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CEN-M05-E01: o jogador precisa saber que há drop retido — o item não é
/// descartado, mas também não aparece na grade até haver espaço.
class _FullInventoryBanner extends StatelessWidget {
  const _FullInventoryBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF4A2A2A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: const Text(
        'Inventário cheio. Novos itens ficam retidos até você abrir espaço.',
        style: TextStyle(fontSize: 11, color: Color(0xFFE8B44A)),
      ),
    );
  }
}

class _ItemGrid extends ConsumerWidget {
  const _ItemGrid({required this.items, required this.heroes});

  final List<GameItem> items;
  final List<domain.Hero> heroes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum item ainda. Eles caem sozinhos.',
          style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          onTap: () => _openDetail(context, ref, item),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF272238),
              border: Border.all(color: RarityPalette.of(item.rarity)),
            ),
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.type.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: RarityPalette.of(item.rarity),
                  ),
                ),
                const Spacer(),
                Text(
                  'iLv${item.itemLevel}',
                  style: const TextStyle(fontSize: 9, color: Color(0xFFB4AAC6)),
                ),
                if (item.isFavorited)
                  const Text(
                    '★',
                    style: TextStyle(fontSize: 9, color: Color(0xFFE8B44A)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, GameItem item) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      builder: (sheetContext) =>
          _ItemSheet(item: item, heroes: heroes),
    );
  }
}

/// Detalhe do item: comparação com o equipado de cada herói e as ações de
/// equipar, favoritar e vender.
///
/// A comparação aparece já aberta, sem passo intermediário: SC-M05-01 dá ao
/// jogador no máximo 3 interações da tela de combate até equipar.
class _ItemSheet extends ConsumerWidget {
  const _ItemSheet({required this.item, required this.heroes});

  final GameItem item;
  final List<domain.Hero> heroes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loot = ref.read(lootControllerProvider.notifier);
    final combat = ref.read(combatControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ItemHeadline(item: item),
          const SizedBox(height: 12),
          for (final hero in heroes) ...[
            Text(
              hero.classId,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            ItemComparison(
              candidate: item,
              equipped: loot.equippedInSlot(hero, item.type),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () {
                  combat.equipItem(hero.id, item);
                  Navigator.of(context).pop();
                },
                child: const Text('Equipar'),
              ),
            ),
            const Divider(color: Color(0xFF3A3548)),
          ],
          Row(
            children: [
              TextButton(
                onPressed: () {
                  combat.toggleFavorite(item);
                  Navigator.of(context).pop();
                },
                child: Text(
                  item.isFavorited ? 'Desfavoritar' : 'Favoritar',
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  combat.sellItem(item);
                  Navigator.of(context).pop();
                },
                child: const Text('Vender'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EssenceList extends StatelessWidget {
  const _EssenceList({required this.essences});

  final List<Essence> essences;

  static const Map<AffixType, String> _labels = {
    AffixType.critChance: 'Crítico',
    AffixType.critDamage: 'Dano crítico',
    AffixType.attackSpeed: 'Velocidade de ataque',
    AffixType.goldFind: 'Ouro',
    AffixType.xpGain: 'XP',
    AffixType.fireResist: 'Resistência a fogo',
    AffixType.iceResist: 'Resistência a gelo',
    AffixType.lightningResist: 'Resistência a raio',
  };

  @override
  Widget build(BuildContext context) {
    if (essences.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma Essência. Elas caem raramente e não ocupam slot.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: essences.length,
      itemBuilder: (context, index) {
        final essence = essences[index];
        return ListTile(
          dense: true,
          title: Text(
            _labels[essence.guaranteedAffixType] ??
                essence.guaranteedAffixType.id,
            style: const TextStyle(fontSize: 13),
          ),
          subtitle: const Text(
            'Garante este sufixo numa fusão do Cubo',
            style: TextStyle(fontSize: 10, color: Color(0xFFB4AAC6)),
          ),
        );
      },
    );
  }
}
