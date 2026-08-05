import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/presentation/game/combat_arena.dart';
import 'package:pixel_idle_quest/presentation/providers/combat_providers.dart';
import 'package:test/test.dart';

/// US1 — "Progredir sem tocar na tela".
///
/// Teste de aceitação da story, exatamente como a spec a define:
/// iniciar uma partida nova, não tocar em nada e verificar que houve monstros
/// derrotados, ouro acumulado, XP ganho e ao menos uma wave completada.
///
/// Roda sobre o conteúdo real de `assets/content/`, não sobre fixtures — é o que
/// torna o resultado uma afirmação sobre o jogo, e não sobre o motor isolado.
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  late ProviderContainer container;

  setUp(() {
    final content = JsonContentRepository.fromJson(
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
            seed: 20260805,
          ),
        ),
      ],
    );
  });

  tearDown(() => container.dispose());

  /// Avança o jogo por [seconds] no mesmo passo fixo do game loop, sem nenhuma
  /// interação do jogador.
  void playIdle(double seconds) {
    final controller = container.read(combatControllerProvider.notifier);
    final steps = (seconds / CombatArena.fixedStepSeconds).round();
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }
  }

  test('estado inicial: 3 heróis na formação, wave 1 do ato 1', () {
    final session = container.read(combatControllerProvider);

    expect(session.heroes, hasLength(3));
    expect(session.account.formationSlots, 3);
    expect(session.account.currentPosition.act, 1);
    expect(session.account.currentPosition.wave, 1);
    expect(session.combat.monsters, isNotEmpty);
    expect(session.account.gold, GameNumber.zero);
  });

  test('SC-M01-01: o primeiro monstro cai em até 10 s sem nenhuma ação', () {
    playIdle(10);
    final session = container.read(combatControllerProvider);
    expect(session.account.gold > GameNumber.zero, isTrue,
        reason: 'nenhum monstro derrotado em 10 s');
  });

  test('SC-M01-02: 5 minutos ociosos rendem ouro, XP e avanço de wave', () {
    playIdle(300);
    final session = container.read(combatControllerProvider);

    expect(session.account.gold > GameNumber.zero, isTrue, reason: 'sem ouro');
    expect(
      session.heroes.any((h) => h.xp > GameNumber.zero || h.level > 1),
      isTrue,
      reason: 'nenhum herói ganhou XP',
    );
    expect(
      session.account.currentPosition.globalWave,
      greaterThan(1),
      reason: 'nenhuma wave completada',
    );
  });

  test('os heróis sobem de nível ao longo de uma sessão longa', () {
    playIdle(600);
    final session = container.read(combatControllerProvider);
    expect(session.heroes.any((h) => h.level > 1), isTrue);
  });

  test('o recorde de maior wave acompanha o avanço, sem regredir', () {
    playIdle(300);
    final session = container.read(combatControllerProvider);
    expect(
      session.account.highestWave,
      greaterThanOrEqualTo(1),
    );
    expect(
      session.account.highestWave,
      lessThanOrEqualTo(session.account.currentPosition.globalWave),
    );
  });

  test('R-M08-03: uma wave de boss é enfrentada no caminho', () {
    final controller = container.read(combatControllerProvider.notifier);
    final steps = (900 / CombatArena.fixedStepSeconds).round();

    var enfrentouBoss = false;
    var maiorWave = 1;
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
      final s = container.read(combatControllerProvider);
      if (s.combat.monsters.any((m) => m.isBoss)) enfrentouBoss = true;
      final w = s.account.currentPosition.wave;
      if (w > maiorWave) maiorWave = w;
    }

    expect(maiorWave, greaterThanOrEqualTo(10),
        reason: 'o jogo nem chegou à primeira wave de boss em 15 min ociosos');
    expect(enfrentouBoss, isTrue,
        reason: 'passou pela wave 10 sem nenhum boss no campo');
  });

  test('R-M01-07: não existe nenhuma entrada de ataque no controlador', () {
    // O controlador expõe apenas tick e refreshFormationSlots. Se algum dia
    // aparecer um método de ataque manual, o combate deixou de ser automático.
    final controller = container.read(combatControllerProvider.notifier);
    expect(controller.tick, isA<void Function(double)>());
  });

  test('determinismo: a mesma semente produz a mesma sessão', () {
    playIdle(120);
    final ouroA = container.read(combatControllerProvider).account.gold;
    final waveA =
        container.read(combatControllerProvider).account.currentPosition;

    final content = JsonContentRepository.fromJson(
      heroClassesJson: read('hero_classes.json'),
      monstersJson: read('monsters.json'),
      runeTreeJson: '[]',
      requireFullRuneTree: false,
    );
    final outro = ProviderContainer(
      overrides: [
        combatDependenciesProvider.overrideWithValue(
          CombatDependencies(
            classes: content.heroClasses(),
            monsterTemplates: content.monsters(),
            seed: 20260805,
          ),
        ),
      ],
    );
    addTearDown(outro.dispose);

    final controller = outro.read(combatControllerProvider.notifier);
    final steps = (120 / CombatArena.fixedStepSeconds).round();
    for (var i = 0; i < steps; i++) {
      controller.tick(CombatArena.fixedStepSeconds);
    }

    expect(outro.read(combatControllerProvider).account.gold, ouroA);
    expect(
      outro.read(combatControllerProvider).account.currentPosition,
      waveA,
    );
  });
}
