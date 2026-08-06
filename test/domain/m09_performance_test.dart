import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/engines/offline_simulator.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// Orçamento de desempenho da simulação offline — SC-M09-01.
///
/// O critério é medido no **aparelho de referência** de plan.md (4 GB, SoC de
/// entrada, Android 10), não na máquina de desenvolvimento. Como este teste roda
/// na máquina de desenvolvimento, ele usa um orçamento proporcionalmente muito
/// mais apertado: se 8 h simuladas passarem de algumas centenas de milissegundos
/// aqui, é porque a simulação voltou a ser tick a tick e vai estourar os 3 s lá.
/// A medição no aparelho real continua sendo T144, da Fase 10.
void main() {
  const simulator = OfflineSimulator();
  final salvoEm = DateTime.utc(2026, 8, 5, 12);

  /// Margem local. O aparelho de referência é ~10× mais lento que a máquina de
  /// desenvolvimento típica; 300 ms aqui deixa folga confortável para os 3 s lá.
  const budget = Duration(milliseconds: 300);

  final classe = TestContent.heroClass(
    id: 'herói',
    attack: 600,
    defense: 40,
    maxHp: 3000,
    attacksPerSecond: 3,
  );

  final director = WaveDirector(
    templates: [
      TestContent.monster(id: 'comum', act: 1, maxHp: 100, attack: 10),
      TestContent.monster(id: 'rapido', act: 1, maxHp: 80, attack: 8),
      TestContent.monster(
        id: 'boss',
        act: 1,
        isBoss: true,
        maxHp: 400,
        attack: 20,
      ),
    ],
  );

  SaveState save() => SaveState(
    schemaVersion: SaveState.currentSchemaVersion,
    account: PlayerAccount.fresh(now: salvoEm, seed: 7).copyWith(
      goldPerSecond: GameNumber.fromDouble(500),
      lastSaveAt: salvoEm,
    ),
    entitlements: Entitlements.initial(),
    heroes: [
      for (var i = 0; i < 4; i++)
        Hero.fresh(id: 'h$i', classId: classe.id).copyWith(formationIndex: i),
    ],
    equippedItems: const [],
    inventory: Inventory.empty(),
    lastMonotonicMillis: 0,
  );

  OfflineSimulation simulate(Duration ausencia) => simulator.simulate(
    state: save(),
    now: salvoEm.add(ausencia),
    combat: CombatEngine(rng: RngStream(seed: 31)),
    waves: director,
    classes: [classe],
  );

  test('SC-M09-01: 8 h de ausência são resolvidas dentro do orçamento', () {
    // Aquecimento: a primeira execução paga JIT e carga de classes, que não
    // fazem parte do custo que o critério mede.
    simulate(const Duration(minutes: 5));

    final relogio = Stopwatch()..start();
    final r = simulate(const Duration(hours: 8));
    relogio.stop();

    expect(
      relogio.elapsed,
      lessThan(budget),
      reason:
          '8 h levaram ${relogio.elapsedMilliseconds} ms — acima do orçamento '
          'local de ${budget.inMilliseconds} ms. A 30 ticks/s, 8 h seriam '
          '864.000 ticks: verifique se a simulação voltou a ser tick a tick '
          '(research.md R3).',
    );
    expect(r.report.wavesAdvanced, greaterThan(0), reason: 'nada simulado');
  });

  test('o custo cresce com o intervalo sem explodir', () {
    simulate(const Duration(minutes: 5));

    Duration medir(Duration ausencia) {
      final relogio = Stopwatch()..start();
      simulate(ausencia);
      relogio.stop();
      return relogio.elapsed;
    }

    final umaHora = medir(const Duration(hours: 1));
    final oitoHoras = medir(const Duration(hours: 8));

    // Crescimento linear no tempo simulado, com folga generosa para ruído de
    // medição. Superlinear indicaria trabalho por wave crescendo com o total.
    expect(
      oitoHoras.inMicroseconds,
      lessThan(umaHora.inMicroseconds * 40 + budget.inMicroseconds),
    );
  });

  test('o teto de 8 h também é teto de trabalho', () {
    simulate(const Duration(minutes: 5));

    final relogio = Stopwatch()..start();
    simulate(const Duration(days: 30));
    relogio.stop();

    expect(
      relogio.elapsed,
      lessThan(budget),
      reason: '30 dias precisam custar o mesmo que 8 h — o teto vem antes',
    );
  });
}
