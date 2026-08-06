import '../../domain/entities/progress_position.dart';

/// Curvas de escalonamento de item (M04, M08).
///
/// Vivem em `core/constants/` e não dentro do gerador porque a mesma curva é
/// consumida pelo combate, pela simulação offline e pela projeção do widget —
/// três lugares que precisam concordar sobre o poder de um item obtido na mesma
/// posição.
///
/// É o único ponto de `core/` que importa de `domain/`: [ProgressPosition] é o
/// vocabulário da curva, e duplicá-la como um trio de inteiros soltos abriria
/// espaço para trocar `wave` por `globalWave` na chamada — o erro que V-PP-04
/// existe para prevenir.
abstract final class ItemScaling {
  /// Quanto cada dificuldade acrescenta ao item level (R-M08-08, CEN-M04-012).
  ///
  /// É um degrau fixo, não um fator: a dificuldade já multiplica os atributos
  /// dos monstros: fazê-la multiplicar também o item level empilharia dois
  /// crescimentos exponenciais e o balanceamento sairia de controle.
  static const int itemLevelPerDifficulty = 10;

  /// Item level de um drop obtido em [position]:
  /// `f(wave, act) + 10 × (difficulty − 1)` (R-M04-05, contrato de M04).
  ///
  /// `f` é a wave acumulada entre atos ([ProgressPosition.globalWave]), não a
  /// wave relativa: usar a relativa faria o item level despencar na virada de
  /// ato, e a wave 1 do Ato 2 dropar pior que a wave 100 do Ato 1 (V-PP-04).
  static int itemLevelFor(ProgressPosition position) =>
      position.globalWave +
      itemLevelPerDifficulty * (position.difficulty - 1);

  /// Atributo base de um item, antes da variância do sorteio.
  ///
  /// Linear no item level e geométrico na raridade: dois itens de mesmo tipo e
  /// raridade se ordenam pelo item level (CEN-M04-005), e dois de mesmo item
  /// level se ordenam pela raridade (CEN-M04-006).
  static double baseStatFor({required int itemLevel, required int rarityIndex}) {
    var value = 5.0 + 2.0 * itemLevel;
    for (var i = 0; i < rarityIndex; i++) {
      value *= rarityStatMultiplier;
    }
    return value;
  }

  /// Ganho de atributo base por degrau de raridade.
  static const double rarityStatMultiplier = 1.6;

  /// Variância multiplicativa do atributo base, para que dois itens iguais no
  /// papel não sejam idênticos na prática.
  static const double baseStatVariance = 0.15;
}
