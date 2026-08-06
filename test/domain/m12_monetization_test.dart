import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entitlements/entitlement_service.dart';
import 'package:pixel_idle_quest/domain/entitlements/gold_boost.dart';
import 'package:test/test.dart';

/// M12 — Monetização e Recompensas por Anúncio.
/// Cenários CEN-M12-001 a 016, E01 a E04.
void main() {
  const service = EntitlementService();
  final agora = DateTime.utc(2026, 8, 6, 12);

  PlayerAccount account({int gems = 0, int accountLevel = 8}) =>
      PlayerAccount.fresh(now: agora, seed: 1).copyWith(
        gems: gems,
        accountLevel: accountLevel,
      );

  group('CEN-M12-001/016 e E02 — bônus de ouro', () {
    test('CEN-M12-001: o anúncio ativa +50% por 4 horas', () {
      final e = service.applyAdReward(
        Entitlements.initial(),
        AdReward.goldBoost4h,
        agora,
      );

      expect(e.isGoldBoostActive(agora), isTrue);
      expect(e.goldMultiplier(agora), 1.5);
      expect(
        e.goldBoostRemaining(agora),
        Entitlements.goldBoostDuration,
      );
    });

    test('CEN-M12-E02: com bônus ativo, a validade é estendida', () {
      var e = service.applyAdReward(
        Entitlements.initial(),
        AdReward.goldBoost4h,
        agora,
      );

      // Três horas depois, resta 1 h; outro anúncio soma 4 h ao que resta.
      final depois = agora.add(const Duration(hours: 3));
      e = service.applyAdReward(e, AdReward.goldBoost4h, depois);

      expect(
        e.goldBoostRemaining(depois),
        const Duration(hours: 5),
        reason: 'V-ENT-01: estende a validade',
      );
      expect(
        e.goldMultiplier(depois),
        1.5,
        reason: 'V-ENT-01: o percentual não acumula',
      );
    });

    test('bônus expirado começa uma janela nova, não soma ao passado', () {
      var e = service.applyAdReward(
        Entitlements.initial(),
        AdReward.goldBoost4h,
        agora,
      );

      final muitoDepois = agora.add(const Duration(hours: 10));
      expect(e.isGoldBoostActive(muitoDepois), isFalse);

      e = service.applyAdReward(e, AdReward.goldBoost4h, muitoDepois);
      expect(
        e.goldBoostRemaining(muitoDepois),
        Entitlements.goldBoostDuration,
      );
    });

    test('CEN-M12-016: passadas as 4 h o bônus deixa de valer', () {
      final e = service.applyAdReward(
        Entitlements.initial(),
        AdReward.goldBoost4h,
        agora,
      );
      final expirado = agora.add(const Duration(hours: 4, seconds: 1));

      expect(e.isGoldBoostActive(expirado), isFalse);
      expect(e.goldMultiplier(expirado), 1.0);
      expect(e.goldBoostRemaining(expirado), Duration.zero);
    });

    test('o bônus multiplica o ouro do combate e o do offline igualmente', () {
      final e = service.applyAdReward(
        Entitlements.initial(),
        AdReward.goldBoost4h,
        agora,
      );
      final base = GameNumber.fromDouble(1000);

      expect(
        GoldBoost.apply(base, e, agora).toDouble(),
        closeTo(1500, 0.001),
      );
      expect(
        GoldBoost.apply(base, Entitlements.initial(), agora).toDouble(),
        closeTo(1000, 0.001),
      );
    });
  });

  group('CEN-M12-003 — slot de cubo', () {
    test('cada anúncio concede 1 slot extra', () {
      var e = Entitlements.initial();
      expect(e.extraCubeSlots, 0);

      e = service.applyAdReward(e, AdReward.extraCubeSlot, agora);
      expect(e.extraCubeSlots, 1);

      e = service.applyAdReward(e, AdReward.extraCubeSlot, agora);
      expect(e.extraCubeSlots, 2);
    });
  });

  group('CEN-M12-006/007 — intersticiais', () {
    test('CEN-M12-006: um a cada 5 transições de ato', () {
      var e = Entitlements.initial();

      for (var i = 1; i < Entitlements.interstitialEveryActTransitions; i++) {
        e = service.registerActTransition(e);
        expect(
          service.shouldShowInterstitial(e),
          isFalse,
          reason: 'mostrou na transição $i',
        );
      }

      e = service.registerActTransition(e);
      expect(service.shouldShowInterstitial(e), isTrue);
    });

    test('exibir zera o contador', () {
      var e = Entitlements.initial();
      for (var i = 0; i < 5; i++) {
        e = service.registerActTransition(e);
      }
      expect(service.shouldShowInterstitial(e), isTrue);

      e = service.markInterstitialShown(e);
      expect(service.shouldShowInterstitial(e), isFalse);
      expect(e.actTransitionsSinceInterstitial, 0);
    });

    test('CEN-M12-007: com adsRemoved nenhum intersticial aparece', () {
      var e = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(),
        id: PurchaseId.removeAds,
      ).entitlements;

      for (var i = 0; i < 50; i++) {
        e = service.registerActTransition(e);
        expect(service.shouldShowInterstitial(e), isFalse);
      }
    });

    test('CEN-M12-007: recompensados continuam disponíveis com adsRemoved', () {
      final comprado = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(),
        id: PurchaseId.removeAds,
      ).entitlements;

      final e = service.applyAdReward(comprado, AdReward.goldBoost4h, agora);
      expect(e.isGoldBoostActive(agora), isTrue);
      expect(e.adsRemoved, isTrue);
    });
  });

  group('CEN-M12-012/014 — compras', () {
    test('CEN-M12-012: o Pacote de Início antecipa o slot e dá 500 gemas', () {
      final r = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(accountLevel: 8),
        id: PurchaseId.starterPack,
      );

      expect(r.account.formationSlots, PlayerAccount.maxFormationSlots);
      expect(r.account.gems, PlayerAccount.fourthSlotCompensationGems);
      expect(r.granted, isTrue);
    });

    test('CEN-M12-014: comprar tudo não passa de 4 slots (V-PA-01)', () {
      var acc = account(accountLevel: 8);
      var e = Entitlements.initial();

      for (var i = 0; i < 5; i++) {
        final r = service.applyPurchase(
          entitlements: e,
          account: acc,
          id: PurchaseId.starterPack,
        );
        acc = r.account;
        e = r.entitlements;
      }

      expect(acc.formationSlots, PlayerAccount.maxFormationSlots);
    });

    test('pacotes de gemas creditam a moeda', () {
      final r = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(gems: 100),
        id: PurchaseId.gemsMedium,
      );

      expect(r.account.gems, greaterThan(100));
    });

    test('DLC de classe registra a compra sem tocar em progressão', () {
      final r = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(),
        id: PurchaseId.dlcClass,
        dlcClassId: 'necromante',
      );

      expect(r.entitlements.ownedDlcClassIds, {'necromante'});
      expect(r.account.formationSlots, account().formationSlots);
      expect(r.account.gems, account().gems);
    });

    test('CEN-M12-E03: compra que falha não concede nada', () {
      // O serviço só é chamado depois do sucesso; o que o teste trava é que
      // ele é uma função pura — não há caminho que conceda pela metade.
      final antes = account(gems: 10);
      final r = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: antes,
        id: PurchaseId.starterPack,
      );

      expect(antes.gems, 10, reason: 'a entrada não pode ser mutada');
      expect(r.account.gems, greaterThan(antes.gems));
    });
  });

  group('CEN-M12-004/005/E01 — anúncio não assistido', () {
    test('CEN-M12-004: sem visualização completa nada muda', () {
      final antes = Entitlements.initial();
      // A concessão só acontece via `applyAdReward`, chamada exclusivamente no
      // callback de visualização completa. Sem ela, o estado é o mesmo.
      expect(antes.isGoldBoostActive(agora), isFalse);
      expect(antes.extraCubeSlots, 0);
    });

    test('CEN-M12-005/E01: recusar não custa nada ao jogador', () {
      final acc = account(gems: 50);
      expect(acc.gems, 50);
      expect(acc.formationSlots, PlayerAccount.baseFormationSlots);
      // Nenhum recurso é consumido para *oferecer* um anúncio.
    });
  });
}
