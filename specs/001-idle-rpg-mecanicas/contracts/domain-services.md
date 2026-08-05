# Contract — Serviços de Domínio

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04

Superfície pública do núcleo de domínio (`lib/domain/`), consumida pela camada de apresentação, pelos providers Riverpod e pelos serviços de plataforma. Assinaturas em Dart, ilustrativas quanto à forma, normativas quanto ao comportamento.

**Invariantes que valem para todos os serviços deste contrato:**

- **I-1 — Puros quanto a I/O**: nenhum serviço lê ou grava disco, rede ou preferências. Estado entra por parâmetro e sai por retorno.
- **I-2 — Determinísticos**: dados o mesmo estado de entrada, a mesma semente de RNG e o mesmo relógio injetado, a saída é idêntica (research R5). Nenhum serviço chama `DateTime.now()` nem `Random()` diretamente.
- **I-3 — Sem exceção para regra de negócio**: entrada inválida retorna um resultado de recusa tipado, não lança. Exceção fica reservada para invariante violada, que é bug.
- **I-4 — Não mutam a entrada**: retornam novo estado. Isso é o que permite descartar um resultado de simulação sem efeito colateral.

---

## Portas (implementadas fora do domínio)

```dart
abstract class Clock {
  DateTime now();               // relógio de parede
  int monotonicMillis();        // contador monotônico (research R7)
}

abstract class RngStream {
  int get counter;
  double nextDouble();
  int nextInt(int maxExclusive);
  RngStream fork(String label);  // subfluxo isolado; não avança o pai
}

abstract class SaveRepository {
  Future<SaveState?> load();
  Future<void> save(SaveState state);
}

abstract class ContentRepository {
  List<HeroClassDefinition> heroClasses();
  List<MonsterTemplate> monsters();
  RuneTreeDefinition runeTree();
}
```

`fork` existe para que loot, crítico e composição de wave consumam fluxos independentes. Sem isso, mudar a ordem de duas chamadas altera todo o loot subsequente e quebra a equivalência entre combate ao vivo e simulação offline.

---

## CombatEngine — M01, M02

```dart
class CombatEngine {
  CombatEngine({required RngStream rng, required RuneModifiers runes});

  CombatState startWave(ProgressPosition position, List<Hero> formation);

  CombatTickResult tick(CombatState state, Duration fixedStep);

  GameNumber resolveDamage({
    required Stats attacker, required Stats defender,
    required HeroClassDefinition attackerClass, required bool isCritical,
  });

  Duration timeToClearWave(CombatState state);   // usado por OfflineSimulator
}

class CombatTickResult {
  final CombatState state;
  final List<MonsterDefeated> defeats;   // dispara ouro, XP, avaliação de drop
  final List<HeroIncapacitated> downs;
  final List<HeroRevived> revives;
  final bool waveCleared;
}
```

**Comportamento normativo**

- `resolveDamage` = `ATK + bônus − DEF`, saturado em mínimo 1 (R-M01-03, CEN-M01-003); crítico multiplica por 2 (R-M01-05).
- `tick` avança em passo fixo, nunca no `dt` do render (research R10). Chamá-lo N vezes com passo P equivale a um intervalo de N×P.
- Herói incapacitado não ataca nem é alvo, e revive em 30 s (R-M01-06); com toda a formação caída, `waveCleared` nunca fica `true` e nenhum monstro é removido (CEN-M01-010).
- `timeToClearWave` é a mesma função de dano usada por `tick`. **Este é o ponto de acoplamento intencional que impede o offline de divergir do online** (research R3).

---

## LootGenerator — M04

```dart
class LootGenerator {
  GameItem? rollDrop({
    required MonsterTemplate monster, required ProgressPosition position,
    required RngStream rng, required bool guaranteed,
  });

  GameItem generate({
    required ItemType type, required ItemRarity rarity,
    required int itemLevel, required RngStream rng,
  });

  Essence? rollEssence({
    required MonsterTemplate monster, required ProgressPosition position,
    required RngStream rng,
  });
}
```

**Comportamento normativo**

