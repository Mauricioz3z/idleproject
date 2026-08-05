import 'package:flame/game.dart';

/// Shell do jogo em Flame.
///
/// O ponto central aqui é o **passo fixo** (research.md R10): a lógica de
/// domínio nunca avança pelo `dt` do render. Um jogo cujo resultado de combate
/// depende da taxa de quadros do aparelho dá loot diferente em celular rápido e
/// lento — isso é um bug de justiça, não de performance.
///
/// Esta camada só acumula tempo e desenha. Toda regra vive em `lib/domain/`.
class IdleRpgGame extends FlameGame {
  IdleRpgGame({required this.onFixedStep});

  /// Passo fixo da simulação: 30 Hz, alinhado ao alvo de 30 FPS de
  /// `specification.md` §8.
  static const double fixedStepSeconds = 1 / 30;

  /// Teto de passos por quadro. Sem ele, um congelamento longo (app volta do
  /// background, GC agressivo) tentaria recuperar minutos de simulação num
  /// único quadro e travaria a interface. O tempo excedente não é perdido: cai
  /// no cálculo offline de M09, que é feito exatamente para isso.
  static const int maxStepsPerFrame = 5;

  /// Chamado uma vez por passo fixo. Recebe sempre [fixedStepSeconds].
  final void Function(double fixedDt) onFixedStep;

  double _accumulator = 0;

  /// Quantos passos fixos já foram executados. Útil para diagnóstico e para os
  /// testes de determinismo por FPS.
  int get stepsExecuted => _stepsExecuted;
  int _stepsExecuted = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _accumulator += dt;
    var steps = 0;
    while (_accumulator >= fixedStepSeconds && steps < maxStepsPerFrame) {
      onFixedStep(fixedStepSeconds);
      _accumulator -= fixedStepSeconds;
      steps++;
      _stepsExecuted++;
    }
    if (steps == maxStepsPerFrame) {
      // Descarta o atraso acumulado em vez de arrastá-lo por vários quadros.
      _accumulator = 0;
    }
  }
}
