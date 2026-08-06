import 'dart:ui';

import 'package:flame/components.dart';

import '../sprite_catalog.dart';

/// Base visual de um combatente.
///
/// Desenha o sprite quando ele existe e cai no retângulo colorido quando não —
/// que é o estado que `specification.md` §6 Fase 1 prescreve para validar o
/// laço antes de investir em arte. Os dois caminhos convivem de propósito: a
/// arte pode chegar em levas sem quebrar nada.
class CombatantComponent extends PositionComponent {
  CombatantComponent({
    required this.entityId,
    required this.bodyColor,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.bottomCenter);

  SpriteAnimationComponent? _sprite;
  CombatantAnimations? _animations;
  bool _playingOneShot = false;

  /// Liga as animações. Antes disso — ou se o asset não existir — o componente
  /// segue desenhando o retângulo.
  void applyAnimations(CombatantAnimations animations) {
    _animations = animations;
    final component = SpriteAnimationComponent(
      animation: animations.idle,
      size: size.clone(),
      // O sprite ocupa exatamente a caixa do componente, cuja âncora já é a
      // base — é o que faz os pés encostarem no chão (contrato §1).
      anchor: Anchor.topLeft,
    );
    _sprite = component;
    add(component);
  }

  bool get hasSprite => _sprite != null;

  /// Dispara a animação de golpe, uma vez, voltando ao idle no fim.
  void playAttack() {
    final animations = _animations;
    final sprite = _sprite;
    if (animations == null || sprite == null || isDown || _playingOneShot) {
      return;
    }

    _playingOneShot = true;
    // Em Flame 1.38 quem avisa a conclusão é o ticker, não a animação: cada
    // `set animation` cria um ticker novo, então o callback vai depois.
    sprite.animation = animations.attack.clone();
    sprite.animationTicker?.onComplete = () {
      _playingOneShot = false;
      if (!isDown) sprite.animation = animations.idle;
    };
  }

  void _syncDownState() {
    final animations = _animations;
    final sprite = _sprite;
    if (animations == null || sprite == null) return;

    if (isDown) {
      // A queda toca uma vez e o último quadro fica congelado durante o
      // revive; reiniciá-la a cada tick daria um loop de morte.
      if (sprite.animation != animations.death) {
        _playingOneShot = false;
        sprite.animation = animations.death.clone();
      }
    } else if (!_playingOneShot && sprite.animation == animations.death) {
      sprite.animation = animations.idle;
    }
  }

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
    _syncDownState();

    // A piscada de dano é efeito de código sobre o sprite, e não arte: o
    // contrato de assets é explícito em não pedir quadros de "hit".
    _sprite?.opacity = isDown ? 0.6 : 1.0;
  }

  @override
  void render(Canvas canvas) {
    if (!hasSprite) {
      final body = Paint()
        ..color = _hitFlash > 0
            ? const Color(0xFFFFFFFF)
            : (isDown ? bodyColor.withValues(alpha: 0.25) : bodyColor);
      canvas.drawRect(Offset.zero & size.toSize(), body);
    } else if (_hitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size.toSize(),
        Paint()..color = const Color(0x66FFFFFF),
      );
    }

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
