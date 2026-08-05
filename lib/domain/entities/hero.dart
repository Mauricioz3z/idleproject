import '../../core/constants/game_enums.dart';
import '../../core/numeric/game_number.dart';

/// Um combatente controlado pelo sistema (M01, M02, M03).
///
/// Campos derivados ([currentHp], [reviveAtMs]) não são persistidos: heróis
/// retornam com HP cheio após reabertura, conforme
/// contracts/persistence-save-schema.md.
class Hero {
  Hero({
    required this.id,
    required this.classId,
    required this.level,
    required this.xp,
    required Map<ItemType, String?> equipment,
    required List<String> unlockedSkillIds,
    this.formationIndex,
    GameNumber? currentHp,
    this.reviveAtMs,
  }) : equipment = Map.unmodifiable(equipment),
       unlockedSkillIds = List.unmodifiable(unlockedSkillIds),
       currentHp = currentHp ?? GameNumber.zero;

  factory Hero.fresh({required String id, required String classId}) => Hero(
    id: id,
    classId: classId,
    level: 1,
    xp: GameNumber.zero,
    equipment: {for (final t in ItemType.values) t: null},
    unlockedSkillIds: const [],
  );

  final String id;

  /// Referência à `HeroClassDefinition` carregada do conteúdo.
  final String classId;

  final int level;
  final GameNumber xp;

  /// Um item por slot, no máximo (V-H-02). `null` significa slot vazio.
  final Map<ItemType, String?> equipment;

  final List<String> unlockedSkillIds;

  /// Posição na formação, ou `null` se fora dela.
  /// Só heróis com índice recebem XP (V-H-05).
  final int? formationIndex;

  /// **[derivado]** HP corrente. Restaurado cheio no boot.
  final GameNumber currentHp;

  /// **[derivado]** Instante-alvo do revive automático de 30 s, em milissegundos
  /// monotônicos. `null` quando o herói está ativo.
  final int? reviveAtMs;

  bool get isInFormation => formationIndex != null;

  /// Incapacitado não ataca e não é alvo — mas ainda recebe XP (CEN-M03-006).
  /// Nunca é estado terminal: não existe morte permanente (CEN-M01-010).
  bool get isIncapacitated => reviveAtMs != null;

  bool get isActive => isInFormation && !isIncapacitated;

  /// IDs dos itens equipados, sem nulos.
  Iterable<String> get equippedItemIds =>
      equipment.values.whereType<String>();

  Hero copyWith({
    int? level,
    GameNumber? xp,
    Map<ItemType, String?>? equipment,
    List<String>? unlockedSkillIds,
    int? formationIndex,
    bool clearFormationIndex = false,
    GameNumber? currentHp,
    int? reviveAtMs,
    bool clearReviveAt = false,
  }) => Hero(
    id: id,
    classId: classId,
    level: level ?? this.level,
    xp: xp ?? this.xp,
    equipment: equipment ?? this.equipment,
    unlockedSkillIds: unlockedSkillIds ?? this.unlockedSkillIds,
    formationIndex: clearFormationIndex
        ? null
        : (formationIndex ?? this.formationIndex),
    currentHp: currentHp ?? this.currentHp,
    reviveAtMs: clearReviveAt ? null : (reviveAtMs ?? this.reviveAtMs),
  );

  /// Equipa um item no slot correspondente, devolvendo o novo herói e o ID do
  /// item que estava no slot (`null` se vazio) — CEN-M05-003.
  (Hero, String?) equipItem(ItemType slot, String itemId) {
    final previous = equipment[slot];
    final next = Map<ItemType, String?>.from(equipment)..[slot] = itemId;
    return (copyWith(equipment: next), previous);
  }

  (Hero, String?) unequipSlot(ItemType slot) {
    final previous = equipment[slot];
    final next = Map<ItemType, String?>.from(equipment)..[slot] = null;
    return (copyWith(equipment: next), previous);
  }

  @override
  bool operator ==(Object other) => other is Hero && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
