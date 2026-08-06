import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';
import '../../domain/entities/entitlements.dart';
import '../../domain/entities/essence.dart';
import '../../domain/entities/game_item.dart';
import '../../domain/entities/hero.dart';
// `CubeBlueprint` mora junto de `Inventory`, que é o agregado que o contém.
import '../../domain/entities/inventory.dart';
import '../../domain/entities/player_account.dart';
import '../../domain/entities/progress_position.dart';
import '../../domain/entities/save_state.dart';

/// Serialização do estado persistido, conforme
/// contracts/persistence-save-schema.md.
///
/// Escrita à mão de propósito: `hive_generator` está abandonado desde 2023 e é
/// incompatível com o `analyzer` atual. Como o contrato define um documento
/// JSON explícito e o inventário tem teto de 50 itens, `TypeAdapter` gerado não
/// traria ganho — e mapas planos deixam as migrações (D-01..D-07) triviais.
abstract final class SaveCodec {
  // ---------------------------------------------------------------- GameNumber

  /// Toda grandeza escalável é gravada como par mantissa/expoente, **nunca**
  /// como inteiro (research.md R6).
  static Map<String, dynamic> encodeNumber(GameNumber n) => {
    'm': n.mantissa,
    'e': n.exponent,
  };

  /// Aceita também um número JSON simples, tratando-o como `{m: valor, e: 0}` —
  /// tolerância declarada no contrato para saves anteriores à migração.
  static GameNumber decodeNumber(Object? raw) {
    if (raw == null) return GameNumber.zero;
    if (raw is num) return GameNumber.fromDouble(raw.toDouble());
    if (raw is Map) {
      final m = (raw['m'] as num?)?.toDouble() ?? 0.0;
      final e = (raw['e'] as num?)?.toInt() ?? 0;
      return GameNumber(m, e);
    }
    return GameNumber.zero;
  }

  // ---------------------------------------------------------------- GameItem

  static Map<String, dynamic> encodeItem(GameItem item) => {
    'id': item.id,
    'type': item.type.id,
    'rarity': item.rarity.id,
    'itemLevel': item.itemLevel,
    'baseStat': encodeNumber(item.baseStat),
    'affixes': [
      for (final a in item.affixes)
        {'affixType': a.affixType.id, 'value': encodeNumber(a.value)},
    ],
    'isFavorited': item.isFavorited,
    'droppedAt': item.droppedAt.millisecondsSinceEpoch,
  };

