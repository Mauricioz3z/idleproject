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

  /// Cenário do ato. Atos fora de 1..3 caem na Floresta em vez de lançar: um
  /// erro de conteúdo não pode deixar a tela preta durante o combate.
  static ActScenery forAct(int act) => switch (act) {
    2 => ActScenery.cave,
    3 => ActScenery.citadel,
    _ => ActScenery.forest,
  };
}

/// Cenário de fundo da arena, distinto por ato (T082).
class BackgroundComponent extends PositionComponent {
  BackgroundComponent({required int act})
    : scenery = ActScenery.forAct(act),
      super(priority: -100);

  ActScenery scenery;

  /// Altura da faixa de chão, medida a partir da base da arena.
  static const double _groundHeight = 46;

  /// Troca o cenário quando o ato muda. Sem isto o jogador entraria no Ato 2
  /// olhando para a Floresta (CEN-M08-005).
  void syncAct(int act) {
    final next = ActScenery.forAct(act);
    if (next != scenery) scenery = next;
  }

  @override
  void render(Canvas canvas) {
    final w = size.x;
    final h = size.y;
    if (w <= 0 || h <= 0) return;

    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()..color = scenery.sky);

    final groundTop = h - _groundHeight;
    _renderSilhouettes(canvas, w, groundTop);

    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, w, _groundHeight),
      Paint()..color = scenery.ground,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, w, 2),
      Paint()..color = scenery.accent,
    );
  }

  /// Silhuetas ao fundo: árvores na Floresta, estalactites na Caverna, torres
  /// na Cidadela. A forma muda junto com a cor para que o ato seja legível
  /// mesmo para quem não distingue bem as cores.
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
