import '../entities/player_account.dart';

/// O que as gemas podem acelerar (FR-029).
enum RushTarget { cubeOperation, runeRespec }

enum GemSpendRejection { insufficientGems }

sealed class GemSpendResult {
  const GemSpendResult(this.account);
  final PlayerAccount account;
}

class GemSpendApplied extends GemSpendResult {
  const GemSpendApplied(
    super.account, {
    required this.target,
    required this.gemsSpent,
    required this.goldCostMultiplier,
  });

  final RushTarget target;
  final int gemsSpent;

  /// Desconto aplicado ao custo em ouro da operação, quando ela tem um
  /// (CEN-M12-009). `1.0` significa sem desconto.
  final double goldCostMultiplier;
}

class GemSpendRejected extends GemSpendResult {
  const GemSpendRejected(super.account, this.reason);
  final GemSpendRejection reason;
}

/// Gasto de gemas para acelerar operações (FR-029, V-ENT-04).
///
/// **A propriedade que separa aceleração de pay-to-win**: gastar gemas não toca
/// no sorteio. O RNG das operações é consumido na confirmação, não na
/// conclusão, então a distribuição de resultados de uma operação acelerada é
/// idêntica à da mesma operação aguardada. Repare que este arquivo não importa
/// nada de `engines/` — ele não teria como influenciar um resultado nem se
/// quisesse.
class GemSink {
  const GemSink();

  static const int cubeRushCost = 20;
  static const int respecRushCost = 35;

  /// Desconto no ouro do respec acelerado. CEN-M12-009 admite "mais rápido
  /// **ou** com custo reduzido em ouro"; o respec não tem espera, então o que
  /// as gemas compram aqui é o desconto.
  static const double respecGoldDiscount = 0.5;

  static int costFor(RushTarget target) => switch (target) {
    RushTarget.cubeOperation => cubeRushCost,
    RushTarget.runeRespec => respecRushCost,
  };

  GemSpendResult spendToRush(PlayerAccount account, RushTarget target) {
    final cost = costFor(target);
    if (account.gems < cost) {
      return GemSpendRejected(account, GemSpendRejection.insufficientGems);
    }

    return GemSpendApplied(
      account.copyWith(gems: account.gems - cost),
      target: target,
      gemsSpent: cost,
      goldCostMultiplier: switch (target) {
        RushTarget.runeRespec => respecGoldDiscount,
        RushTarget.cubeOperation => 1.0,
      },
    );
  }
}
