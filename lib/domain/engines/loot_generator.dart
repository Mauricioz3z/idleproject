import '../../core/constants/affix_table.dart';
import '../../core/constants/game_enums.dart';
import '../../core/constants/scaling.dart';
import '../../core/numeric/game_number.dart';
import '../../core/rng/rng_stream.dart';
import '../entities/essence.dart';
import '../entities/game_item.dart';
import '../entities/monster_template.dart';
import '../entities/progress_position.dart';

/// Geração procedural de loot (M04).
///
/// Sem estado próprio: todo o resultado sai de `(monstro, posição, fluxo de
/// RNG)`. É o que permite a simulação offline gerar exatamente o mesmo loot que
/// o combate ao vivo geraria no mesmo intervalo (research.md R3) e o que fecha a
/// porta do save-scumming — reabrir o app não re-sorteia o drop.
class LootGenerator {
  const LootGenerator();

  /// Chance base de um monstro comum conceder item, antes do modificador.
  static const double baseDropChance = 0.35;

  /// Chance base de Essência. Uma ordem de grandeza abaixo da de item: a
  /// Essência é o insumo raro do Cubo (R-M04-12), não uma segunda moeda.
  static const double baseEssenceChance = 0.02;

  /// Rótulo do subfluxo de Essência. Ver [RngStream.substream] e R-M04-13.
  static const String essenceStreamLabel = 'essence';

  /// Peso relativo de cada degrau de raridade no sorteio. Cada degrau é ~4×
  /// mais raro que o anterior.
  static const double _rarityWeightDecay = 0.25;

  /// Avalia o drop de um monstro derrotado.
  ///
  /// Devolve `null` quando o sorteio falha — resultado válido e frequente
  /// (CEN-M04-E01). Com [guaranteed] (wave de boss, R-M04-11) o sorteio ainda é
  /// consumido, mas o resultado é ignorado: o fluxo de RNG precisa avançar do
  /// mesmo jeito com e sem boss, ou combate ao vivo e simulação offline
  /// divergiriam na primeira wave de boss.
  GameItem? rollDrop({
    required MonsterTemplate monster,
    required ProgressPosition position,
    required RngStream rng,
    required bool guaranteed,
    required DateTime now,
  }) {
    final dropped = rng.chance(baseDropChance * monster.dropChanceModifier);
    if (!dropped && !guaranteed) return null;

    // Monstro sem tabela de raridades não concede item nem quando o drop é
    // garantido: não há nada de que sortear (CEN-M04-008 no limite).
    if (monster.possibleRarities.isEmpty) return null;

    final rarity = _rollRarity(monster.possibleRarities, rng);
    final type = rng.pick(ItemType.values);

    return generate(
      type: type,
      rarity: rarity,
      itemLevel: ItemScaling.itemLevelFor(position),
      rng: rng,
      now: now,
    );
  }

  /// Constrói um item concreto. Separado de [rollDrop] porque o Cubo (M06)
  /// também gera itens, sem passar por tabela de monstro.
  GameItem generate({
    required ItemType type,
    required ItemRarity rarity,
    required int itemLevel,
    required RngStream rng,
    required DateTime now,
    AffixType? guaranteedAffix,
  }) {
    final id = _newId(rng);

    // A variância é sorteada antes dos sufixos, e não depois, para que dois
    // itens comparados com a mesma semente difiram só pelo que o teste isola —
    // raridade em CEN-M04-006, item level em CEN-M04-005.
    final variance =
        1.0 + (rng.nextDouble() * 2 - 1) * ItemScaling.baseStatVariance;

    final baseStat = GameNumber.fromDouble(
      ItemScaling.baseStatFor(
            itemLevel: itemLevel,
            rarityIndex: rarity.index,
          ) *
          variance,
    );

    return GameItem(
      id: id,
      type: type,
      rarity: rarity,
      itemLevel: itemLevel,
      baseStat: baseStat,
      affixes: _rollAffixes(
        rarity: rarity,
        itemLevel: itemLevel,
        rng: rng,
        guaranteedAffix: guaranteedAffix,
      ),
      droppedAt: now,
    );
  }

