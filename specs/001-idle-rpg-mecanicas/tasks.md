---

description: "Task list for Mecânicas do Idle RPG"
---

# Tasks: Mecânicas do Idle RPG

**Input**: Design documents from `/specs/001-idle-rpg-mecanicas/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: INCLUÍDOS. Não é escolha arbitrária — [research.md](research.md) R9 define que cada cenário `CEN-Mxx-nnn` da spec vira um caso de teste nomeado pelo próprio ID, [plan.md](plan.md) assume testes antes da implementação nas tarefas de domínio, e [quickstart.md](quickstart.md) §6 lista `flutter test` verde como portão de conclusão da feature.

**Organization**: Tarefas agrupadas por user story, na ordem de prioridade de [spec.md](spec.md).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependência pendente)
- **[Story]**: US1–US7, rastreando a user story de origem
- Todo caminho de arquivo é relativo à raiz do repositório

## Path Conventions

Projeto Flutter único, conforme a Structure Decision de [plan.md](plan.md): domínio puro em `lib/domain/`, infraestrutura em `lib/data/` e `lib/services/`, render em `lib/presentation/`, testes headless em `test/domain/` e de plataforma em `integration_test/`.

## Mapa: user story → mecânica

| Story | Prioridade | Mecânicas | Cenários cobertos |
|---|---|---|---|
| US1 | P1 | [M01](mechanics/M01-combate-automatico.md), [M02](mechanics/M02-classes-de-herois.md), [M03](mechanics/M03-progressao-heroi-conta.md) | 45 |
| US2 | P1 | [M04](mechanics/M04-loot-procedural.md), [M05](mechanics/M05-inventario-equipamento.md) | 31 |
| US3 | P1 | [M08](mechanics/M08-atos-waves-dificuldades.md) | 15 |
| US4 | P2 | [M09](mechanics/M09-progressao-offline.md) | 15 |
| US5 | P2 | [M11](mechanics/M11-widget-notificacao.md) | 14 |
| US6 | P3 | [M06](mechanics/M06-cubo-crafting.md), [M07](mechanics/M07-arvore-de-runas.md) | 28 |
| US7 | P3 | [M12](mechanics/M12-monetizacao-recompensas.md) | 20 |
| Foundational | — | [M10](mechanics/M10-persistencia-salvamento.md) | 13 |

**Total: 181 cenários.** M10 é P1 mas bloqueia todas as stories, então vive na fase Foundational, sem rótulo de story.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Criar o projeto Flutter, que hoje não existe — o repositório só contém documentos.

- [x] T001 Rodar `flutter create --org com.pixelidle --platforms android .` na raiz e revisar os arquivos gerados, preservando `specification.md`, `.specify/`, `.claude/` e `specs/`; remover o contador de exemplo de `lib/main.dart`
- [x] T002 Declarar dependências de [plan.md](plan.md) em `pubspec.yaml` (flame, flutter_riverpod, hive, hive_flutter, flutter_local_notifications, flutter_foreground_task, home_widget, workmanager, google_mobile_ads, in_app_purchase, firebase_analytics, firebase_crashlytics) e dev_dependencies (test, flutter_test, integration_test, build_runner, hive_generator)
- [x] T003 Inicializar o repositório com `git init` e escrever `.gitignore` para Flutter/Android — o diretório ainda não é um repositório git, e o fluxo de trabalho deste plano pressupõe commits por tarefa
- [x] T004 [P] Configurar lint estrito em `analysis_options.yaml`, incluindo regra que proíbe importar Flutter/Flame dentro de `lib/domain/`
- [x] T005 [P] Fixar `minSdkVersion 24` e `targetSdkVersion 34` em `android/app/build.gradle`
- [x] T006 [P] Criar a árvore de diretórios de [plan.md](plan.md) em `lib/` (core, domain, data, presentation, services) com um `.gitkeep` por pasta
- [x] T007 [P] Criar a árvore de testes `test/domain/`, `test/data/`, `test/presentation/` e `integration_test/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Núcleo transversal do qual toda story depende — tipo numérico, RNG determinístico, relógio, entidades, persistência.

**⚠️ CRITICAL**: Nenhuma user story pode começar antes desta fase terminar. Ela também entrega M10 por inteiro.

### Núcleo transversal

- [x] T008 [P] Escrever testes de `GameNumber` em `test/domain/core/game_number_test.dart` cobrindo normalização V-GN-01, saturação em zero V-GN-02 e aritmética acima de 1e18
- [x] T009 Implementar `GameNumber` (mantissa + expoente) em `lib/core/numeric/game_number.dart` conforme [research.md](research.md) R6 — soma, subtração saturante, multiplicação, comparação
- [x] T010 [P] Implementar formatação abreviada (`1.2K`, `3.4M`, `5.6aa`) em `lib/core/numeric/number_format.dart`
- [x] T011 [P] Escrever testes de `RngStream` em `test/domain/core/rng_test.dart` provando reprodutibilidade por semente e isolamento de `fork`
- [x] T012 Implementar `RngStream` xorshift128+ com contador persistível e `fork(label)` em `lib/core/rng/rng_stream.dart` conforme [research.md](research.md) R5
- [x] T013 [P] Implementar porta `Clock` e `FakeClock` de teste em `lib/core/clock/clock.dart` e `test/support/fake_clock.dart` conforme [research.md](research.md) R7
- [x] T014 [P] Definir enums de conteúdo (`ItemType`, `ItemRarity` ordenada Bronze→Cósmico, `AffixType`, `HeroRole`, `TargetingRule`) em `lib/core/constants/game_enums.dart`

