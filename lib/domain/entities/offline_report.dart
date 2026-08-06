import '../../core/numeric/game_number.dart';
import 'game_item.dart';

/// Uma subida de nível ocorrida durante a ausência.
class OfflineLevelUp {
  const OfflineLevelUp({
    required this.heroId,
    required this.from,
    required this.to,
  });

  final String heroId;
  final int from;
  final int to;

  int get levelsGained => to - from;
}

/// Resumo dos ganhos da ausência (R-M09-06).
///
/// **[derivado]**: exibido uma vez e descartado. Nada aqui é persistido — o
/// estado resultante vai em `OfflineSimulation.state`, e manter os dois
/// separados é o que impede o resumo de virar uma segunda fonte de verdade
/// sobre o progresso.
class OfflineReport {
  const OfflineReport({
    required this.elapsedSeconds,
    required this.wasCapped,
    required this.goldGained,
    required this.goldFromAutoSell,
    required this.xpGained,
    required this.wavesAdvanced,
    required this.itemsObtained,
    required this.rareHighlights,
    required this.levelUps,
    required this.inventoryBecameFull,
  });

  /// Relatório de "nada aconteceu": primeira abertura, relógio atrasado ou
  /// ausência de zero segundo (CEN-M09-E02, E03).
  static const OfflineReport empty = OfflineReport(
    elapsedSeconds: 0,
    wasCapped: false,
    goldGained: GameNumber.zero,
    goldFromAutoSell: GameNumber.zero,
    xpGained: GameNumber.zero,
    wavesAdvanced: 0,
    itemsObtained: [],
    rareHighlights: [],
    levelUps: [],
    inventoryBecameFull: false,
  );

  /// Já limitado ao teto de 8 h (V-OR-01).
  final int elapsedSeconds;

  /// Verdadeiro quando a ausência real foi maior que o teto — o jogador merece
  /// saber que passou do limite, senão o teto parece um bug.
  final bool wasCapped;

  /// Ouro da fórmula fechada `gps × elapsed × 0,8` (R-M09-03). Só isto.
  final GameNumber goldGained;

  /// Ouro da venda automática disparada pelos drops offline (R-M05-06).
  ///
  /// Separado de [goldGained] porque tem outra origem: o cálculo offline é uma
  /// fórmula sobre o tempo, e este é consequência do inventário ter enchido.
  /// Somá-los tornaria impossível conferir a fórmula.
  final GameNumber goldFromAutoSell;

  final GameNumber xpGained;
  final int wavesAdvanced;

  final List<GameItem> itemsObtained;

  /// Lendário ou superior (CEN-M09-007). Subconjunto de [itemsObtained].
  final List<GameItem> rareHighlights;

  final List<OfflineLevelUp> levelUps;

  /// Dispara a notificação de inventário cheio (CEN-M09-009).
  final bool inventoryBecameFull;

  /// Sem nada a mostrar: não abre o resumo (CEN-M09-E03).
  bool get isEmpty =>
      elapsedSeconds == 0 &&
      goldGained.isZero &&
      xpGained.isZero &&
      wavesAdvanced == 0 &&
      itemsObtained.isEmpty;

  Duration get elapsed => Duration(seconds: elapsedSeconds);
}
