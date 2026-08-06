import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/numeric/number_format.dart';
import '../../domain/engines/rune_tree_service.dart';
import '../../domain/entities/rune_node.dart';
import '../../domain/entitlements/gem_sink.dart';
import '../providers/combat_providers.dart';
import '../providers/rune_providers.dart';

/// Árvore de runas em constelação (M07).
///
/// A disposição é derivada do próprio grafo, não de coordenadas no conteúdo: os
/// nós são distribuídos em anéis por distância à raiz, e as arestas desenhadas
/// entre eles. Guardar posições no JSON tornaria cada ajuste de balanceamento
/// um trabalho de diagramação.
class RuneTreeScreen extends ConsumerWidget {
  const RuneTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(runeTreeViewProvider);
    final account = ref.watch(combatControllerProvider).account;
    final service = ref.watch(runeTreeServiceProvider);
    final cost = service.respecCost(account.respecCount);

    return Scaffold(
      appBar: AppBar(title: const Text('Árvore de Runas')),
      body: Column(
        children: [
          _Header(view: view),
          Expanded(
            child: view.tree.nodes.isEmpty
                ? const Center(
                    child: Text(
                      'Árvore indisponível.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB4AAC6)),
                    ),
                  )
                : _Constellation(view: view),
          ),
          _RespecBar(
            // SC-M07-04: o custo é sempre exibido antes da confirmação.
            costLabel: NumberFormat.compact(cost),
            canAfford: account.gold >= cost,
            hasUnlocked: view.unlockedIds.isNotEmpty,
            gemCost: GemSink.costFor(RushTarget.runeRespec),
            onRespec: () => _confirmRespec(context, ref),
            onRespecWithGems: () => _respecWithGems(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRespec(BuildContext context, WidgetRef ref) async {
    final service = ref.read(runeTreeServiceProvider);
    final account = ref.read(combatControllerProvider).account;
    final cost = service.respecCost(account.respecCount);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Redistribuir runas'),
        content: Text(
          'Custa ${NumberFormat.withSeparators(cost)} de ouro e devolve todos '
          'os pontos gastos. O próximo respec custará mais.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Redistribuir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final result = ref.read(combatControllerProvider.notifier).respecRunes();
    _report(context, ref, result);
  }

  /// CEN-M12-009: gemas reduzem o **custo em ouro** do respec. Nenhum nó fica
  /// inacessível a quem não usa gemas — o desconto não toca na árvore.
  Future<void> _respecWithGems(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(combatControllerProvider.notifier);
    final spend = controller.spendGems(RushTarget.runeRespec);

    if (spend is GemSpendRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gemas insuficientes. Nada foi debitado.'),
        ),
      );
      return;
    }

    final result = controller.respecRunes(
      goldCostMultiplier: (spend as GemSpendApplied).goldCostMultiplier,
    );
    if (context.mounted) _report(context, ref, result);
  }

  void _report(BuildContext context, WidgetRef ref, RespecResult result) {
    if (result is RespecRejected && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.reason == RespecRejection.insufficientGold
                ? 'Ouro insuficiente. Nada foi cobrado.'
                : 'Não há nós desbloqueados para redistribuir.',
          ),
        ),
      );
    }
  }
}

/// Barra do respec. O custo fica sempre visível, mesmo quando o jogador não
/// tem ouro para pagá-lo (SC-M07-04).
class _RespecBar extends StatelessWidget {
  const _RespecBar({
    required this.costLabel,
    required this.canAfford,
    required this.hasUnlocked,
    required this.gemCost,
    required this.onRespec,
    required this.onRespecWithGems,
  });

  final String costLabel;
  final bool canAfford;
  final bool hasUnlocked;
  final int gemCost;
  final VoidCallback onRespec;
  final VoidCallback onRespecWithGems;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E1B2E),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Respec: $costLabel de ouro',
              style: TextStyle(
                fontSize: 12,
                color: canAfford
                    ? const Color(0xFFB4AAC6)
                    : const Color(0xFFD24B4B),
              ),
            ),
          ),
          TextButton(
            onPressed: hasUnlocked ? onRespecWithGems : null,
            child: Text('$gemCost gemas'),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: hasUnlocked && canAfford ? onRespec : null,
            child: const Text('Redistribuir'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.view});

  final RuneTreeView view;

  @override
  Widget build(BuildContext context) {
    final m = view.modifiers;
    String percent(double v) => '${((v - 1) * 100).toStringAsFixed(0)}%';

    return Container(
      width: double.infinity,
      color: const Color(0xFF272238),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${view.availablePoints} pontos disponíveis  ·  '
            '${view.unlockedIds.length}/${view.tree.nodes.length} nós',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE8B44A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dano +${percent(m.damageMultiplier)}  ·  '
            'Ouro +${percent(m.goldMultiplier)}  ·  '
            'XP +${percent(m.xpMultiplier)}'
            '${m.firstAttackAlwaysCritical ? "  ·  1º ataque crítico" : ""}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFB4AAC6)),
          ),
        ],
      ),
    );
  }
}

/// Desenha os nós em anéis e liga as arestas.
class _Constellation extends ConsumerWidget {
  const _Constellation({required this.view});

  final RuneTreeView view;