### Entidades compartilhadas

- [x] T015 [P] Implementar `Stats` e `ProgressPosition` com validações V-PP-01 e V-PP-02 em `lib/domain/entities/stats.dart` e `lib/domain/entities/progress_position.dart`
- [x] T016 [P] Implementar `GameItem` e `ItemAffix` com invariantes V-GI-01 a V-GI-03 em `lib/domain/entities/game_item.dart`
- [x] T017 [P] Implementar `Essence` com invariantes V-ES-01 a V-ES-04 em `lib/domain/entities/essence.dart`
- [x] T018 [P] Implementar `Hero` com invariantes V-H-01 a V-H-04 em `lib/domain/entities/hero.dart`
- [x] T019 Implementar `PlayerAccount` com invariantes V-PA-01 a V-PA-05, incluindo `formationSlots`, `fourthSlotSource` e `gems`, em `lib/domain/entities/player_account.dart`
- [x] T020 [P] Implementar `Entitlements` e `Inventory` (com `essences` fora do limite de 50 slots) em `lib/domain/entities/entitlements.dart` e `lib/domain/entities/inventory.dart`
- [x] T021 [P] Declarar as portas `SaveRepository` e `ContentRepository` em `lib/domain/ports/`, conforme [contracts/domain-services.md](contracts/domain-services.md)

### Conteúdo declarativo

- [x] T022 [P] Criar assets de conteúdo `assets/content/hero_classes.json`, `assets/content/monsters.json` e `assets/content/rune_tree.json`, e registrá-los em `pubspec.yaml`
- [x] T023 Implementar `ContentRepository` com validação no boot (≥200 nós V-RN-01, adjacência simétrica V-RN-02, alcançabilidade V-RN-03) em `lib/data/repositories/content_repository_impl.dart`

### Persistência — M10

- [x] T024 [P] Escrever testes de serialização round-trip em `test/data/serialization_test.dart`, incluindo codificação `{m,e}` de `GameNumber` e a lista `essences`
- [x] T025 [P] Escrever testes das invariantes de desserialização D-01 a D-07 em `test/data/deserialization_invariants_test.dart`
- [x] T026 [P] Escrever testes de M10 (CEN-M10-001 a 010, E01 a E03) em `test/data/m10_persistence_test.dart`
- [x] T027 Implementar DTOs e codecs versionados em `lib/data/dto/` conforme [contracts/persistence-save-schema.md](contracts/persistence-save-schema.md), com `equippedItems` separado de `items` e `essences` em box próprio
- [x] T028 Implementar `HiveSaveRepository` com os quatro boxes e gravação atômica via box sombra + `committedVersion` em `lib/data/repositories/hive_save_repository.dart` (CEN-M10-007)
- [x] T029 Implementar as verificações de desserialização D-01 a D-07 com registro em analytics em `lib/data/dto/save_validator.dart`
- [x] T030 Implementar o encadeamento de migrações `v(n)→v(n+1)` e a recusa de `schemaVersion` futuro em `lib/data/migrations/migration_runner.dart`
- [x] T031 Implementar auto-save de 30 s e gravação em `onAppPause` em `lib/services/save_scheduler.dart` (R-M10-01, R-M10-02)

### Esqueleto do app

- [x] T032 Implementar o shell do app com Riverpod e `ProviderScope` em `lib/main.dart` e `lib/app.dart`
- [x] T033 Implementar o `FlameGame` base com passo fixo desacoplado do render em `lib/presentation/game/idle_rpg_game.dart` conforme [research.md](research.md) R10

**Checkpoint**: Núcleo determinístico e persistência prontos. `flutter test test/data/` verde. As user stories podem começar.

---

## Phase 3: User Story 1 - Progredir sem tocar na tela (Priority: P1) 🎯 MVP

**Goal**: Heróis lutam sozinhos, derrotam monstros, ganham ouro e XP, sobem de nível e revivem — sem nenhuma entrada do jogador.

**Independent Test**: Iniciar partida nova, não tocar em nada por 3 minutos e verificar monstros derrotados, ouro acumulado, XP ganho e ao menos 1 wave completada.

### Tests for User Story 1 ⚠️

> Escrever primeiro e garantir que falham antes de implementar.

- [x] T034 [P] [US1] Testes de M01 combate (CEN-M01-001 a 013, E01, E02) em `test/domain/m01_combat_test.dart`
- [x] T035 [P] [US1] Testes do 4º slot em combate (CEN-M01-012, 012b, 012c) em `test/domain/m01_formation_test.dart`
- [x] T036 [P] [US1] Testes de M02 classes (CEN-M02-001 a 010, E01, E02) em `test/domain/m02_classes_test.dart`
- [x] T037 [P] [US1] Testes de M03 progressão (CEN-M03-001 a 014, E01, E02), incluindo a compensação de 500 gemas em CEN-M03-012, em `test/domain/m03_progression_test.dart`
- [x] T038 [P] [US1] Teste de determinismo independente de FPS (300 ticks de 33 ms ≡ 150 de 66 ms) em `test/domain/determinism_test.dart`

