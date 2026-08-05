import '../../core/numeric/game_number.dart';

/// Tipos de efeito que um nó de runa pode conceder (R-M07-05).
///
/// Expressos como `(tipo, valor)` para que o balanceamento seja edição de dados
/// em `assets/content/rune_tree.json`, não recompilação — research.md R8.
enum RuneEffectType {
  damagePercent('damagePercent'),
  goldPercent('goldPercent'),
  xpPercent('xpPercent'),
  critChancePercent('critChancePercent'),
  attackSpeedPercent('attackSpeedPercent'),

  /// "O primeiro ataque de cada wave é crítico" (CEN-M07-007).
  firstAttackAlwaysCritical('firstAttackAlwaysCritical');

  const RuneEffectType(this.id);
  final String id;

  static RuneEffectType? fromId(String id) {
    for (final v in values) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Efeitos booleanos ignoram o campo de valor.
  bool get isFlag => this == RuneEffectType.firstAttackAlwaysCritical;
}

class RuneEffect {
  const RuneEffect({required this.type, required this.value});

  final RuneEffectType type;
  final double value;
}

/// Nó da árvore de runas. Conteúdo estático, não estado do jogador — o save
/// guarda apenas os IDs desbloqueados (research.md R8).
class RuneNode {
  const RuneNode({
    required this.id,
    required this.cost,
    required this.neighborIds,
    required this.isRoot,
    required this.effect,
  });

  /// ID estável entre versões: o save referencia por ele. Renomear um ID
  /// invalida o nó no save de todos os jogadores (V-PA-05).
  final String id;
  final int cost;
  final List<String> neighborIds;

  /// Nós raiz dispensam adjacência (R-M07-03).
  final bool isRoot;
  final RuneEffect effect;
}

/// Bônus agregados dos nós desbloqueados. Recalculado a cada mudança, o que
/// torna o respec durante combate seguro (CEN-M07-E03).
class RuneModifiers {
  const RuneModifiers({
    this.damageMultiplier = 1.0,
    this.goldMultiplier = 1.0,
    this.xpMultiplier = 1.0,
    this.bonusCritChance = 0.0,
    this.attackSpeedMultiplier = 1.0,
    this.firstAttackAlwaysCritical = false,
  });

  static const RuneModifiers none = RuneModifiers();

  final double damageMultiplier;
  final double goldMultiplier;
  final double xpMultiplier;
  final double bonusCritChance;
  final double attackSpeedMultiplier;
  final bool firstAttackAlwaysCritical;

  GameNumber applyDamage(GameNumber base) => base.scaled(damageMultiplier);
  GameNumber applyGold(GameNumber base) => base.scaled(goldMultiplier);
  GameNumber applyXp(GameNumber base) => base.scaled(xpMultiplier);
}

/// Árvore completa, carregada e validada no boot.
class RuneTreeDefinition {
  RuneTreeDefinition({required List<RuneNode> nodes})
    : nodes = List.unmodifiable(nodes),
      _byId = {for (final n in nodes) n.id: n};

  /// Mínimo exigido por R-M07-01. A violação falha no boot, não em produção.
  static const int minimumNodes = 200;

  final List<RuneNode> nodes;
  final Map<String, RuneNode> _byId;

  RuneNode? byId(String id) => _byId[id];
  bool contains(String id) => _byId.containsKey(id);

  /// V-RN-01: quantidade mínima de nós.
  bool get hasMinimumNodes => nodes.length >= minimumNodes;

  /// V-RN-02: toda aresta aparece nos dois nós.
  List<String> findAsymmetricEdges() {
    final problems = <String>[];
    for (final node in nodes) {
      for (final neighborId in node.neighborIds) {
        final neighbor = _byId[neighborId];
        if (neighbor == null) {
          problems.add('${node.id} -> $neighborId (vizinho inexistente)');
        } else if (!neighbor.neighborIds.contains(node.id)) {
          problems.add('${node.id} -> $neighborId (não é recíproca)');
        }
      }
    }
    return problems;
  }

  /// V-RN-03: todo nó alcançável a partir de alguma raiz. Árvore desconexa é
  /// erro de conteúdo que precisa aparecer em teste, não para o jogador.
  List<String> findUnreachableNodes() {
    final roots = nodes.where((n) => n.isRoot).map((n) => n.id);
    if (roots.isEmpty) return nodes.map((n) => n.id).toList();

    final visited = <String>{};
    final queue = [...roots];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      if (!visited.add(id)) continue;
      final node = _byId[id];
      if (node == null) continue;
      queue.addAll(node.neighborIds.where((n) => !visited.contains(n)));
    }
    return nodes.map((n) => n.id).where((id) => !visited.contains(id)).toList();
  }
}
