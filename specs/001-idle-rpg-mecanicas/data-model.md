# Phase 1 — Data Model: Mecânicas do Idle RPG

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Plan**: [plan.md](plan.md)

Modelo de domínio derivado de [spec.md](spec.md) e dos 12 arquivos em [mechanics/](mechanics/). Descreve entidades, campos, relações, regras de validação e transições de estado. A forma serializada está em [contracts/persistence-save-schema.md](contracts/persistence-save-schema.md); as assinaturas de operação, em [contracts/domain-services.md](contracts/domain-services.md).

Convenção: campos marcados **[persistido]** entram no save; **[derivado]** são recalculados em memória e nunca gravados; **[conteúdo]** vêm de assets estáticos e não do save.

---

## Objetos de valor

### GameNumber

Representação de grandeza sem teto (research R6). Substitui `int` em toda grandeza que escala com dificuldade.

| Campo | Tipo | Notas |
|---|---|---|
| `mantissa` | `double` | Normalizada em `[1, 10)`, ou exatamente `0` |
| `exponent` | `int` | Potência de 10 |

**Regras**

- **V-GN-01**: Após qualquer operação, o valor é renormalizado; `mantissa == 0` implica `exponent == 0`.
- **V-GN-02**: Grandezas de jogo nunca são negativas. Subtração que resultaria em negativo satura em zero — vale para ouro, HP e XP.
- **V-GN-03**: Contadores discretos (nível, wave, ato, dificuldade, slots, pontos de runa, contagem de itens) permanecem `int`; não usam este tipo.

### Stats

| Campo | Tipo | Origem |
|---|---|---|
| `str`, `dex`, `int_`, `vit`, `agi` | `GameNumber` | §4.3 |

Usado tanto por `Hero` quanto por `Monster`.

---

## Entidades de estado do jogador

### PlayerAccount

Raiz do progresso persistente. Uma instância por instalação.

| Campo | Tipo | Notas |
|---|---|---|
| `accountLevel` | `int` | **[persistido]** ≥ 1 |
| `accountXp` | `GameNumber` | **[persistido]** |
| `gold` | `GameNumber` | **[persistido]** |
| `gems` | `int` | **[persistido]** Moeda premium (M12) |
| `runePoints` | `int` | **[persistido]** Disponíveis, não gastos |
| `unlockedRuneNodeIds` | `Set<String>` | **[persistido]** Apenas IDs (research R8) |
| `respecCount` | `int` | **[persistido]** Base do custo crescente (R-M07-08) |
| `formationSlots` | `int` | **[persistido]** 3 ou 4 |
| `fourthSlotSource` | `enum` | **[persistido]** `none` \| `accountLevel` \| `purchase` |
| `highestWave` | `int` | **[persistido]** Monotônico |
| `highestAct` | `int` | **[persistido]** Monotônico |
| `highestDifficulty` | `int` | **[persistido]** Monotônico |
| `currentPosition` | `ProgressPosition` | **[persistido]** Onde o jogador está agora |
| `lastSaveAt` | `DateTime` | **[persistido]** Base do cálculo offline |
| `rngSeed`, `rngCounter` | `int` | **[persistido]** Fluxo determinístico (research R5) |

**Regras**

- **V-PA-01**: `formationSlots ∈ {3, 4}`. Nunca 5 — teto absoluto de R-M12-10.
- **V-PA-02**: `formationSlots == 4` ⟺ `fourthSlotSource != none`. Os dois campos não podem discordar.
- **V-PA-03**: `highestWave`, `highestAct` e `highestDifficulty` só aumentam (R-M03-08). Uma atualização que os reduziria é descartada, não aplicada.
- **V-PA-04**: `runePoints ≥ 0`. Desbloqueio com saldo insuficiente é recusado antes de debitar (CEN-M07-004).
- **V-PA-05**: `unlockedRuneNodeIds` só contém IDs existentes na árvore carregada; ID órfão após atualização de conteúdo é descartado e o ponto correspondente é devolvido.

> `fourthSlotSource` existe por causa de CEN-M03-012 e CEN-M12-015: ao atingir o nível 25, o jogo precisa distinguir quem já comprou o slot (recebe compensação) de quem não comprou (recebe o slot). Sem esse campo os dois casos são indistinguíveis.

### ProgressPosition

| Campo | Tipo | Notas |
|---|---|---|
| `difficulty` | `int` | ≥ 1 |
| `act` | `int` | 1..3 |
| `wave` | `int` | 1..100 |

**Regras**

