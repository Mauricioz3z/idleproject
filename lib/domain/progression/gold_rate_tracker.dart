import '../../core/numeric/game_number.dart';

/// Apura o ouro por segundo do jogo ativo (M09, suposição declarada).
///
/// A taxa é medida, não derivada da formação: é o desempenho **real** dos
/// últimos minutos, já contando quanto tempo o time passou incapacitado e
/// quanto tempo levou por wave. Derivar do poder teórico prometeria offline um
/// ouro que o jogador não estava conseguindo online.
///
/// Implementado como janela deslizante com decaimento, e não como média desde o
/// início da sessão: quem acabou de equipar um item melhor precisa que a taxa
/// suba em minutos, não que ela fique presa ao desempenho de uma hora atrás.
class GoldRateTracker {
  GoldRateTracker({this.windowSeconds = defaultWindowSeconds});

  /// Janela de apuração. Dois minutos cobrem várias waves sem tornar a taxa
  /// refém de um único boss.
  static const double defaultWindowSeconds = 120;

  final double windowSeconds;

  GameNumber _gold = GameNumber.zero;
  double _seconds = 0;

  /// Segundos já acumulados na janela. Abaixo de [minimumSampleSeconds] a taxa
  /// ainda não é confiável.
  double get sampleSeconds => _seconds;

  /// Amostra mínima para publicar uma taxa. Sem ela, abrir e fechar o app em
  /// dois segundos durante um boss produziria uma taxa absurda, e o teto de 8 h
  /// a transformaria numa fortuna.
  static const double minimumSampleSeconds = 5;

  bool get hasEnoughSamples => _seconds >= minimumSampleSeconds;

  /// Registra o ouro ganho em [dt] segundos de jogo.
  void record(GameNumber gold, double dt) {
    if (dt <= 0) return;
    _gold = _gold + gold;
    _seconds += dt;

    if (_seconds > windowSeconds) {
      // Decai proporcionalmente em vez de zerar: zerar faria a taxa oscilar em
      // degraus a cada janela fechada.
      final factor = windowSeconds / _seconds;
      _gold = _gold.scaled(factor);
      _seconds = windowSeconds;
    }
  }

  /// Taxa apurada. Zero enquanto a amostra for curta demais.
  GameNumber get ratePerSecond {
    if (!hasEnoughSamples || _seconds <= 0) return GameNumber.zero;
    return _gold / GameNumber.fromDouble(_seconds);
  }

  void reset() {
    _gold = GameNumber.zero;
    _seconds = 0;
  }
}
