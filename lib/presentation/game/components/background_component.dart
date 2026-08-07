import 'dart:ui';

import 'package:flame/components.dart';

/// Paleta e silhuetas de cada ato (R-M08-01).
///
/// Os três atos precisam ser reconhecíveis num relance — é o principal sinal de
/// que o jogador saiu da Floresta e entrou na Caverna (CEN-M08-005). Com
/// retângulos coloridos no lugar da arte final (T143), a cor **é** o cenário.
enum ActScenery {
  forest(
    name: 'Floresta',
    sky: Color(0xFF16281C),
    ground: Color(0xFF23422B),
    silhouette: Color(0xFF1B3322),
    accent: Color(0xFF3E6B45),
  ),
  cave(
    name: 'Caverna',
    sky: Color(0xFF1A1622),
    ground: Color(0xFF2B2436),
    silhouette: Color(0xFF221C2E),
    accent: Color(0xFF4A3B63),
  ),
  citadel(
    name: 'Cidadela',
    sky: Color(0xFF221A18),
    ground: Color(0xFF3A2C27),
    silhouette: Color(0xFF2C211D),
    accent: Color(0xFF6B4A3E),
  );

  const ActScenery({
    required this.name,
    required this.sky,
    required this.ground,
    required this.silhouette,
    required this.accent,
  });

  final String name;
  final Color sky;
  final Color ground;
  final Color silhouette;
  final Color accent;

  /// Nome do arquivo em `assets/sprites/backgrounds/`.
  String get assetName => switch (this) {
    ActScenery.forest => 'forest',
    ActScenery.cave => 'cave',
    ActScenery.citadel => 'citadel',
  };

  /// Cenário do ato. Atos fora de 1..3 caem na Floresta em vez de lançar: um
  /// erro de conteúdo não pode deixar a tela preta durante o combate.
  static ActScenery forAct(int act) => switch (act) {
    2 => ActScenery.cave,
    3 => ActScenery.citadel,
    _ => ActScenery.forest,
  };
}

/// Primeiro plano do chão: o que passa **na frente** dos pés do time.
///
/// Existe por uma razão só — dar sensação de deslocamento. Um cenário de uma
/// camada só, por mais que role, não diz a que velocidade nem a que distância
/// nada está: sem um segundo plano em velocidade diferente, o olho lê a cena
/// como um painel deslizando, não como alguém andando. Este aqui corre ao
/// [parallax] da rolagem do fundo, e é o que o jogador percebe primeiro porque
/// está mais perto do olho.
///
/// Fica confinado abaixo da linha dos pés: em cima dela taparia os combatentes.
class GroundParallaxComponent extends PositionComponent {
  GroundParallaxComponent({required this.scenery}) : super(priority: 50);

  ActScenery scenery;

  /// Deslocamento do fundo. Quem escreve é a arena, com o mesmo valor que
  /// alimenta [BackgroundComponent.scrollX] — a razão entre as camadas vive
  /// em [parallax], e não em duas contagens que podem divergir.
  double scrollX = 0;

  /// Quantas vezes mais rápido que o fundo. Acima de ~2,5 o primeiro plano
  /// vira listra e cansa; abaixo de ~1,5 ele não se distingue do fundo.
  static const double parallax = 2.1;

  /// Distância entre um elemento e o seguinte, em pixels de arte.
  static const double _spacing = 21;

  /// A partir de quantos pixels abaixo da linha dos pés o primeiro plano
  /// começa. Menos que isto e ele encosta nos tornozelos.
  static const double _below = 5;

