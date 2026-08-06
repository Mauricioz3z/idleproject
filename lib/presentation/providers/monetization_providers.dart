import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entitlements/entitlement_service.dart';
import '../../services/ad_service.dart';
import '../../services/iap_service.dart';
import 'combat_providers.dart';

final adServiceProvider = Provider<AdService>((ref) {
  final service = AdService();
  ref.onDispose(service.dispose);
  return service;
});

final iapServiceProvider = Provider<IapService>((ref) {
  final service = IapService();
  ref.onDispose(service.dispose);
  return service;
});

/// Resultado de uma oferta de anúncio, para a tela dar retorno ao jogador.
class AdOutcome {
  const AdOutcome({required this.granted, this.failure});

  final bool granted;
  final AdFailure? failure;
}

/// Ponte entre as ofertas e o estado do jogo.
///
/// A regra que este controlador existe para garantir: **a recompensa só é
/// aplicada no callback de visualização completa**. O `AdService` chama
/// `onEarned` só nesse ponto, e é dali que sai a única chamada a
/// `grantAdReward` (R-M12-08, CEN-M12-004).
class MonetizationController extends Notifier<void> {
  @override
  void build() {}

  /// Oferece um recompensado. Falhar nunca custa nada ao jogador (R-M12-07).
  Future<AdOutcome> watchRewarded(AdReward reward) async {
    var granted = false;

    final failure = await ref.read(adServiceProvider).showRewarded(
      reward: reward,
      onEarned: (earned) {
        granted = true;
        ref.read(combatControllerProvider.notifier).grantAdReward(earned);
      },
    );

    return AdOutcome(granted: granted, failure: failure);
  }

  /// Chamado na virada de ato. Exibe o intersticial só quando a regra permite.
  Future<void> onActTransition() async {
    final shouldShow = ref
        .read(combatControllerProvider.notifier)
        .registerActTransition();
    if (!shouldShow) return;
    await ref.read(adServiceProvider).showInterstitial();
  }

  /// Liga a loja e restaura compras no boot (CEN-M12-E04).
  Future<void> initializeStore() async {
    await ref.read(iapServiceProvider).initialize(
      onPurchased: (id, dlcClassId) => ref
          .read(combatControllerProvider.notifier)
          .applyPurchase(id, dlcClassId: dlcClassId),
    );
  }
}

final monetizationControllerProvider =
    NotifierProvider<MonetizationController, void>(
      MonetizationController.new,
    );
