import '../../core/numeric/game_number.dart';

/// Atributos primários, compartilhados por heróis e monstros (§4.3).
///
/// Usa [GameNumber] e não `int` porque os atributos de monstro escalam por
/// `1.5^(dificuldade-1)` sem teto (R-M08-08/09) — ver research.md R6.
class Stats {
  const Stats({
    required this.str,
    required this.dex,
    required this.intel,
    required this.vit,
    required this.agi,
    required this.attack,
    required this.defense,
    required this.maxHp,
  });

  factory Stats.zero() => const Stats(
    str: GameNumber.zero,
    dex: GameNumber.zero,
    intel: GameNumber.zero,
    vit: GameNumber.zero,
    agi: GameNumber.zero,
    attack: GameNumber.zero,
    defense: GameNumber.zero,
    maxHp: GameNumber.zero,
  );

  /// Força.
  final GameNumber str;

  /// Destreza.
  final GameNumber dex;

  /// Inteligência. Nomeado `intel` porque `int` é palavra reservada em Dart.
  final GameNumber intel;

  /// Vitalidade.
  final GameNumber vit;

  /// Agilidade.
  final GameNumber agi;

  /// Ataque efetivo, já somando bônus de itens.
  final GameNumber attack;

  /// Defesa efetiva.
  final GameNumber defense;

  final GameNumber maxHp;

  Stats operator +(Stats other) => Stats(
    str: str + other.str,
    dex: dex + other.dex,
    intel: intel + other.intel,
    vit: vit + other.vit,
    agi: agi + other.agi,
    attack: attack + other.attack,
    defense: defense + other.defense,
    maxHp: maxHp + other.maxHp,
  );

  /// Multiplica todos os atributos por um fator escalar.
  /// É a operação de escalonamento por dificuldade (R-M08-08).
  Stats scaledBy(GameNumber factor) => Stats(
    str: str * factor,
    dex: dex * factor,
    intel: intel * factor,
    vit: vit * factor,
    agi: agi * factor,
    attack: attack * factor,
    defense: defense * factor,
    maxHp: maxHp * factor,
  );

  Stats copyWith({
    GameNumber? str,
    GameNumber? dex,
    GameNumber? intel,
    GameNumber? vit,
    GameNumber? agi,
    GameNumber? attack,
    GameNumber? defense,
    GameNumber? maxHp,
  }) => Stats(
    str: str ?? this.str,
    dex: dex ?? this.dex,
    intel: intel ?? this.intel,
    vit: vit ?? this.vit,
    agi: agi ?? this.agi,
    attack: attack ?? this.attack,
    defense: defense ?? this.defense,
    maxHp: maxHp ?? this.maxHp,
  );
}
