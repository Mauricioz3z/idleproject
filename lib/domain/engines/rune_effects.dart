import '../entities/rune_node.dart';

/// Regras especiais de combate concedidas por nós de runa (R-M07-05).
///
/// Existem à parte dos multiplicadores porque não são números: são condições
/// avaliadas durante o tick. Concentrá-las aqui evita que cada nova regra vire
/// mais um `if` espalhado pelo motor — o caminho pelo qual um efeito passa a
/// valer em combate mas não na simulação offline, ou vice-versa.
abstract final class RuneEffects {
  /// CEN-M07-007: "o primeiro ataque de cada wave é crítico".
  ///
  /// O gatilho é a wave, não o herói: quem der o primeiro golpe da wave leva o
  /// crítico, e os demais voltam ao sorteio normal.
  static bool forcesCritical({
    required RuneModifiers runes,
    required bool firstAttackDone,
  }) => runes.firstAttackAlwaysCritical && !firstAttackDone;
}
