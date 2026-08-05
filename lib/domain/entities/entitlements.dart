/// Estado de monetização (M12).
///
/// **V-ENT-03**: nenhum campo aqui pode ser pré-requisito de conteúdo de
/// progressão (R-M12-01). Tudo aqui acelera ou remove atrito; nada destranca.
class Entitlements {
  const Entitlements({
    required this.adsRemoved,
    required Set<String> ownedDlcClassIds,
    required this.goldBoostExpiresAt,
    required this.extraCubeSlots,
    required this.actTransitionsSinceInterstitial,
  }) : _ownedDlcClassIds = ownedDlcClassIds;

  factory Entitlements.initial() => const Entitlements(
    adsRemoved: false,
    ownedDlcClassIds: {},
    goldBoostExpiresAt: null,
    extraCubeSlots: 0,
    actTransitionsSinceInterstitial: 0,
  );

  /// Bônus de ouro concedido por anúncio (R-M12-03).
  static const Duration goldBoostDuration = Duration(hours: 4);

  /// Percentual do bônus. Ver bônus com um já ativo **estende a validade**;
  /// o percentual permanece +50% (V-ENT-01, CEN-M12-E02).
  static const double goldBoostMultiplier = 1.5;

  /// Intervalo entre intersticiais, em transições de ato (R-M12-04).
  static const int interstitialEveryActTransitions = 5;

  final bool adsRemoved;
  final Set<String> _ownedDlcClassIds;
  final DateTime? goldBoostExpiresAt;
  final int extraCubeSlots;
  final int actTransitionsSinceInterstitial;

  Set<String> get ownedDlcClassIds => Set.unmodifiable(_ownedDlcClassIds);

  bool isGoldBoostActive(DateTime now) =>
      goldBoostExpiresAt != null && goldBoostExpiresAt!.isAfter(now);

  /// Multiplicador de ouro vigente. Aplica-se tanto ao combate ao vivo quanto
  /// ao cálculo offline.
  double goldMultiplier(DateTime now) =>
      isGoldBoostActive(now) ? goldBoostMultiplier : 1.0;

  Duration goldBoostRemaining(DateTime now) => isGoldBoostActive(now)
      ? goldBoostExpiresAt!.difference(now)
      : Duration.zero;

  Entitlements copyWith({
    bool? adsRemoved,
    Set<String>? ownedDlcClassIds,
    DateTime? goldBoostExpiresAt,
    bool clearGoldBoost = false,
    int? extraCubeSlots,
    int? actTransitionsSinceInterstitial,
  }) => Entitlements(
    adsRemoved: adsRemoved ?? this.adsRemoved,
    ownedDlcClassIds: ownedDlcClassIds ?? _ownedDlcClassIds,
    goldBoostExpiresAt: clearGoldBoost
        ? null
        : (goldBoostExpiresAt ?? this.goldBoostExpiresAt),
    extraCubeSlots: extraCubeSlots ?? this.extraCubeSlots,
    actTransitionsSinceInterstitial:
        actTransitionsSinceInterstitial ?? this.actTransitionsSinceInterstitial,
  );
}
