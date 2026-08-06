import '../core/clock/clock.dart';
import '../domain/engines/offline_simulator.dart';

/// O que o cruzamento dos dois relógios revelou.
enum ClockAnomaly {
  /// Relógio de parede e contador monotônico concordam.
  none,

  /// O relógio de parede andou para trás (CEN-M09-E02).
  movedBackwards,

  /// O relógio de parede saltou muito além do tempo real decorrido
  /// (CEN-M09-E01).
  jumpedForward,

  /// O processo reiniciou: o contador monotônico zerou e não há como cruzar os
  /// dois. Não é anomalia do jogador — é o caso normal de reabrir o app.
  processRestarted,
}

/// Leitura de tempo já pronta para a simulação.
class ClockReading {
  const ClockReading({
    required this.now,
    required this.rawElapsed,
    required this.effectiveElapsed,
    required this.anomaly,
  });

  final DateTime now;

  /// Diferença bruta do relógio de parede. Pode ser negativa.
  final Duration rawElapsed;

  /// Já saturada em zero e limitada ao teto de 8 h (R-M09-02).
  final Duration effectiveElapsed;

  final ClockAnomaly anomaly;

  bool get wasCapped => rawElapsed > effectiveElapsed;
  bool get isSuspicious =>
      anomaly == ClockAnomaly.movedBackwards ||
      anomaly == ClockAnomaly.jumpedForward;
}

/// Cruza relógio de parede e contador monotônico (research.md R7).
///
/// **Detecta, não pune.** O teto de 8 h de [OfflineSimulator] já neutraliza o
/// ganho de adiantar o relógio, e atrasar não subtrai nada. O que esta classe
/// acrescenta é observabilidade: saber que aconteceu, registrar em analytics e
/// não confundir manipulação com fuso horário, horário de verão ou sincronismo
/// de rede — nenhum dos quais deve custar progresso ao jogador.
class ClockGuard {
  ClockGuard({
    required Clock clock,
    void Function(ClockAnomaly anomaly, Map<String, Object?> data)? onAnomaly,
  }) : _clock = clock,
       _onAnomaly = onAnomaly;

  /// Folga entre os dois relógios antes de chamar de anomalia. Cobre latência
  /// de gravação, ajuste de NTP e arredondamento de segundo.
  static const Duration tolerance = Duration(minutes: 2);

  final Clock _clock;
  final void Function(ClockAnomaly, Map<String, Object?>)? _onAnomaly;

  ClockReading evaluate({
    required DateTime lastSaveAt,
    required int lastMonotonicMillis,
  }) {
    final now = _clock.now();
    final monotonicNow = _clock.monotonicMillis();
    final raw = now.difference(lastSaveAt);

    final anomaly = _classify(
      raw: raw,
      monotonicNow: monotonicNow,
      lastMonotonicMillis: lastMonotonicMillis,
    );

    final seconds = raw.inSeconds <= 0
        ? 0
        : (raw.inSeconds > OfflineSimulator.maxOfflineSeconds
              ? OfflineSimulator.maxOfflineSeconds
              : raw.inSeconds);

    final reading = ClockReading(
      now: now,
      rawElapsed: raw,
      effectiveElapsed: Duration(seconds: seconds),
      anomaly: anomaly,
    );

    if (reading.isSuspicious) {
      _onAnomaly?.call(anomaly, {
        'rawElapsedSeconds': raw.inSeconds,
        'effectiveElapsedSeconds': seconds,
        'monotonicDeltaMillis': monotonicNow - lastMonotonicMillis,
      });
    }

    return reading;
  }

  ClockAnomaly _classify({
    required Duration raw,
    required int monotonicNow,
    required int lastMonotonicMillis,
  }) {
    if (raw.isNegative) return ClockAnomaly.movedBackwards;

    // O contador monotônico zera com o processo. Nesse caso ele não tem o que
    // dizer sobre o intervalo, e insistir produziria falso positivo em toda
    // reabertura — que é justamente o momento em que a simulação roda.
    if (monotonicNow < lastMonotonicMillis) return ClockAnomaly.processRestarted;

    final monotonicDelta = Duration(
      milliseconds: monotonicNow - lastMonotonicMillis,
    );
    if (raw - monotonicDelta > tolerance) return ClockAnomaly.jumpedForward;

    return ClockAnomaly.none;
  }
}
