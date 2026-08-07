import 'dart:ui';

import 'package:flame/components.dart';

/// Poeira levantada pelo pé de quem caminha (R-M08-13).
///
/// O time não muda de lugar durante a caminhada — quem passa é o cenário —, e
/// isso deixa uma ambiguidade que nenhuma animação de pernas resolve sozinha:
/// o mundo pode estar deslizando **sob** um grupo parado. A poeira desfaz a
/// dúvida porque nasce presa ao pé e fica para trás com o chão: é a única coisa
/// na tela que liga o passo do herói ao movimento do mundo.
///
/// Some sozinha ao fim da vida — ninguém precisa colecioná-la.
class DustPuffComponent extends PositionComponent {
  DustPuffComponent({
    required super.position,
    required this.driftSpeed,
    required this.color,
  }) : super(priority: 40);

  /// Com que velocidade fica para trás, em pixels de arte por segundo. É a
  /// mesma rolagem do cenário: a poeira pertence ao chão a partir do instante
  /// em que sai do pé.
  final double driftSpeed;

  final Color color;

  static const double _lifetime = 0.42;
  static const double _rise = 5;
  static const double _radius = 1.6;

  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    if (_age >= _lifetime) {
      removeFromParent();
      return;
    }
    position.x -= driftSpeed * dt;
    position.y -= _rise * dt;
  }

  @override
  void render(Canvas canvas) {
    final t = _age / _lifetime;
    // Cresce enquanto some: nuvem que só apaga lê como pixel com defeito.
    canvas.drawCircle(
      Offset.zero,
      _radius * (0.6 + t),
      Paint()..color = color.withValues(alpha: 0.5 * (1 - t)),
    );
  }
}