  @override
  void render(Canvas canvas) {
    if (size.x <= 0 || size.y <= 0) return;

    final scale = size.x / BackgroundComponent.artWidth;
    canvas.save();
    canvas.translate(0, size.y - BackgroundComponent.artHeight * scale);
    canvas.scale(scale);

    const feet =
        BackgroundComponent.artHeight -
        BackgroundComponent.groundHeight +
        BackgroundComponent.footInset;
    const top = feet + _below;

    // Mais escuro que a silhueta do fundo, e de propósito: o primeiro plano
    // precisa de contraste próprio para se destacar do chão em movimento. A
    // regra de baixo contraste do cenário vale para o que está **atrás** dos
    // combatentes e compete com eles — isto passa abaixo dos pés.
    final body = Paint()
      ..color = Color.lerp(scenery.silhouette, const Color(0xFF14121C), 0.55)!;
    final rim = Paint()..color = scenery.accent;
    final travelled = scrollX * parallax;

    // Cada elemento tem índice próprio e imutável: derivar a forma do índice, e
    // não da posição na tela, é o que impede o primeiro plano de "piscar"
    // formas novas enquanto passa.
    final first = (travelled / _spacing).floor();
    for (var k = first; ; k++) {
      final x = k * _spacing - travelled;
      if (x > BackgroundComponent.artWidth) break;

      final h = _hash(k);
      // Três feitios em rodízio. Um só, por mais que varie de tamanho, alinha
      // topos parecidos e o primeiro plano vira cerca de estacas.
      final (width, height) = switch (h % 3) {
        0 => ((11 + (h >> 7) % 8).toDouble(), (5 + (h >> 11) % 4).toDouble()),
        1 => ((5 + (h >> 7) % 4).toDouble(), (8 + (h >> 11) % 6).toDouble()),
        _ => ((4 + (h >> 7) % 4).toDouble(), (3 + (h >> 11) % 3).toDouble()),
      };
      // Ancorados na base da arena: um plano próximo cortado pela borda de
      // baixo é o que dá a leitura de "isto está entre mim e a cena".
      final bottom = BackgroundComponent.artHeight - (h >> 17) % 3;
      final y = bottom - height;
      if (y < top) continue;

      // Duas larguras empilhadas em vez de um retângulo: uma caixa nítida lê
      // como interface, uma silhueta em degrau lê como pedra.
      canvas.drawRect(Rect.fromLTWH(x, y + 1, width, height), body);
      canvas.drawRect(Rect.fromLTWH(x + 2, y, width - 4, 2), body);
      // Fio de luz no topo: mancha escura sobre chão escuro não se lê em
      // movimento, por mais rápido que passe.
      canvas.drawRect(Rect.fromLTWH(x + 2, y, width - 4, 1), rim);
    }

    canvas.restore();
  }

  /// Espalha bits do índice. Multiplicador de Knuth, truncado para 31 bits
  /// porque em web `int` é double e o produto perderia precisão.
  static int _hash(int index) => (index * 2654435761) & 0x7FFFFFFF;
}

/// Cenário de fundo da arena, distinto por ato (T082).
class BackgroundComponent extends PositionComponent {
  BackgroundComponent({required int act})
    : scenery = ActScenery.forAct(act),
      super(priority: -100);

  ActScenery scenery;

  /// Imagem do ato, quando entregue. Sem ela, o cenário é desenhado.
  Sprite? sprite;

  /// Deslocamento horizontal da rolagem, em pixels de arte.
  ///
  /// Cresce enquanto o time caminha (R-M08-13) e é o que faz o cenário passar
  /// em vez de ficar parado. Nunca é zerado: o mundo dá a volta em [_wrapWidth].
  double scrollX = 0;

  /// A arte volta ao início a cada duas larguras porque a cópia ímpar é
  /// **espelhada**.
  ///
  /// Repetir a mesma imagem lado a lado deixaria uma costura visível a cada
  /// 320 px, já que os cenários não são desenhados para encaixar borda com
  /// borda. Espelhando, a borda encontra a si mesma e a emenda desaparece —
  /// truque velho, e o único que funciona com arte que não foi feita para
  /// repetir.
  double get _wrapWidth => artWidth * 2;

  /// Resolução nativa dos cenários de `assets/sprites/backgrounds/`, igual à de
  /// `tool/backgrounds.py`. Tudo aqui é desenhado nessas coordenadas e escalado
  /// de uma vez, então a arte e o traçado de reserva têm a mesma geometria.
  static const double artWidth = 320;
  static const double artHeight = 180;

  /// Altura da faixa de chão, medida a partir da base da arte.
  static const double groundHeight = 46;

  /// Quanto os pés afundam na faixa de chão. Zero deixaria os combatentes
  /// pousados exatamente na linha de horizonte, que lê como flutuando.
  ///
  /// Vive aqui, e não na arena, porque o primeiro plano precisa da mesma linha
  /// para saber onde pode desenhar sem tapar quem está de pé.
  static const double footInset = 16;

  /// Troca o cenário quando o ato muda. Sem isto o jogador entraria no Ato 2
  /// olhando para a Floresta (CEN-M08-005).
  void syncAct(int act) {
    final next = ActScenery.forAct(act);
    if (next != scenery) scenery = next;
  }

  /// Escala entre as coordenadas da arte e as do componente.
  double get _scale => size.x / artWidth;