### Implementation for User Story 1

- [x] T039 [P] [US1] Implementar `HeroClassDefinition` e `SkillDefinition` com carregamento do asset em `lib/domain/entities/hero_class_definition.dart`
- [x] T040 [P] [US1] Popular `assets/content/hero_classes.json` com as 6 classes de [M02](mechanics/M02-classes-de-herois.md) — papel, atributos principais, regra de alvo, atributos base, crescimento por nível e habilidades com nível de desbloqueio
- [x] T041 [P] [US1] Implementar `Monster` e derivação de atributos a partir de `MonsterTemplate` em `lib/domain/entities/monster.dart`
- [x] T042 [P] [US1] Popular `assets/content/monsters.json` com os templates dos 3 atos e os bosses, incluindo `possibleRarities`, `dropChanceModifier` e `isBoss`
- [x] T043 [US1] Implementar `CombatEngine.resolveDamage` — `ATK + bônus − DEF` saturado em 1, crítico 2× (R-M01-03 a 05) em `lib/domain/engines/combat_engine.dart`
- [x] T044 [US1] Implementar seleção de alvo por `nearest` e `lowestHp`, com troca de alvo após morte, em `lib/domain/engines/targeting.dart`
- [x] T045 [US1] Implementar `CombatEngine.tick` em passo fixo retornando `CombatTickResult` conforme [contracts/domain-services.md](contracts/domain-services.md)
- [x] T046 [US1] Implementar incapacitação e revive automático de 30 s, sem estado de derrota permanente (R-M01-06, CEN-M01-010) em `lib/domain/engines/combat_engine.dart`
- [x] T047 [US1] Implementar `CombatEngine.timeToClearWave` — mesma função de dano do tick, exigida por US4 (`research.md` R3)
- [x] T048 [P] [US1] Implementar as 6 mecânicas únicas de classe (provocação, área elemental, penetração de DEF, cura + buff, sangramento, escala com HP) em `lib/domain/engines/class_mechanics.dart`
- [x] T049 [US1] Implementar `ProgressionService.grantHeroXp` com resolução de múltiplos níveis em uma chamada (CEN-M03-E01) em `lib/domain/progression/progression_service.dart`
- [x] T050 [US1] Implementar nível de conta, concessão de pontos de runa e `recordProgress` monotônico (V-PA-03) em `lib/domain/progression/progression_service.dart`
- [x] T051 [US1] Implementar `evaluateFourthSlot` com os três resultados `NoChange`, `Granted` e `AlreadyOwnedCompensated` creditando 500 gemas (CEN-M03-011 a 013, V-ENT-05) em `lib/domain/progression/formation_slots.dart`
- [x] T052 [P] [US1] Implementar `HeroComponent` e `MonsterComponent` com animações idle, ataque, hit e morte em `lib/presentation/game/components/`
- [x] T053 [P] [US1] Implementar `DamageNumberComponent` flutuante, distinguindo dano normal, crítico e cura, em `lib/presentation/game/components/damage_number_component.dart`
- [x] T054 [US1] Implementar os providers Riverpod que ligam `CombatEngine` à camada Flame em `lib/presentation/providers/combat_providers.dart`
- [x] T055 [US1] Implementar a tela de combate com HUD de ouro, XP, wave e formação em `lib/presentation/screens/combat_screen.dart`
- [x] T056 [US1] Ligar `CombatTickResult.defeats` à concessão de ouro e XP e ao auto-save em `lib/presentation/providers/combat_providers.dart`

**Checkpoint**: US1 funcional e demonstrável. O jogo já é um idle jogável — este é o MVP.

---

## Phase 4: User Story 2 - Ficar mais forte com o loot (Priority: P1)

**Goal**: Itens caem automaticamente, o jogador compara e equipa, e os atributos do herói sobem na hora.

**Independent Test**: Obter dois itens do mesmo slot com atributos diferentes, equipar o melhor e confirmar aumento do atributo e retorno do item anterior ao inventário.

### Tests for User Story 2 ⚠️

- [x] T057 [P] [US2] Testes de M04 loot (CEN-M04-001 a 013, E01 a E03), incluindo o drop de Essência em CEN-M04-013, em `test/domain/m04_loot_test.dart`
- [x] T058 [P] [US2] Testes de M05 inventário (CEN-M05-001 a 012, E01 a E03) e da drenagem de `pendingDrops` (V-INV-04) em `test/domain/m05_inventory_test.dart`
- [x] T059 [P] [US2] Teste de determinismo de loot — mesma semente produz a mesma sequência de itens, e a taxa de Essência não desloca o sorteio de itens (R-M04-13) — em `test/domain/determinism_test.dart`

### Implementation for User Story 2

