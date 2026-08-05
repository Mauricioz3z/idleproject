import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter/widgets.dart' show Color;

/// Natureza do número flutuante, que define cor e tamanho.
enum FloatingNumberKind { damage, critical, heal, bleed }

/// Número flutuante sobre o alvo (R-M01-08).
///
/// Crítico, dano normal, cura e sangramento precisam ser distinguíveis à
/// primeira vista — é o principal feedback de que o combate automático está
/// funcionando, num jogo em que o jogador não dá nenhum comando.
class DamageNumberComponent extends TextComponent {
  DamageNumberComponent({
    required String value,
    required this.kind,
    required super.position,
  }) : super(
         text: kind == FloatingNumberKind.heal ? '+$value' : value,
         anchor: Anchor.bottomCenter,
         priority: 100,
       );

  final FloatingNumberKind kind;

  static const double _lifetime = 0.9;
  static const double _riseDistance = 26;

  static const Map<FloatingNumberKind, Color> _colors = {
    FloatingNumberKind.damage: Color(0xFFEDE7DA),
    FloatingNumberKind.critical: Color(0xFFE8B44A),
    FloatingNumberKind.heal: Color(0xFF5FBF60),
    FloatingNumberKind.bleed: Color(0xFFD24B4B),
  };

  @override
  Future<void> onLoad() async {
    textRenderer = TextPaint(
      style: TextStyle(
        color: _colors[kind],
        fontSize: kind == FloatingNumberKind.critical ? 14 : 10,
        fontWeight: kind == FloatingNumberKind.critical
            ? FontWeight.bold
            : FontWeight.normal,
      ),
    );

    add(
      MoveByEffect(
        Vector2(0, -_riseDistance),
        EffectController(duration: _lifetime, curve: Curves.easeOut),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        EffectController(duration: _lifetime),
        onComplete: removeFromParent,
      ),
    );
  }
}
