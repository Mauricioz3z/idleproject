# Contract — Schema de Save

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Mecânica**: [M10](../mechanics/M10-persistencia-salvamento.md)

Formato serializado do estado do jogador. É um contrato de compatibilidade: um save gravado por qualquer versão do app precisa continuar carregável pelas versões seguintes.

## Layout de armazenamento

Hive, quatro boxes. A separação existe para que o auto-save de 30 s grave apenas o que mudou, em vez de reserializar tudo.

| Box | Chave | Conteúdo |
|---|---|---|
| `meta` | `schemaVersion` | `int` |
| `meta` | `lastSaveTimestamp` | `int` — epoch ms |
| `meta` | `lastMonotonicMillis` | `int` — detecção de relógio (research R7) |
| `account` | `playerAccount` | Objeto `PlayerAccount` |
| `account` | `entitlements` | Objeto `Entitlements` |
| `heroes` | `heroes` | Lista de `Hero` (equipamento por ID) |
| `heroes` | `equippedItems` | Lista de `GameItem` atualmente equipados |
| `inventory` | `items` | Lista de `GameItem` não equipados |
| `inventory` | `pendingDrops` | Lista de `GameItem` retidos |
| `inventory` | `essences` | Lista de `Essence` — fora do limite de 50 slots |
| `inventory` | `blueprints` | Lista de `CubeBlueprint` |

## Codificação de `GameNumber`

Toda grandeza escalável é gravada como par mantissa/expoente, **nunca** como inteiro (research R6).

```json
{ "m": 1.234567890123, "e": 21 }
```

Regra: `m` em `[1,10)` ou exatamente `0`; `e == 0` quando `m == 0`. Um leitor que encontre um número JSON simples onde espera este objeto deve tratá-lo como `{m: valor, e: 0}` — tolerância para saves da v1 antes da migração.

## Documento raiz

```json
{
  "schemaVersion": 1,
  "lastSaveTimestamp": 1785600000000,
  "lastMonotonicMillis": 84321000,
  "playerAccount": {
    "accountLevel": 24,
    "accountXp": { "m": 4.2, "e": 6 },
    "gold": { "m": 8.31, "e": 14 },
    "gems": 500,
    "runePoints": 3,
    "unlockedRuneNodeIds": ["root_atk", "atk_02", "gold_01"],
    "respecCount": 2,
    "formationSlots": 3,
    "fourthSlotSource": "none",
    "highestWave": 143, "highestAct": 2, "highestDifficulty": 1,
    "currentPosition": { "difficulty": 1, "act": 2, "wave": 43 },
    "rngSeed": 8412739481273, "rngCounter": 918273,
    "goldPerSecond": { "m": 4.7, "e": 3 }
  },
  "entitlements": {
    "adsRemoved": false,
    "ownedDlcClassIds": [],
    "goldBoostExpiresAt": null,
    "extraCubeSlots": 0,
    "actTransitionsSinceInterstitial": 3
  },
  "heroes": [
    {
      "id": "h-9f2c", "heroClass": "vanguard", "level": 31,
      "xp": { "m": 2.7, "e": 5 },
      "equipment": { "weapon": "i-4a11", "armor": "i-7c02", "helmet": null,
                     "gloves": null, "boots": null, "amulet": null, "ring": null },
      "unlockedSkillIds": ["taunt", "aoe_reduction"],
      "formationIndex": 0
    }
  ],
  "equippedItems": [
    { "id": "i-4a11", "type": "weapon", "rarity": "epico", "itemLevel": 143,
      "baseStat": { "m": 3.4, "e": 4 },
      "affixes": [ { "affixType": "critChance", "value": { "m": 1.2, "e": 1 } } ],
      "isFavorited": true, "droppedAt": 1785599000000 }
  ],
  "items": [
    { "id": "i-8b30", "type": "ring", "rarity": "prata", "itemLevel": 140,
      "baseStat": { "m": 9.1, "e": 2 },
      "affixes": [],
      "isFavorited": false, "droppedAt": 1785599400000 }
  ],
  "pendingDrops": [],
  "essences": [
    { "id": "e-2f70", "guaranteedAffixType": "critChance", "droppedAt": 1785598000000 }
  ],
  "blueprints": []
}
```

