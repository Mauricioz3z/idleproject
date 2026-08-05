import 'dart:math' as math;

import '../../core/numeric/game_number.dart';
import '../entities/hero.dart';
import '../entities/hero_class_definition.dart';
import '../entities/player_account.dart';
import '../entities/progress_position.dart';
import '../entities/stats.dart';

class XpResult {
  const XpResult({required this.hero, required this.levelsGained});
  final Hero hero;
  final int levelsGained;
}

class AccountXpResult {
  const AccountXpResult({
    required this.account,
    required this.levelsGained,
    required this.runePointsGranted,
  });
  final PlayerAccount account;
  final int levelsGained;
  final int runePointsGranted;
}

/// Progressão de herói e de conta (M03).
///
/// As duas trilhas são deliberadamente independentes: subir o nível de um herói
/// não move a conta, e vice-versa (CEN-M03-007). É o que garante que o jogador
/// sempre esteja avançando em alguma coisa.
class ProgressionService {
  /// XP do primeiro nível. A curva é geométrica: cada nível exige 15% a mais.
  static const double baseXpToNext = 100;
  static const double xpGrowthRate = 1.15;

  /// Pontos de runa por nível de conta (R-M03-06).
  static const int runePointsPerAccountLevel = 1;

  static const double baseAccountXpToNext = 500;
  static const double accountXpGrowthRate = 1.2;

  /// Trava contra laço infinito caso uma curva mal configurada retorne zero.
  static const int _maxLevelsPerGrant = 10000;

  GameNumber xpToNext(int level) =>
      GameNumber.fromDouble(baseXpToNext * math.pow(xpGrowthRate, level - 1));

  GameNumber accountXpToNext(int level) => GameNumber.fromDouble(
    baseAccountXpToNext * math.pow(accountXpGrowthRate, level - 1),
  );

  /// Só heróis na formação recebem XP (V-H-05, CEN-M03-005) — inclusive os
  /// incapacitados, que continuam ganhando pela wave (CEN-M03-006).
  bool isEligibleForXp(Hero hero) => hero.isInFormation;

  /// Atributos totais de um herói no nível dado.
  Stats statsForLevel(HeroClassDefinition definition, int level) {
    final growth = level - 1;
    if (growth <= 0) return definition.baseStats;
    return definition.baseStats +
        definition.statGrowthPerLevel.scaledBy(GameNumber.fromInt(growth));
  }

  /// Concede XP e resolve **todos** os níveis alcançados de uma vez.
  ///
  /// Resolver em laço, e não um nível por chamada, é o que faz CEN-M03-E01
  /// funcionar: um ganho grande de XP — típico do retorno offline — precisa
  /// aplicar todos os ganhos de atributo e desbloqueios intermediários.
  XpResult grantHeroXp(
    Hero hero,
    GameNumber amount,
    HeroClassDefinition definition,
  ) {
    var level = hero.level;
    var xp = hero.xp + amount;
    var gained = 0;

    while (gained < _maxLevelsPerGrant) {
      final needed = xpToNext(level);
      if (needed.isZero || xp < needed) break;
      xp = xp - needed;
      level++;
      gained++;
    }

    final skills = definition
        .skillsUpTo(level)
        .map((s) => s.id)
        .toList();

    return XpResult(
      hero: hero.copyWith(level: level, xp: xp, unlockedSkillIds: skills),
      levelsGained: gained,
    );
  }

  /// Concede XP de conta e os pontos de runa correspondentes (R-M03-06).
  ///
  /// Não avalia o 4º slot: quem chama deve passar o resultado por
  /// `FormationSlots.evaluate`, que é o único ponto autorizado a mexer em
  /// `formationSlots` (V-PA-02).
  AccountXpResult grantAccountXp(PlayerAccount account, GameNumber amount) {
    var level = account.accountLevel;
    var xp = account.accountXp + amount;
    var gained = 0;

    while (gained < _maxLevelsPerGrant) {
      final needed = accountXpToNext(level);
      if (needed.isZero || xp < needed) break;
      xp = xp - needed;
      level++;
      gained++;
    }

    final points = gained * runePointsPerAccountLevel;
    return AccountXpResult(
      account: account.copyWith(
        accountLevel: level,
        accountXp: xp,
        runePoints: account.runePoints + points,
      ),
      levelsGained: gained,
      runePointsGranted: points,
    );
  }

  /// Registra progresso alcançado sem nunca reduzir um recorde (V-PA-03).
  ///
  /// Usa `globalWave`, não `wave`: o recorde precisa ser comparável entre atos,
  /// e `wave` é relativa ao ato (V-PP-04).
  PlayerAccount recordProgress(
    PlayerAccount account,
    ProgressPosition reached,
  ) => account.copyWith(
    highestWave: math.max(account.highestWave, reached.globalWave),
    highestAct: math.max(account.highestAct, reached.act),
    highestDifficulty: math.max(
      account.highestDifficulty,
      reached.difficulty,
    ),
  );
}