- **V-PP-01**: `act ∈ [1,3]` e `wave ∈ [1,100]` (R-M08-01, R-M08-02).
- **V-PP-02**: `wave % 10 == 0` identifica wave de boss (R-M08-03).
- **V-PP-03**: A posição salva sempre aponta para o **início** de uma wave; waves parciais não são persistidas (CEN-M10-E01).
- **V-PP-04**: `wave` é **relativa ao ato** (1 a 100). O número que o jogador vê — "Wave 142 (Ato 2)", como em `specification.md` §4.6 — é acumulado: `globalWave = (act−1)×100 + wave`. Os dois não são a mesma grandeza, e confundi-los produz posições impossíveis como "wave 142 do ato 2". `highestWave` na conta guarda o valor **acumulado**, porque é um recorde que precisa ser comparável entre atos.

### Hero

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | **[persistido]** UUID |
| `heroClass` | `HeroClass` | **[persistido]** |
| `level` | `int` | **[persistido]** ≥ 1 |
| `xp` | `GameNumber` | **[persistido]** |
| `equipment` | `Map<ItemType, String?>` | **[persistido]** 7 slots → ID de item |
| `unlockedSkillIds` | `List<String>` | **[persistido]** Derivável do nível, gravado para auditoria |
| `formationIndex` | `int?` | **[persistido]** `null` = fora da formação |
| `currentHp` | `GameNumber` | **[derivado]** Restaurado cheio no boot |
| `reviveAtMs` | `int?` | **[derivado]** Alvo do temporizador de 30 s |
| `xpToNext` | `GameNumber` | **[derivado]** Função do nível |
| `effectiveStats` | `Stats` | **[derivado]** Base + nível + itens + runas |

**Regras**

- **V-H-01**: `formationIndex` não nulo é único entre heróis e está em `[0, formationSlots)`.
- **V-H-02**: Cada `ItemType` aparece no máximo uma vez em `equipment` (R-M05-02, CEN-M05-012).
- **V-H-03**: Um item só pode estar equipado em um herói por vez; equipar em outro remove do primeiro (CEN-M05-E02).
- **V-H-04**: `currentHp` nunca excede o HP máximo derivado, e nunca fica negativo.
- **V-H-05**: XP só é creditado a heróis com `formationIndex != null` (CEN-M03-005), inclusive incapacitados (CEN-M03-006).

**Transições de estado**

```
        dano letal                  30 s decorridos  |  anúncio de revive
ATIVO ─────────────► INCAPACITADO ──────────────────────────────────────► ATIVO
  ▲                    │                                                    │
  └────────────────────┘ (não ataca, não é alvo, ainda recebe XP)          HP cheio
```

`INCAPACITADO` não é terminal: não existe morte permanente (CEN-M01-010). O revive por anúncio (CEN-M12-002) apenas antecipa a mesma transição.

### GameItem

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | **[persistido]** UUID |
| `type` | `ItemType` | **[persistido]** 7 valores |
| `rarity` | `ItemRarity` | **[persistido]** 8 valores ordenados |
| `itemLevel` | `int` | **[persistido]** Escala com wave (R-M04-05) |
| `baseStat` | `GameNumber` | **[persistido]** Prefixo principal |
| `affixes` | `List<ItemAffix>` | **[persistido]** 0 a 3 |
| `isFavorited` | `bool` | **[persistido]** Protege da auto-venda |
| `droppedAt` | `DateTime` | **[persistido]** |

**Regras**

- **V-GI-01**: `affixes.length ∈ [0, 3]` e nenhum `affixType` se repete (CEN-M04-004).
- **V-GI-02**: O prefixo principal é coerente com o tipo — arma gera ATK, armadura gera DEF (CEN-M04-003).
- **V-GI-03**: Nenhuma operação promove raridade acima de `cosmico` (CEN-M04-E03, CEN-M06-E01).
- **V-GI-04**: Item equipado não conta para a capacidade de 50 slots e é inelegível para auto-venda (R-M05-05) e para material de cubo (R-M06-08).

**Transições de estado**

```
GERADO ──► INVENTÁRIO ◄──────────► EQUIPADO
              │  ▲
              │  └── desequipar
              ├──► VENDIDO (manual, ou auto-venda a 50 slots)
              └──► CONSUMIDO (material de fusão no cubo)
```

`VENDIDO` e `CONSUMIDO` são terminais. `EQUIPADO` e `CONSUMIDO` são mutuamente exclusivos por V-GI-04.

### ItemAffix

| Campo | Tipo | Notas |
|---|---|---|
| `affixType` | `enum` | `critChance`, `attackSpeed`, `fireResist`, ... |
| `value` | `GameNumber` | Escala com `itemLevel` e raridade |

### Inventory

Agregado, não entidade persistida isoladamente.

