import 'dart:io';

import 'package:pixel_idle_quest/data/repositories/content_repository_impl.dart';
import 'package:pixel_idle_quest/domain/engines/rune_tree_service.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/rune_node.dart';
import 'package:test/test.dart';

/// Validação do conteúdo da árvore de runas — V-RN-01 a V-RN-03, T112.
///
/// A árvore é dado, não código, e um erro aqui não aparece como exceção: aparece
/// como um nó que o jogador nunca consegue alcançar, ou uma aresta que existe de
/// um lado só. Por isso a validação roda contra o **arquivo real** de
/// `assets/content/`, e não contra uma fixture.
void main() {
  final json = File('assets/content/rune_tree.json').readAsStringSync();

  final content = JsonContentRepository.fromJson(
    heroClassesJson: File(
      'assets/content/hero_classes.json',
    ).readAsStringSync(),
    monstersJson: File('assets/content/monsters.json').readAsStringSync(),
    runeTreeJson: json,
    // Agora que a árvore está autorada (T123), o mínimo de 200 nós é exigido.
    requireFullRuneTree: true,
  );

  final tree = content.runeTree();

  group('invariantes de conteúdo', () {
    test('V-RN-01: a árvore tem ao menos 200 nós', () {
      expect(tree.nodes.length, greaterThanOrEqualTo(200));
      expect(tree.hasMinimumNodes, isTrue);
    });

    test('V-RN-02: toda aresta é recíproca', () {
      expect(tree.findAsymmetricEdges(), isEmpty);
    });

    test('V-RN-03: nenhum nó órfão — tudo alcançável a partir de uma raiz', () {
      expect(tree.findUnreachableNodes(), isEmpty);
    });

    test('existe ao menos uma raiz, e ela dispensa adjacência', () {
      final roots = tree.nodes.where((n) => n.isRoot).toList();
      expect(roots, isNotEmpty);
      for (final root in roots) {
        expect(root.neighborIds, isNotEmpty, reason: '${root.id} isolada');
      }
    });

    test('nenhum ID se repete — o save referencia por ID', () {
      final ids = tree.nodes.map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('todo nó custa ao menos 1 ponto', () {
      for (final node in tree.nodes) {
        expect(node.cost, greaterThanOrEqualTo(1), reason: node.id);
      }
    });

    test('nenhum nó tem efeito nulo — um nó sem efeito é um ponto jogado fora', () {
      for (final node in tree.nodes) {
        if (node.effect.type.isFlag) continue;
        expect(node.effect.value, greaterThan(0), reason: node.id);
      }
    });
  });

  group('a árvore é jogável de ponta a ponta', () {
    const service = RuneTreeService();

    test('todo nó é alcançável gastando pontos, um por vez', () {
      // Percorre a árvore como o jogador percorreria: só desbloqueia o que a
      // adjacência permite. Se um nó ficar de fora, existe uma região da
      // árvore que nenhum jogador jamais abriria (R-M07-03).
      var account = PlayerAccount.fresh(now: DateTime.utc(2026), seed: 1)
          .copyWith(runePoints: 100000);

      var progressed = true;
      while (progressed) {
        progressed = false;
        for (final id in service.unlockableIds(account, tree)) {
          final result = service.unlock(id, account, tree);
          if (result is UnlockGranted) {
            account = result.account;
            progressed = true;
          }
        }
      }

      expect(
        account.unlockedRuneNodeIds.length,
        tree.nodes.length,
        reason: 'nós inalcançáveis por jogo real: '
            '${tree.nodes.map((n) => n.id).toSet().difference(account.unlockedRuneNodeIds).take(5)}',
      );
    });

    test('os efeitos agregados da árvore inteira ficam em faixa sã', () {
      final todos = tree.nodes.map((n) => n.id).toSet();
      final m = service.modifiersFor(todos, tree);

      // A árvore completa é progressão de centenas de níveis de conta. O que
      // este teste protege é a ordem de grandeza: um zero a mais numa linha do
      // gerador de conteúdo passaria despercebido de outra forma.
      expect(m.damageMultiplier, greaterThan(1));
      expect(m.damageMultiplier, lessThan(20));
      expect(m.goldMultiplier, greaterThan(1));
      expect(m.goldMultiplier, lessThan(20));
      expect(m.xpMultiplier, greaterThan(1));
      expect(m.xpMultiplier, lessThan(20));
      expect(m.bonusCritChance, greaterThan(0));
      expect(m.bonusCritChance, lessThan(1));
      expect(m.attackSpeedMultiplier, greaterThan(1));
      expect(m.attackSpeedMultiplier, lessThan(5));
    });

    test('existe ao menos um nó de regra especial', () {
      expect(
        tree.nodes.any(
          (n) => n.effect.type == RuneEffectType.firstAttackAlwaysCritical,
        ),
        isTrue,
        reason: 'R-M07-05 cita a regra especial como exemplo do que a árvore '
            'oferece; sem nenhum nó assim, a mecânica não existe',
      );
    });

    test('há diversidade de efeitos, não uma árvore de um tipo só', () {
      final tipos = tree.nodes.map((n) => n.effect.type).toSet();
      expect(tipos.length, greaterThanOrEqualTo(4));
    });
  });
}
