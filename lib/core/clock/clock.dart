/// Porta de tempo. Nenhum serviço de domínio chama `DateTime.now()`
/// diretamente — isso quebraria o determinismo exigido por research.md R9 e
/// tornaria CEN-M09-E01/E02 (manipulação de relógio) intestáveis.
///
/// São dois relógios porque eles servem a propósitos diferentes e podem
/// discordar (research.md R7):
/// - [now] é o relógio de parede, base do cálculo de intervalo offline. O
///   jogador pode mexer nele.
/// - [monotonicMillis] é um contador que só avança. Serve para **detectar** que
///   o relógio de parede foi alterado, não para punir o jogador.
abstract interface class Clock {
  DateTime now();
  int monotonicMillis();
}

/// Implementação de produção.
class SystemClock implements Clock {
  SystemClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  DateTime now() => DateTime.now();

  @override
  int monotonicMillis() => _stopwatch.elapsedMilliseconds;
}