- `guaranteed: true` (boss) sempre retorna item; caso contrário `null` é resultado válido (CEN-M04-E01).
- Raridade sorteada nunca excede `monster.possibleRarities` (CEN-M04-008) nem `cosmico` (V-GI-03).
- `itemLevel` = `f(wave, act) + 10 × (difficulty − 1)` (R-M04-05, R-M08-08).
- 0 a 3 afixos, sem repetição de `affixType` (V-GI-01).
- `rollEssence` consome um `fork` de RNG **independente** do de `rollDrop` (R-M04-13): o mesmo monstro pode conceder item e Essência, um só ou nenhum, e a presença de um não pode deslocar o sorteio do outro. Se compartilhassem fluxo, mudar a taxa de Essência alteraria todo o loot subsequente.

---

## InventoryService — M05

```dart
class InventoryService {
  EquipResult equip(Hero hero, GameItem item, Inventory inv);
  UnequipResult unequip(Hero hero, ItemType slot, Inventory inv);
  IntakeResult intake(GameItem dropped, Inventory inv, List<Hero> heroes);
  SellResult sell(GameItem item, Inventory inv);
}

sealed class IntakeResult {
  // Stored(inv) | AutoSold(inv, soldItems, goldGained) | Pending(inv, reason)
}
```

```dart
extension on InventoryService {
  Inventory intakeEssence(Essence e, Inventory inv);  // nunca retorna Pending
  Inventory drainPending(Inventory inv);              // chamado a cada mudança de ocupação
}
```

**Comportamento normativo**

- `equip` em slot ocupado devolve o item anterior ao inventário; a contagem de slots não muda (CEN-M05-003).
- `intake` a 50 slots dispara auto-venda de bronze/prata não favoritados e não equipados (R-M05-06); sem candidatos, retorna `Pending` — jamais descarta (V-INV-03).
- Equipar item já equipado em outro herói o transfere (CEN-M05-E02).
- `intakeEssence` nunca falha por lotação: Essências ficam fora do limite de 50 slots (V-ES-01).
- `drainPending` devolve itens retidos ao inventário assim que abre espaço, e é invocado por `equip`, `sell`, pela auto-venda e pelo consumo no Cubo — não apenas no próximo drop (V-INV-04). Sem isso um item retido fica preso para sempre.

---

## ProgressionService — M03

```dart
class ProgressionService {
  XpResult grantHeroXp(Hero hero, GameNumber xp);        // múltiplos níveis de uma vez
  AccountXpResult grantAccountXp(PlayerAccount acc, GameNumber xp);
  SlotUnlockResult evaluateFourthSlot(PlayerAccount acc);
  PlayerAccount recordProgress(PlayerAccount acc, ProgressPosition reached);
}

sealed class SlotUnlockResult {
  // NoChange | Granted(account)               // nível 25, fourthSlotSource=accountLevel
  // AlreadyOwnedCompensated(account, gems)    // comprado antes; CEN-M03-012 / CEN-M12-015
}
```

**Comportamento normativo**

- `grantHeroXp` resolve múltiplos níveis em uma chamada, aplicando todos os ganhos de atributo e desbloqueios intermediários (CEN-M03-E01).
- `evaluateFourthSlot` é o único ponto que ramifica sobre `fourthSlotSource`; é chamado após toda subida de nível de conta e após toda restauração de compra.
- `recordProgress` é monotônico: nunca reduz um recorde (V-PA-03).

---

## WaveDirector — M08

```dart
class WaveDirector {
  List<Monster> spawnWave(ProgressPosition position, RngStream rng);
  bool isBossWave(int wave);                                   // wave % 10 == 0
  AdvanceResult advance(ProgressPosition current, PlayerAccount acc);
}

sealed class AdvanceResult {
  // NextWave(pos) | NextAct(pos) | DifficultyUnlocked(pos, newDifficulty)
}
```

**Comportamento normativo**

- Escalonamento por dificuldade: todos os atributos × `1.5^(difficulty−1)` (R-M08-08), em `GameNumber` (research R6).
- Concluir a wave 100 do ato 3 emite `DifficultyUnlocked` e reposiciona em dificuldade+1, ato 1, wave 1 (R-M08-10), preservando heróis, itens e runas (CEN-M08-009).
- Sem teto de dificuldade (R-M08-09).

---

## OfflineSimulator — M09

```dart
class OfflineSimulator {
  OfflineReport simulate({
    required SaveState state, required DateTime now,
    required CombatEngine combat, required LootGenerator loot,
  });
}
```

**Comportamento normativo**