- [x] T060 [US2] Implementar `LootGenerator.generate` com prefixo coerente ao tipo e 0–3 afixos sem repetição (V-GI-01, V-GI-02) em `lib/domain/engines/loot_generator.dart`
- [x] T061 [US2] Implementar `LootGenerator.rollDrop` respeitando `possibleRarities`, `dropChanceModifier` e o teto Cósmico em `lib/domain/engines/loot_generator.dart`
- [x] T062 [US2] Implementar `LootGenerator.rollEssence` em fluxo de RNG independente do de `rollDrop` (R-M04-12, R-M04-13) em `lib/domain/engines/loot_generator.dart`
- [x] T063 [US2] Implementar a curva de item level `f(wave, act) + 10 × (difficulty − 1)` em `lib/core/constants/scaling.dart`
- [x] T064 [P] [US2] Implementar a tabela de afixos por raridade e item level em `lib/core/constants/affix_table.dart`
- [x] T065 [US2] Implementar `InventoryService.equip` e `unequip` com devolução do item anterior e transferência entre heróis (CEN-M05-003, E02) em `lib/domain/inventory/inventory_service.dart`
- [x] T066 [US2] Implementar `intake` com auto-venda de bronze/prata não favoritados a 50 slots, retorno `Pending` sem descarte, `intakeEssence` sem limite de lotação e `drainPending` invocado a cada mudança de ocupação (V-INV-02 a 04, V-ES-01) em `lib/domain/inventory/inventory_service.dart`
- [x] T067 [US2] Implementar favoritar item e venda manual em `lib/domain/inventory/inventory_service.dart`
- [x] T068 [US2] Implementar o cálculo de atributos efetivos do herói — base + nível + itens + runas — em `lib/domain/entities/hero_stats_resolver.dart`
- [x] T069 [US2] Ligar `CombatTickResult.defeats` a `rollDrop`, `rollEssence` e `intake` em `lib/presentation/providers/loot_providers.dart`
- [x] T070 [P] [US2] Implementar `LootPopupComponent` com destaque visual para lendário+ em `lib/presentation/game/components/loot_popup_component.dart`
- [x] T071 [P] [US2] Implementar a tela de inventário com cor por raridade, grade de 50 slots e aba de Essências em `lib/presentation/screens/inventory_screen.dart`
- [x] T072 [US2] Implementar o comparador de item equipado versus item do inventário, com ganhos e perdas distinguíveis (CEN-M05-006), em `lib/presentation/widgets/item_comparison.dart`
- [x] T073 [US2] Implementar a tela de detalhe do herói com os 7 slots de equipamento em `lib/presentation/screens/hero_detail_screen.dart`

**Checkpoint**: US1 e US2 funcionam de forma independente. O laço de recompensa está fechado.

---

## Phase 5: User Story 3 - Avançar de wave, ato e dificuldade (Priority: P1)

**Goal**: Waves encadeiam sozinhas, bosses aparecem a cada 10, atos se sucedem e completar o Ato 3 desbloqueia a dificuldade seguinte.

**Independent Test**: Progredir até a wave 10, verificar o boss e o loot garantido, e confirmar atualização do recorde de maior wave.

### Tests for User Story 3 ⚠️

- [x] T074 [P] [US3] Testes de M08 (CEN-M08-001 a 012, E01 a E03) em `test/domain/m08_progression_test.dart`
- [x] T075 [P] [US3] Teste de escalonamento por dificuldade em `GameNumber` acima de 1e18, provando ausência de transbordo (`research.md` R6), em `test/domain/m08_scaling_test.dart`

### Implementation for User Story 3

- [x] T076 [US3] Implementar `WaveDirector.spawnWave` e `isBossWave` (wave % 10 == 0) em `lib/domain/engines/wave_director.dart`
- [x] T077 [US3] Implementar o escalonamento de monstros `baseStats × f(wave, act) × 1.5^(difficulty−1)` em `lib/core/constants/scaling.dart`
- [x] T078 [US3] Implementar `WaveDirector.advance` com os resultados `NextWave`, `NextAct` e `DifficultyUnlocked` em `lib/domain/engines/wave_director.dart`
- [x] T079 [US3] Implementar o reposicionamento em dificuldade+1 / ato 1 / wave 1 preservando heróis, itens e runas (R-M08-10, CEN-M08-009) em `lib/domain/engines/wave_director.dart`
- [x] T080 [US3] Implementar o drop garantido em wave de boss ligando `WaveDirector` a `LootGenerator.rollDrop(guaranteed: true)` em `lib/presentation/providers/wave_providers.dart`
- [x] T081 [US3] Implementar a seleção de ato e dificuldade já concluídos, sem regredir recordes (CEN-M08-011), em `lib/presentation/screens/act_select_screen.dart`
- [x] T082 [P] [US3] Implementar cenários visuais distintos por ato — Floresta, Caverna, Cidadela — em `lib/presentation/game/components/background_component.dart`
- [x] T083 [P] [US3] Implementar a apresentação visual de boss, distinta de monstro comum, em `lib/presentation/game/components/boss_component.dart`
- [x] T084 [US3] Implementar o HUD de ato, wave e dificuldade em tela única (SC-M08-02) em `lib/presentation/widgets/progress_hud.dart`

**Checkpoint**: As três stories P1 estão completas. O jogo tem laço de curto, médio e longo prazo.

---

## Phase 6: User Story 4 - Continuar progredindo com o app fechado (Priority: P2)

