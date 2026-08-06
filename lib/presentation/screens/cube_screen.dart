import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engines/cube_service.dart';
import '../../domain/entities/essence.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/inventory.dart';
import '../game/components/loot_popup_component.dart';
import '../providers/cube_providers.dart';
import '../providers/loot_providers.dart';
import '../widgets/item_comparison.dart';

/// Cubo de crafting (M06).
///
/// A tela é construída em torno de uma regra: **nada é consumido antes da
/// confirmação** (R-M06-09, CEN-M06-010). O preview mostra a raridade
/// resultante e a chance de recriação por molde (SC-M06-03) sem sortear nada, e
/// o botão de confirmar é o único caminho que toca no inventário.
class CubeScreen extends ConsumerWidget {
  const CubeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(cubeControllerProvider);
    final controller = ref.read(cubeControllerProvider.notifier);
    final inventory = ref.watch(lootControllerProvider).inventory;
    final preview = controller.preview;

    return Scaffold(
      appBar: AppBar(title: const Text('Cubo')),
      body: Column(
        children: [
          _MaterialSlots(materials: selection.materials),
          _PreviewPanel(preview: preview),
          if (selection.lastResult != null)
            _ResultBanner(result: selection.lastResult!),
          const Divider(height: 1, color: Color(0xFF3A3548)),
          Expanded(
            child: DefaultTabController(
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Materiais'),
                      Tab(text: 'Essências'),
                      Tab(text: 'Moldes'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _MaterialPicker(
                          items: inventory.items,
                          selectedIds: {
                            for (final m in selection.materials) m.id,
                          },
                          onToggle: controller.toggleMaterial,
                          onImprint: controller.imprint,
                        ),
                        _EssencePicker(
                          essences: inventory.essences,
                          selected: selection.essence,
                          onChoose: controller.chooseEssence,
                        ),
                        _BlueprintPicker(
                          blueprints: inventory.blueprints,
                          selected: selection.blueprint,
                          onChoose: controller.chooseBlueprint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _ConfirmBar(
            preview: preview,
            onConfirm: () => _confirm(context, ref),
            onClear: controller.clear,
          ),
        ],
      ),
    );
  }

  /// CEN-M06-010: confirmação explícita antes de qualquer consumo, e cancelar
  /// mantém tudo intacto.
  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(cubeControllerProvider.notifier);
    final preview = controller.preview;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar fusão'),
        content: Text(
          'Os 3 materiais serão consumidos e não voltam. '
          'O resultado será de raridade ${preview.resultingRarity?.id}.'
          '${preview.consumesEssence ? "\n\nA Essência é consumida mesmo que o "
              "resultado não agrade." : ""}'
          '${preview.recreationChance > 0 ? "\n\nChance de recriar o molde: "
              "${(preview.recreationChance * 100).toStringAsFixed(0)}%." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Fundir'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final result = controller.confirm();

    if (result is FusionRejected && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_rejectionMessage(result.reason))),
      );
    }
  }

  static String _rejectionMessage(FusionRejection reason) => switch (reason) {
    FusionRejection.notThreeItems =>
      'A fusão precisa de exatamente 3 materiais.',
    FusionRejection.mixedRarities =>
      'Os 3 materiais precisam ter a mesma raridade.',
    FusionRejection.maxRarity =>
      'Cósmico é a raridade máxima e não pode ser fundido.',
    FusionRejection.itemEquipped =>
      'Desequipe o item antes de usá-lo como material.',
    FusionRejection.materialNotInInventory =>
      'Um dos materiais não está mais no inventário.',
  };
}

class _MaterialSlots extends StatelessWidget {
  const _MaterialSlots({required this.materials});

  final List<GameItem> materials;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          for (var i = 0; i < CubeService.materialsRequired; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF272238),
                    border: Border.all(
                      color: i < materials.length
                          ? RarityPalette.of(materials[i].rarity)
                          : const Color(0xFF3A3548),
                    ),
                  ),
                  child: i < materials.length
                      ? Text(
                          '${materials[i].rarity.id}\n${materials[i].type.id}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: RarityPalette.of(materials[i].rarity),
                          ),
                        )
                      : const Text(
                          'vazio',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5D5670),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.preview});

  final FusionPreview preview;

  @override
  Widget build(BuildContext context) {
    if (!preview.isValid) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          preview.rejection == null
              ? ''
              : CubeScreen._rejectionMessage(preview.rejection!),
          style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Text(
            'Resultado: ${preview.resultingRarity!.id}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: RarityPalette.of(preview.resultingRarity!),
            ),
          ),
          const Spacer(),
          if (preview.recreationChance > 0)
            Text(
              'molde: ${(preview.recreationChance * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
            ),
        ],
      ),
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});

  final FusionSuccess result;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF272238),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ItemHeadline(item: result.item),
          if (result.recreatedBlueprint)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'O molde foi recriado.',
                style: TextStyle(fontSize: 11, color: Color(0xFF5FBF60)),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'O molde não foi recriado desta vez.',
                style: TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
              ),
            ),
        ],
      ),
    );
  }
}

