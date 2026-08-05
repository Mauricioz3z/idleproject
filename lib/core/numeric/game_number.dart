import 'dart:math' as math;

/// Grandeza de jogo sem teto prático, representada como mantissa + expoente.
///
/// Existe porque R-M08-08 multiplica todos os atributos dos monstros por 1,5 a
/// cada dificuldade, sem teto (R-M08-09). Esse crescimento estoura `int64`
/// (máximo ~9,22e18) em algum ponto entre a dificuldade 74 e 108 conforme a
/// base adotada, e em Dart nativo o transbordo de `int` é **silencioso** — o
/// ouro viraria negativo sem lançar exceção. Ver research.md R6.
///
/// Invariantes (data-model.md):
/// - **V-GN-01**: após qualquer operação o valor é renormalizado; mantissa fica
///   em `[1,10)`, ou o valor é exatamente zero (mantissa 0, expoente 0).
/// - **V-GN-02**: grandezas de jogo nunca são negativas; a subtração satura.
///
/// Contadores discretos (nível, wave, slots, pontos de runa) **não** usam este
/// tipo — V-GN-03.
class GameNumber implements Comparable<GameNumber> {
  const GameNumber._(this.mantissa, this.exponent);

  /// Constrói a partir de mantissa e expoente arbitrários, normalizando.
  factory GameNumber(double mantissa, int exponent) {
    if (mantissa == 0 || !mantissa.isFinite) {
      return mantissa.isFinite ? zero : infinity;
    }
    if (mantissa < 0) return zero; // V-GN-02
    final shift = (math.log(mantissa) / math.ln10).floor();
    final normalized = mantissa / math.pow(10, shift);
    return GameNumber._(normalized, exponent + shift);
  }

  factory GameNumber.fromInt(int value) =>
      value <= 0 ? zero : GameNumber(value.toDouble(), 0);

  factory GameNumber.fromDouble(double value) =>
      value <= 0 ? zero : GameNumber(value, 0);

  /// Mantissa normalizada em `[1,10)`, ou exatamente `0`.
  final double mantissa;

  /// Potência de 10 associada à mantissa.
  final int exponent;

  static const GameNumber zero = GameNumber._(0, 0);
  static const GameNumber one = GameNumber._(1, 0);

  /// Sentinela de estouro. Não deve ocorrer em jogo; existe para que um bug
  /// apareça como valor infinito em vez de virar lixo silenciosamente.
  static const GameNumber infinity = GameNumber._(double.infinity, 0);

  bool get isZero => mantissa == 0;
  bool get isFinite => mantissa.isFinite;

  /// Além deste ponto a soma de um operando menor não altera a mantissa do
  /// maior dentro da precisão de `double`.
  static const int _precisionWindow = 17;

  GameNumber operator +(GameNumber other) {
    if (isZero) return other;
    if (other.isZero) return this;
    final diff = exponent - other.exponent;
    if (diff > _precisionWindow) return this;
    if (diff < -_precisionWindow) return other;
    if (diff >= 0) {
      return GameNumber(
        mantissa + other.mantissa / math.pow(10, diff),
        exponent,
      );
    }
    return GameNumber(
      other.mantissa + mantissa / math.pow(10, -diff),
      other.exponent,
    );
  }

  /// Subtração saturante: nunca produz valor negativo (V-GN-02).
  GameNumber operator -(GameNumber other) {
    if (other.isZero) return this;
    if (this <= other) return zero;
    final diff = exponent - other.exponent;
    if (diff > _precisionWindow) return this;
    return GameNumber(mantissa - other.mantissa / math.pow(10, diff), exponent);
  }

  GameNumber operator *(GameNumber other) {
    if (isZero || other.isZero) return zero;
    return GameNumber(mantissa * other.mantissa, exponent + other.exponent);
  }

  /// Divisão por zero devolve zero em vez de `NaN` — nenhuma fórmula de jogo
  /// tem significado útil para NaN, e propagá-lo corromperia o save.
  GameNumber operator /(GameNumber other) {
    if (other.isZero || isZero) return zero;
    return GameNumber(mantissa / other.mantissa, exponent - other.exponent);
  }

  GameNumber scaled(double factor) =>
      factor <= 0 || isZero ? zero : GameNumber(mantissa * factor, exponent);

  /// Eleva a uma potência inteira. Usado pelo escalonamento de dificuldade
  /// `1.5^(difficulty-1)` sem laço no caminho quente.
  GameNumber pow(int e) {
    if (isZero) return zero;
    if (e == 0) return one;
    final logTotal = (math.log(mantissa) / math.ln10 + exponent) * e;
    final intPart = logTotal.floor();
    return GameNumber(math.pow(10, logTotal - intPart).toDouble(), intPart);
  }

  bool operator <(GameNumber other) => compareTo(other) < 0;
  bool operator <=(GameNumber other) => compareTo(other) <= 0;
  bool operator >(GameNumber other) => compareTo(other) > 0;
  bool operator >=(GameNumber other) => compareTo(other) >= 0;

  @override
  int compareTo(GameNumber other) {
    if (isZero && other.isZero) return 0;
    if (isZero) return -1;
    if (other.isZero) return 1;
    if (exponent != other.exponent) return exponent.compareTo(other.exponent);
    return mantissa.compareTo(other.mantissa);
  }

  /// Converte para `double`. Pode saturar em infinito acima de ~1e308 — use
  /// apenas para exibição ou comparação em faixa segura, nunca para persistir.
  double toDouble() => mantissa * math.pow(10, exponent);

  /// Converte para `int`. Satura no máximo de int64 em vez de transbordar.
  int toInt() {
    if (exponent > 18) return 9223372036854775807;
    return toDouble().floor();
  }

  /// Tolerância relativa de 1e-9: as operações passam por `double`, então
  /// igualdade estrita de bits produziria falsos negativos.
  @override
  bool operator ==(Object other) {
    if (other is! GameNumber) return false;
    if (isZero && other.isZero) return true;
    return exponent == other.exponent &&
        (mantissa - other.mantissa).abs() < 1e-9;
  }

  @override
  int get hashCode => Object.hash(exponent, (mantissa * 1e9).round());

  @override
  String toString() => isZero ? '0' : '${mantissa}e$exponent';
}
