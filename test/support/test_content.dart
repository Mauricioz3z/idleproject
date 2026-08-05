import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/entities/hero_class_definition.dart';
import 'package:pixel_idle_quest/domain/entities/monster_template.dart';
import 'package:pixel_idle_quest/domain/entities/stats.dart';

/// Fixtures de conteúdo para testes de domínio.
///
/// Valores redondos de propósito: um teste que afirma "70 de dano" comunica a
/// fórmula; um que afirma "68,3" comunica só que alguém rodou o código.
abstract final class TestContent {
  static Stats stats({
    double attack = 0,
    double defense = 0,
    double maxHp = 100,
    double str = 10,
    double dex = 10,
    double intel = 10,
    double vit = 10,
    double agi = 10,
  }) => Stats(
    str: GameNumber.fromDouble(str),
    dex: GameNumber.fromDouble(dex),
    intel: GameNumber.fromDouble(intel),
    vit: GameNumber.fromDouble(vit),
    agi: GameNumber.fromDouble(agi),
    attack: GameNumber.fromDouble(attack),
    defense: GameNumber.fromDouble(defense),
    maxHp: GameNumber.fromDouble(maxHp),
  );

  static HeroClassDefinition heroClass({
    String id = 'test_class',
    HeroRole role = HeroRole.meleeDamage,
    TargetingRule targetingRule = TargetingRule.nearest,
    ClassMechanic mechanic = ClassMechanic.bleed,
    double attack = 100,
    double defense = 10,
    double maxHp = 500,
    double attacksPerSecond = 1,
    List<SkillDefinition> skills = const [],
  }) => HeroClassDefinition(
    id: id,
    displayName: id,
    role: role,
    primaryStats: const ['str'],
    targetingRule: targetingRule,
    mechanic: mechanic,
    baseStats: stats(attack: attack, defense: defense, maxHp: maxHp),
    statGrowthPerLevel: stats(
      attack: 10,
      defense: 1,
      maxHp: 50,
      str: 2,
      dex: 1,
      intel: 1,
      vit: 2,
      agi: 1,
    ),
    attacksPerSecond: attacksPerSecond,
    skills: skills,
  );

  /// As 6 classes de M02, com as mecânicas únicas corretas.
  static List<HeroClassDefinition> sixClasses() => [
    heroClass(
      id: 'vanguard',
      role: HeroRole.tank,
      mechanic: ClassMechanic.taunt,
      targetingRule: TargetingRule.nearest,
      attack: 60,
      defense: 40,
      maxHp: 1000,
    ),
    heroClass(
      id: 'elementalist',
      role: HeroRole.magicDamage,
      mechanic: ClassMechanic.areaElemental,
      targetingRule: TargetingRule.nearest,
      attack: 120,
      defense: 8,
      maxHp: 400,
    ),
    heroClass(
      id: 'sharpshooter',
      role: HeroRole.rangedDamage,
      mechanic: ClassMechanic.defensePenetration,
      targetingRule: TargetingRule.lowestHp,
      attack: 110,
      defense: 10,
      maxHp: 450,
    ),
    heroClass(
      id: 'medtech',
      role: HeroRole.support,
      mechanic: ClassMechanic.healAndHaste,
      targetingRule: TargetingRule.lowestHp,
      attack: 50,
      defense: 15,
      maxHp: 600,
    ),
    heroClass(
      id: 'tracker',
      role: HeroRole.meleeDamage,
      mechanic: ClassMechanic.bleed,
      targetingRule: TargetingRule.nearest,
      attack: 90,
      defense: 12,
      maxHp: 550,
      attacksPerSecond: 2,
    ),
    heroClass(
      id: 'berserker',
      role: HeroRole.brute,
      mechanic: ClassMechanic.rageOnLowHp,
      targetingRule: TargetingRule.nearest,
      attack: 130,
      defense: 10,
      maxHp: 700,
    ),
  ];

  static MonsterTemplate monster({
    String id = 'slime',
    int act = 1,
    double attack = 20,
    double defense = 10,
    double maxHp = 100,
    bool isBoss = false,
    List<ItemRarity> rarities = const [ItemRarity.bronze, ItemRarity.prata],
    double dropChanceModifier = 1.0,
    double essenceChanceModifier = 1.0,
  }) => MonsterTemplate(
    id: id,
    displayName: id,
    act: act,
    baseStats: stats(attack: attack, defense: defense, maxHp: maxHp),
    possibleRarities: rarities,
    dropChanceModifier: dropChanceModifier,
    essenceChanceModifier: essenceChanceModifier,
    isBoss: isBoss,
  );
}