  static GameItem decodeItem(Map<dynamic, dynamic> raw) {
    final affixesRaw = (raw['affixes'] as List?) ?? const [];
    final seen = <AffixType>{};
    final affixes = <ItemAffix>[];
    for (final a in affixesRaw) {
      final map = a as Map;
      final type = AffixType.fromId(map['affixType'] as String? ?? '');
      // V-GI-01: sufixo repetido em save adulterado é descartado, não duplicado.
      if (!seen.add(type)) continue;
      if (affixes.length >= GameItem.maxAffixes) break;
      affixes.add(
        ItemAffix(affixType: type, value: decodeNumber(map['value'])),
      );
    }
    return GameItem(
      id: raw['id'] as String,
      type: ItemType.fromId(raw['type'] as String? ?? ''),
      rarity: ItemRarity.fromId(raw['rarity'] as String? ?? ''),
      itemLevel: (raw['itemLevel'] as num?)?.toInt() ?? 1,
      baseStat: decodeNumber(raw['baseStat']),
      affixes: affixes,
      isFavorited: raw['isFavorited'] as bool? ?? false,
      droppedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['droppedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  // ---------------------------------------------------------------- Essence

  static Map<String, dynamic> encodeEssence(Essence e) => {
    'id': e.id,
    'guaranteedAffixType': e.guaranteedAffixType.id,
    'droppedAt': e.droppedAt.millisecondsSinceEpoch,
  };

  static Essence decodeEssence(Map<dynamic, dynamic> raw) => Essence(
    id: raw['id'] as String,
    guaranteedAffixType: AffixType.fromId(
      raw['guaranteedAffixType'] as String? ?? '',
    ),
    droppedAt: DateTime.fromMillisecondsSinceEpoch(
      (raw['droppedAt'] as num?)?.toInt() ?? 0,
    ),
  );

  // ---------------------------------------------------------------- Blueprint

  static Map<String, dynamic> encodeBlueprint(CubeBlueprint b) => {
    'id': b.id,
    // Referência histórica: pode apontar para um item já vendido, e é isso que
    // faz o molde sobreviver à venda da origem (V-CB-01, CEN-M05-E03).
    'sourceItemId': b.sourceItemId,
    'type': b.type.id,
    'targetAffixTypes': [for (final a in b.targetAffixTypes) a.id],
  };

  static CubeBlueprint decodeBlueprint(Map<dynamic, dynamic> raw) =>
      CubeBlueprint(
        id: raw['id'] as String,
        sourceItemId: raw['sourceItemId'] as String? ?? '',
        type: ItemType.fromId(raw['type'] as String? ?? ''),
        targetAffixTypes: [
          for (final a in (raw['targetAffixTypes'] as List?) ?? const [])
            AffixType.fromId(a as String),
        ],
      );

  // ---------------------------------------------------------------- Hero

  static Map<String, dynamic> encodeHero(Hero hero) => {
    'id': hero.id,
    'heroClass': hero.classId,
    'level': hero.level,
    'xp': encodeNumber(hero.xp),
    'equipment': {
      for (final entry in hero.equipment.entries) entry.key.id: entry.value,
    },
    'unlockedSkillIds': hero.unlockedSkillIds,
    'formationIndex': hero.formationIndex,
  };

  static Hero decodeHero(Map<dynamic, dynamic> raw) {
    final equipRaw = (raw['equipment'] as Map?) ?? const {};
    final equipment = <ItemType, String?>{
      for (final t in ItemType.values) t: equipRaw[t.id] as String?,
    };
    return Hero(
      id: raw['id'] as String,
      classId: raw['heroClass'] as String? ?? '',
      level: (raw['level'] as num?)?.toInt() ?? 1,
      xp: decodeNumber(raw['xp']),
      equipment: equipment,
      unlockedSkillIds: ((raw['unlockedSkillIds'] as List?) ?? const [])
          .cast<String>(),
      formationIndex: (raw['formationIndex'] as num?)?.toInt(),
    );
  }

  // ---------------------------------------------------------------- Account

  static Map<String, dynamic> encodeAccount(PlayerAccount a) => {
    'accountLevel': a.accountLevel,
    'accountXp': encodeNumber(a.accountXp),
    'gold': encodeNumber(a.gold),
    'gems': a.gems,
    'runePoints': a.runePoints,
    'unlockedRuneNodeIds': a.unlockedRuneNodeIds.toList(),
    'respecCount': a.respecCount,
    'formationSlots': a.formationSlots,
    'fourthSlotSource': a.fourthSlotSource.id,
    'highestWave': a.highestWave,
    'highestAct': a.highestAct,
    'highestDifficulty': a.highestDifficulty,
    'currentPosition': {
      'difficulty': a.currentPosition.difficulty,
      'act': a.currentPosition.act,
      'wave': a.currentPosition.wave,
    },
    'rngSeed': a.rngSeed,
    'rngCounter': a.rngCounter,
    // Acrescentado em US4. Save anterior sem a chave decodifica como zero, que
    // é o comportamento correto: sem taxa apurada, não há ouro offline.
    'goldPerSecond': encodeNumber(a.goldPerSecond),
  };

  static PlayerAccount decodeAccount(
    Map<dynamic, dynamic> raw,
    DateTime lastSaveAt,
  ) {
    final posRaw = (raw['currentPosition'] as Map?) ?? const {};
    final source = FourthSlotSource.fromId(
      raw['fourthSlotSource'] as String? ?? 'none',
    );
    // D-03: discordância entre os dois campos resolve a favor de
    // fourthSlotSource, que carrega a informação de *como* o slot foi obtido.
    final slots = source == FourthSlotSource.none
        ? PlayerAccount.baseFormationSlots
        : PlayerAccount.maxFormationSlots;

    return PlayerAccount(
      accountLevel: (raw['accountLevel'] as num?)?.toInt() ?? 1,
      accountXp: decodeNumber(raw['accountXp']),
      gold: decodeNumber(raw['gold']),
      gems: (raw['gems'] as num?)?.toInt() ?? 0,
      runePoints: (raw['runePoints'] as num?)?.toInt() ?? 0,
      unlockedRuneNodeIds: ((raw['unlockedRuneNodeIds'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      respecCount: (raw['respecCount'] as num?)?.toInt() ?? 0,
      formationSlots: slots,
      fourthSlotSource: source,
      highestWave: (raw['highestWave'] as num?)?.toInt() ?? 1,
      highestAct: (raw['highestAct'] as num?)?.toInt() ?? 1,
      highestDifficulty: (raw['highestDifficulty'] as num?)?.toInt() ?? 1,
      // D-07: posição fora dos limites satura em vez de lançar.
      currentPosition: ProgressPosition.clamped(
        difficulty: (posRaw['difficulty'] as num?)?.toInt() ?? 1,
        act: (posRaw['act'] as num?)?.toInt() ?? 1,
        wave: (posRaw['wave'] as num?)?.toInt() ?? 1,
      ),
      lastSaveAt: lastSaveAt,
      rngSeed: (raw['rngSeed'] as num?)?.toInt() ?? 0,
      rngCounter: (raw['rngCounter'] as num?)?.toInt() ?? 0,
      goldPerSecond: decodeNumber(raw['goldPerSecond']),
    );
  }

  // ---------------------------------------------------------------- Entitlements

  static Map<String, dynamic> encodeEntitlements(Entitlements e) => {
    'adsRemoved': e.adsRemoved,
    'ownedDlcClassIds': e.ownedDlcClassIds.toList(),
    'goldBoostExpiresAt': e.goldBoostExpiresAt?.millisecondsSinceEpoch,
    'extraCubeSlots': e.extraCubeSlots,
    'actTransitionsSinceInterstitial': e.actTransitionsSinceInterstitial,
  };

  static Entitlements decodeEntitlements(Map<dynamic, dynamic> raw) {
    final expiresRaw = (raw['goldBoostExpiresAt'] as num?)?.toInt();
    return Entitlements(
      adsRemoved: raw['adsRemoved'] as bool? ?? false,
      ownedDlcClassIds: ((raw['ownedDlcClassIds'] as List?) ?? const [])
          .cast<String>()
          .toSet(),
      goldBoostExpiresAt: expiresRaw == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(expiresRaw),
      extraCubeSlots: (raw['extraCubeSlots'] as num?)?.toInt() ?? 0,
      actTransitionsSinceInterstitial:
          (raw['actTransitionsSinceInterstitial'] as num?)?.toInt() ?? 0,
    );
  }

  // ---------------------------------------------------------------- Root

  static Map<String, dynamic> encodeSave(SaveState state) => {
    'schemaVersion': state.schemaVersion,
    'lastSaveTimestamp': state.account.lastSaveAt.millisecondsSinceEpoch,
    'lastMonotonicMillis': state.lastMonotonicMillis,
    'playerAccount': encodeAccount(state.account),
    'entitlements': encodeEntitlements(state.entitlements),
    'heroes': [for (final h in state.heroes) encodeHero(h)],
    'equippedItems': [for (final i in state.equippedItems) encodeItem(i)],
    'items': [for (final i in state.inventory.items) encodeItem(i)],
    'pendingDrops': [
      for (final i in state.inventory.pendingDrops) encodeItem(i),
    ],
    'essences': [
      for (final e in state.inventory.essences) encodeEssence(e),
    ],
    'blueprints': [
      for (final b in state.inventory.blueprints) encodeBlueprint(b),
    ],
  };

  static SaveState decodeSave(Map<dynamic, dynamic> raw) {
    final lastSaveAt = DateTime.fromMillisecondsSinceEpoch(
      (raw['lastSaveTimestamp'] as num?)?.toInt() ?? 0,
    );
    return SaveState(
      schemaVersion: (raw['schemaVersion'] as num?)?.toInt() ?? 1,
      account: decodeAccount(
        (raw['playerAccount'] as Map?) ?? const {},
        lastSaveAt,
      ),
      entitlements: decodeEntitlements(
        (raw['entitlements'] as Map?) ?? const {},
      ),
      heroes: [
        for (final h in (raw['heroes'] as List?) ?? const [])
          decodeHero(h as Map),
      ],
      equippedItems: [
        for (final i in (raw['equippedItems'] as List?) ?? const [])
          decodeItem(i as Map),
      ],
      inventory: Inventory(
        items: [
          for (final i in (raw['items'] as List?) ?? const [])
            decodeItem(i as Map),
        ],
        pendingDrops: [
          for (final i in (raw['pendingDrops'] as List?) ?? const [])
            decodeItem(i as Map),
        ],
        essences: [
          for (final e in (raw['essences'] as List?) ?? const [])
            decodeEssence(e as Map),
        ],
        blueprints: [
          for (final b in (raw['blueprints'] as List?) ?? const [])
            decodeBlueprint(b as Map),
        ],
      ),
      lastMonotonicMillis:
          (raw['lastMonotonicMillis'] as num?)?.toInt() ?? 0,
    );
  }
}
