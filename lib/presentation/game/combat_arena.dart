import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
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
import 'sprite_catalog.dart';

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

  /// Entidades cujo carregamento de sprite já foi disparado.
  ///
  /// Só é registrado quando existe catálogo: antes disso a tentativa é repetida
  /// no quadro seguinte. Sem isso os heróis ficavam **para sempre** como
  /// retângulos, porque nascem no primeiro `sync` — que vem do `build` da tela,
  /// antes de `onLoad` terminar — e nunca eram vestidos de novo. Os monstros
  /// escapavam por acidente: cada wave troca os componentes, então da wave 2 em
  /// diante o catálogo já existia.
  final Set<String> _dressed = {};

  BackgroundComponent? _background;
  SpriteCatalog? _catalog;
  String? _loadedBackgroundAct;

  /// Tamanho do mundo em pixels de arena, ou `null` até haver layout.
  ///
  /// É o sinal de "pode desenhar": `sync` vem do `build` da tela, que roda antes
  /// de o `GameWidget` ter layout, e ler `size` ali lança asserção.
  Vector2? _world;

  double _accumulator = 0;
  CombatState? _latest;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // A origem do mundo no canto superior esquerdo do viewport.
    //
    // O padrão do Flame é `Anchor.center`: o mundo (0,0) cai no **centro** da
    // tela. Como toda a composição desta arena é medida a partir do canto — o
    // cenário em (0,0), os heróis em x=60, o chão perto da base —, o padrão
    // empurrava tudo meia tela para baixo e para a direita, deixando o
    // quadrante superior esquerdo preto e jogando os monstros de slot alto para
    // fora da tela.
    camera.viewfinder.anchor = Anchor.topLeft;
    _applyViewport(size);

    _catalog = await SpriteCatalog.load();

    // O fundo nasce aqui, e não no primeiro `sync`, porque depende de `size`.
    // Em `onLoad` o tamanho já existe: o Flame garante `onGameResize` antes. O
    // ato começa em 1 e é corrigido no primeiro `syncAct`, que é idempotente.
    final background = BackgroundComponent(act: 1)..size = _world!.clone();
    _background = background;
    world.add(background);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Girar o aparelho não pode deixar o fundo cortado. Este é o único ponto
    // que deve reagir a tamanho — nunca o caminho de `sync`.
    _applyViewport(size);
    _background?.size = _world!.clone();
    // As posições dos combatentes saem do mundo, então o primeiro `sync` depois
    // daqui já as recoloca. Antecipar aqui evita um quadro com tudo no lugar
    // antigo.
    final state = _latest;
    if (state != null) sync(state, null);
  }

  /// Traduz o viewport em mundo e ajusta o zoom.
  ///
  /// A largura do mundo é fixa em [BackgroundComponent.artWidth]: a composição
  /// é a mesma em qualquer aparelho, e o cenário sai em escala 1:1 com a arte
  /// gerada por `tool/backgrounds.py`. A altura acompanha a proporção do
  /// viewport, que em retrato é bem mais alta que os 16:9 da arte — a sobra é
  /// céu, tratada por `BackgroundComponent`.
  void _applyViewport(Vector2 viewport) {
    if (viewport.x <= 0 || viewport.y <= 0) return;
    final zoom = viewport.x / BackgroundComponent.artWidth;
    camera.viewfinder.zoom = zoom;
    _world = Vector2(BackgroundComponent.artWidth, viewport.y / zoom);
  }

  static const List<Color> _heroColors = [
    Color(0xFF4A90D9),
    Color(0xFFBF5FA8),
    Color(0xFF5FBF60),
    Color(0xFFE8B44A),
  ];

  /// Quanto os pés afundam na faixa de chão. Zero deixaria os combatentes
  /// pousados exatamente na linha de horizonte, que lê como flutuando.
  static const double _footInset = 16;

  static const double _heroBaseX = 60;
  static const double _heroSpacing = 34;

  /// Os monstros vêm em até 8 por wave (R-M08-05) e a arena tem 320 px de
  /// largura, dos quais os heróis ocupam a esquerda. Oito numa fileira só não
  /// cabem — daí duas fileiras de quatro, a de trás mais alta e desenhada
  /// atrás, que é como se dá profundidade em pixel art sem perspectiva.
  static const double _monsterBaseX = 190;
  static const double _monsterSpacing = 30;
  static const int _monstersPerRow = 4;

  /// Quanto a fileira de trás sobe. Fica abaixo de [_footInset] de propósito:
  /// passar disso colocaria os pés **acima** da linha de horizonte, o que num
  /// cenário sem perspectiva lê como flutuando no céu.
  static const double _rowDepth = 12;

  static const double _lootX = 160;

  /// Altura dos avisos de drop, medida acima da linha do chão.
  static const double _lootHeight = 90;
  static const double _lootSpacing = 14;

  /// Linha em que os combatentes pisam.
  double get _groundY =>
      (_background?.groundTopY ??
          _world!.y - BackgroundComponent.groundHeight) +
      _footInset;

  /// Velocidade da rolagem do cenário durante a caminhada, em pixels de arte por
  /// segundo. Vem da leitura, não da física: mais rápido que isto e o cenário
  /// borra; mais devagar e o time parece patinar no lugar.
  static const double _scrollSpeed = 70;

  /// De quanto além da borda direita o grupo novo vem.
  static const double _entryDistance = 70;

  /// Andamento da caminhada: 0 acabou de sair, 1 chegou. Fora da caminhada é 1.
  double _travelProgress = 1;

  bool get _isWalking => _travelProgress < 1;

  /// Recebe o estado mais recente e os eventos do tick.
  ///
  /// [travelProgress] é o andamento da caminhada até o grupo seguinte
  /// (R-M08-13): 1 significa em combate, e é o padrão para quem não tem essa
  /// noção — os testes de fumaça, por exemplo.
  void sync(
    CombatState state,
    CombatTickResult? events, {
    double travelProgress = 1,
  }) {
    _latest = state;
    _travelProgress = travelProgress.clamp(0.0, 1.0);
    // Sem layout não há onde posicionar nada, e ler `size` aqui lançaria. O
    // quadro seguinte já tem tudo: `onGameResize` chama `sync` de volta.
    if (_world == null) return;
    _syncBackground(state);
    _syncHeroes(state);
    _syncMonsters(state);
    if (events != null) _spawnFloatingNumbers(state, events);
  }

  void _syncBackground(CombatState state) {
    // Pode ainda não existir: `sync` vem do `build` da tela, que roda antes de
    // `onLoad` terminar. Sem fundo, o quadro sai com a cor de base — e o
    // seguinte já tem tudo.
    final background = _background;
    if (background == null) return;

    background.syncAct(state.position.act);

    final act = background.scenery.assetName;
    if (_loadedBackgroundAct != act) {
      _loadedBackgroundAct = act;
      unawaited(
        _catalog?.background(act).then((sprite) {
          if (sprite != null) background.sprite = sprite;
        }) ?? Future<void>.value(),
      );
    }
  }

  /// Exibe os itens de um lote de drops (CEN-M04-011).
  ///
  /// Empilha os avisos verticalmente para que uma wave que derruba quatro
  /// monstros de uma vez não sobreponha quatro textos no mesmo pixel.
  void showLoot(List<GameItem> items) {
    if (_world == null) return;
    final baseY = _groundY - _lootHeight;
    for (var i = 0; i < items.length; i++) {
      world.add(
        LootPopupComponent(
          item: items[i],
          position: Vector2(_lootX, baseY - i * _lootSpacing),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    // O cenário passa enquanto o time anda (R-M08-13). A rolagem é acumulada em
    // tempo de render, e não derivada do andamento, para ficar suave mesmo com
    // o passo fixo de 30 Hz atrás dela.
    final background = _background;
    if (background != null && _isWalking) {
      background.scrollX += _scrollSpeed * dt;
    }

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
          position: Vector2(_heroBaseX + i * _heroSpacing, _groundY),
          color: _heroColors[i % _heroColors.length],
        );
        world.add(c);
        return c;
      });
      // A posição é reafirmada a cada sync: ela depende do tamanho do mundo, e
      // girar o aparelho muda a linha do chão.
      view.position.setValues(_heroBaseX + i * _heroSpacing, _groundY);
      view.hpFraction = hero.hpFraction;
      view.isDown = hero.isIncapacitated;
      // Os heróis não saem do lugar: quem se move é o cenário. É o que permite
      // manter a formação e a mira do combate intactas enquanto a caminhada
      // acontece.
      view.isWalking = _isWalking;
      // O sprite chega depois do componente: carregar é assíncrono e o combate
      // não pode esperar por asset.
      _ensureDressed(view, () => _catalog!.hero(hero.definition.id));
    }
  }

  /// Dispara o carregamento do sprite de uma entidade, uma vez.
  ///
  /// Enquanto não houver catálogo nada é registrado, e a tentativa volta no
  /// quadro seguinte — é isso que impede um componente criado antes de `onLoad`
  /// de ficar de retângulo para sempre.
  void _ensureDressed(
    CombatantComponent view,
    Future<CombatantAnimations?> Function() load,
  ) {
    if (_catalog == null || view.hasSprite) return;
    if (!_dressed.add(view.entityId)) return;
    unawaited(
      load().then((animations) {
        if (animations != null && !view.hasSprite) {
          view.applyAnimations(animations);
        }
      }),
    );
  }

  void _syncMonsters(CombatState state) {
    final present = <String>{};
    for (final monster in state.monsters) {
      present.add(monster.instanceId);
      final position = _monsterPosition(monster.slot);
      final row = monster.slot ~/ _monstersPerRow;

      final view = _monsterViews.putIfAbsent(monster.instanceId, () {
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
        // A fileira de trás fica atrás mesmo, sem tapar quem está na frente.
        c.priority = -row;
        world.add(c);
        return c;
      });
      view.position.setFrom(position);
      view.hpFraction = monster.stats.maxHp.isZero
          ? 0
          : (monster.currentHp / monster.stats.maxHp).toDouble();
      view.isDown = !monster.isAlive;
      // Entrando pela direita enquanto o time anda, e andando também: quem
      // chega vindo de longe não chega parado.
      view.isWalking = _isWalking;
      _ensureDressed(
        view,
        () => _catalog!.monster(monster.template.id, isBoss: monster.isBoss),
      );
    }

    // Monstros da wave anterior somem quando a nova começa. O registro de
    // sprite vai com eles: `instanceId` é único por instância, e mantê-los
    // faria o conjunto crescer sem teto ao longo de milhares de waves.
    _monsterViews.removeWhere((id, view) {
      if (present.contains(id)) return false;
      view.removeFromParent();
      _dressed.remove(id);
      return true;
    });
  }

  Vector2 _monsterPosition(int slot) => Vector2(
    _monsterBaseX +
        (slot % _monstersPerRow) * _monsterSpacing +
        _entryOffset(slot),
    _groundY - (slot ~/ _monstersPerRow) * _rowDepth,
  );

  /// Quanto o monstro ainda está à direita do seu lugar.
  ///
  /// A desaceleração é quadrática: o grupo entra rápido e assenta devagar, que é
  /// como uma aproximação lê. Os de trás na fila chegam um pouco depois, para o
  /// grupo não se mover como um bloco só.
  double _entryOffset(int slot) {
    if (!_isWalking) return 0;
    final lag = (slot % _monstersPerRow) * 0.06;
    final own = ((_travelProgress - lag) / (1 - lag)).clamp(0.0, 1.0);
    final eased = 1 - (1 - own) * (1 - own);
    return _entryDistance * (1 - eased);
  }

  void _spawnFloatingNumbers(CombatState state, CombatTickResult events) {
    for (final hit in events.hits) {
      // Quem bateu toca a animação de golpe; quem apanhou pisca.
      _heroViews[hit.heroId]?.playAttack();

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
