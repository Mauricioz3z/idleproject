import 'dart:math' as math;

import '../../core/numeric/game_number.dart';
import '../entities/player_account.dart';
import '../entities/rune_node.dart';

enum UnlockRejection {
  notAdjacent,
  insufficientPoints,
  alreadyUnlocked,
  unknownNode,
}

/// Resultado de um desbloqueio. A recusa devolve a conta intacta, para que
/// quem chama não precise guardar o estado anterior (CEN-M07-003/004).
sealed class UnlockResult {
  const UnlockResult(this.account);
  final PlayerAccount account;
}

class UnlockGranted extends UnlockResult {
  const UnlockGranted(super.account, {required this.node});
  final RuneNode node;
}

class UnlockRejected extends UnlockResult {
  const UnlockRejected(super.account, this.reason);
  final UnlockRejection reason;
}

enum RespecRejection { insufficientGold, nothingUnlocked }

sealed class RespecResult {
  const RespecResult(this.account);
  final PlayerAccount account;
}

class RespecDone extends RespecResult {
  const RespecDone(
    super.account, {
    required this.pointsRefunded,
    required this.goldSpent,
  });

  final int pointsRefunded;
  final GameNumber goldSpent;
}

class RespecRejected extends RespecResult {
  const RespecRejected(super.account, this.reason);
  final RespecRejection reason;
}

/// Árvore de runas (M07).
///
/// Progressão de **conta**, não de herói: os bônus valem para todos os heróis,
/// inclusive os que entrarem na formação depois (R-M07-06, CEN-M07-008). É por
/// isso que [modifiersFor] recebe apenas o conjunto de IDs — não existe estado
/// por herói a consultar.
class RuneTreeService {
  const RuneTreeService();

  /// Custo do primeiro respec, e passo de crescimento.
  ///
  /// A fórmula não consta do documento de origem (suposição de M07); o que a
  /// spec exige é apenas que cresça estritamente (R-M07-08, CEN-M07-010).
  static const double baseRespecCost = 10000;
  static const double respecGrowth = 2.2;

  /// R-M07-08: estritamente crescente em [respecCount].
  GameNumber respecCost(int respecCount) => GameNumber.fromDouble(
    baseRespecCost * math.pow(respecGrowth, respecCount).toDouble(),
  );

  /// Desbloqueia um nó, consumindo pontos.
  UnlockResult unlock(
    String nodeId,
    PlayerAccount account,
    RuneTreeDefinition tree,
  ) {
    final node = tree.byId(nodeId);
    if (node == null) {
      return UnlockRejected(account, UnlockRejection.unknownNode);
    }
    if (account.unlockedRuneNodeIds.contains(nodeId)) {
      return UnlockRejected(account, UnlockRejection.alreadyUnlocked);
    }
    if (account.runePoints < node.cost) {
      return UnlockRejected(account, UnlockRejection.insufficientPoints);
    }
    if (!_isReachable(node, account.unlockedRuneNodeIds)) {
      return UnlockRejected(account, UnlockRejection.notAdjacent);
    }

    return UnlockGranted(
      account.copyWith(
        runePoints: account.runePoints - node.cost,
        unlockedRuneNodeIds: {...account.unlockedRuneNodeIds, nodeId},
      ),
      node: node,
    );
  }

  /// Nós que o jogador pode abrir agora (CEN-M07-001).
  ///
  /// Vazio quando não há pontos: destacar o que não dá para comprar é convite
  /// para um toque que só produz recusa.
  Set<String> unlockableIds(PlayerAccount account, RuneTreeDefinition tree) {
    if (account.runePoints <= 0) return const {};
    return {
      for (final node in tree.nodes)
        if (!account.unlockedRuneNodeIds.contains(node.id) &&
            node.cost <= account.runePoints &&
            _isReachable(node, account.unlockedRuneNodeIds))
          node.id,
    };
  }

  /// Devolve **todos** os pontos gastos e cobra ouro (R-M07-07).
  ///
  /// Ouro insuficiente recusa sem debitar e sem devolver ponto algum
  /// (CEN-M07-011): meio respec deixaria a conta num estado que nenhuma regra
  /// descreve.
  RespecResult respec(PlayerAccount account, RuneTreeDefinition tree) {
    if (account.unlockedRuneNodeIds.isEmpty) {
      return RespecRejected(account, RespecRejection.nothingUnlocked);
    }

    final cost = respecCost(account.respecCount);
    if (account.gold < cost) {
      return RespecRejected(account, RespecRejection.insufficientGold);
    }

    // Reembolsa pelo custo de cada nó, não pela contagem: um nó de 4 pontos
    // devolve 4. IDs órfãos de uma versão antiga do conteúdo não devolvem nada
    // aqui — quem os limpa é a validação de carga (V-PA-05).
    var refunded = 0;
    for (final id in account.unlockedRuneNodeIds) {
      refunded += tree.byId(id)?.cost ?? 0;
    }

    return RespecDone(
      account.copyWith(
        gold: account.gold - cost,
        runePoints: account.runePoints + refunded,
        unlockedRuneNodeIds: const {},
        respecCount: account.respecCount + 1,
      ),
      pointsRefunded: refunded,
      goldSpent: cost,
    );
  }

  /// Agrega os efeitos dos nós desbloqueados (R-M07-06).
  ///
  /// Função pura, recalculada a cada mudança em vez de mantida como estado. É
  /// isso que torna o respec durante combate seguro (CEN-M07-E03): não há bônus
  /// aplicado ao herói para desfazer, só um agregado que passa a ser outro.
  ///
  /// Percentuais do mesmo tipo **somam** antes de multiplicar: com 20 nós de
  /// +10%, multiplicar daria ×6,7 em vez de ×3, e a curva de balanceamento
  /// fugiria do controle sem ninguém perceber.
  RuneModifiers modifiersFor(Set<String> unlockedIds, RuneTreeDefinition tree) {
    var damage = 0.0;
    var gold = 0.0;
    var xp = 0.0;
    var crit = 0.0;
    var attackSpeed = 0.0;
    var firstAttackCritical = false;

    for (final id in unlockedIds) {
      // ID desconhecido é conteúdo de outra versão: ignorar é o comportamento
      // de V-PA-05, não um erro.
      final node = tree.byId(id);
      if (node == null) continue;

      final effect = node.effect;
      switch (effect.type) {
        case RuneEffectType.damagePercent:
          damage += effect.value;
        case RuneEffectType.goldPercent:
          gold += effect.value;
        case RuneEffectType.xpPercent:
          xp += effect.value;
        case RuneEffectType.critChancePercent:
          crit += effect.value;
        case RuneEffectType.attackSpeedPercent:
          attackSpeed += effect.value;
        case RuneEffectType.firstAttackAlwaysCritical:
          firstAttackCritical = true;
      }
    }

    return RuneModifiers(
      damageMultiplier: 1 + damage,
      goldMultiplier: 1 + gold,
      xpMultiplier: 1 + xp,
      bonusCritChance: crit,
      attackSpeedMultiplier: 1 + attackSpeed,
      firstAttackAlwaysCritical: firstAttackCritical,
    );
  }

  /// Raiz dispensa adjacência; os demais exigem um vizinho já aberto
  /// (R-M07-03).
  bool _isReachable(RuneNode node, Set<String> unlocked) =>
      node.isRoot || node.neighborIds.any(unlocked.contains);
}
