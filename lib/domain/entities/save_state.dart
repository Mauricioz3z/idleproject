import 'entitlements.dart';
import 'game_item.dart';
import 'hero.dart';
import 'inventory.dart';
import 'player_account.dart';

/// Estado completo persistido. Raiz do contrato de save
/// (contracts/persistence-save-schema.md).
///
/// [equippedItems] é separado de `inventory.items` de propósito: um item está
/// equipado **ou** livre, nunca nos dois (V-GI-04). É essa separação que a
/// invariante D-01 verifica na carga.
class SaveState {
  SaveState({
    required this.schemaVersion,
    required this.account,
    required this.entitlements,
    required List<Hero> heroes,
    required List<GameItem> equippedItems,
    required this.inventory,
    required this.lastMonotonicMillis,
  }) : heroes = List.unmodifiable(heroes),
       equippedItems = List.unmodifiable(equippedItems);

  factory SaveState.fresh({required DateTime now, required int seed}) =>
      SaveState(
        schemaVersion: currentSchemaVersion,
        account: PlayerAccount.fresh(now: now, seed: seed),
        entitlements: Entitlements.initial(),
        heroes: const [],
        equippedItems: const [],
        inventory: Inventory.empty(),
        lastMonotonicMillis: 0,
      );

  /// Sobe a cada mudança incompatível de formato.
  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final PlayerAccount account;
  final Entitlements entitlements;
  final List<Hero> heroes;

  /// Objetos dos itens atualmente equipados. `Hero.equipment` guarda só IDs.
  final List<GameItem> equippedItems;

  final Inventory inventory;

  /// Contador monotônico do último save, para detectar relógio alterado
  /// (research.md R7).
  final int lastMonotonicMillis;

  GameItem? equippedItemById(String id) {
    for (final i in equippedItems) {
      if (i.id == id) return i;
    }
    return null;
  }

  SaveState copyWith({
    PlayerAccount? account,
    Entitlements? entitlements,
    List<Hero>? heroes,
    List<GameItem>? equippedItems,
    Inventory? inventory,
    int? lastMonotonicMillis,
  }) => SaveState(
    schemaVersion: schemaVersion,
    account: account ?? this.account,
    entitlements: entitlements ?? this.entitlements,
    heroes: heroes ?? this.heroes,
    equippedItems: equippedItems ?? this.equippedItems,
    inventory: inventory ?? this.inventory,
    lastMonotonicMillis: lastMonotonicMillis ?? this.lastMonotonicMillis,
  );
}
