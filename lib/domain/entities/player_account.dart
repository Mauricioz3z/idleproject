import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import 'progress_position.dart';

/// Raiz do progresso persistente (M03). Uma instância por instalação.
class PlayerAccount {
  PlayerAccount({
    required this.accountLevel,
    required this.accountXp,
    required this.gold,
    required this.gems,
    required this.runePoints,
    required Set<String> unlockedRuneNodeIds,
    required this.respecCount,
    required this.formationSlots,
    required this.fourthSlotSource,
    required this.highestWave,
    required this.highestAct,
    required this.highestDifficulty,
    required this.currentPosition,
    required this.lastSaveAt,
    required this.rngSeed,
    required this.rngCounter,
  }) : unlockedRuneNodeIds = Set.unmodifiable(unlockedRuneNodeIds) {
    assert(
      formationSlots == baseFormationSlots ||
          formationSlots == maxFormationSlots,
      'V-PA-01: formationSlots deve ser 3 ou 4, nunca 5',
    );
    assert(
      (formationSlots == maxFormationSlots) !=
          (fourthSlotSource == FourthSlotSource.none),
      'V-PA-02: formationSlots e fourthSlotSource não podem discordar',
    );
  }

  factory PlayerAccount.fresh({required DateTime now, required int seed}) =>
      PlayerAccount(
        accountLevel: 1,
        accountXp: GameNumber.zero,
        gold: GameNumber.zero,
        gems: 0,
        runePoints: 0,
        unlockedRuneNodeIds: const {},
        respecCount: 0,
        formationSlots: baseFormationSlots,
        fourthSlotSource: FourthSlotSource.none,
        highestWave: 1,
        highestAct: 1,
        highestDifficulty: 1,
        currentPosition: ProgressPosition.start(),
        lastSaveAt: now,
        rngSeed: seed,
        rngCounter: 0,
      );

  /// Formação padrão (R-M01-01).
  static const int baseFormationSlots = 3;

  /// Teto absoluto, inultrapassável por compra ou anúncio (R-M12-10).
  static const int maxFormationSlots = 4;

  /// Nível de conta que desbloqueia o 4º slot gratuitamente (FR-028).
  /// Valor de balanceamento, ajustável.
  static const int fourthSlotUnlockLevel = 25;

  /// Compensação a quem já possuía o slot por compra (R-M03-11, V-ENT-05).
  static const int fourthSlotCompensationGems = 500;

  final int accountLevel;
  final GameNumber accountXp;
  final GameNumber gold;
  final int gems;

  /// Pontos de runa disponíveis, ainda não gastos (V-PA-04).
  final int runePoints;
  final Set<String> unlockedRuneNodeIds;

  /// Base do custo crescente de respec (R-M07-08).
  final int respecCount;

  final int formationSlots;
  final FourthSlotSource fourthSlotSource;

  final int highestWave;
  final int highestAct;
  final int highestDifficulty;

  final ProgressPosition currentPosition;
  final DateTime lastSaveAt;

  final int rngSeed;
  final int rngCounter;

  bool get hasFourthSlot => formationSlots == maxFormationSlots;

  bool get isEligibleForFourthSlot => accountLevel >= fourthSlotUnlockLevel;

  /// Aplica um progresso alcançado sem nunca reduzir um recorde (V-PA-03).
  PlayerAccount recordReached(ProgressPosition reached) => copyWith(
    highestWave: reached.wave > highestWave ? reached.wave : highestWave,
    highestAct: reached.act > highestAct ? reached.act : highestAct,
    highestDifficulty: reached.difficulty > highestDifficulty
        ? reached.difficulty
        : highestDifficulty,
  );

  PlayerAccount copyWith({
    int? accountLevel,
    GameNumber? accountXp,
    GameNumber? gold,
    int? gems,
    int? runePoints,
    Set<String>? unlockedRuneNodeIds,
    int? respecCount,
    int? formationSlots,
    FourthSlotSource? fourthSlotSource,
    int? highestWave,
    int? highestAct,
    int? highestDifficulty,
    ProgressPosition? currentPosition,
    DateTime? lastSaveAt,
    int? rngSeed,
    int? rngCounter,
  }) => PlayerAccount(
    accountLevel: accountLevel ?? this.accountLevel,
    accountXp: accountXp ?? this.accountXp,
    gold: gold ?? this.gold,
    gems: gems ?? this.gems,
    runePoints: runePoints ?? this.runePoints,
    unlockedRuneNodeIds: unlockedRuneNodeIds ?? this.unlockedRuneNodeIds,
    respecCount: respecCount ?? this.respecCount,
    formationSlots: formationSlots ?? this.formationSlots,
    fourthSlotSource: fourthSlotSource ?? this.fourthSlotSource,
    highestWave: highestWave ?? this.highestWave,
    highestAct: highestAct ?? this.highestAct,
    highestDifficulty: highestDifficulty ?? this.highestDifficulty,
    currentPosition: currentPosition ?? this.currentPosition,
    lastSaveAt: lastSaveAt ?? this.lastSaveAt,
    rngSeed: rngSeed ?? this.rngSeed,
    rngCounter: rngCounter ?? this.rngCounter,
  );
}
