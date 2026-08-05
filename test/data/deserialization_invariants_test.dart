import 'package:pixel_idle_quest/core/constants/game_enums.dart';
import 'package:pixel_idle_quest/core/numeric/game_number.dart';
import 'package:pixel_idle_quest/data/dto/save_codec.dart';
import 'package:pixel_idle_quest/data/dto/save_validator.dart';
import 'package:pixel_idle_quest/domain/entities/entitlements.dart';
import 'package:pixel_idle_quest/domain/entities/game_item.dart';
import 'package:pixel_idle_quest/domain/entities/hero.dart';
import 'package:pixel_idle_quest/domain/entities/inventory.dart';
import 'package:pixel_idle_quest/domain/entities/player_account.dart';
import 'package:pixel_idle_quest/domain/entities/save_state.dart';
import 'package:test/test.dart';

/// Invariantes D-01 a D-07 — contracts/persistence-save-schema.md.
///
/// A filosofia é reparar em vez de rejeitar: um save levemente inconsistente
/// não deve custar o progresso do jogador. Mas todo reparo é reportado.
void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(1785600000000);

  GameItem item(String id, {ItemRarity rarity = ItemRarity.ouro}) => GameItem(
    id: id,
    type: ItemType.weapon,
    rarity: rarity,
    itemLevel: 10,
    baseStat: GameNumber(1, 2),
    affixes: const [],
    droppedAt: now,
  );

  SaveState build({
    List<Hero> heroes = const [],
    List<GameItem> equipped = const [],
    List<GameItem> items = const [],
    List<GameItem> pending = const [],
    PlayerAccount? account,
  }) => SaveState(
    schemaVersion: 1,
    account: account ?? PlayerAccount.fresh(now: now, seed: 1),
    entitlements: Entitlements.initial(),
    heroes: heroes,
    equippedItems: equipped,
    inventory: Inventory(
      items: items,
      pendingDrops: pending,
      essences: const [],
      blueprints: const [],
    ),
    lastMonotonicMillis: 0,
  );

  test('D-01: item duplicado entre equipado e inventário é resolvido', () {
    final dup = item('i-dup');
    final hero = Hero.fresh(id: 'h1', classId: 'vanguard');
    final (equippedHero, _) = hero.equipItem(ItemType.weapon, 'i-dup');

    final result = SaveValidator.validate(
      build(heroes: [equippedHero], equipped: [dup], items: [dup]),
    );

    final allIds = [
      ...result.state.equippedItems.map((i) => i.id),
      ...result.state.inventory.items.map((i) => i.id),
    ];
    expect(allIds.length, allIds.toSet().length, reason: 'sem duplicatas');
    expect(result.repairs.any((r) => r.rule == 'D-01'), isTrue);
  });

  test('D-02: referência de equipamento órfã é limpa', () {
    final hero = Hero.fresh(id: 'h1', classId: 'vanguard');
    final (withGhost, _) = hero.equipItem(ItemType.weapon, 'i-fantasma');

    final result = SaveValidator.validate(build(heroes: [withGhost]));

    expect(result.state.heroes.single.equipment[ItemType.weapon], isNull);
    expect(result.repairs.any((r) => r.rule == 'D-02'), isTrue);
  });

  test('D-02: item equipado sem dono volta ao inventário, não é perdido', () {
    final result = SaveValidator.validate(build(equipped: [item('i-sozinho')]));

    expect(result.state.equippedItems, isEmpty);
    expect(result.state.inventory.items.single.id, 'i-sozinho');
  });

  test('D-03: formationSlots discordante resolve a favor de fourthSlotSource',
      () {
    // Save adulterado: 4 slots declarados, mas fonte "none".
    final raw = {
      'schemaVersion': 1,
      'lastSaveTimestamp': now.millisecondsSinceEpoch,
      'playerAccount': {
        'formationSlots': 4,
        'fourthSlotSource': 'none',
      },
    };
    final decoded = SaveCodec.decodeSave(raw);
    expect(decoded.account.formationSlots, PlayerAccount.baseFormationSlots);
    expect(decoded.account.fourthSlotSource, FourthSlotSource.none);
  });

  test('D-03: fonte de compra implica 4 slots', () {
    final raw = {
      'schemaVersion': 1,
      'lastSaveTimestamp': now.millisecondsSinceEpoch,
      'playerAccount': {
        'formationSlots': 3,
        'fourthSlotSource': 'purchase',
      },
    };
    final decoded = SaveCodec.decodeSave(raw);
    expect(decoded.account.formationSlots, PlayerAccount.maxFormationSlots);
  });

  test('D-04: formationIndex repetido remove o excedente da formação', () {
    final a = Hero.fresh(id: 'h1', classId: 'c').copyWith(formationIndex: 0);
    final b = Hero.fresh(id: 'h2', classId: 'c').copyWith(formationIndex: 0);

    final result = SaveValidator.validate(build(heroes: [a, b]));

    final inFormation =
        result.state.heroes.where((h) => h.isInFormation).toList();
    expect(inFormation.length, 1);
    expect(result.repairs.any((r) => r.rule == 'D-04'), isTrue);
  });

  test('D-04: índice além do limite de slots é removido', () {
    final h = Hero.fresh(id: 'h1', classId: 'c').copyWith(formationIndex: 3);
    // Conta padrão tem 3 slots: índices válidos são 0, 1 e 2.
    final result = SaveValidator.validate(build(heroes: [h]));
    expect(result.state.heroes.single.isInFormation, isFalse);
  });

  test('D-05: excedente de 50 slots vai para pendentes, nunca truncado', () {
    final many = [for (var i = 0; i < 57; i++) item('i-$i')];
    final result = SaveValidator.validate(build(items: many));

    expect(result.state.inventory.items.length, Inventory.capacity);
    expect(result.state.inventory.pendingDrops.length, 7);
    // Nenhum item some.
    expect(
      result.state.inventory.items.length +
          result.state.inventory.pendingDrops.length,
      57,
    );
  });

  test('D-06: nó de runa desconhecido é descartado e o ponto devolvido', () {
    final account = PlayerAccount.fresh(now: now, seed: 1).copyWith(
      unlockedRuneNodeIds: {'valido', 'removido_em_atualizacao'},
      runePoints: 2,
    );
    final result = SaveValidator.validate(
      build(account: account),
      knownRuneNodeIds: {'valido'},
    );

    expect(result.state.account.unlockedRuneNodeIds, {'valido'});
    expect(result.state.account.runePoints, 3, reason: 'ponto devolvido');
    expect(result.repairs.any((r) => r.rule == 'D-06'), isTrue);
  });

  test('D-07: posição fora dos limites satura no válido mais próximo', () {
    final raw = {
      'schemaVersion': 1,
      'lastSaveTimestamp': now.millisecondsSinceEpoch,
      'playerAccount': {
        'currentPosition': {'difficulty': 0, 'act': 9, 'wave': 500},
      },
    };
    final decoded = SaveCodec.decodeSave(raw);
    expect(decoded.account.currentPosition.difficulty, 1);
    expect(decoded.account.currentPosition.act, 3);
    expect(decoded.account.currentPosition.wave, 100);
  });

  test('save íntegro não gera nenhum reparo', () {
    final hero = Hero.fresh(id: 'h1', classId: 'c').copyWith(formationIndex: 0);
    final (equipped, _) = hero.equipItem(ItemType.weapon, 'i-1');
    final result = SaveValidator.validate(
      build(heroes: [equipped], equipped: [item('i-1')], items: [item('i-2')]),
    );
    expect(result.isClean, isTrue, reason: result.repairs.join('; '));
  });
}
