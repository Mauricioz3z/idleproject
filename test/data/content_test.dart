import 'dart:io';

import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/entities/progress_position.dart';
import 'package:test/test.dart';

/// Valida o conteúdo real de `assets/content/`.
///
/// Um erro aqui é erro de dados do desenvolvedor, não do jogador — daí a
/// validação ser agressiva e rodar em teste (research.md R8).
void main() {
  String read(String name) => File('assets/content/$name').readAsStringSync();

  group('classes de herói — M02', () {
    late JsonContentRepository repo;

    setUp(() {
      repo = JsonContentRepository.fromJson(
        heroClassesJson: read('hero_classes.json'),
        monstersJson: read('monsters.json'),
        // A árvore de runas só é populada em T123 (US6); usa uma raiz mínima
        // para não bloquear a validação das outras coleções.
        runeTreeJson: _minimalRuneTree,
        requireFullRuneTree: false,
      );
    });

    test('as 6 classes de M02 existem', () {
      expect(repo.heroClasses(), hasLength(6));
      expect(
        repo.heroClasses().map((c) => c.id).toSet(),
        {
          'vanguard',
          'elementalist',
          'sharpshooter',
          'medtech',
          'tracker',
          'berserker',
        },
      );
    });

    test('cada classe tem mecânica única distinta', () {
      final mecanicas = repo.heroClasses().map((c) => c.mechanic).toSet();
      expect(mecanicas, hasLength(6));
    });

    test('cada classe tem papel distinto', () {
      expect(repo.heroClasses().map((c) => c.role).toSet(), hasLength(6));
    });

    test('as mecânicas conferem com a tabela de M02', () {
      ClassMechanic of(String id) =>
          repo.heroClassById(id)!.mechanic;

      expect(of('vanguard'), ClassMechanic.taunt);
      expect(of('elementalist'), ClassMechanic.areaElemental);
      expect(of('sharpshooter'), ClassMechanic.defensePenetration);
      expect(of('medtech'), ClassMechanic.healAndHaste);
      expect(of('tracker'), ClassMechanic.bleed);
      expect(of('berserker'), ClassMechanic.rageOnLowHp);
    });

    test('toda classe tem atributos base e crescimento positivos', () {
      for (final c in repo.heroClasses()) {
        expect(c.baseStats.maxHp > GameNumber.zero, isTrue, reason: c.id);
        expect(c.baseStats.attack > GameNumber.zero, isTrue, reason: c.id);
        expect(c.statGrowthPerLevel.attack > GameNumber.zero, isTrue,
            reason: c.id);
        expect(c.attacksPerSecond, greaterThan(0), reason: c.id);
      }
    });

    test('toda classe tem ao menos uma habilidade de nível 1', () {
      for (final c in repo.heroClasses()) {
        expect(c.skillsUpTo(1), isNotEmpty, reason: c.id);
      }
    });

    test('o Tracker ataca mais rápido que o Vanguard', () {
      expect(
        repo.heroClassById('tracker')!.attacksPerSecond,
        greaterThan(repo.heroClassById('vanguard')!.attacksPerSecond),
      );
    });
  });

  group('monstros — M08', () {
    late JsonContentRepository repo;

    setUp(() {
      repo = JsonContentRepository.fromJson(
        heroClassesJson: read('hero_classes.json'),
        monstersJson: read('monsters.json'),
        runeTreeJson: _minimalRuneTree,
        requireFullRuneTree: false,
      );
    });

    test('os 3 atos têm monstros', () {
      for (var act = ProgressPosition.minAct;
          act <= ProgressPosition.maxAct;
          act++) {
        expect(repo.monstersForAct(act), isNotEmpty, reason: 'ato $act');
      }
    });

    test('cada ato tem exatamente um boss', () {
      for (var act = 1; act <= 3; act++) {
        final bosses = repo.monstersForAct(act).where((m) => m.isBoss);
        expect(bosses, hasLength(1), reason: 'ato $act');
      }
    });

    test('bosses são mais fortes que os comuns do mesmo ato', () {
      for (var act = 1; act <= 3; act++) {
        final doAto = repo.monstersForAct(act);
        final boss = doAto.firstWhere((m) => m.isBoss);
        for (final comum in doAto.where((m) => !m.isBoss)) {
          expect(boss.baseStats.maxHp > comum.baseStats.maxHp, isTrue,
              reason: '${boss.id} vs ${comum.id}');
        }
      }
    });

    test('os atos escalam em dificuldade', () {
      double hpMedio(int act) {
        final normais =
            repo.monstersForAct(act).where((m) => !m.isBoss).toList();
        final soma = normais.fold<double>(
          0,
          (acc, m) => acc + m.baseStats.maxHp.toDouble(),
        );
        return soma / normais.length;
      }

      expect(hpMedio(2), greaterThan(hpMedio(1)));
      expect(hpMedio(3), greaterThan(hpMedio(2)));
    });

    test('todo monstro tem ao menos uma raridade possível de drop', () {
      for (final m in repo.monsters()) {
        expect(m.possibleRarities, isNotEmpty, reason: m.id);
      }
    });

    test('bosses concedem raridades melhores que os comuns do ato', () {
      for (var act = 1; act <= 3; act++) {
        final doAto = repo.monstersForAct(act);
        final boss = doAto.firstWhere((m) => m.isBoss);
        final melhorDoBoss = boss.possibleRarities
            .map((r) => r.index)
            .reduce((a, b) => a > b ? a : b);
        for (final comum in doAto.where((m) => !m.isBoss)) {
          final melhorComum = comum.possibleRarities
              .map((r) => r.index)
              .reduce((a, b) => a > b ? a : b);
          expect(melhorDoBoss, greaterThanOrEqualTo(melhorComum),
              reason: '${boss.id} vs ${comum.id}');
        }
      }
    });

    test('modificadores de drop e de essência são independentes — R-M04-13', () {
      // Se fossem sempre iguais, não haveria razão para dois campos, e a
      // independência de fluxos de RNG seria decorativa.
      final diferentes = repo
          .monsters()
          .where((m) => m.dropChanceModifier != m.essenceChanceModifier);
      expect(diferentes, isNotEmpty);
    });
  });
}

const _minimalRuneTree = '''
[
  {"id":"root","cost":1,"neighborIds":[],"isRoot":true,
   "effect":{"type":"damagePercent","value":5}}
]
''';