> `heroes[].equipment` guarda apenas **IDs**; os objetos dos itens equipados vivem em `equippedItems`, separados de `items`. A armadilha a evitar é gravar o mesmo item nas duas listas: V-GI-04 exige que um item esteja equipado **ou** livre no inventário, nunca nos dois, e é isso que D-01 verifica na carga.

## Invariantes de desserialização

Verificadas ao carregar, antes de o estado alcançar o domínio:

- **D-01**: Nenhum ID de item aparece em mais de um lugar (inventário, equipamento de qualquer herói, drops pendentes).
- **D-02**: Todo ID em `equipment` existe; referência órfã é limpa para `null` e registrada.
- **D-03**: `formationSlots ∈ {3,4}` e concorda com `fourthSlotSource` (V-PA-02). Discordância resolve a favor de `fourthSlotSource`.
- **D-04**: `formationIndex` é único entre heróis e menor que `formationSlots`; conflito remove o herói excedente da formação.
- **D-05**: `items.length ≤ 50`; excedente vai para `pendingDrops` em vez de ser truncado.
- **D-06**: IDs de runa desconhecidos são descartados e os pontos correspondentes devolvidos (V-PA-05).
- **D-07**: `currentPosition` dentro dos limites (V-PP-01); fora, satura para o limite válido mais próximo.

> `currentPosition.wave` é **relativa ao ato** (1 a 100), enquanto `highestWave` é o valor **acumulado** entre atos (V-PP-04). No exemplo acima, ato 2 / wave 43 é o que o jogador vê como "Wave 143". Gravar 143 em `currentPosition.wave` faz D-07 saturar em 100 e move o jogador para trás — foi exatamente o que o teste de M10 pegou.

Toda correção aplicada por D-02 a D-07 é registrada em analytics. Correção silenciosa em massa é sinal de bug de gravação, e precisa ser visível.

## Gravação atômica

`specification.md` §4.5 fixa auto-save de 30 s e gravação em `onAppPause`. CEN-M10-007 exige que save corrompido nunca substitua save válido, o que a gravação direta em box não garante sozinha.

Protocolo: gravar no box sombra `*_pending` → `flush` → marcar `meta.committedVersion` → promover. Na carga, se `committedVersion` não bate com o conteúdo pendente, o pendente é descartado e o último commit válido é carregado.

Consequência para CEN-M10-E03 (duas instâncias): a promoção é a seção crítica; a última promoção vence e nenhum estado meio-gravado sobrevive. Sem duplicação de itens porque o RNG é semeado e contado (research R5) — reprocessar o mesmo intervalo reproduz o mesmo resultado, não gera loot novo.

## Migração de versão

- `schemaVersion` começa em 1 e sobe a cada mudança incompatível.
- Migrações são funções encadeadas `v(n) → v(n+1)` em `lib/data/migrations/`, aplicadas na ordem, cada uma com teste próprio.
- Migração nunca destrói dados que não sabe interpretar: campo desconhecido é preservado.
- Save com `schemaVersion` **maior** que o suportado (downgrade do app) não é aberto nem sobrescrito; o jogador é avisado. Sobrescrever aqui destrói o progresso de quem tem duas instalações.

**Campos acrescentados sem subir a versão**: um campo **novo e opcional**, cuja ausência tem um default correto, não é mudança incompatível e não exige migração. Foi o caso de `goldPerSecond` (US4): save gravado antes dele decodifica como zero, e zero é a resposta certa — sem taxa apurada não há ouro offline (R-M09-03). A regra vale só nesta direção: remover, renomear ou mudar o significado de um campo existente continua exigindo `v(n) → v(n+1)`.

## O que nunca é persistido

`currentHp`, temporizadores de revive, HP dos monstros, alvos, estado de wave parcial, `OfflineReport` já exibido, `xpToNext` e `effectiveStats`. Tudo derivado: a wave reinicia do começo (V-PP-03, CEN-M10-E01) e os heróis retornam com HP cheio.