- `elapsed = clamp(now − state.lastSaveAt, 0, 8h)` (R-M09-02, CEN-M09-E01/E02).
- Ouro por forma fechada: `goldPerSecond × elapsed × 0.8` (R-M09-03).
- Waves e loot por blocos amortizados usando `combat.timeToClearWave`, nunca tick a tick (research R3); quando o tempo por wave excede o restante, a progressão estagna sem morte permanente (CEN-M09-011).
- Loot passa por `InventoryService.intake`, respeitando capacidade e auto-venda (CEN-M09-007).
- Sem `lastSaveAt` (primeira abertura), retorna relatório vazio (CEN-M09-E03).
- **Orçamento**: ≤3 s para 8 h em dispositivo de entrada (SC-M09-01).

---

## CubeService — M06

```dart
class CubeService {
  FusionPreview preview(List<GameItem> materials, Essence? essence, CubeBlueprint? bp);
  FusionResult fuse(List<GameItem> materials, Essence?, CubeBlueprint?, Inventory, RngStream);
  CubeBlueprint imprint(GameItem source);
}

sealed class FusionResult {
  // Success(item, inventory) | Rejected(reason)
}
enum FusionRejection { notThreeItems, mixedRarities, maxRarity, itemEquipped }
```

**Comportamento normativo**

- Exatamente 3 materiais de raridade idêntica (R-M06-01); qualquer desvio retorna `Rejected` sem consumir nada (CEN-M06-003/004).
- Atributos totalmente re-rolados (R-M06-02); Essência garante um sufixo e é sempre consumida (R-M06-04/05).
- `preview` expõe a probabilidade de recriação por molde **antes** da confirmação (SC-M06-03).
- Operação atômica: ou os 3 materiais somem e o resultado existe, ou nada muda (CEN-M06-E03).

---

## RuneTreeService — M07

```dart
class RuneTreeService {
  UnlockResult unlock(String nodeId, PlayerAccount acc, RuneTreeDefinition tree);
  RespecResult respec(PlayerAccount acc, RuneTreeDefinition tree);
  GameNumber respecCost(int respecCount);
  RuneModifiers modifiersFor(Set<String> unlockedIds, RuneTreeDefinition tree);
}

enum UnlockRejection { notAdjacent, insufficientPoints, alreadyUnlocked }
```

**Comportamento normativo**

- Adjacência obrigatória, salvo nós raiz (R-M07-03, CEN-M07-003/E01).
- `respecCost` é estritamente crescente em `respecCount` (R-M07-08); ouro insuficiente recusa sem devolver pontos (CEN-M07-011).
- `modifiersFor` é agregação pura, recalculada a cada mudança — o que faz o respec durante combate ser seguro (CEN-M07-E03).

---

## EntitlementService — M12

```dart
class EntitlementService {
  Entitlements applyAdReward(Entitlements e, AdReward reward, DateTime now);
  bool shouldShowInterstitial(Entitlements e);
  Entitlements registerActTransition(Entitlements e);
  Entitlements applyPurchase(Entitlements e, PurchaseId id);
}

enum AdReward { goldBoost4h, instantRevive, extraCubeSlot }

sealed class GemSpendResult {
  // Applied(account, effect) | Rejected(insufficientGems)
}

abstract class GemSink {                       // FR-029
  GemSpendResult spendToRush(PlayerAccount acc, RushTarget target);
}
enum RushTarget { cubeOperation, runeRespec }
```

**Comportamento normativo**

- `goldBoost4h` com bônus ativo **estende a validade**; o percentual permanece +50% (V-ENT-01, CEN-M12-E02).
- `shouldShowInterstitial` só é `true` a cada 5 transições de ato e nunca com `adsRemoved` (R-M12-04/05).
- Recompensa só é aplicada após visualização completa; interrupção não concede nada e não consome recurso (CEN-M12-004).
- `applyPurchase(starterPack)` delega a `ProgressionService.evaluateFourthSlot` — não escreve `formationSlots` por conta própria, para não violar V-PA-02.
- `spendToRush` debita gemas e conclui a operação antes do tempo, **sem tocar no sorteio**: a distribuição de resultados de uma fusão acelerada é idêntica à da mesma fusão aguardada (V-ENT-04). Concretamente, o RNG é consumido na confirmação da operação, não na conclusão — do contrário gastar gemas mudaria o item obtido e viraria pay-to-win.
- Saldo insuficiente retorna `Rejected` sem debitar nem alterar a operação em curso.
- `AlreadyOwnedCompensated` credita 500 gemas (V-ENT-05).
