import '../../core/numeric/game_number.dart';
import 'monster_template.dart';
import 'stats.dart';

/// Instância viva de um monstro dentro de uma wave.
///
/// Distinta de [MonsterTemplate], que é conteúdo estático: aqui os atributos já
/// vêm escalados por wave, ato e dificuldade (R-M08-06, R-M08-08), e o HP
/// corrente muda a cada golpe. Nada disto é persistido — `CombatState` é
/// transitório e a wave reinicia do começo após reabertura (V-PP-03).
class Monster {
  const Monster._({
    required this.instanceId,
    required this.template,
    required this.stats,
    required this.currentHp,
    required this.slot,
    required this.bleedDps,
    required this.bleedRemaining,
  });

  factory Monster.spawn({
    required String instanceId,
    required MonsterTemplate template,
    required Stats stats,
    required int slot,
  }) => Monster._(
    instanceId: instanceId,
    template: template,
    stats: stats,
    currentHp: stats.maxHp,
    slot: slot,
    bleedDps: GameNumber.zero,
    bleedRemaining: 0,
  );

  final String instanceId;
  final MonsterTemplate template;

  /// Atributos já escalados para a posição atual.
  final Stats stats;

  final GameNumber currentHp;

  /// Posição na formação inimiga. Menor é mais próximo — base da regra de alvo
  /// `nearest` (R-M01-02).
  final int slot;

  /// Dano por segundo do sangramento ativo (M02, Tracker).
  final GameNumber bleedDps;

  /// Segundos restantes de sangramento.
  final double bleedRemaining;

  bool get isAlive => currentHp > GameNumber.zero;
  bool get isBoss => template.isBoss;
  bool get isBleeding => bleedRemaining > 0;

  Monster damaged(GameNumber amount) => _copy(currentHp: currentHp - amount);

  Monster withBleed({required GameNumber dps, required double seconds}) =>
      _copy(bleedDps: dps, bleedRemaining: seconds);

  /// Aplica o dano ao longo do tempo de [dt] segundos.
  ///
  /// O sangramento continua entre golpes — é justamente o que diferencia o
  /// Tracker de uma classe que só bate mais rápido (CEN-M02-007).
  Monster tickBleed(double dt) {
    if (!isBleeding || !isAlive) return this;
    final applied = dt < bleedRemaining ? dt : bleedRemaining;
    return _copy(
      currentHp: currentHp - bleedDps.scaled(applied),
      bleedRemaining: bleedRemaining - applied,
    );
  }

  Monster _copy({
    GameNumber? currentHp,
    GameNumber? bleedDps,
    double? bleedRemaining,
  }) => Monster._(
    instanceId: instanceId,
    template: template,
    stats: stats,
    currentHp: currentHp ?? this.currentHp,
    slot: slot,
    bleedDps: bleedDps ?? this.bleedDps,
    bleedRemaining: bleedRemaining ?? this.bleedRemaining,
  );

  @override
  bool operator ==(Object other) =>
      other is Monster && other.instanceId == instanceId;

  @override
  int get hashCode => instanceId.hashCode;
}