| Campo | Tipo | Notas |
|---|---|---|
| `items` | `List<GameItem>` | **[persistido]** Somente não equipados |
| `pendingDrops` | `List<GameItem>` | **[persistido]** Retidos por inventário cheio |
| `essences` | `List<Essence>` | **[persistido]** Fora do limite de 50 slots (V-ES-01) |

**Regras**

- **V-INV-01**: `items.length ≤ 50` (R-M05-01).
- **V-INV-02**: Ao atingir 50, a auto-venda remove itens `bronze` e `prata` não favoritados (R-M05-06); os demais permanecem.
- **V-INV-03**: Se a auto-venda não liberar espaço, o drop vai para `pendingDrops` e dispara notificação — nunca é descartado em silêncio (CEN-M04-E02, CEN-M05-E01).
- **V-INV-04**: `pendingDrops` é drenado para `items` assim que houver espaço. A drenagem é avaliada a cada mudança de ocupação — venda manual, auto-venda, equipar ou consumo no Cubo —, nunca só no próximo drop; do contrário um item retido ficaria preso indefinidamente.

### Essence

Consumível raro obtido por drop (R-M04-12), usado no Cubo para garantir um sufixo (R-M06-04).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | **[persistido]** UUID |
| `guaranteedAffixType` | `enum` | **[persistido]** Sufixo que a Essência garante |
| `droppedAt` | `DateTime` | **[persistido]** |

**Regras**

- **V-ES-01**: Essências **não** contam para o limite de 50 slots do inventário — são consumíveis, não equipamentos.
- **V-ES-02**: Uma Essência é consumida na fusão independentemente do resultado (R-M06-05); nunca é devolvida.
- **V-ES-03**: Nunca são vendidas automaticamente, favoritadas ou equipadas — as regras de M05 não se aplicam a elas.
- **V-ES-04**: `guaranteedAffixType` é sorteado na geração e é imutável.

**Transições de estado**

```
GERADA ──► INVENTÁRIO ──► CONSUMIDA (fusão no cubo)
```

`CONSUMIDA` é terminal.

### CubeBlueprint

Molde salvo pela função "Imprimir" (R-M06-06).

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | **[persistido]** |
| `sourceItemId` | `String` | **[persistido]** Referência histórica, pode apontar para item já vendido |
| `type` | `ItemType` | **[persistido]** |
| `targetAffixTypes` | `List<enum>` | **[persistido]** Combinação a recriar |

**Regras**

- **V-CB-01**: O molde sobrevive à venda do item de origem (CEN-M05-E03) — é cópia dos atributos, não referência viva.

### Entitlements

Estado de monetização (M12).

| Campo | Tipo | Notas |
|---|---|---|
| `adsRemoved` | `bool` | **[persistido]** |
| `ownedDlcClassIds` | `Set<String>` | **[persistido]** |
| `goldBoostExpiresAt` | `DateTime?` | **[persistido]** +50% por 4 h |
| `extraCubeSlots` | `int` | **[persistido]** |
| `actTransitionsSinceInterstitial` | `int` | **[persistido]** Contador de R-M12-04 |

**Regras**

- **V-ENT-01**: Ver bônus de ouro com um já ativo **estende a validade**, não soma percentual (CEN-M12-E02).
- **V-ENT-02**: `adsRemoved == true` suprime intersticiais e preserva recompensados (R-M12-05).
- **V-ENT-03**: Nenhum campo aqui pode ser pré-requisito de conteúdo de progressão (R-M12-01).
- **V-ENT-04**: Gemas aceleram operações do Cubo e o respec (FR-029) sem alterar o conjunto de resultados possíveis. Uma operação acelerada por gemas e a mesma operação aguardada produzem a mesma distribuição de resultados.
- **V-ENT-05**: A compensação por 4º slot já antecipado é de 500 gemas (R-M03-11, R-M12-11).

---

## Entidades de conteúdo (assets, não save)

### HeroClassDefinition **[conteúdo]**

| Campo | Tipo |
|---|---|
| `id`, `displayName` | `String` |
| `role` | `enum` |
| `primaryStats` | `List<enum>` |
| `targetingRule` | `enum` — `nearest` \| `lowestHp` (R-M01-02) |
| `uniqueMechanic` | `enum` — provocação, área, penetração, cura, sangramento, escala com HP |
| `baseStats`, `statGrowthPerLevel` | `Stats` |
| `skills` | `List<SkillDefinition>` com `unlockLevel` |

As 6 definições da tabela de M02. Classes de DLC entram por este mesmo mecanismo.

### MonsterTemplate **[conteúdo]**

