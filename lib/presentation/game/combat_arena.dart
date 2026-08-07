import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../core/numeric/number_format.dart';
import '../../domain/engines/combat_engine.dart';
import '../../domain/entities/game_item.dart';
import 'components/background_component.dart';
import 'components/boss_component.dart';
import 'components/combatant_component.dart';
import 'components/damage_number_component.dart';
import 'components/dust_puff_component.dart';
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
  GroundParallaxComponent? _foreground;
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

    final foreground = GroundParallaxComponent(scenery: background.scenery)
      ..size = _world!.clone();
    _foreground = foreground;
    world.add(foreground);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Girar o aparelho não pode deixar o fundo cortado. Este é o único ponto
    // que deve reagir a tamanho — nunca o caminho de `sync`.
    _applyViewport(size);
    _background?.size = _world!.clone();
    _foreground?.size = _world!.clone();
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

  static const double _footInset = BackgroundComponent.footInset;

  /// Onde para quem luta na frente do time.
  ///
  /// Encostada na coluna da frente dos monstros de propósito. Com o time
  /// plantado em x=60 e o primeiro monstro em x=190 sobravam 130 px de chão
  /// vazio entre os dois lados: cada um batia no ar do seu canto, e a arena
  /// lia como dois grupos em telas diferentes — que foi a queixa que originou
  /// esta composição.
  ///
  /// A luta inteira fica um pouco à esquerda do centro: o chão que sobra à
  /// direita é por onde o grupo seguinte entra, e o que sobra à esquerda é o
  /// caminho já andado.
  static const double _frontLineX = 140;

  /// Distância entre um herói e o de trás dele na fila.
  static const double _heroSpacing = 26;

  /// Os monstros vêm em até 8 por wave (R-M08-05) e a arena tem 320 px de
  /// largura, dos quais os heróis ocupam a esquerda. Oito numa fileira só não
  /// cabem — daí duas fileiras de quatro, a de trás mais alta e desenhada
  /// atrás, que é como se dá profundidade em pixel art sem perspectiva.
  static const double _monsterBaseX = 162;
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
  /// segundo.
  ///
  /// Vem da leitura, não da física. A 70 px/s o mundo andava 70 px por wave —
  /// menos de um quarto da largura da arena, sobre um chão de cor chapada. Dava
  /// para jogar cinquenta waves sem ver a paisagem mudar, e a sensação era a de
  /// estar sempre no mesmo lugar. A 150 o time cruza quase meia arena por wave,
  /// e o primeiro plano, que corre ao dobro, atravessa a tela inteira.
  static const double _scrollSpeed = 150;

  /// De quanto além do seu lugar o grupo novo nasce.
  ///
  /// Derivada de [CombatantComponent.walkSpeed] e de
  /// [CombatEngine.travelSeconds], com folga: o grupo tem de **chegar** antes de
  /// o motor voltar a correr, senão os primeiros golpes da wave caem sobre um
  /// monstro que ainda está entrando na tela. Os 10% cobrem a diferença entre o
  /// passo fixo, que mede a caminhada, e o quadro de render, que a desenha.
  static const double _entryDistance =
      CombatantComponent.walkSpeed * CombatEngine.travelSeconds * 0.9;

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
    _foreground?.scenery = background.scenery;

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
      // Uma contagem só para as duas camadas: a razão entre elas é constante
      // (`GroundParallaxComponent.parallax`), e dois acumuladores separados
      // acabariam divergindo por arredondamento ao longo de horas de sessão.
      _foreground?.scrollX = background.scrollX;
      _emitDust(dt);
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

  /// Intervalo entre baforadas de poeira, por herói.
  static const double _dustInterval = 0.16;

  double _untilDust = 0;

  /// Solta poeira sob o pé de quem está andando.
  void _emitDust(double dt) {
    _untilDust -= dt;
    if (_untilDust > 0) return;
    _untilDust = _dustInterval;

    final scenery = _background?.scenery;
    if (scenery == null) return;

    for (final view in _heroViews.values) {
      if (view.isDown) continue;
      world.add(
        DustPuffComponent(
          // Atrás do calcanhar, não sob o centro do corpo: poeira que sai do
          // meio do sprite parece vazamento, não passada.
          position: Vector2(view.position.x - 5, view.position.y - 1),
          driftSpeed: _scrollSpeed,
          // Um pouco mais clara que o realce do ato: na cor do próprio cenário
          // a poeira desaparece no chão, que é onde ela precisa aparecer.
          color: Color.lerp(scenery.accent, const Color(0xFFEDE7DA), 0.3)!,
        ),
      );
    }
  }

  void _syncHeroes(CombatState state) {
    final line = _battleLine(state.heroes);

    for (var i = 0; i < state.heroes.length; i++) {
      final hero = state.heroes[i];
      final x = line[hero.heroId]!;
      final view = _heroViews.putIfAbsent(hero.heroId, () {
        final c = HeroComponent(
          entityId: hero.heroId,
          position: Vector2(x, _groundY),
          color: _heroColors[i % _heroColors.length],
        );
        world.add(c);
        return c;
      });
      // Andando, não teleportando: quem dá o passo é o componente. A linha do
      // chão é reafirmada a cada sync porque depende do tamanho do mundo, e
      // girar o aparelho a move.
      view.walkTo(x);
      view.position.y = _groundY;
      view.hpFraction = hero.hpFraction;
      view.isDown = hero.isIncapacitated;
      // Na caminhada entre waves o time não muda de x — quem passa é o
      // cenário —, mas as pernas andam. É o que mantém a formação e a mira do
      // combate intactas enquanto a caminhada acontece.
      view.isMarching = _isWalking;
      // O sprite chega depois do componente: carregar é assíncrono e o combate
      // não pode esperar por asset.
      _ensureDressed(view, () => _catalog!.hero(hero.definition.id));
    }
  }

  /// Onde cada herói se posta, da frente para trás.
  ///
  /// Quem luta corpo a corpo vai à frente e o resto atrás, na ordem da
  /// formação. Sem esta ordenação o arqueiro podia ficar colado no monstro com
  /// o tanque três posições atrás — o oposto do que a mecânica de provocação
  /// do Vanguard (CEN-M02-002) mostra acontecendo.
  Map<String, double> _battleLine(List<HeroCombatant> heroes) {
    final front = <String>[];
    final back = <String>[];
    for (final hero in heroes) {
      (_fightsUpClose(hero.definition.role) ? front : back).add(hero.heroId);
    }

    final line = <String, double>{};
    var rank = 0;
    for (final id in [...front, ...back]) {
      line[id] = _frontLineX - rank * _heroSpacing;
      rank++;
    }
    return line;
  }

  static bool _fightsUpClose(HeroRole role) => switch (role) {
    HeroRole.tank || HeroRole.meleeDamage || HeroRole.brute => true,
    HeroRole.magicDamage || HeroRole.rangedDamage || HeroRole.support => false,
  };

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
    // Quantos vivos já ocuparam lugar em cada fileira. É o que faz quem está
    // atrás dar um passo à frente quando o da frente cai, em vez de a fila
    // ficar com um buraco e o time bater no vazio.
    final taken = <int, int>{};

    final ordered = [...state.monsters]
      ..sort((a, b) => a.slot.compareTo(b.slot));

    for (final monster in ordered) {
      present.add(monster.instanceId);
      final row = monster.slot ~/ _monstersPerRow;
      final column = taken[row] ?? 0;
      if (monster.isAlive) taken[row] = column + 1;

      final position = _monsterPosition(row, column, isBoss: monster.isBoss);

      final view = _monsterViews.putIfAbsent(monster.instanceId, () {
        // Grupo que chega enquanto o time caminha nasce fora da tela e entra
        // andando (R-M08-13). Na primeira wave não há caminhada, e ele já
        // começa no lugar — SC-M01-01 pede ação imediata, não uma entrada.
        final spawn = _isWalking
            ? Vector2(position.x + _entryDistance, position.y)
            : position;
        // Boss ganha componente próprio, com aura e coroa (T083).
        final MonsterComponent c = monster.isBoss
            ? BossComponent(
                entityId: monster.instanceId,
                position: spawn,
                swingPhase: monster.slot / _monstersPerRow,
              )
            : MonsterComponent(
                entityId: monster.instanceId,
                position: spawn,
                isBoss: false,
                // Golpes escalonados por lugar na fila: o grupo inteiro
                // batendo no mesmo quadro lê como um bloco só.
                swingPhase: monster.slot / _monstersPerRow,
              );
        // A fileira de trás fica atrás mesmo, sem tapar quem está na frente.
        c.priority = -row;
        world.add(c);
        return c;
      });

      // Morto fica onde caiu: o corpo é a marca de que ali havia um inimigo, e
      // arrastá-lo pela fila daria a um cadáver o lugar de quem ainda luta.
      if (monster.isAlive) view.walkTo(position.x);
      view.position.y = position.y;
      view.hpFraction = monster.stats.maxHp.isZero
          ? 0
          : (monster.currentHp / monster.stats.maxHp).toDouble();
      view.isDown = !monster.isAlive;
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

  Vector2 _monsterPosition(int row, int column, {required bool isBoss}) =>
      Vector2(
        // A âncora é o centro, e o boss é o dobro de largo: sem compensar a
        // sobra ele encostaria no herói da frente, que é a única coisa que
        // sobrou de pé no campo numa wave de boss.
        _monsterBaseX + column * _monsterSpacing + (isBoss ? _bossInset : 0),
        _groundY - row * _rowDepth,
      );

  /// Meia diferença entre a largura do boss e a do monstro comum.
  static const double _bossInset = 9;

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
