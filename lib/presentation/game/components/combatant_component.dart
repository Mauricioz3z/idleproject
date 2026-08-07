import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../sprite_catalog.dart';

/// Base visual de um combatente.
///
/// Desenha o sprite quando ele existe e cai no retângulo colorido quando não —
/// que é o estado que `specification.md` §6 Fase 1 prescreve para validar o
/// laço antes de investir em arte. Os dois caminhos convivem de propósito: a
/// arte pode chegar em levas sem quebrar nada.
///
/// **Quem anda é este componente, não quem chama.** A arena diz para onde
/// ([walkTo]); o passo até lá é dado aqui, a [walkSpeed] pixels por segundo.
/// Escrever `position.x` de fora teleportaria o combatente — era o que
/// acontecia antes, e é o motivo de o time parecer estático mesmo com o cenário
/// rolando atrás dele.
class CombatantComponent extends PositionComponent {
  CombatantComponent({
    required this.entityId,
    required this.bodyColor,
    required super.position,
    required super.size,
    this.facing = 1,
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

  /// Se o que está tocando agora é a passada desenhada, e não o idle.
  ///
  /// Existe para ser afirmado: a folha sem linha de caminhada cai no idle de
  /// propósito (`SpriteCatalog`), e o jogo continua rodando igual. Foi assim que
  /// o time passou 29 sprites inteiros "andando" com a pose parada e um balanço
  /// de 1 pixel — nada quebra, só que ninguém anda.
  bool get isPlayingWalkAnimation {
    final animations = _animations;
    if (animations == null || !animations.hasWalkRow) return false;
    return _sprite?.animation == animations.walk;
  }

  /// Dispara a animação de golpe, uma vez, voltando ao idle no fim.
  void playAttack() {
    if (isDown) return;

    // O avanço do corpo vale mesmo sem folha entregue: é o que distingue um
    // golpe de um boneco parado quando a arte ainda é retângulo.
    _lungeRemaining = lungeSeconds;

    final animations = _animations;
    final sprite = _sprite;
    if (animations == null || sprite == null || _playingOneShot) return;

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
      return;
    }

    if (_playingOneShot) return;

    // Caminhada e idle disputam o mesmo lugar; o golpe em curso vence os dois.
    final wanted = isWalking ? animations.walk : animations.idle;
    if (sprite.animation != wanted) sprite.animation = wanted;
  }

  /// ID do herói ou do monstro que este componente representa.
  final String entityId;
  final Color bodyColor;

  /// Para onde o combatente encara: 1 é direita (heróis), -1 é esquerda
  /// (monstros). Define o lado para o qual o corpo avança no golpe.
  final int facing;

  /// Fração de HP, de 0 a 1. Alimenta a barra de vida.
  double hpFraction = 1;

  /// Incapacitado ou morto: desenhado esmaecido, sem barra.
  bool isDown = false;

  /// Marchando para o grupo seguinte (R-M08-13).
  ///
  /// A arena liga isto durante a caminhada entre waves, em que o time não muda
  /// de lugar — quem se move é o cenário. Andar de verdade, mudando de x, é o
  /// outro caso, e sai de [walkTo].
  bool isMarching = false;

  /// Em movimento: marchando com o cenário ou indo até um alvo em [walkTo].
  /// É o que escolhe entre a linha de caminhada e a de idle na folha.
  bool get isWalking => isMarching || _isMoving;

  /// Velocidade da caminhada, em pixels de arena por segundo.
  ///
  /// Casada com [CombatEngine.travelSeconds] e com a distância de entrada da
  /// arena: um grupo que nasce fora da tela precisa chegar ao seu lugar no
  /// momento em que o combate volta a correr, senão ele apanha entrando.
  static const double walkSpeed = 80;

  /// Nulo enquanto ninguém mandou o combatente a lugar nenhum: ele fica onde
  /// nasceu. É o estado dos testes de fumaça, que só desenham um quadro.
  double? _targetX;
  bool _isMoving = false;

  /// Manda o combatente andar até [x]. Ele leva o tempo que a [walkSpeed]
  /// impuser — e toca a caminhada enquanto isso.
  void walkTo(double x) => _targetX = x;

  /// Coloca o combatente em [x] sem andar. Só para quem acabou de nascer: um
  /// componente novo não pode deslizar desde a posição de spawn.
  void placeAt(double x) {
    _targetX = x;
    position.x = x;
    _isMoving = false;
  }

  /// Segundos restantes do flash de dano.
  double _hitFlash = 0;

  /// Fase do balanço de caminhada, em segundos.
  double _walkPhase = 0;

  /// Segundos restantes do avanço do golpe.
  double _lungeRemaining = 0;

  static const double _walkBobPixels = 1;
  static const double _walkStepsPerSecond = 4;

  /// Duração do avanço do golpe. Um pouco abaixo dos 4 quadros da animação de
  /// ataque (4 × 0,14 s), para o corpo já ter voltado quando ela termina.
  static const double lungeSeconds = 0.5;

  /// Quanto o corpo avança no golpe.
  ///
  /// A folha de ataque já desloca o corpo em 1 px, o que a esta escala quase
  /// não aparece. Sem este avanço o golpe lê como o boneco tremendo no lugar,
  /// e não como alguém batendo em alguém.
  static const double _lungePixels = 5;

  /// Deslocamento horizontal do golpe: vai e volta em meio seno.
  double get _lungeOffset {
    if (_lungeRemaining <= 0) return 0;
    final progress = 1 - _lungeRemaining / lungeSeconds;
    return facing * _lungePixels * math.sin(progress * math.pi);
  }

  /// Deslocamento vertical do passo, em pixels. Inteiro de propósito: meio pixel
  /// em pixel art tremula.
  ///
  /// Só entra quando **não** há linha de caminhada na folha. Com ela entregue,
  /// somar o balanço por cima faria o corpo saltar duas vezes por passada.
  double get _walkBob {
    if (!isWalking || isDown) return 0;
    if (_animations?.hasWalkRow ?? false) return 0;
    return (_walkPhase * _walkStepsPerSecond) % 2 < 1 ? -_walkBobPixels : 0;
  }

  static const double _barHeight = 3;
  static const double _barGap = 4;
  static const double hitFlashDuration = 0.12;

  void flashHit() => _hitFlash = hitFlashDuration;

  @override
  void update(double dt) {
    super.update(dt);
    if (_hitFlash > 0) _hitFlash -= dt;
    if (_lungeRemaining > 0) _lungeRemaining -= dt;
    if (isWalking) _walkPhase += dt;
    _advance(dt);
    _syncDownState();

    // A piscada de dano é efeito de código sobre o sprite, e não arte: o
    // contrato de assets é explícito em não pedir quadros de "hit".
    _sprite?.opacity = isDown ? 0.6 : 1.0;
    _sprite?.position.setValues(_lungeOffset, _walkBob);
  }

  /// Dá o passo deste quadro em direção ao alvo de [walkTo].
  void _advance(double dt) {
    // Quem caiu não anda: seria o cadáver deslizando pelo chão enquanto os
    // vivos reorganizam a linha.
    final target = _targetX;
    if (isDown || target == null) {
      _isMoving = false;
      return;
    }

    final delta = target - position.x;
    final step = walkSpeed * dt;
    if (delta.abs() <= step) {
      position.x = target;
      _isMoving = false;
      return;
    }
    position.x += delta.isNegative ? -step : step;
    _isMoving = true;
  }

  @override
  void render(Canvas canvas) {
    // O balanço do passo e o avanço do golpe movem o corpo, e só ele. A barra
    // de vida fica onde está: barra subindo e descendo com o passo lê como dano
    // recebido.
    canvas.save();
    canvas.translate(_lungeOffset, _walkBob);
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
    canvas.restore();

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
    double swingPhase = 0,
  }) : super(
         bodyColor: isBoss ? const Color(0xFF9B3FBF) : const Color(0xFFB55A45),
         size: isBoss ? Vector2(32, 32) : Vector2(16, 16),
         facing: -1,
       ) {
    _untilSwing = swingInterval * swingPhase;
  }

  /// Intervalo entre os golpes do monstro, em segundos.
  ///
  /// Cosmético, e sem nada a sincronizar: o motor não emite evento de ataque de
  /// monstro — o dano deles é contínuo, aplicado por tick sobre o alvo
  /// provocado (`combat_engine.dart`). Sem isto, metade da arena fica imóvel
  /// enquanto a outra bate, e a luta lê como treino de saco de pancadas.
  static const double swingInterval = 1.6;

  double _untilSwing = 0;

  @override
  void update(double dt) {
    super.update(dt);
    if (isDown || isWalking) return;
    _untilSwing -= dt;
    if (_untilSwing > 0) return;
    _untilSwing = swingInterval;
    playAttack();
  }
}