**Goal**: O jogador volta depois de horas e recebe um resumo do que aconteceu.

**Independent Test**: Salvar, fechar, avançar o relógio em 2 h, reabrir e conferir ouro ≈ `gps × 7200 × 0,8` com resumo exibido antes do retorno ao combate.

### Tests for User Story 4 ⚠️

- [x] T085 [P] [US4] Testes de M09 (CEN-M09-001 a 011, E01 a E04) em `test/domain/m09_offline_test.dart`
- [x] T086 [P] [US4] Teste de equivalência online ≡ offline — 1 h simulada produz o mesmo ouro, waves e loot que ticks equivalentes — em `test/domain/determinism_test.dart`
- [x] T087 [P] [US4] Teste de orçamento de desempenho: 8 h simuladas em ≤3 s no aparelho de referência de [plan.md](plan.md) (SC-M09-01) em `test/domain/m09_performance_test.dart`

### Implementation for User Story 4

- [x] T088 [US4] Implementar o cálculo de intervalo com teto de 8 h e delta negativo tratado como zero (R-M09-02, CEN-M09-E01, E02) em `lib/domain/engines/offline_simulator.dart`
- [x] T089 [US4] Implementar o ouro por forma fechada `gps × elapsed × 0,8` em `lib/domain/engines/offline_simulator.dart`
- [x] T090 [US4] Implementar o avanço de waves e XP por blocos amortizados usando `CombatEngine.timeToClearWave` (`research.md` R3) em `lib/domain/engines/offline_simulator.dart`
- [x] T091 [US4] Implementar a geração de loot offline passando por `InventoryService.intake`, com estagnação sem morte permanente (CEN-M09-007, 011), em `lib/domain/engines/offline_simulator.dart`
- [x] T092 [US4] Implementar a montagem de `OfflineReport` com ouro, XP, waves, itens, lendários+ e subidas de nível em `lib/domain/entities/offline_report.dart`
- [x] T093 [US4] Implementar a apuração e persistência de `goldPerSecond` no momento do save em `lib/domain/progression/gold_rate_tracker.dart`
- [x] T094 [US4] Implementar a detecção de relógio inconsistente por contador monotônico, com registro em analytics (`research.md` R7), em `lib/services/clock_guard.dart`
- [x] T095 [US4] Implementar a tela de resumo offline, bloqueando o retorno ao combate até ser dispensada (CEN-M09-005), em `lib/presentation/screens/offline_summary_screen.dart`
- [x] T096 [US4] Ligar a simulação offline ao boot do app e ao retorno de background em `lib/presentation/providers/offline_providers.dart`

**Checkpoint**: O jogo passa a recompensar ausência — o diferencial do gênero idle está funcionando.

---

## Phase 7: User Story 5 - Acompanhar o jogo sem abrir o app (Priority: P2)

**Goal**: Widget na tela inicial e notificação persistente mostram o estado do jogo sem abrir o app.

**Independent Test**: Adicionar o widget, deixar o app em segundo plano por 5 minutos, verificar atualização e confirmar que tocar nele abre a tela de combate.

### Tests for User Story 5 ⚠️

- [x] T097 [P] [US5] Testes da projeção do widget — mesma fórmula de M09, com teto de 8 h e penalidade de 0,8 — em `test/domain/m11_projection_test.dart`
- [x] T098 [P] [US5] Testes de integração de widget e notificação (CEN-M11-001 a 011, E01 a E03) em `integration_test/m11_widget_test.dart`

### Implementation for User Story 5

- [x] T099 [US5] Implementar a projeção de estado a partir de `(save, tempo decorrido)` em `lib/domain/engines/state_projector.dart` conforme [research.md](research.md) R4
- [x] T100 [US5] Implementar a escrita do payload plano `w_*`, incluindo `w_projectionBaseMs` e `w_goldPerSecRaw`, em `lib/services/home_widget_service.dart` conforme [contracts/platform-android.md](contracts/platform-android.md) §1
- [x] T101 [US5] Implementar o `AppWidgetProvider` Kotlin que projeta o valor no momento do desenho em `android/app/src/main/kotlin/com/pixelidle/widget/IdleStatusWidgetProvider.kt`
- [x] T102 [P] [US5] Implementar o layout do widget e o estado inicial neutro para quando não há save (CEN-M11-011) em `android/app/src/main/res/layout/widget_idle_status.xml`
- [x] T103 [US5] Implementar a notificação persistente com título, subtexto e as ações Abrir e Coletar Loot em `lib/services/notification_service.dart`
- [x] T104 [US5] Implementar os canais `idle_status`, `idle_loot` e `idle_inventory` e o pedido de `POST_NOTIFICATIONS` com degradação graciosa (CEN-M11-E01) em `lib/services/notification_service.dart`
- [x] T105 [US5] Implementar as tarefas WorkManager `refresh_widget` e `detect_rare_events` a 15 min, sem executar combate nem gravar save, em `lib/services/background_service.dart`
- [x] T106 [US5] Implementar a tarefa `foreground_status` de 1 min via `flutter_foreground_task` em `lib/services/background_service.dart`
- [x] T107 [US5] Implementar a opção de desativar a notificação persistente sem afetar progresso (CEN-M11-010) em `lib/presentation/screens/settings_screen.dart`
- [x] T108 [US5] Implementar os deep links `pixelidle://combat`, `://offline-summary` e `://inventory` em `lib/app.dart`
- [x] T109 [US5] Declarar permissões e o serviço em primeiro plano em `android/app/src/main/AndroidManifest.xml` conforme [contracts/platform-android.md](contracts/platform-android.md) §6, sem `SCHEDULE_EXACT_ALARM`