  static const double _nodeSize = 26;
  static const double _ringGap = 92;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = _layout(view.tree);
    final extent = positions.values.fold<double>(
      0,
      (acc, p) => math.max(acc, math.max(p.dx.abs(), p.dy.abs())),
    );
    final canvas = (extent + _ringGap) * 2;

    return InteractiveViewer(
      minScale: 0.3,
      maxScale: 2.5,
      boundaryMargin: const EdgeInsets.all(200),
      child: SizedBox(
        width: canvas,
        height: canvas,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _EdgePainter(
                  tree: view.tree,
                  positions: positions,
                  center: Offset(canvas / 2, canvas / 2),
                  unlocked: view.unlockedIds,
                ),
              ),
            ),
            for (final node in view.tree.nodes)
              Positioned(
                left: canvas / 2 + positions[node.id]!.dx - _nodeSize / 2,
                top: canvas / 2 + positions[node.id]!.dy - _nodeSize / 2,
                child: _NodeDot(
                  node: node,
                  isUnlocked: view.isUnlocked(node.id),
                  isUnlockable: view.isUnlockable(node.id),
                  onTap: () => _tap(context, ref, node),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _tap(BuildContext context, WidgetRef ref, RuneNode node) {
    final result = ref
        .read(combatControllerProvider.notifier)
        .unlockRuneNode(node.id);

    if (result is UnlockRejected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result.reason) {
            UnlockRejection.notAdjacent =>
              'Desbloqueie um nó vizinho antes deste.',
            UnlockRejection.insufficientPoints =>
              'Pontos de runa insuficientes.',
            UnlockRejection.alreadyUnlocked => 'Este nó já está desbloqueado.',
            UnlockRejection.unknownNode => 'Nó desconhecido.',
          }),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Posiciona por distância à raiz: anel por nível, ângulo distribuído dentro
  /// do anel. Determinístico, então a árvore não "dança" entre aberturas.
  static Map<String, Offset> _layout(RuneTreeDefinition tree) {
    final depth = <String, int>{};
    final queue = <String>[];

    for (final node in tree.nodes) {
      if (node.isRoot) {
        depth[node.id] = 0;
        queue.add(node.id);
      }
    }

    var head = 0;
    while (head < queue.length) {
      final id = queue[head++];
      final node = tree.byId(id);
      if (node == null) continue;
      for (final neighbor in node.neighborIds) {
        if (depth.containsKey(neighbor)) continue;
        depth[neighbor] = depth[id]! + 1;
        queue.add(neighbor);
      }
    }

    final byRing = <int, List<String>>{};
    for (final node in tree.nodes) {
      byRing.putIfAbsent(depth[node.id] ?? 0, () => []).add(node.id);
    }

    final positions = <String, Offset>{};
    for (final entry in byRing.entries) {
      final ring = entry.key;
      final ids = entry.value..sort();
      final radius = ring * _ringGap;
      for (var i = 0; i < ids.length; i++) {
        final angle = (i / ids.length) * 2 * math.pi;
        positions[ids[i]] = Offset(
          radius * math.cos(angle),
          radius * math.sin(angle),
        );
      }
    }
    return positions;
  }
}

class _EdgePainter extends CustomPainter {
  const _EdgePainter({
    required this.tree,
    required this.positions,
    required this.center,
    required this.unlocked,
  });

  final RuneTreeDefinition tree;
  final Map<String, Offset> positions;
  final Offset center;
  final Set<String> unlocked;

  @override
  void paint(Canvas canvas, Size size) {
    final dim = Paint()
      ..color = const Color(0xFF3A3548)
      ..strokeWidth = 1;
    final lit = Paint()
      ..color = const Color(0xFFE8B44A)
      ..strokeWidth = 2;

    for (final node in tree.nodes) {
      final from = positions[node.id];
      if (from == null) continue;
      for (final neighborId in node.neighborIds) {
        // Cada aresta é recíproca (V-RN-02); desenhar só uma direção evita
        // pintar tudo duas vezes.
        if (node.id.compareTo(neighborId) > 0) continue;
        final to = positions[neighborId];
        if (to == null) continue;

        canvas.drawLine(
          center + from,
          center + to,
          unlocked.contains(node.id) && unlocked.contains(neighborId)
              ? lit
              : dim,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EdgePainter old) => old.unlocked != unlocked;
}

class _NodeDot extends StatelessWidget {
  const _NodeDot({
    required this.node,
    required this.isUnlocked,
    required this.isUnlockable,
    required this.onTap,
  });

  final RuneNode node;
  final bool isUnlocked;
  final bool isUnlockable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isUnlocked
        ? const Color(0xFFE8B44A)
        : isUnlockable
        ? const Color(0xFF5FBF60)
        : const Color(0xFF3A3548);

    return Tooltip(
      message: '${node.id}\n'
          '${node.effect.type.id}'
          '${node.effect.type.isFlag ? "" : " ${(node.effect.value * 100).toStringAsFixed(1)}%"}'
          '\ncusto: ${node.cost}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: _Constellation._nodeSize,
          height: _Constellation._nodeSize,
          decoration: BoxDecoration(
            color: isUnlocked ? color : const Color(0xFF1E1B2E),
            border: Border.all(color: color, width: isUnlockable ? 2 : 1),
          ),
          child: node.effect.type.isFlag
              ? const Icon(Icons.star, size: 14, color: Color(0xFFEDE7DA))
              : null,
        ),
      ),
    );
  }
}
