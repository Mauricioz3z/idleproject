import 'package:pixel_idle_quest/core/clock/clock.dart';

/// Relógio controlável para testes.
///
/// Permite mover o relógio de parede sem mover o monotônico — que é exatamente
/// o que caracteriza manipulação de relógio pelo jogador (CEN-M09-E01, E02).
class FakeClock implements Clock {
  FakeClock({DateTime? start, int monotonic = 0})
    : _now = start ?? DateTime.utc(2026, 1, 1),
      _monotonic = monotonic;

  DateTime _now;
  int _monotonic;

  @override
  DateTime now() => _now;

  @override
  int monotonicMillis() => _monotonic;

  /// Avança ambos os relógios de forma coerente — passagem normal de tempo.
  void advance(Duration d) {
    _now = _now.add(d);
    _monotonic += d.inMilliseconds;
  }

  /// Move só o relógio de parede: simula o jogador adiantando ou atrasando o
  /// aparelho. O monotônico permanece, revelando a inconsistência.
  void skewWallClock(Duration d) => _now = _now.add(d);

  /// Avança só o monotônico, sem tocar no relógio de parede.
  void advanceMonotonic(Duration d) => _monotonic += d.inMilliseconds;
}