  /// Avalia o drop de Essência, em fluxo **independente** do de itens
  /// (R-M04-12, R-M04-13).
  ///
  /// A independência não é elegância: se os dois compartilhassem fluxo, ajustar
  /// a taxa de Essência em um patch de balanceamento mudaria todo o loot que o
  /// jogador receberia dali em diante, e o mesmo save produziria itens
  /// diferentes antes e depois da atualização.
  Essence? rollEssence({
    required MonsterTemplate monster,
    required ProgressPosition position,
    required RngStream rng,
    required DateTime now,
  }) {
    final stream = rng.substream(essenceStreamLabel);
    if (!stream.chance(baseEssenceChance * monster.essenceChanceModifier)) {
      return null;
    }
    return Essence(
      id: 'ess_${_newId(stream)}',
      // Sorteado na geração e imutável dali em diante (V-ES-04).
      guaranteedAffixType: stream.pick(AffixType.suffixPool),
      droppedAt: now,
    );
  }

  /// Sorteio ponderado dentro da tabela do monstro.
  ///
  /// Nunca sai da lista: é isso que impede um slime do Ato 1 de conceder um
  /// Cósmico (CEN-M04-008) e, por consequência, que qualquer promoção passe do
  /// teto de raridade (V-GI-03, CEN-M04-E03).
  ItemRarity _rollRarity(List<ItemRarity> possible, RngStream rng) {
    final lowest = possible
        .map((r) => r.index)
        .reduce((a, b) => a < b ? a : b);

    var total = 0.0;
    final weights = <double>[];
    for (final rarity in possible) {
      var w = 1.0;
      for (var i = lowest; i < rarity.index; i++) {
        w *= _rarityWeightDecay;
      }
      weights.add(w);
      total += w;
    }

    var roll = rng.nextDouble() * total;
    for (var i = 0; i < possible.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return possible[i];
    }
    return possible.last;
  }

  /// 0 a 3 sufixos, sem repetir `affixType` (V-GI-01, CEN-M04-004).
  List<ItemAffix> _rollAffixes({
    required ItemRarity rarity,
    required int itemLevel,
    required RngStream rng,
    AffixType? guaranteedAffix,
  }) {
    final min = AffixTable.minAffixes(rarity);
    final max = AffixTable.maxAffixes(rarity);
    var count = min + rng.nextInt(max - min + 1);
    if (guaranteedAffix != null && count < 1) count = 1;

    final pool = [...AffixType.suffixPool];
    final chosen = <AffixType>[];

    if (guaranteedAffix != null) {
      pool.remove(guaranteedAffix);
      chosen.add(guaranteedAffix);
    }

    while (chosen.length < count && pool.isNotEmpty) {
      chosen.add(pool.removeAt(rng.nextInt(pool.length)));
    }

    return [
      for (final type in chosen)
        ItemAffix(
          affixType: type,
          value: GameNumber.fromDouble(
            AffixTable.rangeFor(
              type: type,
              rarity: rarity,
              itemLevel: itemLevel,
            ).at(rng.nextDouble()),
          ),
        ),
    ];
  }

  /// Identificador do item, derivado do próprio fluxo determinístico.
  ///
  /// 60 bits de sorteio: a chance de colisão dentro de uma vida de save é
  /// desprezível, e como sai do RNG persistido, dois aparelhos reprocessando o
  /// mesmo intervalo geram o mesmo ID em vez de duplicar o item (CEN-M10-E03).
  String _newId(RngStream rng) {
    final hi = rng.nextInt(1 << 30);
    final lo = rng.nextInt(1 << 30);
    return '${hi.toRadixString(36)}${lo.toRadixString(36)}';
  }
}
