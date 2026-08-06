import '../entities/entitlements.dart';
import '../entities/player_account.dart';
import '../progression/formation_slots.dart';

/// Recompensas de anúncio (R-M12-03).
enum AdReward { goldBoost4h, instantRevive, extraCubeSlot }

/// Produtos do catálogo (contracts/platform-android.md §5).
enum PurchaseId {
  removeAds('remove_ads', isConsumable: false),
  starterPack('starter_pack', isConsumable: false),
  gemsSmall('gems_small', isConsumable: true, gems: 100),
  gemsMedium('gems_medium', isConsumable: true, gems: 600),
  gemsLarge('gems_large', isConsumable: true, gems: 1500),
  gemsMega('gems_mega', isConsumable: true, gems: 4000),

  /// O ID real leva o sufixo da classe: `dlc_class_<id>`.
  dlcClass('dlc_class_', isConsumable: false);

  const PurchaseId(this.storeId, {required this.isConsumable, this.gems = 0});

  final String storeId;

  /// Consumível é creditado uma vez e some. Restaurar **não** o recredita — é
  /// o que impede transformar restauração em fonte infinita de gemas.
  final bool isConsumable;

  final int gems;
}

/// Estado depois de uma compra: os dois agregados que ela pode tocar.
class PurchaseResult {
  const PurchaseResult({
    required this.entitlements,
    required this.account,
    required this.granted,
  });

  final Entitlements entitlements;
  final PlayerAccount account;

  /// Falso quando o produto não mudou nada — comprar de novo o que já se tem.
  final bool granted;
}

/// Regras de monetização (M12).
///
/// **V-ENT-03 é a regra que governa este arquivo inteiro**: nada aqui pode ser
/// pré-requisito de conteúdo de progressão. Tudo acelera, remove atrito ou
/// antecipa um marco que chegaria de graça — e é por isso que
/// `test/domain/m12_no_paywall_test.dart` consegue percorrer o jogo inteiro sem
/// passar por nenhuma função deste serviço.
class EntitlementService {
  const EntitlementService();

  /// Concede a recompensa. Chamado **apenas** no callback de visualização
  /// completa (R-M12-08, CEN-M12-004).
  Entitlements applyAdReward(
    Entitlements entitlements,
    AdReward reward,
    DateTime now,
  ) => switch (reward) {
    // V-ENT-01: com bônus ativo, **estende a validade**; o percentual continua
    // +50%. Multiplicar o percentual transformaria uma sessão de anúncios numa
    // curva exponencial de ouro.
    AdReward.goldBoost4h => entitlements.copyWith(
      goldBoostExpiresAt:
          (entitlements.isGoldBoostActive(now)
                  ? entitlements.goldBoostExpiresAt!
                  : now)
              .add(Entitlements.goldBoostDuration),
    ),

    AdReward.extraCubeSlot => entitlements.copyWith(
      extraCubeSlots: entitlements.extraCubeSlots + 1,
    ),

    // O revive não é estado persistente: age sobre o combate em curso, e quem
    // o aplica é o controlador (T138).
    AdReward.instantRevive => entitlements,
  };

  /// R-M12-04: no máximo um a cada 5 transições de ato.
  /// R-M12-05: `adsRemoved` suprime, e não afeta os recompensados.
  bool shouldShowInterstitial(Entitlements entitlements) =>
      !entitlements.adsRemoved &&
      entitlements.actTransitionsSinceInterstitial >=
          Entitlements.interstitialEveryActTransitions;

  Entitlements registerActTransition(Entitlements entitlements) =>
      entitlements.copyWith(
        actTransitionsSinceInterstitial:
            entitlements.actTransitionsSinceInterstitial + 1,
      );

  Entitlements markInterstitialShown(Entitlements entitlements) =>
      entitlements.copyWith(actTransitionsSinceInterstitial: 0);

  /// Aplica um produto adquirido.
  ///
  /// O Pacote de Início **delega** o 4º slot a [FormationSlots], em vez de
  /// escrever `formationSlots` por conta própria: é o único caminho que respeita
  /// V-PA-02 e o teto de R-M12-10.
  PurchaseResult applyPurchase({
    required Entitlements entitlements,
    required PlayerAccount account,
    required PurchaseId id,
    String? dlcClassId,
    bool creditConsumables = true,
  }) {
    switch (id) {
      case PurchaseId.removeAds:
        if (entitlements.adsRemoved) {
          return PurchaseResult(
            entitlements: entitlements,
            account: account,
            granted: false,
          );
        }
        return PurchaseResult(
          entitlements: entitlements.copyWith(adsRemoved: true),
          account: account,
          granted: true,
        );

      case PurchaseId.starterPack:
        final jaTinha = account.hasFourthSlot;
        final comSlot = FormationSlots.grantByPurchase(account);
        return PurchaseResult(
          entitlements: entitlements,
          // As gemas do pacote acompanham a primeira concessão. Restaurar não
          // as recredita, senão reinstalar viraria fonte de moeda.
          account: jaTinha
              ? comSlot
              : comSlot.copyWith(
                  gems:
                      comSlot.gems + PlayerAccount.fourthSlotCompensationGems,
                ),
          granted: !jaTinha,
        );

      case PurchaseId.gemsSmall:
      case PurchaseId.gemsMedium:
      case PurchaseId.gemsLarge:
      case PurchaseId.gemsMega:
        if (!creditConsumables) {
          return PurchaseResult(
            entitlements: entitlements,
            account: account,
            granted: false,
          );
        }
        return PurchaseResult(
          entitlements: entitlements,
          account: account.copyWith(gems: account.gems + id.gems),
          granted: true,
        );

      case PurchaseId.dlcClass:
        if (dlcClassId == null) {
          return PurchaseResult(
            entitlements: entitlements,
            account: account,
            granted: false,
          );
        }
        // R-M12-12: aqui só o registro da compra. O conteúdo da classe é
        // pós-lançamento.
        return PurchaseResult(
          entitlements: entitlements.copyWith(
            ownedDlcClassIds: {
              ...entitlements.ownedDlcClassIds,
              dlcClassId,
            },
          ),
          account: account,
          granted: true,
        );
    }
  }

  /// Reaplica produtos não consumíveis no boot (CEN-M12-E04).
  ///
  /// Consumíveis ficam de fora por definição: eles já foram creditados quando
  /// comprados, e recreditá-los a cada restauração seria uma torneira aberta.
  PurchaseResult restorePurchases({
    required Entitlements entitlements,
    required PlayerAccount account,
    required List<PurchaseId> purchased,
    Map<PurchaseId, String>? dlcClassIds,
  }) {
    var currentEntitlements = entitlements;
    var currentAccount = account;

    for (final id in purchased) {
      if (id.isConsumable) continue;

      final result = applyPurchase(
        entitlements: currentEntitlements,
        account: currentAccount,
        id: id,
        dlcClassId: dlcClassIds?[id],
        creditConsumables: false,
      );
      currentEntitlements = result.entitlements;
      currentAccount = result.account;
    }

    return PurchaseResult(
      entitlements: currentEntitlements,
      account: currentAccount,
      granted: true,
    );
  }
}