**Checkpoint**: O diferencial declarado do produto está entregue, com a limitação de plataforma tratada por projeção em vez de escondida.

---

## Phase 8: User Story 6 - Aprofundar a build (Priority: P3)

**Goal**: Cubo converte itens em raridades superiores; árvore de runas dá passivas permanentes de conta.

**Independent Test**: Fundir 3 itens de mesma raridade e obter 1 da raridade superior com atributos re-rolados; separadamente, gastar 1 ponto de runa e confirmar o bônus valendo em combate.

### Tests for User Story 6 ⚠️

- [ ] T110 [P] [US6] Testes de M06 cubo (CEN-M06-001 a 010, E01 a E03) em `test/domain/m06_cube_test.dart`
- [ ] T111 [P] [US6] Testes de M07 runas (CEN-M07-001 a 012, E01 a E03) em `test/domain/m07_runes_test.dart`
- [ ] T112 [P] [US6] Teste de validação da árvore de conteúdo — ≥200 nós, adjacência simétrica, sem nó órfão (V-RN-01 a 03) — em `test/data/rune_tree_content_test.dart`

### Implementation for User Story 6

- [ ] T113 [US6] Implementar `CubeService.fuse` exigindo 3 materiais de raridade idêntica e recusando sem consumir (CEN-M06-003, 004) em `lib/domain/engines/cube_service.dart`
- [ ] T114 [US6] Implementar o re-roll completo de atributos e o teto Cósmico (R-M06-02, CEN-M06-E01) em `lib/domain/engines/cube_service.dart`
- [ ] T115 [US6] Implementar o consumo de `Essence` com sufixo garantido e consumo incondicional (R-M06-04, R-M06-05, V-ES-02) em `lib/domain/engines/cube_service.dart`
- [ ] T116 [US6] Implementar `imprint` e a recriação probabilística por molde, sobrevivendo à venda do item de origem (CEN-M05-E03), em `lib/domain/engines/cube_service.dart`
- [ ] T117 [US6] Implementar `preview` expondo a probabilidade antes da confirmação e a atomicidade da fusão, consumindo o RNG na confirmação (CEN-M06-E03, SC-M06-03, V-ENT-04), em `lib/domain/engines/cube_service.dart`
- [ ] T118 [US6] Implementar `RuneTreeService.unlock` com exigência de adjacência e nós raiz (R-M07-03) em `lib/domain/engines/rune_tree_service.dart`
- [ ] T119 [US6] Implementar `respecCost` estritamente crescente e `respec` que recusa sem ouro sem devolver pontos (CEN-M07-010, 011) em `lib/domain/engines/rune_tree_service.dart`
- [ ] T120 [US6] Implementar `modifiersFor` como agregação pura recalculada a cada mudança, segura durante combate (CEN-M07-E03), em `lib/domain/engines/rune_tree_service.dart`
- [ ] T121 [US6] Ligar `RuneModifiers` ao `CombatEngine` e às fórmulas de ouro e XP em `lib/domain/engines/combat_engine.dart`
- [ ] T122 [US6] Implementar efeitos de regra especial, como "primeiro ataque de cada wave é crítico" (CEN-M07-007), em `lib/domain/engines/rune_effects.dart`
- [ ] T123 [US6] Popular `assets/content/rune_tree.json` com 200+ nós em constelação, com efeitos de dano, ouro, XP e regras especiais
- [ ] T124 [P] [US6] Implementar a tela do Cubo com seleção de materiais, escolha de Essência, preview e confirmação obrigatória em `lib/presentation/screens/cube_screen.dart`
- [ ] T125 [P] [US6] Implementar a tela da árvore de runas com navegação em constelação, nós desbloqueáveis destacados e custo de respec visível em `lib/presentation/screens/rune_tree_screen.dart`

**Checkpoint**: Profundidade de build entregue. Todas as mecânicas de progressão estão completas.

---

## Phase 9: User Story 7 - Acelerar opcionalmente, sem nada bloqueado (Priority: P3)

**Goal**: Anúncios recompensados, gemas e compras aceleram o jogo sem bloquear nenhuma progressão.

**Independent Test**: Com conta que nunca pagou nem assistiu anúncio, verificar que waves, atos, dificuldades, raridades, nós de runa e o 4º slot permanecem alcançáveis.

### Tests for User Story 7 ⚠️

