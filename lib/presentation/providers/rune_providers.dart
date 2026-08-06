import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/engines/rune_tree_service.dart';
import '../../domain/entities/rune_node.dart';
import 'combat_providers.dart';

/// Árvore carregada do conteúdo.
///
/// Sobrescrito no `ProviderScope` junto das demais dependências; sem
/// sobrescrita devolve uma árvore vazia, que é o que os testes de combate
/// querem — nenhum bônus, nenhum nó.
final runeTreeProvider = Provider<RuneTreeDefinition>(
  (ref) => RuneTreeDefinition(nodes: const []),
);

final runeTreeServiceProvider = Provider<RuneTreeService>(
  (ref) => const RuneTreeService(),
);

/// Visão da árvore para a tela: o que está aberto, o que dá para abrir agora e
/// quanto custa desfazer tudo.
class RuneTreeView {
  const RuneTreeView({
    required this.tree,
    required this.unlockedIds,
    required this.unlockableIds,
    required this.availablePoints,
    required this.modifiers,
  });

  final RuneTreeDefinition tree;
  final Set<String> unlockedIds;

  /// Destacados na tela (CEN-M07-001).
  final Set<String> unlockableIds;

  final int availablePoints;
  final RuneModifiers modifiers;

  bool isUnlocked(String id) => unlockedIds.contains(id);
  bool isUnlockable(String id) => unlockableIds.contains(id);
}

/// Derivado do estado da conta: nada aqui é guardado, tudo é recalculado a
/// cada mudança — a mesma razão pela qual o respec em combate é seguro
/// (CEN-M07-E03).
final runeTreeViewProvider = Provider<RuneTreeView>((ref) {
  final account = ref.watch(combatControllerProvider).account;
  final tree = ref.watch(runeTreeProvider);
  final service = ref.watch(runeTreeServiceProvider);

  return RuneTreeView(
    tree: tree,
    unlockedIds: account.unlockedRuneNodeIds,
    unlockableIds: service.unlockableIds(account, tree),
    availablePoints: account.runePoints,
    modifiers: service.modifiersFor(account.unlockedRuneNodeIds, tree),
  );
});
