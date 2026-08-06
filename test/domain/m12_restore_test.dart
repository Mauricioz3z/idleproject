import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entitlements/entitlement_service.dart';
import 'package:pixel_idle_quest/domain/progression/formation_slots.dart';
import 'package:test/test.dart';

/// Restauração de compra — CEN-M12-015, CEN-M12-E04, V-PA-01, V-ENT-05.
///
/// O caminho mais perigoso da monetização inteira: quem comprou o Pacote de
/// Início antes do nível 25 tem o 4º slot por compra. Ao chegar ao marco
/// gratuito, um sistema ingênuo concederia **outro** slot. O teto de 4 é
/// absoluto (R-M12-10), então a resposta certa é compensar em gemas.
void main() {
  const service = EntitlementService();
  final agora = DateTime.utc(2026, 8, 6);

  PlayerAccount account({
    int accountLevel = 8,
    int gems = 0,
    FourthSlotSource source = FourthSlotSource.none,
    int slots = PlayerAccount.baseFormationSlots,
  }) => PlayerAccount.fresh(now: agora, seed: 1).copyWith(
    accountLevel: accountLevel,
    gems: gems,
    formationSlots: slots,
    fourthSlotSource: source,
  );

  group('CEN-M12-015 — compensação por slot já antecipado', () {
    test('comprar no nível 8 e chegar ao 25 rende 500 gemas, não um slot', () {
      // 1. Compra antecipa o slot.
      final comprado = service.applyPurchase(
        entitlements: Entitlements.initial(),
        account: account(accountLevel: 8),
        id: PurchaseId.starterPack,
      );

      expect(comprado.account.formationSlots, 4);
      expect(comprado.account.fourthSlotSource, FourthSlotSource.purchase);
      final gemasAposCompra = comprado.account.gems;

      // 2. A conta chega ao marco gratuito.
      final noMarco = comprado.account.copyWith(
        accountLevel: PlayerAccount.fourthSlotUnlockLevel,
      );
      final avaliado = FormationSlots.evaluate(noMarco);

      expect(avaliado, isA<SlotAlreadyOwnedCompensated>());
      final compensado = avaliado as SlotAlreadyOwnedCompensated;

      expect(
        compensado.account.formationSlots,
        PlayerAccount.maxFormationSlots,
        reason: 'V-PA-01: nunca 5',
      );
      expect(
        compensado.gemsGranted,
        PlayerAccount.fourthSlotCompensationGems,
        reason: 'V-ENT-05: 500 gemas',
      );
      expect(
        compensado.account.gems,
        gemasAposCompra + PlayerAccount.fourthSlotCompensationGems,
      );
    });

    test('a compensação acontece uma vez só', () {
      var acc = account(
        accountLevel: PlayerAccount.fourthSlotUnlockLevel,
        slots: PlayerAccount.maxFormationSlots,
        source: FourthSlotSource.purchase,
      );

      final primeira = FormationSlots.evaluate(acc);
      expect(primeira, isA<SlotAlreadyOwnedCompensated>());
      acc = primeira.account;

      // Todo nível seguinte reavalia; nenhum concede de novo.
      for (var nivel = 26; nivel < 40; nivel++) {
        final r = FormationSlots.evaluate(
          acc.copyWith(accountLevel: nivel),
        );
        expect(r, isA<SlotNoChange>(), reason: 'repetiu no nível $nivel');
        acc = r.account;
      }

      expect(
        acc.gems,
        PlayerAccount.fourthSlotCompensationGems,
        reason: 'as gemas foram creditadas mais de uma vez',
      );
    });

    test('quem nunca comprou recebe o slot, não gemas (CEN-M12-013)', () {
      final r = FormationSlots.evaluate(
        account(accountLevel: PlayerAccount.fourthSlotUnlockLevel),
      );

      expect(r, isA<SlotGranted>());
      expect(r.account.formationSlots, PlayerAccount.maxFormationSlots);
      expect(r.account.fourthSlotSource, FourthSlotSource.accountLevel);
      expect(r.account.gems, 0);
    });
  });

  group('CEN-M12-E04 — restauração após reinstalar', () {
    test('restaurar "Remover Ads" devolve o benefício', () {
      final restaurado = service.restorePurchases(
        entitlements: Entitlements.initial(),
        account: account(),
        purchased: const [PurchaseId.removeAds],
      );

      expect(restaurado.entitlements.adsRemoved, isTrue);
    });

    test(
      'restaurar o Pacote de Início depois do nível 25 não cria quinto slot',
      () {
        // O jogador comprou, reinstalou, e nesse meio-tempo passou do marco.
        final acc = account(
          accountLevel: 30,
          slots: PlayerAccount.maxFormationSlots,
          source: FourthSlotSource.accountLevel,
        );

        final restaurado = service.restorePurchases(
          entitlements: Entitlements.initial(),
          account: acc,
          purchased: const [PurchaseId.starterPack],
        );

        expect(
          restaurado.account.formationSlots,
          PlayerAccount.maxFormationSlots,
        );
        expect(
          restaurado.account.fourthSlotSource,
          FourthSlotSource.accountLevel,
          reason: 'a fonte gratuita não é sobrescrita pela restauração',
        );
      },
    );

    test('restaurar duas vezes não duplica nada', () {
      final acc = account(accountLevel: 10);

      final primeira = service.restorePurchases(
        entitlements: Entitlements.initial(),
        account: acc,
        purchased: const [PurchaseId.starterPack, PurchaseId.removeAds],
      );
      final segunda = service.restorePurchases(
        entitlements: primeira.entitlements,
        account: primeira.account,
        purchased: const [PurchaseId.starterPack, PurchaseId.removeAds],
      );

      expect(segunda.account.formationSlots, PlayerAccount.maxFormationSlots);
      expect(
        segunda.account.gems,
        primeira.account.gems,
        reason: 'gemas do pacote não podem ser creditadas a cada restauração',
      );
      expect(segunda.entitlements.adsRemoved, isTrue);
    });

    test('restaurar consumíveis de gema não recredita a moeda', () {
      final acc = account(gems: 300);

      final restaurado = service.restorePurchases(
        entitlements: Entitlements.initial(),
        account: acc,
        purchased: const [PurchaseId.gemsMega],
      );

      expect(
        restaurado.account.gems,
        300,
        reason: 'consumível já foi consumido; restaurar não recredita',
      );
    });
  });
}
