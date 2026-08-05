import '../../core/constants/game_enums.dart';
import '../entities/player_account.dart';

/// Resultado da avaliação do 4º slot de formação.
sealed class SlotUnlockResult {
  const SlotUnlockResult(this.account);
  final PlayerAccount account;
}

/// Nada a fazer: ou o jogador ainda não chegou ao marco, ou já foi resolvido.
class SlotNoChange extends SlotUnlockResult {
  const SlotNoChange(super.account);
}

/// Slot concedido gratuitamente ao atingir o nível de conta (CEN-M03-011).
class SlotGranted extends SlotUnlockResult {
  const SlotGranted(super.account);
}

/// O jogador já tinha o slot por compra: recebe gemas, não um quinto slot
/// (CEN-M03-012, CEN-M12-015).
class SlotAlreadyOwnedCompensated extends SlotUnlockResult {
  const SlotAlreadyOwnedCompensated(super.account, this.gemsGranted);
  final int gemsGranted;
}

/// Regras do 4º slot de formação (FR-028).
///
/// Todo o cuidado aqui existe por causa de uma invariante: `formationSlots` e
/// `fourthSlotSource` não podem discordar (V-PA-02), e nenhum caminho pode
/// produzir um quinto slot (V-PA-01). É por isso que este é o **único** lugar
/// que escreve esses dois campos — `EntitlementService.applyPurchase` delega
/// para cá em vez de mexer neles direto.
abstract final class FormationSlots {
  /// Um índice de formação é utilizável nesta conta?
  static bool canPlaceAt(PlayerAccount account, int index) =>
      index >= 0 && index < account.formationSlots;

  /// Avalia se o marco gratuito de nível concede algo.
  ///
  /// Chamado após toda subida de nível de conta e após toda restauração de
  /// compra — os dois momentos em que o estado pode mudar.
  static SlotUnlockResult evaluate(PlayerAccount account) {
    if (!account.isEligibleForFourthSlot) return SlotNoChange(account);

    switch (account.fourthSlotSource) {
      case FourthSlotSource.none:
        return SlotGranted(
          account.copyWith(
            formationSlots: PlayerAccount.maxFormationSlots,
            fourthSlotSource: FourthSlotSource.accountLevel,
          ),
        );

      case FourthSlotSource.purchase:
        // Antecipou pagando e agora alcançou o marco: compensa em gemas e
        // marca a fonte como accountLevel, para que a compensação não se
        // repita a cada nível seguinte.
        return SlotAlreadyOwnedCompensated(
          account.copyWith(
            gems: account.gems + PlayerAccount.fourthSlotCompensationGems,
            fourthSlotSource: FourthSlotSource.accountLevel,
          ),
          PlayerAccount.fourthSlotCompensationGems,
        );

      case FourthSlotSource.accountLevel:
        return SlotNoChange(account);
    }
  }

  /// Concede o slot por compra, antes do marco gratuito.
  ///
  /// Se o jogador já tem o slot, a compra não adiciona nada — é o que impede
  /// um quinto slot (V-PA-01).
  static PlayerAccount grantByPurchase(PlayerAccount account) {
    if (account.hasFourthSlot) return account;
    return account.copyWith(
      formationSlots: PlayerAccount.maxFormationSlots,
      fourthSlotSource: FourthSlotSource.purchase,
    );
  }
}