- [ ] T126 [P] [US7] Testes de M12 (CEN-M12-001 a 016, E01 a E04) em `test/domain/m12_monetization_test.dart`
- [ ] T127 [P] [US7] Teste de invariante anti-paywall — nenhum conteúdo de progressão exige `Entitlements` (V-ENT-03, SC-M12-01) — em `test/domain/m12_no_paywall_test.dart`
- [ ] T128 [P] [US7] Teste do caminho de restauração de compra que não gera quinto slot e credita 500 gemas (CEN-M12-015, V-PA-01, V-ENT-05) em `test/domain/m12_restore_test.dart`
- [ ] T129 [P] [US7] Teste de que acelerar com gemas não altera a distribuição de resultados (V-ENT-04, FR-029) em `test/domain/m12_gems_test.dart`

### Implementation for User Story 7

- [ ] T130 [US7] Implementar `EntitlementService.applyAdReward` com extensão de validade do bônus de ouro em vez de soma percentual (V-ENT-01) em `lib/domain/entitlements/entitlement_service.dart`
- [ ] T131 [US7] Implementar `shouldShowInterstitial` e `registerActTransition` — 1 a cada 5 transições, suprimido por `adsRemoved` — em `lib/domain/entitlements/entitlement_service.dart`
- [ ] T132 [US7] Implementar `applyPurchase` delegando o 4º slot a `evaluateFourthSlot`, sem escrever `formationSlots` diretamente (V-PA-02), em `lib/domain/entitlements/entitlement_service.dart`
- [ ] T133 [US7] Implementar `GemSink.spendToRush` com débito, recusa por saldo insuficiente e neutralidade sobre o sorteio (FR-029, V-ENT-04) em `lib/domain/entitlements/gem_sink.dart`
- [ ] T134 [US7] Ligar `spendToRush(cubeOperation)` à tela do Cubo, acelerando a conclusão sem alterar o resultado já sorteado (CEN-M12-008), em `lib/presentation/screens/cube_screen.dart`
- [ ] T135 [US7] Ligar `spendToRush(runeRespec)` ao respec, reduzindo tempo ou custo em ouro sem tornar nós inacessíveis (CEN-M12-009), em `lib/presentation/screens/rune_tree_screen.dart`
- [ ] T136 [US7] Implementar `AdService` com concessão apenas no callback de visualização completa e falha silenciosa sem rede (CEN-M12-004, E01) em `lib/services/ad_service.dart`
- [ ] T137 [US7] Implementar `IapService` com os product IDs de [contracts/platform-android.md](contracts/platform-android.md) §5 e restauração no boot em `lib/services/iap_service.dart`
- [ ] T138 [US7] Implementar o revive instantâneo por anúncio, cancelando o timer de 30 s (CEN-M12-002), em `lib/presentation/providers/combat_providers.dart`
- [ ] T139 [US7] Implementar o bônus de ouro de +50% por 4 h aplicado ao cálculo de ouro em combate e offline em `lib/domain/entitlements/gold_boost.dart`
- [ ] T140 [US7] Implementar o slot extra de cubo por anúncio em `lib/presentation/screens/cube_screen.dart`
- [ ] T141 [P] [US7] Implementar a loja com as ofertas de M12, saldo de gemas e tempo restante de bônus ativo em `lib/presentation/screens/store_screen.dart`

> **Fora de escopo desta feature** (R-M12-12): aplicação da skin exclusiva do Pacote de Início e desbloqueio de classes de DLC. T137 registra as compras; o conteúdo correspondente é pós-lançamento, conforme `specification.md` §6 Fase 5.

**Checkpoint**: Monetização completa e comprovadamente não bloqueante.

---

## Phase 10: Polish & Cross-Cutting Concerns

- [ ] T142 [P] Integrar Firebase Analytics e Crashlytics em `lib/services/analytics_service.dart`
- [ ] T143 [P] Substituir sprites placeholder por pixel art final em `assets/sprites/`, em sprite sheets únicos por classe e por tipo de monstro
- [ ] T144 Perfilar com `flutter run --profile` no aparelho de referência de [plan.md](plan.md) e garantir 30 FPS sustentados com 4 heróis e 8 monstros, ajustando `lib/presentation/game/idle_rpg_game.dart` conforme necessário
- [ ] T145 Converter `assets/sprites/` para WebP e verificar APK release < 30 MB por ABI via `flutter build apk --release --split-per-abi`
- [ ] T146 [P] Implementar tratamento de armazenamento cheio na gravação (CEN-M10-E02) em `lib/data/repositories/hive_save_repository.dart`
- [ ] T147 [P] Revisar formatação de números grandes em todas as telas usando `lib/core/numeric/number_format.dart`
- [ ] T148 Executar a validação manual V1 a V7 de [quickstart.md](quickstart.md) §4, incluindo a contagem de interações para equipar um item (SC-007) e a travessia da wave 1 à 100 do Ato 1 sem decisão obrigatória (SC-008)
- [ ] T149 Executar as verificações de determinismo de [quickstart.md](quickstart.md) §5
- [ ] T150 Rodar `flutter analyze` e zerar todos os avisos em `lib/` e `test/`, respeitando as regras de `analysis_options.yaml`
- [ ] T151 Percorrer o checklist anti-plágio de `specification.md` §9 antes de qualquer publicação

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Fase 1)**: sem dependências
- **Foundational (Fase 2)**: depende da Fase 1 — **bloqueia todas as user stories**
- **US1 (Fase 3)**: depende da Fase 2
- **US2 (Fase 4)**: depende da Fase 2; consome `CombatTickResult.defeats` de T056 para ligar drops ao combate
- **US3 (Fase 5)**: depende da Fase 2; o drop garantido de boss (T080) precisa de T061 de US2
- **US4 (Fase 6)**: depende de **T047** (`timeToClearWave`, US1) e de **T066** (`intake`, US2) — é a story com mais acoplamento real
- **US5 (Fase 7)**: depende da Fase 2 e de T093 (taxa de ouro, US4) para o payload; o restante é independente
- **US6 (Fase 8)**: depende da Fase 2; T115 precisa de T062 (`rollEssence`, US2) para ter Essências disponíveis; T121 integra com `CombatEngine` de US1
- **US7 (Fase 9)**: depende de T051 (`evaluateFourthSlot`, US1); T134 e T140 tocam a tela de Cubo de US6, T135 a tela de runas de US6, T138 a de combate de US1
- **Polish (Fase 10)**: depende das stories desejadas

