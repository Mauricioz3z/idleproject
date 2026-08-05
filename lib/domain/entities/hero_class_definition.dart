import '../../core/constants/game_enums.dart';
import 'stats.dart';

/// Habilidade desbloqueada por nível de herói (R-M03-04).
class SkillDefinition {
  const SkillDefinition({
    required this.id,
    required this.displayName,
    required this.unlockLevel,
  });

  final String id;
  final String displayName;
  final int unlockLevel;
}

/// Definição de classe, carregada de `assets/content/hero_classes.json`.
///
/// Conteúdo estático: o save guarda apenas o `classId` do herói. As 6 classes
/// de M02 e futuras classes de DLC entram pelo mesmo mecanismo.
class HeroClassDefinition {
  const HeroClassDefinition({
    required this.id,
    required this.displayName,
    required this.role,
    required this.primaryStats,
    required this.targetingRule,
    required this.mechanic,
    required this.baseStats,
    required this.statGrowthPerLevel,
    required this.skills,
    this.attacksPerSecond = 1.0,
  });

  final String id;
  final String displayName;
  final HeroRole role;

  /// Atributos principais da classe (um ou dois, conforme a tabela de M02).
  final List<String> primaryStats;

  /// Regra de alvo, definida por classe (R-M01-02).
  final TargetingRule targetingRule;

  /// Mecânica única, sempre ativa em combate (R-M02-04).
  final ClassMechanic mechanic;

  final Stats baseStats;
  final Stats statGrowthPerLevel;
  final List<SkillDefinition> skills;

  /// Cadência de ataque base. O Tracker ataca mais rápido (M02), o Vanguard
  /// mais devagar. Modificada por sufixos de item e pelo buff do Medtech.
  final double attacksPerSecond;

  /// Habilidades desbloqueadas até o nível dado.
  List<SkillDefinition> skillsUpTo(int level) =>
      skills.where((s) => s.unlockLevel <= level).toList();
}
