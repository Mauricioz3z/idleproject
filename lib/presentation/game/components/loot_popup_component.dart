import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart' show TextStyle, FontWeight;
import 'package:flutter/widgets.dart' show Color;

import '../../../core/constants/game_enums.dart';
import '../../../domain/entities/game_item.dart';

/// Cores de raridade. São o principal canal de leitura do loot: SC-M04-03 exige
/// que o jogador distinga a raridade à primeira vista, por nome **e** cor.
abstract final class RarityPalette {
  static const Map<ItemRarity, Color> colors = {
    ItemRarity.bronze: Color(0xFF9C7A55),
    ItemRarity.prata: Color(0xFFB9BEC7),
    ItemRarity.ouro: Color(0xFFE8B44A),
    ItemRarity.epico: Color(0xFF9B3FBF),
    ItemRarity.lendario: Color(0xFFE8702A),
    ItemRarity.mitico: Color(0xFFD24B4B),
    ItemRarity.transcendental: Color(0xFF4AC5E8),
    ItemRarity.cosmico: Color(0xFF7BE88C),
  };

  static Color of(ItemRarity rarity) =>
      colors[rarity] ?? const Color(0xFFEDE7DA);
}

/// Aviso flutuante de item obtido (CEN-M04-011).
///
/// Lendário ou superior recebe tratamento distinto — maior, em negrito e com
/// vida mais longa. Num jogo em que o loot cai sozinho, o destaque é o único
/// momento em que o jogador é convidado a olhar para o inventário.
class LootPopupComponent extends TextComponent {
  LootPopupComponent({required this.item, required super.position})
    : super(
        text: item.rarity.isRareHighlight
            ? '★ ${_label(item)}'
            : _label(item),
        anchor: Anchor.bottomCenter,
        priority: 110,
      );

  final GameItem item;

  static const double _lifetime = 1.6;
  static const double _rareLifetime = 2.6;
  static const double _riseDistance = 34;

  static String _label(GameItem item) =>
      '${item.type.id} iLv${item.itemLevel}';

  bool get _isRare => item.rarity.isRareHighlight;

  @override
  Future<void> onLoad() async {
    textRenderer = TextPaint(
      style: TextStyle(
        color: RarityPalette.of(item.rarity),
        fontSize: _isRare ? 13 : 9,
        fontWeight: _isRare ? FontWeight.bold : FontWeight.normal,
      ),
    );

    final duration = _isRare ? _rareLifetime : _lifetime;
    add(
      MoveByEffect(
        Vector2(0, -_riseDistance),
        EffectController(duration: duration, curve: Curves.easeOut),
      ),
    );
    add(
      OpacityEffect.fadeOut(
        // Só desbota no fim: um item raro precisa ficar legível o tempo todo,
        // não sumir gradualmente desde o primeiro quadro.
        EffectController(
          duration: duration * 0.35,
          startDelay: duration * 0.65,
        ),
        onComplete: removeFromParent,
      ),
    );
  }
}
