import 'dart:ui' show Image;

import 'package:flame/components.dart';
import 'package:flame/flame.dart';
import 'package:flutter/foundation.dart';

/// Animações de uma entidade, conforme a grade do contrato de assets.
class CombatantAnimations {
  const CombatantAnimations({
    required this.idle,
    required this.attack,
    required this.death,
    required this.walk,
  });

  final SpriteAnimation idle;

  /// Toca uma vez. O impacto cai no 3º quadro, que é onde o contrato manda o
  /// artista posicionar o golpe.
  final SpriteAnimation attack;

  /// Toca uma vez e **congela no último quadro** — ele fica na tela os 30 s do
  /// revive (R-M01-06), então precisa ser legível parado.
  final SpriteAnimation death;

  /// Caminhada entre waves (R-M08-13), linha 3 da folha.
  ///
  /// É a única linha **opcional**: folha de 3 linhas continua válida e cai no
  /// idle aqui. A arena compensa com o balanço vertical e o cenário rolando, o
  /// que já lê como andar — é o que mantém a arte entregável em levas.
  final SpriteAnimation walk;
}

/// Carrega os sprites de `assets/sprites/` conforme
/// `contracts/assets-sprites.md`.
///
/// **Ausência de arquivo nunca quebra o jogo.** Todo carregamento devolve
/// `null` quando o asset não existe, e os componentes caem no retângulo
/// colorido. É o que permite entregar a arte em levas — e o que impede um zip
/// incompleto de derrubar a tela de combate.
class SpriteCatalog {
  SpriteCatalog._();

  static const double _frameDuration = 0.14;
  static const int _columns = 4;

  /// Prefixo de asset do Flame.
  ///
  /// O padrão do Flame é `assets/images/`, e a arte deste projeto está em
  /// `assets/sprites/` (contracts/assets-sprites.md §2). Sem corrigir isto,
  /// **todo** carregamento erra o caminho, cai no `catch` de [_image] e o jogo
  /// desenha retângulos coloridos no lugar dos 29 sprites — sem uma única
  /// exceção visível, porque a ausência de arte é estado esperado aqui.
  static const String _assetPrefix = 'assets/';

  final Map<String, CombatantAnimations?> _combatants = {};
  final Map<String, Sprite?> _backgrounds = {};

  static Future<SpriteCatalog> load() async {
    Flame.images.prefix = _assetPrefix;
    return SpriteCatalog._();
  }

  /// Animações de um herói (quadro 16×24).
  Future<CombatantAnimations?> hero(String classId) =>
      _combatant('heroes/$classId.png', 16, 24);

  /// Animações de um monstro. Bosses usam quadro 32×32; comuns, 16×16.
  Future<CombatantAnimations?> monster(String templateId, {bool isBoss = false}) {
    final size = isBoss ? 32 : 16;
    return _combatant('monsters/$templateId.png', size, size);
  }

  Future<Sprite?> background(String act) async {
    if (_backgrounds.containsKey(act)) return _backgrounds[act];
    final image = await _image('backgrounds/$act.png');
    final sprite = image == null ? null : Sprite(image);
    _backgrounds[act] = sprite;
    return sprite;
  }

  Future<CombatantAnimations?> _combatant(
    String path,
    int frameWidth,
    int frameHeight,
  ) async {
    if (_combatants.containsKey(path)) return _combatants[path];

    final image = await _image(path);
    if (image == null) {
      _combatants[path] = null;
      return null;
    }

    // Folha no tamanho errado é recusada aqui.
    //
    // `SpriteAnimation.fromFrameData` **não** valida se a grade cabe na imagem:
    // pedir quadros de 32×32 numa folha de 64×48 devolve recortes fora dos
    // limites, sem exceção e sem aviso — desenha lixo ou nada. Já custou um
    // teste verde que afirmava o contrário do conteúdo do jogo.
    final rows = image.height ~/ frameHeight;
    if (image.width < _columns * frameWidth || rows < 3) {
      if (kDebugMode) {
        debugPrint(
          'folha fora do contrato (usando retângulo): sprites/$path é '
          '${image.width}×${image.height}, esperado ao menos '
          '${_columns * frameWidth}×${frameHeight * 3} para quadros de '
          '$frameWidth×$frameHeight',
        );
      }
      _combatants[path] = null;
      return null;
    }

    final size = Vector2(frameWidth.toDouble(), frameHeight.toDouble());
    SpriteAnimation row(int index, {required bool loop}) =>
        SpriteAnimation.fromFrameData(
          image,
          SpriteAnimationData.sequenced(
            amount: _columns,
            stepTime: _frameDuration,
            textureSize: size,
            texturePosition: Vector2(0, index * frameHeight.toDouble()),
            loop: loop,
          ),
        );

    final idle = row(0, loop: true);
    final animations = CombatantAnimations(
      idle: idle,
      attack: row(1, loop: false),
      death: row(2, loop: false),
      // Linha 3 quando entregue; idle quando a folha ainda tem 3 linhas.
      walk: rows >= 4 ? row(3, loop: true) : idle,
    );
    _combatants[path] = animations;
    return animations;
  }

  Future<Image?> _image(String path) async {
    try {
      return await Flame.images.load('sprites/$path');
    } on Object catch (error) {
      // Asset ainda não entregue: o componente usa o retângulo. Só avisa em
      // debug, porque em produção isso é estado esperado até a arte final.
      if (kDebugMode) {
        debugPrint('sprite ausente (usando retângulo): sprites/$path — $error');
      }
      return null;
    }
  }
}
