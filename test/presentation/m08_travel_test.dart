import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/engines/combat_engine.dart';
import 'package:pixel_idle_quest/domain/engines/offline_simulator.dart';
import 'package:pixel_idle_quest/domain/engines/wave_director.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:test/test.dart';

import '../support/test_content.dart';

/// R-M08-13 — a caminhada entre waves.
///
/// O time anda até o grupo seguinte em vez de o grupo aparecer parado na frente
/// dele. É tempo de jogo de verdade: 1 s em que o combate não corre.
///
/// O risco desta mecânica não é visual, é de **paridade**: quem cobra o pedágio
/// da caminhada são dois pontos independentes — o tick ao vivo e a simulação
/// offline. Se só um cobrasse, a mesma hora de ausência renderia mais waves que
/// a mesma hora de jogo aberto, que é exatamente a divergência que research.md
/// R3 existe para impedir. Os testes daqui cercam os dois lados: o combate
/// parado durante a caminhada prova o pedágio ao vivo, e o teto de waves por
/// intervalo prova o pedágio no offline.
///
/// A primeira versão do último teste comparava as waves das duas vias
/// diretamente e acusou 96 contra 39 em 5 minutos. **Não é a caminhada**: a
/// simulação offline congela o poder dos heróis no nível do save
/// (`offline_simulator.dart`, `combatants` montado antes do laço), então uma
/// ausência longa credita muito menos que o jogo aberto, que sobe de nível no
/// caminho. Divergência conservadora — o jogador nunca recebe demais — mas real
/// e anterior a esta mecânica.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  late JsonContentRepository content;
  late ProviderContainer container;

  setUp(() {
    content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );
    container = ProviderContainer(
      overrides: [
        combatDependenciesProvider.overrideWithValue(
          CombatDependencies(
            classes: content.heroClasses(),
            monsterTemplates: content.monsters(),
            seed: 20260807,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  CombatSession sessao() => container.read(combatControllerProvider);

  void tick([double seconds = CombatArena.fixedStepSeconds]) {
    final steps = (seconds / CombatArena.fixedStepSeconds).round();
    final controller = container.read(combatControllerProvider.notifier);
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }
  }

  /// Roda até a primeira wave ser concluída, e para no primeiro quadro de
  /// caminhada.
  void tickUntilTraveling() {
    for (var i = 0; i < 3000; i++) {
      tick();
      if (sessao().isTraveling) return;
    }
    fail('nenhuma wave foi concluída em 100 s — o combate não está andando');
  }

  test('a primeira wave começa em combate, sem caminhada antes', () {
    // SC-M01-01 depende disto: o jogador abre o app e vê ação, não uma
    // caminhada de aquecimento.
    expect(sessao().isTraveling, isFalse);
    expect(sessao().travelProgress, 1);
  });

  test('R-M08-13: concluir a wave leva a 1 s de caminhada', () {
    tickUntilTraveling();

    expect(sessao().travelRemaining, closeTo(CombatEngine.travelSeconds, 0.05));
    expect(sessao().travelProgress, lessThan(0.1));
  });

  test('o combate não corre durante a caminhada', () {
    tickUntilTraveling();

    final hpAntes = sessao().combat.monsters.map((m) => m.currentHp).toList();
    final ouroAntes = sessao().account.gold;
    final waveAntes = sessao().account.currentPosition.globalWave;

    // Meia caminhada: tempo mais que suficiente para um golpe, se o motor
    // estivesse correndo.
    tick(CombatEngine.travelSeconds / 2);

    expect(
      sessao().combat.monsters.map((m) => m.currentHp).toList(),
      hpAntes,
      reason: 'monstro levou dano enquanto o time ainda estava andando',
    );
    expect(sessao().account.gold, ouroAntes);
    expect(sessao().account.currentPosition.globalWave, waveAntes);
    expect(sessao().isTraveling, isTrue);
  });

  test('a caminhada acaba e o combate volta a correr', () {
    tickUntilTraveling();
    final hpAntes = sessao().combat.monsters.first.currentHp;

    tick(CombatEngine.travelSeconds + 0.1);
    expect(sessao().isTraveling, isFalse);
    expect(sessao().travelProgress, 1);

    // Um segundo de luta depois de chegar: agora o dano tem de aparecer.
    tick(1);
    expect(
      sessao().combat.monsters.isEmpty ||
          sessao().combat.monsters.first.currentHp < hpAntes ||
          sessao().account.currentPosition.globalWave > 1,
      isTrue,
      reason: 'o combate não retomou depois da caminhada',
    );
  });

  test('os eventos do último golpe não sobrevivem à caminhada', () {
    tickUntilTraveling();
    // A arena repassa `lastEvents` a cada quadro. Se eles persistissem durante
    // a caminhada, o mesmo número de dano seria cuspido 30 vezes por segundo
    // por cima de um monstro que ainda está entrando na tela.
    tick();
    expect(sessao().lastEvents, isNull);
  });

  test('a taxa de ouro inclui os segundos de caminhada', () {
    // A taxa alimenta o widget (M11) e o cálculo offline (M09). Medi-la só nos
    // segundos de luta faria as duas prometerem mais do que o jogo entrega.
    tickUntilTraveling();
    final taxaNaChegada = sessao().account.goldPerSecond;
    tick(CombatEngine.travelSeconds * 0.9);

    expect(
      sessao().account.goldPerSecond <= taxaNaChegada,
      isTrue,
      reason: 'a taxa subiu durante a caminhada, em que não entra ouro',
    );
  });

  test('a simulação offline cobra a caminhada de cada wave', () {
    // O cenário é montado para que a **caminhada domine** o tempo por wave: um
    // herói que mata tudo com um golpe a 20 golpes por segundo gasta no máximo
    // 0,4 s de luta por wave, contra 1 s de caminhada. Assim o teto abaixo é um
    // teste de verdade: sem o pedágio, o mesmo intervalo renderia de 3 a 5×
    // mais waves, e nenhum ajuste de dano encobre isso.
    final classe = TestContent.heroClass(
      id: 'veloz',
      attack: 100000,
      defense: 50,
      maxHp: 100000,
      attacksPerSecond: 20,
    );
    final director = WaveDirector(
      templates: [TestContent.monster(id: 'frágil', act: 1, maxHp: 1, attack: 0)],
    );

    const segundos = 120;
    final salvoEm = DateTime.utc(2026, 8, 7, 12);
    final save = SaveState(
      schemaVersion: SaveState.currentSchemaVersion,
      account: PlayerAccount.fresh(now: salvoEm, seed: 7).copyWith(
        goldPerSecond: GameNumber.fromDouble(1),
        lastSaveAt: salvoEm,
      ),
      entitlements: Entitlements.initial(),
      heroes: [
        Hero.fresh(id: 'h1', classId: classe.id).copyWith(formationIndex: 0),
      ],
      equippedItems: const [],
      inventory: Inventory.empty(),
      lastMonotonicMillis: 0,
    );

    final report = const OfflineSimulator()
        .simulate(
          state: save,
          now: salvoEm.add(const Duration(seconds: segundos)),
          combat: CombatEngine(rng: RngStream(seed: 7)),
          waves: director,
          classes: [classe],
        )
        .report;

    expect(
      report.wavesAdvanced,
      lessThanOrEqualTo(segundos / CombatEngine.travelSeconds),
      reason:
          'o offline avançou ${report.wavesAdvanced} waves em $segundos s — '
          'mais do que ${CombatEngine.travelSeconds} s de caminhada por wave '
          'permite. O pedágio de R-M08-13 não está sendo cobrado aqui, e o '
          'resumo passaria a prometer o que a sessão aberta não entrega',
    );
    expect(
      report.wavesAdvanced,
      greaterThan(segundos / (CombatEngine.travelSeconds + 1)),
      reason: 'avançou menos que a própria conta permite — pedágio dobrado?',
    );
  });
}
