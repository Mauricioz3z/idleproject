import '../../core/constants/game_enums.dart';
import '../entities/monster.dart';

/// As 6 mecânicas únicas de classe (M02, R-M02-04).
///
/// Funções puras, sem estado: cada uma responde "o que esta mecânica muda?"
/// para um aspecto do combate. `CombatEngine` consulta; elas não conhecem o
/// motor. É o que permite testar cada mecânica isoladamente, sem montar uma
/// wave inteira.
abstract final class ClassMechanics {
  /// Fração da DEF do alvo que o Sharpshooter ignora (CEN-M02-004).
  static const double defensePenetrationFraction = 0.5;

  /// Bônus de chance de crítico do Sharpshooter (CEN-M02-005).
  static const double sharpshooterCritBonus = 0.15;

  /// Multiplicador de velocidade de ataque do buff do Medtech (CEN-M02-006).
  static const double medtechHasteMultiplier = 1.25;

  /// Fração do ATK convertida em cura por ação do Medtech.
  static const double medtechHealFraction = 0.6;

  /// Fração do dano do Tracker convertida em sangramento por segundo, e sua
  /// duração (CEN-M02-007).
  static const double bleedDpsFraction = 0.25;
  static const double bleedDurationSeconds = 4;

  /// Dano extra do Berserker com HP zerado (CEN-M02-008). Com HP cheio o
  /// multiplicador é 1,0; a interpolação é linear na perda de HP.
  static const double berserkerMaxBonus = 1.0;

  /// Redução do dano em área recebido pelos aliados, concedida pelo Vanguard.
  static const double vanguardAoeReduction = 0.3;

  /// Quantos monstros um ataque em área atinge além do alvo principal.
  static const int areaExtraTargets = 2;

  /// Multiplicador de dano da mecânica, dado o HP fracionário do atacante.
  ///
  /// Só o Berserker usa [hpFraction]; para as demais o valor é 1,0 — o que faz
  /// o teste de "outras classes não escalam com HP" ser trivialmente verdadeiro.
  static double damageMultiplier(
    ClassMechanic mechanic, {
    required double hpFraction,
  }) {
    if (mechanic != ClassMechanic.rageOnLowHp) return 1.0;
    final missing = (1.0 - hpFraction).clamp(0.0, 1.0);
    return 1.0 + berserkerMaxBonus * missing;
  }

  /// Fração da DEF do alvo efetivamente aplicada contra este atacante.
  static double defenseFactor(ClassMechanic mechanic) =>
      mechanic == ClassMechanic.defensePenetration
      ? 1.0 - defensePenetrationFraction
      : 1.0;

  /// Bônus de chance de crítico da mecânica.
  static double critBonus(ClassMechanic mechanic) =>
      mechanic == ClassMechanic.defensePenetration ? sharpshooterCritBonus : 0.0;

  /// Multiplicador de velocidade de ataque que a mecânica concede ao time.
  static double attackSpeedBuff(ClassMechanic mechanic) =>
      mechanic == ClassMechanic.healAndHaste ? medtechHasteMultiplier : 1.0;

  /// Atrai o alvo dos monstros para si (Vanguard, CEN-M02-002).
  static bool taunts(ClassMechanic mechanic) => mechanic == ClassMechanic.taunt;

  static bool heals(ClassMechanic mechanic) =>
      mechanic == ClassMechanic.healAndHaste;

  static bool causesBleed(ClassMechanic mechanic) =>
      mechanic == ClassMechanic.bleed;

  /// IDs dos monstros atingidos por um golpe, incluindo o alvo principal.
  ///
  /// Só a mecânica de área alcança mais de um (CEN-M02-003).
  static List<String> additionalTargets(
    ClassMechanic mechanic,
    List<Monster> monsters, {
    required String primary,
  }) {
    if (mechanic != ClassMechanic.areaElemental) return [primary];
    final alive = monsters.where((m) => m.isAlive).toList()
      ..sort((a, b) => a.slot.compareTo(b.slot));
    final ids = <String>[primary];
    for (final m in alive) {
      if (ids.length > areaExtraTargets) break;
      if (m.instanceId != primary) ids.add(m.instanceId);
    }
    return ids;
  }
}
