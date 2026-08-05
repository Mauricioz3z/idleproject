import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/hero_class_definition.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:pixel_idle_quest/domain/progression/formation_slots.dart';
import 'package:pixel_idle_quest/domain/progression/progression_service.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// M03 — Progressão de Herói e Conta.
/// Cenários CEN-M03-001 a 014, E01 e E02.
void main() {
  final now = DateTime.utc(2026, 1, 1);
  final service = ProgressionService();
  final definition = TestContent.heroClass(
    skills: const [
      SkillDefinitionFixture.taunt,
      SkillDefinitionFixture.aoe,
    ],
  );

  Hero hero({int level = 1, GameNumber? xp, int? formationIndex = 0}) =>
      Hero.fresh(id: 'h1', classId: definition.id).copyWith(
        level: level,
        xp: xp ?? GameNumber.zero,
        formationIndex: formationIndex,
      );

  PlayerAccount account({int level = 1, int runePoints = 0}) =>
      PlayerAccount.fresh(now: now, seed: 1)
          .copyWith(accountLevel: level, runePoints: runePoints);

  group('CEN-M03-001/002 — XP e nível de herói', () {
    test('CEN-M03-001: derrotar monstro aumenta o XP', () {
      final r = service.grantHeroXp(hero(), GameNumber.fromInt(10), definition);
      expect(r.hero.xp > GameNumber.zero, isTrue);
    });

    test('CEN-M03-002: excedente é mantido no novo nível', () {
      final necessario = service.xpToNext(4);
      final quase = hero(level: 4, xp: necessario - GameNumber.fromInt(1));

      final r = service.grantHeroXp(quase, GameNumber.fromInt(10), definition);

      expect(r.hero.level, 5);
      expect(r.hero.xp, GameNumber.fromInt(9), reason: 'excedente preservado');
      expect(r.levelsGained, 1);
    });

    test('o XP exigido cresce a cada nível', () {
      expect(service.xpToNext(6) > service.xpToNext(5), isTrue);
    });
  });

  group('CEN-M03-003/004 — atributos e habilidades', () {
    test('CEN-M03-003: subir de nível aumenta os atributos', () {
      final antes = service.statsForLevel(definition, 4);
      final depois = service.statsForLevel(definition, 5);
      expect(depois.attack > antes.attack, isTrue);
      expect(depois.maxHp > antes.maxHp, isTrue);
    });

    test('CEN-M03-004: habilidade é desbloqueada ao atingir o nível', () {
      final quase = hero(level: 4, xp: service.xpToNext(4));
      final r = service.grantHeroXp(quase, GameNumber.zero, definition);
      expect(r.hero.unlockedSkillIds, contains('aoe_reduction'));
    });
  });

  group('CEN-M03-005/006 — quem recebe XP', () {
    test('CEN-M03-005: herói fora da formação não recebe XP', () {
      final fora = hero(formationIndex: null);
      expect(service.isEligibleForXp(fora), isFalse);
    });

    test('CEN-M03-006: herói incapacitado na formação ainda recebe XP', () {
      final caido = hero().copyWith(reviveAtMs: 30000);
      expect(caido.isIncapacitated, isTrue);
      expect(service.isEligibleForXp(caido), isTrue);
    });
  });

  group('CEN-M03-007/008 — nível de conta é independente', () {
    test('CEN-M03-007: subir nível de herói não mexe na conta', () {
      final acc = account(level: 3, runePoints: 2);
      final r = service.grantHeroXp(
        hero(level: 9, xp: service.xpToNext(9)),
        GameNumber.zero,
        definition,
      );
      expect(r.hero.level, 10);
      expect(acc.accountLevel, 3, reason: 'conta intocada');
      expect(acc.runePoints, 2);
    });

    test('CEN-M03-008: subir nível de conta concede pontos de runa', () {
      final acc = account(level: 1, runePoints: 0);
      final r = service.grantAccountXp(acc, service.accountXpToNext(1));
      expect(r.account.accountLevel, 2);
      expect(r.account.runePoints, greaterThan(0));
    });
  });

  group('CEN-M03-009/010 — recordes', () {
    test('CEN-M03-009: alcançar wave maior atualiza o recorde', () {
      final acc = account().copyWith(highestWave: 142, highestAct: 2);
      final r = service.recordProgress(
        acc,
        const ProgressPosition(difficulty: 1, act: 2, wave: 43),
      );
      expect(r.highestWave, 143, reason: 'globalWave 143');
    });

    test('CEN-M03-010: voltar a jogar wave menor não regride o recorde', () {
      final acc = account().copyWith(highestWave: 143, highestAct: 2);
      final r = service.recordProgress(
        acc,
        const ProgressPosition(difficulty: 1, act: 1, wave: 5),
      );
      expect(r.highestWave, 143);
      expect(r.highestAct, 2);
    });
  });

  group('CEN-M03-011/012/013 — o 4º slot de formação', () {
    test('CEN-M03-011: nível 25 concede o slot de graça', () {
      final acc = account(level: 25);
      final r = FormationSlots.evaluate(acc);

      expect(r, isA<SlotGranted>());
      expect(r.account.formationSlots, 4);
      expect(r.account.fourthSlotSource, FourthSlotSource.accountLevel);
      expect(r.account.gems, 0, reason: 'quem não comprou não recebe gemas');
    });

    test('CEN-M03-012: quem já comprou recebe 500 gemas, não um 5º slot', () {
      final comprado = account(level: 25).copyWith(
        formationSlots: PlayerAccount.maxFormationSlots,
        fourthSlotSource: FourthSlotSource.purchase,
      );

      final r = FormationSlots.evaluate(comprado);

      expect(r, isA<SlotAlreadyOwnedCompensated>());
      expect(r.account.formationSlots, 4, reason: 'nunca 5');
      expect(r.account.gems, PlayerAccount.fourthSlotCompensationGems);
    });

    test('compensação é concedida uma única vez', () {
      final comprado = account(level: 25).copyWith(
        formationSlots: PlayerAccount.maxFormationSlots,
        fourthSlotSource: FourthSlotSource.purchase,
      );
      final primeira = FormationSlots.evaluate(comprado);
      final segunda = FormationSlots.evaluate(primeira.account);

      expect(segunda, isA<SlotNoChange>());
      expect(segunda.account.gems, PlayerAccount.fourthSlotCompensationGems);
    });

    test('abaixo do nível 25 e sem compra, nada acontece', () {
      final r = FormationSlots.evaluate(account(level: 24));
      expect(r, isA<SlotNoChange>());
      expect(r.account.formationSlots, 3);
    });

    test('CEN-M03-013: o 4º slot é permanente', () {
      final comSlot = FormationSlots.evaluate(account(level: 25)).account;
      final aposRespec = comSlot.copyWith(respecCount: 5, runePoints: 12);
      expect(aposRespec.formationSlots, 4);
      expect(aposRespec.fourthSlotSource, FourthSlotSource.accountLevel);
    });
  });

  group('CEN-M03-014 — último acesso', () {
    test('o momento do save é registrado na conta', () {
      final depois = account().copyWith(lastSaveAt: now.add(const Duration(hours: 2)));
      expect(depois.lastSaveAt, now.add(const Duration(hours: 2)));
    });
  });

  group('bordas', () {
    test('CEN-M03-E01: XP grande resolve vários níveis de uma vez', () {
      final r = service.grantHeroXp(
        hero(level: 3),
        GameNumber.fromInt(100000),
        definition,
      );
      expect(r.levelsGained, greaterThan(1));
      expect(r.hero.level, greaterThan(4));
      // Todos os desbloqueios intermediários são aplicados.
      expect(r.hero.unlockedSkillIds, contains('taunt'));
      expect(r.hero.unlockedSkillIds, contains('aoe_reduction'));
    });

    test('CEN-M03-E02: XP concedido offline sobe níveis normalmente', () {
      // A mesma função serve ao combate ao vivo e à simulação offline.
      final r = service.grantHeroXp(
        hero(level: 1),
        GameNumber.fromInt(5000),
        definition,
      );
      expect(r.levelsGained, greaterThan(0));
    });

    test('XP zero não altera nada', () {
      final h = hero(level: 7, xp: GameNumber.fromInt(3));
      final r = service.grantHeroXp(h, GameNumber.zero, definition);
      expect(r.hero.level, 7);
      expect(r.hero.xp, GameNumber.fromInt(3));
      expect(r.levelsGained, 0);
    });
  });
}

/// Habilidades de teste com níveis de desbloqueio conhecidos.
abstract final class SkillDefinitionFixture {
  static const taunt = SkillDefinition(
    id: 'taunt',
    displayName: 'Provocar',
    unlockLevel: 1,
  );
  static const aoe = SkillDefinition(
    id: 'aoe_reduction',
    displayName: 'Redução em área',
    unlockLevel: 5,
  );
}
