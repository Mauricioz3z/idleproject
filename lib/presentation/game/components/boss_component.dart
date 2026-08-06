import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import 'combatant_component.dart';

/// Boss na arena (CEN-M08-002, SC-M08-03).
///
/// A distinção do monstro comum não pode depender só de tamanho: o jogador
/// precisa saber que está numa wave de boss antes de comparar o inimigo com
/// outro na tela. Por isso o boss tem aura pulsante, coroa e barra de vida
/// própria, mais larga — três sinais independentes.
class BossComponent extends CombatantComponent {
  BossComponent({required super.entityId, required super.position})
    : super(bodyColor: _bossColor, size: Vector2(34, 34));

  static const Color _bossColor = Color(0xFF9B3FBF);
  static const Color _auraColor = Color(0xFFE8B44A);

  /// Ciclos por segundo da aura.
  static const double _pulseRate = 1.2;

  double _elapsed = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
  }

  @override
  void render(Canvas canvas) {
    if (!isDown) _renderAura(canvas);
    super.render(canvas);
    if (!isDown) _renderCrown(canvas);
  }

  void _renderAura(Canvas canvas) {
    final pulse = 0.5 + 0.5 * math.sin(_elapsed * _pulseRate * math.pi * 2);
    final radius = size.x * 0.75 + pulse * 4;

    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      radius,
      Paint()..color = _auraColor.withValues(alpha: 0.10 + pulse * 0.12),
    );
  }

  void _renderCrown(Canvas canvas) {
    final paint = Paint()..color = _auraColor;
    const spikeWidth = 5.0;
    const spikeHeight = 7.0;
    const baseY = -spikeHeight - 2;

    for (var i = 0; i < 3; i++) {
      final x = size.x / 2 - spikeWidth * 1.5 + i * spikeWidth;
      canvas.drawPath(
        Path()
          ..moveTo(x, baseY + spikeHeight)
          ..lineTo(x + spikeWidth / 2, baseY)
          ..lineTo(x + spikeWidth, baseY + spikeHeight)
          ..close(),
        paint,
      );
    }
  }
}
