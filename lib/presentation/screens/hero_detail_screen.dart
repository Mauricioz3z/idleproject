import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/entities/game_item.dart';
// Renomeado: `Hero` também é um widget do Flutter, e as duas classes convivem
// nesta tela.
import '../../domain/entities/hero.dart' as domain;
import '../../domain/entities/hero_stats_resolver.dart';
import '../game/components/loot_popup_component.dart';
import '../providers/combat_providers.dart';
import '../providers/loot_providers.dart';
import '../widgets/item_comparison.dart';

/// Detalhe do herói: os 7 slots de equipamento e os atributos efetivos
/// (R-M05-02).
///
/// Os atributos são recalculados a cada rebuild a partir de
/// [HeroStatsResolver], nunca guardados: é o que faz o efeito de equipar
/// aparecer na hora, sem reiniciar a wave (SC-M05-04).
class HeroDetailScreen extends ConsumerWidget {
  const HeroDetailScreen({required this.heroId, super.key});

  final String heroId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(combatControllerProvider);
    final loot = ref.watch(lootControllerProvider);
    final lootActions = ref.read(lootControllerProvider.notifier);
    final deps = ref.read(combatDependenciesProvider);

    final hero = session.heroes.where((h) => h.id == heroId).firstOrNull;
    if (hero == null) {
      return const Scaffold(body: Center(child: Text('Herói não encontrado')));
    }

    final definition = deps.classes.firstWhere((c) => c.id == hero.classId);
    final effective = HeroStatsResolver.resolve(
      definition: definition,
      level: hero.level,
      equipped: lootActions.equippedOf(hero),
    );

    return Scaffold(
      appBar: AppBar(title: Text('${hero.classId}  ·  Nv ${hero.level}')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _StatBlock(stats: effective),
          const SizedBox(height: 16),
          const Text(
            'Equipamento',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          for (final slot in ItemType.values)
            _SlotRow(
              slot: slot,
              hero: hero,
              equipped: lootActions.equippedInSlot(hero, slot),
              candidates: loot.inventory.items
                  .where((i) => i.type == slot)
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.stats});

  final HeroEffectiveStats stats;

  @override
  Widget build(BuildContext context) {
    String number(GameNumber n) => NumberFormat.compact(n);
    String percent(double v) => '${(v * 100).toStringAsFixed(1)}%';

    return Container(
      color: const Color(0xFF272238),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatLine(label: 'Ataque', value: number(stats.stats.attack)),
          _StatLine(label: 'Defesa', value: number(stats.stats.defense)),
          _StatLine(label: 'Vida', value: number(stats.stats.maxHp)),
          _StatLine(
            label: 'Crítico',
            value: percent(stats.bonusCritChance),
          ),
          _StatLine(
            label: 'Velocidade de ataque',
            value: '×${stats.attackSpeedMultiplier.toStringAsFixed(2)}',
          ),
        ],
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({
    required this.slot,
    required this.hero,
    required this.equipped,
    required this.candidates,
  });

  final ItemType slot;
  final domain.Hero hero;
  final GameItem? equipped;
  final List<GameItem> candidates;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final combat = ref.read(combatControllerProvider.notifier);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF272238),
        border: Border.all(
          color: equipped == null
              ? const Color(0xFF3A3548)
              : RarityPalette.of(equipped!.rarity),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              slot.id,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
            ),
          ),
          Expanded(
            child: equipped == null
                ? const Text(
                    'vazio',
                    style: TextStyle(fontSize: 11, color: Color(0xFF5D5670)),
                  )
                : Text(
                    '${equipped!.rarity.id}  iLv${equipped!.itemLevel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: RarityPalette.of(equipped!.rarity),
                    ),
                  ),
          ),
          if (equipped != null)
            TextButton(
              onPressed: () => combat.unequipSlot(hero.id, slot),
              child: const Text('Tirar'),
            ),
          if (candidates.isNotEmpty)
            TextButton(
              onPressed: () => _pick(context, ref),
              child: Text('Trocar (${candidates.length})'),
            ),
        ],
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    final combat = ref.read(combatControllerProvider.notifier);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1B2E),
      builder: (sheetContext) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final candidate in candidates) ...[
            ItemHeadline(
              item: candidate,
              trailing: ElevatedButton(
                onPressed: () {
                  combat.equipItem(hero.id, candidate);
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Equipar'),
              ),
            ),
            const SizedBox(height: 6),
            ItemComparison(candidate: candidate, equipped: equipped),
            const Divider(color: Color(0xFF3A3548)),
          ],
        ],
      ),
    );
  }
}
