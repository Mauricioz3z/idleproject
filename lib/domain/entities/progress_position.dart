/// Onde o jogador está na progressão: dificuldade, ato e wave.
///
/// **Nota de modelagem** (data-model.md): a spec lista `Wave` como entidade.
/// Ela é decomposta em duas porque as partes têm ciclos de vida opostos — esta
/// classe é persistida, enquanto o encontro em andamento (`CombatState`) é
/// transitório e nunca gravado. Modelar `Wave` como entidade única levaria a
/// persistir combate parcial, contra V-PP-03 e CEN-M10-E01.
class ProgressPosition {
  const ProgressPosition({
    required this.difficulty,
    required this.act,
    required this.wave,
  });

  factory ProgressPosition.start() =>
      const ProgressPosition(difficulty: 1, act: 1, wave: 1);

  /// V-PP-01 com saturação: valores fora da faixa são trazidos para o limite
  /// válido mais próximo em vez de lançar (D-07 da desserialização).
  factory ProgressPosition.clamped({
    required int difficulty,
    required int act,
    required int wave,
  }) => ProgressPosition(
    difficulty: difficulty < 1 ? 1 : difficulty,
    act: act.clamp(minAct, maxAct),
    wave: wave.clamp(minWave, maxWave),
  );

  static const int minAct = 1;
  static const int maxAct = 3;
  static const int minWave = 1;
  static const int maxWave = 100;
  static const int bossInterval = 10;

  /// Dificuldade atual, começando em 1. Sem teto (R-M08-09).
  final int difficulty;

  /// Ato, de 1 a 3 (R-M08-01).
  final int act;

  /// Wave dentro do ato, de 1 a 100 (R-M08-02).
  final int wave;

  /// V-PP-02: wave de boss a cada 10 (R-M08-03).
  bool get isBossWave => wave % bossInterval == 0;

  /// Numeração acumulada entre atos, para exibição e para recordes.
  ///
  /// [wave] é sempre relativa ao ato (1 a 100), porque é assim que R-M08-02 e
  /// R-M08-03 funcionam — o boss a cada 10 conta dentro do ato. Mas o jogador
  /// vê "Wave 142 (Ato 2)", como em `specification.md` §4.6, e é este getter
  /// que produz esse número. Confundir os dois leva a posições impossíveis,
  /// como "wave 142 do ato 2".
  int get globalWave => (act - 1) * maxWave + wave;

  /// Boss final do ato.
  bool get isActFinale => wave == maxWave;

  /// Concluir esta wave desbloqueia a próxima dificuldade (R-M08-07).
  bool get unlocksNextDifficulty => act == maxAct && isActFinale;

  bool get isValid =>
      difficulty >= 1 &&
      act >= minAct &&
      act <= maxAct &&
      wave >= minWave &&
      wave <= maxWave;

  ProgressPosition copyWith({int? difficulty, int? act, int? wave}) =>
      ProgressPosition(
        difficulty: difficulty ?? this.difficulty,
        act: act ?? this.act,
        wave: wave ?? this.wave,
      );

  @override
  bool operator ==(Object other) =>
      other is ProgressPosition &&
      other.difficulty == difficulty &&
      other.act == act &&
      other.wave == wave;

  @override
  int get hashCode => Object.hash(difficulty, act, wave);

  @override
  String toString() => 'D$difficulty A$act W$wave';
}