### Dependências reais entre stories

A independência aqui não é total, e fingir o contrário produziria retrabalho. As arestas que existem de fato:

```
Foundational ──┬──► US1 ──┬──► US4   (timeToClearWave)
               │          ├──► US7   (evaluateFourthSlot)
               │          └──► US6   (integração de RuneModifiers)
               ├──► US2 ──┬──► US3   (drop garantido de boss)
               │          ├──► US4   (intake de loot offline)
               │          └──► US6   (rollEssence → fusão com Essência)
               ├──► US3
               ├──► US5 ◄── US4      (taxa de ouro para o payload)
               └──► US6 ◄── US7      (gemas nas telas de Cubo e runas)
```

US1, US2, US3 e US6 podem começar em paralelo assim que a Fase 2 fechar. US4 é a que mais espera.

### Within Each User Story

- Testes primeiro, falhando, antes da implementação
- Entidades antes de serviços; serviços antes de UI
- Domínio antes de plataforma

### Parallel Opportunities

- Fase 1: T004 a T007 em paralelo
- Fase 2: T008, T011, T013, T014 em paralelo; depois T015 a T022 em paralelo; testes T024 a T026 em paralelo
- Todo bloco de testes no início de cada story roda em paralelo
- Componentes visuais ([P]) são independentes da lógica de domínio da mesma story

---

## Parallel Example: User Story 1

```bash
# Testes de US1, todos juntos (devem falhar antes da implementação):
Task: "Testes de M01 combate em test/domain/m01_combat_test.dart"
Task: "Testes do 4º slot em test/domain/m01_formation_test.dart"
Task: "Testes de M02 classes em test/domain/m02_classes_test.dart"
Task: "Testes de M03 progressão em test/domain/m03_progression_test.dart"
Task: "Teste de determinismo por FPS em test/domain/determinism_test.dart"

# Entidades, conteúdo e componentes visuais de US1, em paralelo:
Task: "HeroClassDefinition em lib/domain/entities/hero_class_definition.dart"
Task: "Popular assets/content/hero_classes.json com as 6 classes"
Task: "Monster em lib/domain/entities/monster.dart"
Task: "Popular assets/content/monsters.json com templates e bosses"
Task: "Mecânicas únicas de classe em lib/domain/engines/class_mechanics.dart"
Task: "HeroComponent e MonsterComponent em lib/presentation/game/components/"
Task: "DamageNumberComponent em lib/presentation/game/components/damage_number_component.dart"
```

---

## Implementation Strategy

### MVP First (US1)

1. Fase 1: Setup
2. Fase 2: Foundational — inclui M10 por inteiro, é o trecho mais longo e bloqueia tudo
3. Fase 3: US1
4. **PARE E VALIDE**: cenário V1 de [quickstart.md](quickstart.md) — abrir, não tocar em nada por 5 minutos, ver progresso acontecer
5. Demonstrável: já é um idle jogável

### Incremental Delivery

1. Setup + Foundational → base determinística e persistente
2. + US1 → **MVP**: combate automático com progressão
3. + US2 → laço de recompensa fechado (loot e equipamento)
4. + US3 → estrutura de longo prazo (atos e dificuldades) — **fim do escopo P1**
5. + US4 → recompensa por ausência
6. + US5 → o diferencial do produto — **fim do escopo P2**
7. + US6 → profundidade de build
8. + US7 → monetização

Parar após o passo 4 entrega um jogo completo e coerente, sem offline e sem widget. Parar após o passo 6 entrega o produto descrito em `specification.md` §3.1.

### Parallel Team Strategy

Com Fase 2 concluída e três desenvolvedores: A em US1 (a mais pesada e a que mais desbloqueia), B em US2 seguido de US3, C em US6 (o mais isolado, exceto pela Essência que vem de T062). US4 espera A e B; US5 espera o começo de US4; US7 espera T051 de A.

---

## Notes

- `[P]` significa arquivos diferentes e sem dependência pendente
- Todo teste de domínio é nomeado pelo ID do cenário (`CEN-Mxx-nnn`), o que torna a cobertura por mecânica contável e liga a falha ao parágrafo exato da spec
- Verifique que os testes falham antes de implementar
- Commit por tarefa ou grupo lógico
- Pare em qualquer checkpoint para validar a story isoladamente