  /// Onde a faixa de chão começa, em coordenadas do componente. É daqui que a
  /// arena tira a linha em que os combatentes pisam — e o motivo de existir:
  /// a arte é ancorada na base, então a linha de horizonte depende da altura do
  /// componente, não de uma constante.
  double get groundTopY => size.y - groundHeight * _scale;

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    // O céu cobre tudo. Numa tela de celular a arena é bem mais alta que os
    // 16:9 da arte, e o que sobra acima dela tem de ser cor de ato — não preto.
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = scenery.sky);

    // A arte é ancorada na base e mantém a proporção nativa. Esticá-la para a
    // altura toda deformaria o pixel art em quase 3× num aparelho em retrato,
    // que é o que acontecia antes.
    final scale = _scale;
    canvas.save();
    canvas.translate(0, h - artHeight * scale);
    canvas.scale(scale);

    // Com a imagem do ato entregue, ela substitui o cenário desenhado por
    // inteiro — inclusive as silhuetas, que existem só como substituto.
    final image = sprite;
    if (image != null) {
      _renderScrolling(canvas, (offset, mirrored) {
        _copy(canvas, offset, mirrored, () {
          image.render(canvas, size: Vector2(artWidth, artHeight));
        });
      });
      canvas.restore();
      return;
    }

    // As silhuetas rolam junto; a faixa de chão é lisa e não precisa.
    const groundTop = artHeight - groundHeight;
    _renderScrolling(canvas, (offset, mirrored) {
      _copy(canvas, offset, mirrored, () {
        _renderSilhouettes(canvas, artWidth, groundTop);
      });
    });

    canvas.drawRect(
      const Rect.fromLTWH(0, groundTop, artWidth, groundHeight),
      Paint()..color = scenery.ground,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, groundTop, artWidth, 2),
      Paint()..color = scenery.accent,
    );
    canvas.restore();
  }

  /// Desenha as cópias necessárias para cobrir a arena na posição atual da
  /// rolagem, chamando [draw] com o deslocamento de cada uma e se ela é a cópia
  /// espelhada.
  void _renderScrolling(
    Canvas canvas,
    void Function(double offset, bool mirrored) draw,
  ) {
    // Rolagem para a esquerda: o time avança para a direita. A volta em duas
    // larguras preserva a paridade do espelho, então a emenda continua casada
    // no instante em que o mundo dá a volta.
    final scrolled = scrollX % _wrapWidth;
    for (var copy = (scrolled / artWidth).floor(); ; copy++) {
      final offset = copy * artWidth - scrolled;
      if (offset >= artWidth) break;
      draw(offset, copy.isOdd);
    }
  }

  /// Aplica a transformação de uma cópia e desenha.
  void _copy(
    Canvas canvas,
    double offset,
    bool mirrored,
    void Function() draw,
  ) {
    canvas.save();
    canvas.translate(offset, 0);
    if (mirrored) {
      // Espelha em torno da própria largura, para a cópia encostar na anterior
      // pela borda que ela mesma tem.
      canvas.translate(artWidth, 0);
      canvas.scale(-1, 1);
    }
    draw();
    canvas.restore();
  }

  /// Silhuetas ao fundo: árvores na Floresta, estalactites na Caverna, torres
  /// na Cidadela. A forma muda junto com a cor para que o ato seja legível
  /// mesmo para quem não distingue bem as cores.
  ///
  /// Continua no arquivo depois de [_renderForeground] por ser o caminho de
  /// reserva; o cenário entregue substitui tudo isto.
  void _renderSilhouettes(Canvas canvas, double width, double groundTop) {
    final paint = Paint()..color = scenery.silhouette;
    const step = 38.0;

    for (var x = 0.0; x < width; x += step) {
      switch (scenery) {
        case ActScenery.forest:
          final height = 40 + (x.toInt() % 3) * 12.0;
          canvas.drawRect(
            Rect.fromLTWH(x + 8, groundTop - height, 10, height),
            paint,
          );
          canvas.drawCircle(
            Offset(x + 13, groundTop - height),
            16,
            paint,
          );
        case ActScenery.cave:
          // Estalactites descem do teto; estalagmites sobem do chão.
          final drop = 26 + (x.toInt() % 4) * 9.0;
          canvas.drawPath(
            Path()
              ..moveTo(x, 0)
              ..lineTo(x + 20, 0)
              ..lineTo(x + 10, drop)
              ..close(),
            paint,
          );
          canvas.drawPath(
            Path()
              ..moveTo(x + 6, groundTop)
              ..lineTo(x + 26, groundTop)
              ..lineTo(x + 16, groundTop - 18)
              ..close(),
            paint,
          );
        case ActScenery.citadel:
          final height = 54 + (x.toInt() % 2) * 22.0;
          canvas.drawRect(
            Rect.fromLTWH(x + 6, groundTop - height, 24, height),
            paint,
          );
          // Ameias, para que a torre não seja só um retângulo alto.
          for (var i = 0; i < 3; i++) {
            canvas.drawRect(
              Rect.fromLTWH(x + 6 + i * 9, groundTop - height - 6, 5, 6),
              paint,
            );
          }
      }
    }
  }
}
