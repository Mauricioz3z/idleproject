import 'dart:ui';

import 'package:flame/game.dart';

import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/entities/game_item.dart';
import 'components/background_component.dart';
import 'components/boss_component.dart';
import 'components/combatant_component.dart';
import 'components/damage_number_component.dart';
import 'components/loot_popup_component.dart';

/// Arena de combate em Flame.
///
/// Só lê estado e desenha. A regra de combate inteira vive em
/// `lib/domain/engines/` — se ela migrasse para cá, ficaria acoplada ao ciclo
/// de render e a simulação offline viraria uma reimplementação paralela
/// (plan.md, Structure Decision).
class CombatArena extends FlameGame {
  CombatArena({required this.onFixedStep});

  /// Passo fixo de 30 Hz, alinhado ao alvo de 30 FPS de `specification.md` §8.
  static const double fixedStepSeconds = 1 / 30;

  /// Teto de passos por quadro. Sem ele, um congelamento longo tentaria
  /// recuperar minutos de simulação num único quadro e travaria a interface.
  /// O tempo excedente não se perde: cai no cálculo offline de M09.
  static const int maxStepsPerFrame = 5;

  final void Function(double fixedDt) onFixedStep;

  final Map<String, CombatantComponent> _heroViews = {};
  final Map<String, CombatantComponent> _monsterViews = {};

  BackgroundComponent? _background;

  double _accumulator = 0;
  CombatState? _latest;

  static const List<Color> _heroColors = [
    Color(0xFF4A90D9),
    Color(0xFFBF5FA8),
    Color(0xFF5FBF60),
    Color(0xFFE8B44A),
  ];

  static const double _groundY = 150;
  static const double _heroBaseX = 60;
  static const double _monsterBaseX = 190;
  static const double _spacing = 34;

  static const double _lootX = 160;
  static const double _lootBaseY = 60;
  static const double _lootSpacing = 14;

  /// Recebe o estado mais recente e os eventos do tick.
  void sync(CombatState state, CombatTickResult? events) {
    _latest = state;
    _syncBackground(state);
    _syncHeroes(state);
    _syncMonsters(state);
    if (events != null) _spawnFloatingNumbers(state, events);
  }

  void _syncBackground(CombatState state) {
    final background = _background ??= () {
      final component = BackgroundComponent(act: state.position.act)
        ..size = size.clone();
      world.add(component);
      return component;
    }();

    background.syncAct(state.position.act);
    // A arena é criada antes de conhecer o tamanho da tela; acompanhar o
    // tamanho a cada sync evita fundo cortado ao girar o aparelho.
    if (background.size != size) background.size = size.clone();
  }

  /// Exibe os itens de um lote de drops (CEN-M04-011).
  ///
  /// Empilha os avisos verticalmente para que uma wave que derruba quatro
  /// monstros de uma vez não sobreponha quatro textos no mesmo pixel.
  void showLoot(List<GameItem> items) {
    for (var i = 0; i < items.length; i++) {
      world.add(
        LootPopupComponent(
          item: items[i],
          position: Vector2(_lootX, _lootBaseY - i * _lootSpacing),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _accumulator += dt;
    var steps = 0;
    while (_accumulator >= fixedStepSeconds && steps < maxStepsPerFrame) {
      onFixedStep(fixedStepSeconds);
      _accumulator -= fixedStepSeconds;
      steps++;
    }
    if (steps == maxStepsPerFrame) _accumulator = 0;
  }

  void _syncHeroes(CombatState state) {
    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      final view = _heroViews.putIfAbsent(hero.heroId, () {
        final c = HeroComponent(
          entityId: hero.heroId,
          position: Vector2(_heroBaseX + i * _spacing, _groundY),
          color: _heroColors[i % _heroColors.length],
        );
        world.add(c);
        return c;
      });
      view.hpFraction = hero.hpFraction;
      view.isDown = hero.isIncapacitated;
    }
  }

  void _syncMonsters(CombatState state) {
    final present = <String>{};
    for (var i = 0; i < state.monsters.length; i++) {
      final monster = state.monsters[i];
      present.add(monster.instanceId);
      final view = _monsterViews.putIfAbsent(monster.instanceId, () {
        final position = Vector2(
          _monsterBaseX + monster.slot * _spacing,
          _groundY,
        );
        // Boss ganha componente próprio, com aura e coroa (T083).
        final CombatantComponent c = monster.isBoss
            ? BossComponent(
                entityId: monster.instanceId,
                position: position,
              )
            : MonsterComponent(
                entityId: monster.instanceId,
                position: position,
                isBoss: false,
              );
        world.add(c);
        return c;
      });
      view.hpFraction = monster.stats.maxHp.isZero
          ? 0
          : (monster.currentHp / monster.stats.maxHp).toDouble();
      view.isDown = !monster.isAlive;
    }

    // Monstros da wave anterior somem quando a nova começa.
    _monsterViews.removeWhere((id, view) {
      if (present.contains(id)) return false;
      view.removeFromParent();
      return true;
    });
  }

  void _spawnFloatingNumbers(CombatState state, CombatTickResult events) {
    for (final hit in events.hits) {
      final target = _monsterViews[hit.monsterId];
      if (target == null) continue;
      target.flashHit();
      world.add(
        DamageNumberComponent(
          value: NumberFormat.compact(hit.damage),
          kind: hit.isCritical
              ? FloatingNumberKind.critical
              : FloatingNumberKind.damage,
          position: target.position.clone()..y -= target.size.y + 6,
        ),
      );
    }

    for (final id in events.downs) {
      _heroViews[id]?.isDown = true;
    }
    for (final id in events.revives) {
      final view = _heroViews[id];
      if (view == null) continue;
      view.isDown = false;
      world.add(
        DamageNumberComponent(
          value: NumberFormat.compact(GameNumber.fromInt(0)),
          kind: FloatingNumberKind.heal,
          position: view.position.clone()..y -= view.size.y + 6,
        ),
      );
    }
  }

  CombatState? get latest => _latest;
}
