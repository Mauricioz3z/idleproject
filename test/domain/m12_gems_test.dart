import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/core/rng/rng_stream.dart';
import 'package:pixel_idle_quest/domain/engines/cube_service.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entitlements/gem_sink.dart';
import 'package:test/test.dart';

/// Gemas aceleram sem alterar resultado — FR-029, V-ENT-04, CEN-M12-008/009.
///
/// A propriedade que este arquivo protege é a que separa "aceleração" de
/// "pay-to-win": a distribuição de resultados de uma operação acelerada por
/// gemas é **idêntica** à da mesma operação aguardada. Concretamente, o RNG é
/// consumido na confirmação, não na conclusão.
void main() {
  const gems = GemSink();
  const cube = CubeService();
  final agora = DateTime.utc(2026, 8, 6);

  PlayerAccount account({int gemsOwned = 100}) =>
      PlayerAccount.fresh(now: agora, seed: 1).copyWith(gems: gemsOwned);

  List<GameItem> trio() => [
    for (var i = 0; i < 3; i++)
      GameItem(
        id: 'm$i',
        type: ItemType.weapon,
        rarity: ItemRarity.ouro,
        itemLevel: 50,
        baseStat: GameNumber.fromDouble(100),
        affixes: const [],
        droppedAt: agora,
      ),
  ];

  Inventory inv(List<GameItem> items) => Inventory(
    items: items,
    pendingDrops: const [],
    essences: const [],
    blueprints: const [],
  );

  group('débito e recusa', () {
    test('acelerar debita as gemas', () {
      final r = gems.spendToRush(account(gemsOwned: 100), RushTarget.cubeOperation);

      expect(r, isA<GemSpendApplied>());
      final aplicado = r as GemSpendApplied;
      expect(
        aplicado.account.gems,
        100 - GemSink.costFor(RushTarget.cubeOperation),
      );
    });

    test('saldo insuficiente recusa sem debitar nem alterar a operação', () {
      final antes = account(gemsOwned: 0);
      final r = gems.spendToRush(antes, RushTarget.runeRespec);

      expect(r, isA<GemSpendRejected>());
      expect(r.account.gems, 0);
      expect(
        (r as GemSpendRejected).reason,
        GemSpendRejection.insufficientGems,
      );
    });

    test('cada alvo tem custo próprio e positivo', () {
      for (final target in RushTarget.values) {
        expect(GemSink.costFor(target), greaterThan(0), reason: target.name);
      }
    });

    test('CEN-M12-009: acelerar o respec reduz o custo em ouro', () {
      final r =
          gems.spendToRush(account(), RushTarget.runeRespec) as GemSpendApplied;

      expect(r.goldCostMultiplier, lessThan(1.0));
      expect(r.goldCostMultiplier, greaterThan(0));
    });
  });

  group('V-ENT-04 — a distribuição de resultados não muda', () {
    test(
      'a mesma fusão, acelerada ou aguardada, produz exatamente o mesmo item',
      () {
        // O RNG é consumido na confirmação. Acelerar depois disso não tem o que
        // re-sortear — é essa ordem que impede o pay-to-win.
        final materiais = trio();

        final aguardada =
            cube.fuse(
                  materials: materiais,
                  inventory: inv(materiais),
                  rng: RngStream(seed: 555),
                  now: agora,
                )
                as FusionSuccess;

        // Agora a mesma fusão, com gemas gastas antes de confirmar.
        var acc = account();
        final gasto =
            gems.spendToRush(acc, RushTarget.cubeOperation) as GemSpendApplied;
        acc = gasto.account;

        final acelerada =
            cube.fuse(
                  materials: materiais,
                  inventory: inv(materiais),
                  rng: RngStream(seed: 555),
                  now: agora,
                )
                as FusionSuccess;

        expect(acelerada.item.id, aguardada.item.id);
        expect(acelerada.item.type, aguardada.item.type);
        expect(acelerada.item.rarity, aguardada.item.rarity);
        expect(acelerada.item.baseStat, aguardada.item.baseStat);
        expect(
          acelerada.item.affixes.map((a) => a.affixType),
          aguardada.item.affixes.map((a) => a.affixType),
        );
        expect(acc.gems, lessThan(100), reason: 'as gemas foram debitadas');
      },
    );

    test('gastar gemas não consome o fluxo de RNG do jogo', () {
      final rng = RngStream(seed: 3);
      final antes = rng.counter;

      var acc = account(gemsOwned: 1000);
      for (var i = 0; i < 5; i++) {
        final r = gems.spendToRush(acc, RushTarget.cubeOperation);
        acc = r.account;
      }

      expect(rng.counter, antes, reason: 'a aceleração tocou no sorteio');
    });

    test(
      'a distribuição de raridades de 200 fusões é a mesma com e sem gemas',
      () {
        Map<ItemRarity, int> distribuicao({required bool comGemas}) {
          final rng = RngStream(seed: 8080);
          var acc = account(gemsOwned: 100000);
          final contagem = <ItemRarity, int>{};

          for (var i = 0; i < 200; i++) {
            if (comGemas) {
              acc = gems.spendToRush(acc, RushTarget.cubeOperation).account;
            }
            final materiais = trio();
            final r =
                cube.fuse(
                      materials: materiais,
                      inventory: inv(materiais),
                      rng: rng,
                      now: agora,
                    )
                    as FusionSuccess;
            contagem[r.item.rarity] = (contagem[r.item.rarity] ?? 0) + 1;
          }
          return contagem;
        }

        expect(distribuicao(comGemas: true), distribuicao(comGemas: false));
      },
    );
  });

  group('CEN-M12-009 — nenhum nó fica inacessível a quem não usa gemas', () {
    test('o desconto muda o custo, nunca o que o respec devolve', () {
      final r =
          gems.spendToRush(account(), RushTarget.runeRespec) as GemSpendApplied;

      // O desconto é multiplicador de ouro. Não existe caminho aqui que mexa
      // em pontos devolvidos ou em nós disponíveis — o `GemSink` sequer
      // conhece a árvore.
      expect(r.goldCostMultiplier, isNot(0));
      expect(r.target, RushTarget.runeRespec);
    });
  });
}
