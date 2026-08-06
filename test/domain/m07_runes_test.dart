import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/domain/engines/rune_tree_service.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/rune_node.dart';
import 'package:test/test.dart';

/// M07 — Árvore de Runas.
/// Cenários CEN-M07-001 a 012, E01 a E03.
void main() {
  const service = RuneTreeService();

  RuneNode node(
    String id, {
    List<String> neighbors = const [],
    bool isRoot = false,
    RuneEffectType type = RuneEffectType.damagePercent,
    double value = 0.10,
    int cost = 1,
  }) => RuneNode(
    id: id,
    cost: cost,
    neighborIds: neighbors,
    isRoot: isRoot,
    effect: RuneEffect(type: type, value: value),
  );

  /// Caminho `raiz → a → b → c`, mais um nó isolado com raiz própria.
  RuneTreeDefinition tree() => RuneTreeDefinition(
    nodes: [
      node('raiz', neighbors: ['a'], isRoot: true),
      node('a', neighbors: ['raiz', 'b']),
      node('b', neighbors: ['a', 'c']),
      node('c', neighbors: ['b'], type: RuneEffectType.goldPercent),
      node(
        'raiz2',
        neighbors: ['especial'],
        isRoot: true,
        type: RuneEffectType.xpPercent,
      ),
      node(
        'especial',
        neighbors: ['raiz2'],
        type: RuneEffectType.firstAttackAlwaysCritical,
        value: 1,
      ),
    ],
  );

  PlayerAccount account({
    int runePoints = 5,
    Set<String> unlocked = const {},
    double gold = 1e6,
    int respecCount = 0,
  }) => PlayerAccount.fresh(now: DateTime.utc(2026), seed: 1).copyWith(
    runePoints: runePoints,
    unlockedRuneNodeIds: unlocked,
    gold: GameNumber.fromDouble(gold),
    respecCount: respecCount,
  );

  group('CEN-M07-001/002 — desbloqueio', () {
    test('CEN-M07-002: nó adjacente a um desbloqueado consome o ponto', () {
      final r = service.unlock(
        'a',
        account(runePoints: 3, unlocked: {'raiz'}),
        tree(),
      );

      expect(r, isA<UnlockGranted>());
      final ok = r as UnlockGranted;
      expect(ok.account.unlockedRuneNodeIds, contains('a'));
      expect(ok.account.runePoints, 2);
    });

    test('nó raiz dispensa adjacência (R-M07-03)', () {
      final r = service.unlock('raiz', account(), tree());
      expect(r, isA<UnlockGranted>());
      expect((r as UnlockGranted).account.unlockedRuneNodeIds, {'raiz'});
    });

    test('CEN-M07-001: os desbloqueáveis do momento são identificáveis', () {
      final disponiveis = service.unlockableIds(
        account(unlocked: {'raiz'}),
        tree(),
      );

      // As duas raízes e o vizinho do que já está aberto.
      expect(disponiveis, containsAll(<String>['a', 'raiz2']));
      expect(disponiveis, isNot(contains('raiz')), reason: 'já desbloqueado');
      expect(disponiveis, isNot(contains('c')), reason: 'não é adjacente');
    });

    test('sem pontos, nada é desbloqueável', () {
      expect(
        service.unlockableIds(account(runePoints: 0, unlocked: {'raiz'}), tree()),
        isEmpty,
      );
    });
  });

  group('CEN-M07-003/004 e E01 — recusas', () {
    test('CEN-M07-003: nó sem vizinho desbloqueado é recusado', () {
      final antes = account(unlocked: {'raiz'});
      final r = service.unlock('c', antes, tree());

      expect(r, isA<UnlockRejected>());
      expect((r as UnlockRejected).reason, UnlockRejection.notAdjacent);
      expect(r.account.runePoints, antes.runePoints, reason: 'nada consumido');
      expect(r.account.unlockedRuneNodeIds, antes.unlockedRuneNodeIds);
    });

    test('CEN-M07-004: sem pontos, a operação é recusada', () {
      final antes = account(runePoints: 0);
      final r = service.unlock('raiz', antes, tree());

      expect((r as UnlockRejected).reason, UnlockRejection.insufficientPoints);
      expect(r.account.unlockedRuneNodeIds, isEmpty);
    });

    test('nó já desbloqueado é recusado sem cobrar de novo', () {
      final antes = account(unlocked: {'raiz'});
      final r = service.unlock('raiz', antes, tree());

      expect((r as UnlockRejected).reason, UnlockRejection.alreadyUnlocked);
      expect(r.account.runePoints, antes.runePoints);
    });

    test('nó inexistente é recusado em vez de lançar', () {
      final r = service.unlock('fantasma', account(), tree());
      expect(r, isA<UnlockRejected>());
    });

    test(
      'CEN-M07-E01: pular os intermediários é recusado e o caminho fica intacto',
      () {
        var acc = account(runePoints: 5);
        acc = (service.unlock('raiz', acc, tree()) as UnlockGranted).account;
        acc = (service.unlock('a', acc, tree()) as UnlockGranted).account;

        final r = service.unlock('c', acc, tree());

        expect((r as UnlockRejected).reason, UnlockRejection.notAdjacent);
        expect(r.account.unlockedRuneNodeIds, {'raiz', 'a'});
      },
    );

    test('CEN-M07-E02: árvore inteira aberta, os pontos ficam acumulados', () {
      var acc = account(runePoints: 10);
      for (final id in ['raiz', 'a', 'b', 'c', 'raiz2', 'especial']) {
        final r = service.unlock(id, acc, tree());
        acc = r.account;
      }

      expect(acc.unlockedRuneNodeIds, hasLength(6));
      expect(acc.runePoints, 4);

      // Pontos novos continuam acumulando sem erro.
      final comMais = acc.copyWith(runePoints: acc.runePoints + 3);
      expect(service.unlockableIds(comMais, tree()), isEmpty);
      expect(comMais.runePoints, 7);
    });
  });

  group('CEN-M07-005/006/007 — efeitos agregados', () {
    test('CEN-M07-005: +10% de dano vira multiplicador 1,1', () {
      final m = service.modifiersFor({'raiz'}, tree());
      expect(m.damageMultiplier, closeTo(1.10, 1e-9));
      expect(m.applyDamage(GameNumber.fromDouble(100)).toDouble(),
          closeTo(110, 1e-6));
    });

    test('bônus do mesmo tipo somam antes de multiplicar', () {
      final m = service.modifiersFor({'raiz', 'a', 'b'}, tree());
      // Três nós de +10% de dano: 1 + 0,30, não 1,1³.
      expect(m.damageMultiplier, closeTo(1.30, 1e-9));
    });

    test('CEN-M07-006: ouro e XP recebem os próprios bônus', () {
      final m = service.modifiersFor({'c', 'raiz2'}, tree());

      expect(m.goldMultiplier, closeTo(1.10, 1e-9));
      expect(m.xpMultiplier, closeTo(1.10, 1e-9));
      expect(m.applyGold(GameNumber.fromDouble(100)).toDouble(),
          closeTo(110, 1e-6));
      expect(m.applyXp(GameNumber.fromDouble(100)).toDouble(),
          closeTo(110, 1e-6));
    });

    test('CEN-M07-007: a regra especial é uma bandeira, não um percentual', () {
      final sem = service.modifiersFor({'raiz'}, tree());
      final com = service.modifiersFor({'raiz', 'especial'}, tree());

      expect(sem.firstAttackAlwaysCritical, isFalse);
      expect(com.firstAttackAlwaysCritical, isTrue);
      // O valor do efeito é ignorado num efeito de bandeira.
      expect(com.damageMultiplier, closeTo(1.10, 1e-9));
    });

    test('conjunto vazio devolve os modificadores neutros', () {
      final m = service.modifiersFor(const {}, tree());

      expect(m.damageMultiplier, 1.0);
      expect(m.goldMultiplier, 1.0);
      expect(m.xpMultiplier, 1.0);
      expect(m.attackSpeedMultiplier, 1.0);
      expect(m.bonusCritChance, 0.0);
      expect(m.firstAttackAlwaysCritical, isFalse);
    });

    test('V-PA-05: ID órfão no save é ignorado sem quebrar a agregação', () {
      final m = service.modifiersFor({'raiz', 'nó_de_outra_versão'}, tree());
      expect(m.damageMultiplier, closeTo(1.10, 1e-9));
    });

    test('CEN-M07-E03: modifiersFor é puro — chamar não muda nada', () {
      final ids = {'raiz', 'a'};
      final a = service.modifiersFor(ids, tree());
      final b = service.modifiersFor(ids, tree());

      expect(a.damageMultiplier, b.damageMultiplier);
      expect(ids, {'raiz', 'a'}, reason: 'a entrada não pode ser mutada');
    });
  });

  group('CEN-M07-009/010/011/012 — respec', () {
    test('CEN-M07-010: o custo cresce estritamente a cada respec', () {
      var anterior = GameNumber.zero;
      for (var n = 0; n < 10; n++) {
        final custo = service.respecCost(n);
        expect(custo > anterior, isTrue, reason: 'respec $n não subiu');
        anterior = custo;
      }
    });

    test('CEN-M07-009: o respec devolve todos os pontos e cobra o ouro', () {
      final acc = account(
        runePoints: 0,
        unlocked: {'raiz', 'a', 'b'},
        gold: 1e9,
      );
      final custo = service.respecCost(acc.respecCount);

      final r = service.respec(acc, tree());

      expect(r, isA<RespecDone>());
      final feito = r as RespecDone;
      expect(feito.account.unlockedRuneNodeIds, isEmpty);
      expect(feito.account.runePoints, 3, reason: 'os 3 pontos voltaram');
      expect(feito.account.respecCount, 1);
      expect(
        feito.account.gold.toDouble(),
        closeTo(acc.gold.toDouble() - custo.toDouble(), 1),
      );
      expect(feito.pointsRefunded, 3);
    });

    test('o reembolso respeita o custo de cada nó, não a contagem', () {
      final caro = RuneTreeDefinition(
        nodes: [
          node('raiz', neighbors: ['caro'], isRoot: true),
          node('caro', neighbors: ['raiz'], cost: 4),
        ],
      );
      final acc = account(runePoints: 0, unlocked: {'raiz', 'caro'});

      final r = service.respec(acc, caro) as RespecDone;
      expect(r.pointsRefunded, 5);
      expect(r.account.runePoints, 5);
    });

    test('CEN-M07-011: sem ouro, recusa sem devolver ponto nem cobrar', () {
      final acc = account(runePoints: 0, unlocked: {'raiz', 'a'}, gold: 1);
      final r = service.respec(acc, tree());

      expect(r, isA<RespecRejected>());
      expect(r.account.gold, acc.gold, reason: 'nada debitado');
      expect(r.account.runePoints, 0, reason: 'nenhum ponto devolvido');
      expect(r.account.unlockedRuneNodeIds, {'raiz', 'a'});
      expect(r.account.respecCount, 0);
    });

    test('SC-M07-03: nenhum ponto se perde no ciclo abrir → respec', () {
      var acc = account(runePoints: 4, gold: 1e9);
      final total = acc.runePoints;

      for (final id in ['raiz', 'a', 'b']) {
        acc = service.unlock(id, acc, tree()).account;
      }
      expect(acc.runePoints, total - 3);

      acc = service.respec(acc, tree()).account;
      expect(acc.runePoints, total, reason: 'o total de pontos mudou');
      expect(acc.unlockedRuneNodeIds, isEmpty);
    });

    test('CEN-M07-012: depois do respec os bônus somem do agregado', () {
      var acc = account(runePoints: 2, gold: 1e9);
      acc = service.unlock('raiz', acc, tree()).account;
      expect(
        service.modifiersFor(acc.unlockedRuneNodeIds, tree()).damageMultiplier,
        closeTo(1.10, 1e-9),
      );

      acc = service.respec(acc, tree()).account;
      expect(
        service.modifiersFor(acc.unlockedRuneNodeIds, tree()).damageMultiplier,
        1.0,
      );
    });

    test('respec sem nada desbloqueado não cobra nem conta', () {
      final acc = account(runePoints: 3);
      final r = service.respec(acc, tree());

      expect(r, isA<RespecRejected>());
      expect(r.account.gold, acc.gold);
      expect(r.account.respecCount, 0);
    });
  });
}
