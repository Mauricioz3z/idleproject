import 'dart:ui';

import 'package:flame/components.dart';

/// Base visual de um combatente.
///
/// Sprites finais chegam na Fase 10 (T143). Até lá, retângulos coloridos —
/// exatamente o que `specification.md` §6 Fase 1 prescreve para validar se o
/// laço de combate é divertido antes de investir em arte.
class CombatantComponent extends PositionComponent {
  CombatantComponent({
    required this.entityId,
    required this.bodyColor,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.bottomCenter);

  /// ID do herói ou do monstro que este componente representa.
  final String entityId;
  final Color bodyColor;

  /// Fração de HP, de 0 a 1. Alimenta a barra de vida.
  double hpFraction = 1;

  /// Incapacitado ou morto: desenhado esmaecido, sem barra.
  bool isDown = false;

  /// Segundos restantes do flash de dano.
  double _hitFlash = 0;

  static const double _barHeight = 3;
  static const double _barGap = 4;
  static const double hitFlashDuration = 0.12;

  void flashHit() => _hitFlash = hitFlashDuration;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlash > 0) _hitFlash -= dt;
  }

  @override
  void render(Canvas canvas) {
    final body = Paint()
      ..color = _hitFlash > 0
          ? const Color(0xFFFFFFFF)
          : (isDown ? bodyColor.withValues(alpha: 0.25) : bodyColor);

    canvas.drawRect(Offset.zero & size.toSize(), body);

    if (isDown) return;

    const barTop = -_barGap - _barHeight;
    canvas.drawRect(
      Rect.fromLTWH(0, barTop, size.x, _barHeight),
      Paint()..color = const Color(0xFF3A3548),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, barTop, size.x * hpFraction.clamp(0, 1), _barHeight),
      Paint()..color = _hpColor(),
    );
  }

  Color _hpColor() {
    if (hpFraction > 0.5) return const Color(0xFF5FBF60);
    if (hpFraction > 0.25) return const Color(0xFFE8B44A);
    return const Color(0xFFD24B4B);
  }
}

/// Herói na arena. Cor por papel, até haver sprites.
class HeroComponent extends CombatantComponent {
  HeroComponent({
    required super.entityId,
    required super.position,
    required Color color,
  }) : super(bodyColor: color, size: Vector2(16, 24));
}

/// Monstro na arena. Bosses são maiores e visualmente distintos
/// (CEN-M08-002).
class MonsterComponent extends CombatantComponent {
  MonsterComponent({
    required super.entityId,
    required super.position,
    required bool isBoss,
  }) : super(
         bodyColor: isBoss ? const Color(0xFF9B3FBF) : const Color(0xFFB55A45),
         size: isBoss ? Vector2(32, 32) : Vector2(16, 16),
       );
}