class _MaterialPicker extends StatelessWidget {
  const _MaterialPicker({
    required this.items,
    required this.selectedIds,
    required this.onToggle,
    required this.onImprint,
  });

  final List<GameItem> items;
  final Set<String> selectedIds;
  final void Function(GameItem) onToggle;
  final void Function(GameItem) onImprint;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Sem itens para fundir.',
          style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final selected = selectedIds.contains(item.id);
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? const Color(0xFFE8B44A)
                  : const Color(0xFF3A3548),
            ),
          ),
          child: ListTile(
            dense: true,
            onTap: () => onToggle(item),
            title: ItemHeadline(item: item),
            trailing: IconButton(
              tooltip: 'Imprimir molde',
              icon: const Icon(Icons.content_copy, size: 18),
              onPressed: () => onImprint(item),
            ),
          ),
        );
      },
    );
  }
}

class _EssencePicker extends StatelessWidget {
  const _EssencePicker({
    required this.essences,
    required this.selected,
    required this.onChoose,
  });

  final List<Essence> essences;
  final Essence? selected;
  final void Function(Essence?) onChoose;

  @override
  Widget build(BuildContext context) {
    if (essences.isEmpty) {
      return const Center(
        child: Text(
          'Nenhuma Essência. Elas garantem um sufixo na fusão.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final essence in essences)
          _ChoiceTile(
            isSelected: selected?.id == essence.id,
            onTap: () =>
                onChoose(selected?.id == essence.id ? null : essence),
            title: 'Garante ${essence.guaranteedAffixType.id}',
            subtitle: 'Consumida na fusão, qualquer que seja o resultado.',
          ),
      ],
    );
  }
}

class _BlueprintPicker extends StatelessWidget {
  const _BlueprintPicker({
    required this.blueprints,
    required this.selected,
    required this.onChoose,
  });

  final List<CubeBlueprint> blueprints;
  final CubeBlueprint? selected;
  final void Function(CubeBlueprint?) onChoose;

  @override
  Widget build(BuildContext context) {
    if (blueprints.isEmpty) {
      return const Center(
        child: Text(
          'Nenhum molde salvo. Use "Imprimir" num item para guardar a '
          'combinação de atributos dele.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        for (final blueprint in blueprints)
          _ChoiceTile(
            isSelected: selected?.id == blueprint.id,
            onTap: () =>
                onChoose(selected?.id == blueprint.id ? null : blueprint),
            title: blueprint.type.id,
            subtitle: blueprint.targetAffixTypes.isEmpty
                ? 'sem sufixos'
                : blueprint.targetAffixTypes.map((a) => a.id).join(', '),
          ),
      ],
    );
  }
}

/// Item de escolha única com desmarcar por toque.
///
/// Escrito à mão em vez de `RadioListTile` porque a escolha aqui é opcional: o
/// jogador precisa poder tirar a Essência ou o molde da fusão depois de
/// tê-los escolhido, e um grupo de rádio não desmarca.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.isSelected,
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  final bool isSelected;
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isSelected
              ? const Color(0xFFE8B44A)
              : const Color(0xFF3A3548),
        ),
      ),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Icon(
          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
          size: 18,
          color: isSelected
              ? const Color(0xFFE8B44A)
              : const Color(0xFF5D5670),
        ),
        title: Text(title, style: const TextStyle(fontSize: 12)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: Color(0xFFB4AAC6)),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar({
    required this.preview,
    required this.onConfirm,
    required this.onClear,
  });

  final FusionPreview preview;
  final VoidCallback onConfirm;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1B2E),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          TextButton(onPressed: onClear, child: const Text('Limpar')),
          const Spacer(),
          ElevatedButton(
            onPressed: preview.isValid ? onConfirm : null,
            child: const Text('Fundir'),
          ),
        ],
      ),
    );
  }
}