| Campo | Tipo | Notas |
|---|---|---|
| `id`, `type` | `String`, `enum` | |
| `baseStats` | `Stats` | Antes de escalar |
| `possibleRarities` | `List<ItemRarity>` | Teto de raridade (CEN-M04-008) |
| `dropChanceModifier` | `double` | (CEN-M04-009) |
| `isBoss` | `bool` | |

Os atributos efetivos são derivados: `baseStats × f(wave, act) × 1.5^(difficulty−1)` (R-M08-06, R-M08-08).

### RuneNode **[conteúdo]**

| Campo | Tipo | Notas |
|---|---|---|
| `id` | `String` | Estável entre versões — o save referencia por ID |
| `cost` | `int` | Padrão 1 |
| `neighborIds` | `List<String>` | Arestas de adjacência |
| `isRoot` | `bool` | Dispensa adjacência |
| `effect` | `RuneEffect` | `(tipo, valor)` |

**Regras**

- **V-RN-01**: A árvore carregada tem ≥ 200 nós (R-M07-01); violação falha no boot, não em produção.
- **V-RN-02**: Adjacência é simétrica; toda aresta aparece nos dois nós.
- **V-RN-03**: Todo nó é alcançável a partir de algum `isRoot` — árvore desconexa é erro de conteúdo detectado em teste.

---

## Entidades transitórias

### OfflineReport **[derivado]**

Produzido por `OfflineSimulator`, exibido uma vez e descartado.

| Campo | Tipo |
|---|---|
| `elapsedSeconds` | `int` — já limitado a 28.800 |
| `wasCapped` | `bool` |
| `goldGained` | `GameNumber` |
| `xpGained` | `GameNumber` |
| `wavesAdvanced` | `int` |
| `itemsObtained` | `List<GameItem>` |
| `rareHighlights` | `List<GameItem>` — lendário ou superior |
| `levelUps` | `List<(heroId, from, to)>` |

**Regras**

- **V-OR-01**: `elapsedSeconds ≤ 28800` sempre (R-M09-02).
- **V-OR-02**: Delta negativo por relógio atrasado produz relatório vazio, nunca perda (CEN-M09-E02).

### CombatState **[derivado]**

HP corrente dos monstros, alvos, temporizadores de ataque e de revive, dano ao longo do tempo ativo. Nunca persistido — a wave reinicia do começo após reabertura (V-PP-03).

> **Nota sobre a entidade `Wave`**: [spec.md](spec.md) lista `Wave` entre as entidades-chave. Aqui ela é decomposta deliberadamente em duas, porque suas partes têm ciclos de vida opostos: **`ProgressPosition`** (qual wave, ato e dificuldade — persistido) e **`CombatState`** (o encontro em andamento — transitório, nunca gravado). Modelar `Wave` como uma entidade única levaria a persistir estado de combate parcial, o que contradiz V-PP-03 e CEN-M10-E01. A composição dos monstros de uma wave é derivada sob demanda por `WaveDirector.spawnWave` a partir de `MonsterTemplate` **[conteúdo]**.

---

## Mapa de relações

```
PlayerAccount 1─┬─* Hero ──*─1 HeroClassDefinition [conteúdo]
                │      └─0..7─► GameItem (equipado)
                ├─1─ Inventory ──┬─*─► GameItem (livre / pendente)
                │                └─*─► Essence (fora do limite de 50)
                ├─*─ CubeBlueprint
                ├─1─ Entitlements
                ├─*─► RuneNode [conteúdo] (por ID)
                └─1─ ProgressPosition ──► Wave ──*─ MonsterTemplate [conteúdo]
```

Um `GameItem` pertence ao inventário **ou** a um slot de herói, nunca aos dois — invariante V-GI-04, verificada na desserialização.

---

## Rastreabilidade

| Mecânica | Entidades principais |
|---|---|
| M01 Combate | Hero, Monster, CombatState |
| M02 Classes | HeroClassDefinition, Stats |
| M03 Progressão | Hero, PlayerAccount, `fourthSlotSource` |
| M04 Loot | GameItem, ItemAffix, MonsterTemplate, Essence |
| M05 Inventário | Inventory, GameItem |
| M06 Cubo | GameItem, Essence, CubeBlueprint |
| M07 Runas | RuneNode, `unlockedRuneNodeIds`, `respecCount` |
| M08 Atos | ProgressPosition, MonsterTemplate |
| M09 Offline | OfflineReport, `lastSaveAt`, `rngSeed` |
| M10 Persistência | Todas as **[persistido]** |
| M11 Widget | Projeção de PlayerAccount + ProgressPosition |
| M12 Monetização | Entitlements, `fourthSlotSource` |
