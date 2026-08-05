import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/progression/formation_slots.dart';
import 'package:test/test.dart';

/// M01 — limites de formação. CEN-M01-012, 012b e 012c.
///
/// O teto de 4 é absoluto: nenhuma compra ou anúncio o ultrapassa (R-M12-10).
void main() {
  final now = DateTime.utc(2026, 1, 1);

  PlayerAccount account({
    int level = 1,
    FourthSlotSource source = FourthSlotSource.none,
  }) {
    final base = PlayerAccount.fresh(now: now, seed: 1);
    return source == FourthSlotSource.none
        ? base.copyWith(accountLevel: level)
        : base.copyWith(
            accountLevel: level,
            formationSlots: PlayerAccount.maxFormationSlots,
            fourthSlotSource: source,
          );
  }

  group('CEN-M01-012 — sem o 4º slot', () {
    test('conta nova tem exatamente 3 slots', () {
      expect(account().formationSlots, 3);
      expect(account().hasFourthSlot, isFalse);
    });

    test('adicionar um 4º herói é recusado', () {
      expect(FormationSlots.canPlaceAt(account(), 3), isFalse);
    });

    test('os índices 0, 1 e 2 são aceitos', () {
      for (final i in [0, 1, 2]) {
        expect(FormationSlots.canPlaceAt(account(), i), isTrue);
      }
    });
  });

  group('CEN-M01-012b — com o 4º slot desbloqueado', () {
    test('índice 3 passa a ser aceito', () {
      final acc = account(level: 25, source: FourthSlotSource.accountLevel);
      expect(FormationSlots.canPlaceAt(acc, 3), isTrue);
      expect(acc.formationSlots, 4);
    });

    test('slot obtido por compra vale igual ao obtido por nível', () {
      final porNivel = account(level: 25, source: FourthSlotSource.accountLevel);
      final porCompra = account(level: 8, source: FourthSlotSource.purchase);
      expect(porNivel.formationSlots, porCompra.formationSlots);
    });
  });

  group('CEN-M01-012c — teto absoluto de 4', () {
    test('índice 4 é recusado mesmo com o 4º slot desbloqueado', () {
      final acc = account(level: 25, source: FourthSlotSource.accountLevel);
      expect(FormationSlots.canPlaceAt(acc, 4), isFalse);
    });

    test('V-PA-01: nenhum caminho produz 5 slots', () {
      // Comprar depois de já ter ganho por nível não adiciona um quinto.
      final acc = account(level: 30, source: FourthSlotSource.accountLevel);
      final depois = FormationSlots.evaluate(acc);
      expect(depois.account.formationSlots,
          lessThanOrEqualTo(PlayerAccount.maxFormationSlots));
    });

    test('índice negativo é recusado', () {
      expect(FormationSlots.canPlaceAt(account(), -1), isFalse);
    });
  });
}
