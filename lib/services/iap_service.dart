import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/entitlements/entitlement_service.dart';

/// Compras via Google Play Billing (contracts/platform-android.md §5).
///
/// Duas regras governam o desenho:
///
/// - **Falha não cobra nem concede** (CEN-M12-E03). O serviço só notifica o
///   jogo em `PurchaseStatus.purchased` ou `restored`; qualquer outro estado
///   termina o fluxo sem tocar no estado do jogador.
/// - **Restauração passa pelo domínio** (CEN-M12-E04). O `starter_pack`
///   restaurado é reavaliado por `EntitlementService`, que delega o 4º slot a
///   `FormationSlots` — se a conta já chegou ao nível 25 nesse meio-tempo, o
///   resultado é compensação, não um quinto slot (V-PA-01).
class IapService {
  IapService({InAppPurchase? store})
    : _store = store ?? InAppPurchase.instance;

  final InAppPurchase _store;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// IDs do contrato. `dlc_class_<id>` é montado com o sufixo da classe.
  static const Set<String> productIds = {
    'remove_ads',
    'starter_pack',
    'gems_small',
    'gems_medium',
    'gems_large',
    'gems_mega',
  };

  bool _available = false;
  List<ProductDetails> _products = const [];

  bool get isAvailable => _available;
  List<ProductDetails> get products => List.unmodifiable(_products);

  /// Liga o fluxo de compras. [onPurchased] recebe apenas transações
  /// concluídas com sucesso.
  Future<void> initialize({
    required void Function(PurchaseId id, String? dlcClassId) onPurchased,
    void Function(String productId)? onFailed,
  }) async {
    _available = await _store.isAvailable();
    if (!_available) return;

    _subscription = _store.purchaseStream.listen((purchases) {
      for (final purchase in purchases) {
        _handle(purchase, onPurchased, onFailed);
      }
    });

    final response = await _store.queryProductDetails(productIds);
    _products = response.productDetails;

    // CEN-M12-E04: restaurar no boot. O que volta entra pelo mesmo fluxo das
    // compras novas, com status `restored`.
    await _store.restorePurchases();
  }

  Future<bool> buy(ProductDetails product) async {
    if (!_available) return false;
    final param = PurchaseParam(productDetails: product);

    // Consumíveis e não consumíveis usam caminhos diferentes no Play: gemas
    // precisam ser consumidas para poderem ser compradas de novo.
    return idFor(product.id)?.isConsumable ?? false
        ? _store.buyConsumable(purchaseParam: param)
        : _store.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restore() => _store.restorePurchases();

  void _handle(
    PurchaseDetails purchase,
    void Function(PurchaseId, String?) onPurchased,
    void Function(String)? onFailed,
  ) {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        final id = idFor(purchase.productID);
        if (id != null) {
          onPurchased(id, _dlcClassIdFor(purchase.productID));
        }

      case PurchaseStatus.error:
      case PurchaseStatus.canceled:
        // Nada é cobrado nem concedido (CEN-M12-E03).
        onFailed?.call(purchase.productID);

      case PurchaseStatus.pending:
        break;
    }

    if (purchase.pendingCompletePurchase) {
      unawaited(_store.completePurchase(purchase));
    }
  }

  /// Traduz o ID da loja para o produto de domínio.
  static PurchaseId? idFor(String productId) {
    for (final id in PurchaseId.values) {
      if (id == PurchaseId.dlcClass) continue;
      if (id.storeId == productId) return id;
    }
    return productId.startsWith(PurchaseId.dlcClass.storeId)
        ? PurchaseId.dlcClass
        : null;
  }

  static String? _dlcClassIdFor(String productId) =>
      productId.startsWith(PurchaseId.dlcClass.storeId)
      ? productId.substring(PurchaseId.dlcClass.storeId.length)
      : null;

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
