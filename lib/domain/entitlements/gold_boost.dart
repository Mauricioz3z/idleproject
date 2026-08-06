import '../../core/numeric/game_number.dart';
import '../entities/entitlements.dart';

/// Aplicação do bônus de +50% de ouro por 4 h (R-M12-03).
///
/// Existe como função única e não como dois cálculos porque o bônus vale nos
/// **dois** caminhos de ouro do jogo: o combate ao vivo e a fórmula fechada do
/// offline. Duplicar a multiplicação abriria espaço para o jogador ver o bônus
/// valer numa tela e não na outra — e a divergência apareceria justamente
/// depois de ele ter assistido a um anúncio para consegui-lo.
abstract final class GoldBoost {
  static GameNumber apply(
    GameNumber base,
    Entitlements entitlements,
    DateTime now,
  ) {
    final multiplier = entitlements.goldMultiplier(now);
    return multiplier == 1.0 ? base : base.scaled(multiplier);
  }
}
