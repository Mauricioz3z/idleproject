import '../../core/constants/game_enums.dart';

/// Consumível raro que garante um sufixo específico numa fusão do Cubo.
///
/// Obtida por drop em combate (R-M04-12), em fluxo de RNG independente do de
/// itens (R-M04-13). Consumida na fusão independentemente do resultado
/// (R-M06-05, V-ES-02).
class Essence {
  const Essence({
    required this.id,
    required this.guaranteedAffixType,
    required this.droppedAt,
  });

  final String id;

  /// Sufixo que esta Essência garante no item resultante. Sorteado na geração
  /// e imutável (V-ES-04).
  final AffixType guaranteedAffixType;

  final DateTime droppedAt;

  @override
  bool operator ==(Object other) => other is Essence && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Essência(${guaranteedAffixType.id})';
}
