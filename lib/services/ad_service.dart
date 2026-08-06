import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../domain/entitlements/entitlement_service.dart';

/// Por que uma tentativa de anúncio não rendeu recompensa.
enum AdFailure { notLoaded, network, dismissedEarly }

/// Slots do contrato (contracts/platform-android.md §5).
abstract final class AdSlots {
  static const String goldBoost = 'rw_gold_boost';
  static const String instantRevive = 'rw_instant_revive';
  static const String cubeSlot = 'rw_cube_slot';
  static const String actTransition = 'int_act_transition';

  /// IDs de teste do AdMob. Os de produção entram na configuração de release —
  /// publicar com estes é preferível a publicar com IDs reais em debug e
  /// arriscar a conta por tráfego inválido.
  static const String testRewardedUnitId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testInterstitialUnitId =
      'ca-app-pub-3940256099942544/1033173712';
}

/// Anúncios recompensados e intersticiais (M12).
///
/// **A recompensa só existe no callback de visualização completa**
/// (R-M12-08, CEN-M12-004). Todo o resto — carregar, falhar, fechar antes do
/// fim, não ter rede — termina sem conceder nada e sem consumir recurso do
/// jogador (CEN-M12-E01). É por isso que [showRewarded] devolve `AdFailure?` em
/// vez de lançar: falhar em ver um anúncio é um caminho normal do jogo, não um
/// erro.
class AdService {
  AdService({this.rewardedUnitId = AdSlots.testRewardedUnitId,
      this.interstitialUnitId = AdSlots.testInterstitialUnitId});

  final String rewardedUnitId;
  final String interstitialUnitId;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    await Future.wait([_loadRewarded(), _loadInterstitial()]);
  }

  bool get isRewardedReady => _rewarded != null;

  /// Exibe um recompensado e concede [reward] **apenas** se o usuário assistir
  /// por inteiro.
  ///
  /// [onEarned] é chamado no callback do SDK; quem o passa é responsável por
  /// aplicar a recompensa ao estado do jogo.
  Future<AdFailure?> showRewarded({
    required AdReward reward,
    required void Function(AdReward) onEarned,
  }) async {
    final ad = _rewarded;
    if (ad == null) {
      // Sem rede ou sem inventário de anúncios. O jogo segue normalmente
      // (CEN-M12-E01) — o próximo carregamento é tentado em segundo plano.
      unawaited(_loadRewarded());
      return AdFailure.notLoaded;
    }

    var earned = false;
    _rewarded = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadRewarded());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadRewarded());
      },
    );

    await ad.show(
      // O `RewardItem` do SDK descreve a moeda configurada no AdMob; o que
      // vale para o jogo é a recompensa que **nós** pedimos, não a que o
      // painel de anúncios declara.
      onUserEarnedReward: (_, _) {
        earned = true;
        onEarned(reward);
      },
    );

    // Fechar antes do fim não concede nada e não consome recurso: o jogador
    // pode tentar de novo (CEN-M12-004).
    return earned ? null : AdFailure.dismissedEarly;
  }

  /// Exibe o intersticial da transição de ato.
  ///
  /// Quem decide **se** cabe um é `EntitlementService.shouldShowInterstitial`;
  /// este método só apresenta. Nenhum intersticial aparece durante o combate
  /// (SC-M12-02) porque só a virada de ato o chama.
  Future<void> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return;
    }
    _interstitial = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
    );
    await ad.show();
  }

  Future<void> _loadRewarded() async {
    try {
      await RewardedAd.load(
        adUnitId: rewardedUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) => _rewarded = ad,
          onAdFailedToLoad: (_) => _rewarded = null,
        ),
      );
    } on Object {
      _rewarded = null;
    }
  }

  Future<void> _loadInterstitial() async {
    try {
      await InterstitialAd.load(
        adUnitId: interstitialUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) => _interstitial = ad,
          onAdFailedToLoad: (_) => _interstitial = null,
        ),
      );
    } on Object {
      _interstitial = null;
    }
  }

  void dispose() {
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
  }
}
