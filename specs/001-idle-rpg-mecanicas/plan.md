# Implementation Plan: Mecânicas do Idle RPG

**Branch**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-idle-rpg-mecanicas/spec.md`

## Summary

Implementar as 12 mecânicas núcleo de um idle ARPG para Android: combate automático, classes, progressão de herói e conta, loot procedural, inventário, cubo de crafting, árvore de runas, atos/waves/dificuldades, progressão offline, persistência, widget/notificação e monetização.

A abordagem técnica central é **separar um núcleo de domínio em Dart puro, determinístico e headless, da camada de renderização Flame e da camada de plataforma Android**. Toda regra de combate, geração de loot, simulação offline e progressão vive nesse núcleo, sem depender de `dt` de render, de I/O ou de plugins. Isso é o que torna os 180 cenários Given-When-Then da spec testáveis diretamente como testes unitários, e é o que permite reaproveitar exatamente o mesmo código para o combate ao vivo e para a simulação offline — eliminando a classe de bug mais cara deste gênero, que é o jogo online e o jogo offline discordarem sobre o resultado.

Três decisões estruturais saem da pesquisa da Fase 0: (1) números de jogo usam representação de mantissa com expoente, não `int`, porque o escalonamento de dificuldade de ×1,5 sem teto estoura `int64` em algum ponto entre a dificuldade ~74 e ~108 conforme a base adotada (cálculo em `research.md` R6); (2) a simulação offline é fechada em forma analítica para ouro e por blocos amortizados para waves e loot, nunca tick a tick, para caber no orçamento de 3 segundos de SC-M09-01; (3) a atualização do widget a cada 1 minuto só é alcançável enquanto houver serviço em primeiro plano — fora dele o Android impõe piso de 15 minutos, e o widget passa a renderizar estado **projetado** a partir da fórmula determinística.

## Technical Context

**Language/Version**: Dart 3.11 / Flutter 3.41.2 (versões instaladas e verificadas em 2026-08-04)

**Primary Dependencies** — versões resolvidas pelo `pub`, não os pinos de `specification.md` §4.1, que eram de meados de 2024: `flame ^1.38.0`, `flutter_riverpod ^3.3.2`, `hive ^2.2.3` + `hive_flutter ^1.1.0`, `flutter_local_notifications ^22.2.0`, `flutter_foreground_task ^10.0.0`, `home_widget ^0.9.3`, `workmanager ^0.10.7`, `google_mobile_ads ^9.0.0`, `in_app_purchase ^3.3.0`, `firebase_core ^4.13.0`, `firebase_analytics ^12.4.6`, `firebase_crashlytics ^5.2.7`. O núcleo de domínio não depende de nenhuma delas.

**Geração de código**: nenhuma. `hive_generator` está abandonado desde 2023 e conflita com o `analyzer` atual; `build_runner` foi omitido junto. A serialização é manual em `lib/data/dto/save_codec.dart` — o contrato de save já define um documento JSON explícito, o inventário tem teto de 50 itens, e mapas planos tornam as migrações triviais. `TypeAdapter` gerado não traria ganho aqui.

**Storage**: Hive (key-value local, gravação fora da thread de UI). Backup em nuvem via Firestore fica fora do escopo desta feature.

**Testing**: `test` (Dart puro) para o núcleo de domínio — cobre a maioria dos 180 cenários; `flutter_test` para widgets e providers; `integration_test` para os fluxos de plataforma (widget de tela inicial, notificação, retomada offline).

**Target Platform**: Android API 24+ (Android 7.0), telas de 16:9 a 20:9.

**Aparelho de referência**: todo critério de desempenho desta feature é medido em um aparelho de entrada — **4 GB de RAM, SoC classe Snapdragon 400 / MediaTek Helio G, Android 10 (API 29)** — nunca no aparelho de desenvolvimento. Sem essa âncora, "≤3 s para 8 h de simulação" e "30 FPS sustentados" não são verificáveis de forma reproduzível.

**Project Type**: Aplicativo móvel Flutter, projeto único, com núcleo de domínio isolado em `lib/domain/`.

**Performance Goals**: 30 FPS sustentados durante combate com 4 heróis e até 8 monstros; resumo offline renderizado em ≤3 s para 8 h de ausência (SC-M09-01); auto-save sem frame drop perceptível (SC-M10-03); APK final < 30 MB.

**Constraints**: Combate real nunca executa em segundo plano (§8 de `specification.md`); perda máxima de 30 s de progresso (SC-M10-01); teto de 8 h de progresso offline resistente a manipulação de relógio (SC-M09-03); atualização de widget sujeita a piso de 15 min do WorkManager fora de serviço em primeiro plano (ver `research.md` R4).

**Scale/Scope**: 12 mecânicas, 180 cenários Given-When-Then, 3 atos × 100 waves × dificuldades ilimitadas, 6 classes, 7 tipos de item × 8 raridades, 200+ nós de runa, ~10 telas.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

**Estado da constituição**: `.specify/memory/constitution.md` está no estado de template não preenchido — todos os princípios são placeholders (`[PRINCIPLE_1_NAME]`, `[SECTION_2_CONTENT]`, etc.). **Não há princípios ratificados para avaliar.**

**Resultado do gate**: PASSA por vacância. Nenhuma violação pode ser apurada porque não há regra vigente contra a qual apurar.

Isso não é aprovação silenciosa: significa que este plano não tem nenhuma âncora de governança do projeto. Recomendo rodar `/speckit-constitution` antes de `/speckit-implement`, principalmente para fixar posição sobre disciplina de testes (este plano assume núcleo testável headless e escreve testes antes da implementação nas tarefas de domínio) e sobre limites de dependências externas. Se a constituição vier a contradizer alguma escolha deste plano, o plano é que cede.

**Re-avaliação pós-Fase 1**: sem alteração — continua PASSA por vacância. Nenhum artefato da Fase 1 introduz complexidade que exigiria justificativa perante princípios inexistentes. A tabela de Complexity Tracking permanece vazia por não haver violação a justificar.

## Project Structure

### Documentation (this feature)

```text
specs/001-idle-rpg-mecanicas/
├── spec.md              # Spec principal (umbrella)
├── mechanics/           # 12 arquivos de mecânica, 180 cenários GWT
├── checklists/
│   └── requirements.md
├── plan.md              # Este arquivo
├── research.md          # Fase 0
├── data-model.md        # Fase 1
├── quickstart.md        # Fase 1
├── contracts/           # Fase 1
│   ├── domain-services.md
│   ├── persistence-save-schema.md
│   └── platform-android.md
└── tasks.md             # Fase 2 (/speckit-tasks — não criado aqui)
```

### Source Code (repository root)

```text
lib/
├── main.dart
├── app.dart
├── core/                    # DART PURO — mesma regra do domínio
│   ├── constants/           # Raridades, tipos de item, curvas de escalonamento
│   ├── numeric/             # GameNumber (mantissa+expoente), formatação
│   ├── rng/                 # Rng determinístico com seed
│   └── clock/               # Clock — tempo monotônico e de parede
├── domain/                  # DART PURO — sem Flutter, sem Flame, sem I/O
│   ├── entities/            # Hero, GameItem, Essence, Monster, PlayerAccount, RuneNode
│   │   └── hero_stats_resolver.dart # Atributos efetivos: base + nível + itens + runas
│   ├── engines/
│   │   ├── combat_engine.dart       # M01, M02
│   │   ├── class_mechanics.dart     # M02 — as 6 mecânicas únicas
│   │   ├── loot_generator.dart      # M04 — itens e Essências
│   │   ├── wave_director.dart       # M08
│   │   ├── offline_simulator.dart   # M09
│   │   ├── state_projector.dart     # M11 — projeção para o widget
│   │   ├── cube_service.dart        # M06
│   │   ├── rune_tree_service.dart   # M07
│   │   └── rune_effects.dart        # M07 — regras especiais de combate
│   ├── progression/         # M03 — XP de herói, nível de conta, slots
│   ├── inventory/           # M05 — capacidade, auto-venda, equipar
│   ├── entitlements/        # M12 — bônus ativos, compras, gemas, fonte do 4º slot
│   └── ports/               # Interfaces que a infraestrutura implementa
├── data/
│   ├── repositories/        # Implementações Hive dos ports
│   ├── dto/                 # Serialização versionada (ver contracts/)
│   └── migrations/          # Migração de schema de save
├── presentation/
│   ├── game/                # Camada Flame: componentes, sprites, câmera
│   ├── screens/             # Combate, Inventário, Cubo, Runas, Resumo Offline
│   ├── theme/               # Tema — apresentação, não core (ver nota abaixo)
│   ├── widgets/
│   └── providers/           # Riverpod — ponte entre domínio e UI
└── services/
    ├── notification_service.dart
    ├── background_service.dart      # WorkManager + foreground task
    ├── home_widget_service.dart
    ├── ad_service.dart
    └── iap_service.dart

android/
└── app/src/main/kotlin/...          # AppWidgetProvider, layouts do widget

test/
├── domain/                  # Um arquivo por mecânica, cenários CEN-Mxx-nnn
├── data/                    # Round-trip de serialização, migrações
└── presentation/
integration_test/            # Widget de tela inicial, notificação, retomada offline
```

**Structure Decision**: Projeto Flutter único com a arquitetura em camadas de `specification.md` §4.2, com dois desvios deliberados.

O primeiro é `lib/domain/engines/`, que não existe no documento de origem. Ele concentra as máquinas determinísticas do jogo — combate, loot, waves, offline, cubo, runas — em Dart puro. O motivo é direto: `OfflineSimulator` precisa produzir exatamente o mesmo resultado que `CombatEngine` produziria se o jogo estivesse aberto. Se essas regras morarem dentro de componentes Flame, elas ficam acopladas ao ciclo de render e o simulador offline vira uma reimplementação paralela — duas fontes de verdade que divergem com o tempo. Com o núcleo isolado, a camada Flame só lê estado e desenha.

O segundo é `core/numeric/` e `core/rng/`, exigidos pelos achados R6 e R5 da pesquisa: números que crescem sem teto e aleatoriedade reproduzível são pré-requisitos transversais, não detalhe de uma mecânica.

`domain/ports/` inverte a dependência de persistência, notificação e anúncios: o domínio declara a interface, `data/` e `services/` implementam. É o que permite rodar o núcleo inteiro em teste sem Hive, sem AdMob e sem Android.

**Correções descobertas na implementação da Fase 2:**

- `core/theme/` saiu de `core/` para `presentation/theme/`. Tema importa Flutter por natureza, e mantê-lo em `core/` tornava falsa a afirmação de que `lib/core/` é Dart puro — o que importa porque `lib/domain/` depende de `core/`. A regra agora é verificável, e `test/domain/architecture_test.dart` a faz falhar o build se alguém a violar. Foi esse teste que pegou o problema.
- As definições de conteúdo (`HeroClassDefinition`, `MonsterTemplate`, `RuneNode`) foram criadas na Fase 2, não em US1 como as tarefas previam: `ContentRepository` (T023, foundational) não compila sem elas. As tarefas T039 e T041 ficam reduzidas ao que sobra — habilidades e derivação de atributos.

**Correções descobertas na implementação de US1:**

- **O piso de 1 de dano é assimétrico.** R-M01-03 fixa dano mínimo de 1, e a primeira implementação aplicou isso nos dois sentidos. O efeito era um herói de nível alto ser lentamente morto por monstros triviais do Ato 1, por mais defesa que acumulasse — o oposto do que a progressão de equipamento deveria comprar. O piso agora vale só para herói→monstro, onde existe progressão a destravar; monstro→herói pode chegar a zero. Um teste trava a regra (`herói com defesa suficiente não sofre dano`).
- **`ContentRepository` ganhou `requireFullRuneTree`.** A validação de ≥200 nós roda no boot, mas a árvore só é autorada em T123 (US6). Sem o parâmetro, o app não abriria durante toda US1–US5 por causa de uma dependência de conteúdo de US6. Adjacência e alcançabilidade continuam validadas sempre.
- **Desugaring obrigatório no Android.** `flutter_local_notifications` 22 usa APIs de `java.time` inexistentes no minSdk 24 e exige `isCoreLibraryDesugaringEnabled` mais `desugar_jdk_libs`. Sem isso o APK **não compila** — não é degradação de notificações, é falha de build.
- **`CombatController._spawnFor` é provisório.** Gera waves com escalonamento fixo; `WaveDirector` (T076, US3) assume a responsabilidade com escalonamento por wave e dificuldade.

**Correções descobertas na implementação de US2:**

- **`RngStream` ganhou `substream(label)`.** `fork` deriva um fluxo novo a cada chamada, o que serve a um consumidor de vida longa que forka uma vez (`CombatEngine`) e falha para um consumidor sem estado que sorteia repetidamente: `rollEssence` receberia o mesmo fluxo do zero a cada monstro e devolveria sempre o mesmo resultado. `substream` memoiza o filho por rótulo e o semeia só a partir de `(seed, label)`, nunca do que o pai consumiu — é o que faz R-M04-13 valer de verdade: mudar a taxa de Essência não desloca nenhum item.
- **`InventoryService` guarda um catálogo `id → item` dos equipados.** A assinatura de `equip` no contrato recebe apenas `(hero, item, inventory)`, mas CEN-M05-003 exige que o item substituído volte ao inventário como objeto completo, e o herói guarda só o ID (V-H-02). O catálogo é essa resolução. Quem carrega um save precisa semeá-lo com `registerEquipped`, senão o primeiro item substituído após a reabertura se perde — por isso o serviço vive num provider único, compartilhado entre loot e combate.
- **`intake` recebe `List<GameItem>`, não `List<Hero>`.** O contrato dizia `List<Hero>`; o que a auto-venda precisa excluir são os itens em uso, e derivá-los do herói obrigaria o serviço a resolver IDs duas vezes.
- **`core/constants/scaling.dart` importa `domain/entities/progress_position.dart`.** É a única importação de `core/` para `domain/`. A alternativa — receber `(difficulty, act, wave)` soltos — abriria espaço para passar `globalWave` no lugar de `wave`, exatamente o erro que V-PP-04 existe para prevenir.
- **`HeroCombatant` ganhou os percentuais de item.** `bonusCritChance`, `bonusCritDamage` e `attackSpeedMultiplier` ficam fora de `Stats` porque não são atributo bruto: somar `+8% de crítico` a `attack` faria a mesma peça valer coisas diferentes conforme o slot. `withStats` reaplica tudo preservando a **fração** de HP, que é o que permite equipar no meio da wave sem curar de graça nem matar por diferença de teto (SC-M05-04).
- **As ações de inventário passam pelo `CombatController`.** Vender credita ouro na conta e equipar reaplica atributos ao combatente; as duas coisas moram lá. `LootController` só cuida do inventário.

**Correções descobertas na implementação de US3:**

- **`CombatDependencies` saiu para `presentation/providers/game_dependencies.dart`.** Combate, loot e waves dependem dela; mantê-la dentro do controlador de combate criava o ciclo `combat → loot → wave → combat`. `combat_providers.dart` reexporta o arquivo novo, então nenhum import existente precisou mudar.
- **A regra de drop garantido virou `BossDropPolicy`, em `wave_providers.dart`.** Ela é sobre a **wave**, não sobre o item: quem sabe que a wave é de boss é o `WaveDirector`. E exige as duas condições — monstro boss **e** wave múltipla de 10 —, senão um template marcado como boss por engano numa wave comum passaria a conceder loot garantido a cada aparição.
- **O fator de wave reinicia a cada ato.** `MonsterScaling.waveFactor` usa `wave` (relativa ao ato), não `globalWave`: com a wave acumulada, a wave 1 do Ato 2 nasceria mais forte que o boss final do Ato 1, já que os templates do ato seguinte já têm atributos base maiores. O ato entra por um degrau próprio (`actMultiplier`), para que a fórmula continue crescente mesmo se um template reaparecer num ato posterior.
- **`WaveDirector.advance` não grava; `applyAdvance` grava.** Separar as duas mantém o motor livre de efeito colateral (I-4) e deixa a preservação de CEN-M08-009 verificável: só posição e recordes são reescritos na conta, e heróis, itens e runas ficam fora do caminho por construção.
- **A wave ganhou fluxo de RNG próprio (`fork('waves')`).** Sem isso, mudar a quantidade de monstros por wave deslocaria o sorteio de crítico e o de loot.
- **`spawnWave` deriva o `instanceId` da posição.** Um contador de instância global tornava a composição da wave dependente de quantas waves a sessão já tinha visto — o offline (M09) e o combate ao vivo produziriam IDs diferentes para a mesma wave.

**Correções descobertas na implementação de US4:**

- **`timeToClearWave` estava errada por até 6× e foi reescrita.** Duas omissões, ambas descobertas comparando a simulação com o combate real wave a wave. (1) Dividir HP total por DPS ignora o **excedente de dano**: quando o time mata cada monstro em um golpe — o caso normal de quem farma um ato antigo — o modelo estimava a wave três vezes mais rápida do que ela é. Agora conta golpes por monstro. (2) Ignorava o **tempo de revive**: numa wave de boss, o alvo cai em segundos e os 30 s de R-M01-06 dominam a luta; a estimativa dizia 24 s onde o combate real levava 139 s. Agora conta quantas vezes o alvo cai durante a wave. Depois das duas correções, 1 h simulada compra 236 waves contra 274 do jogo aberto — conservador, que é o lado certo de errar num modo já penalizado em 20%.
- **`goldPerSecond` entrou em `PlayerAccount` e no schema de save.** O contrato de persistência não previa o campo, mas R-M09-03 é uma fórmula sobre ele. Save antigo sem a chave decodifica como zero, que é o comportamento correto: sem taxa apurada, não há ouro offline. `contracts/persistence-save-schema.md` foi atualizado.
- **`simulate` devolve `OfflineSimulation`, não `OfflineReport`.** O contrato previa só o relatório, mas alguém precisa adotar o estado resultante. Mantê-los separados preserva o que data-model.md diz do `OfflineReport`: objeto de exibição, descartado depois de visto — e não uma segunda fonte de verdade sobre o progresso.
- **O ouro da venda automática offline é creditado e reportado à parte.** Somá-lo a `goldGained` tornaria a fórmula de R-M09-03 impossível de conferir; descartá-lo puniria o jogador por ter enchido o inventário enquanto estava fora.
- **A persistência foi ligada ao app.** `SaveScheduler` existia desde a Fase 2 mas nada o chamava: `main.dart` agora carrega o save, semeia o RNG a partir dele — sem isso reabrir o app re-sortearia todo o loot — e grava em `onAppPause`. `CombatController` ganhou `restore` e `snapshot`, e `snapshot` sem `now` preserva o `lastSaveAt`, porque a retomada mede a ausência **a partir** dele.
- **`ClockGuard` trata reinício de processo como caso normal.** O contador monotônico zera com o processo, e é justamente na reabertura que a simulação roda; cruzar os dois relógios ali produziria falso positivo em toda abertura do app.

**Correções descobertas na implementação de US5:**

- **`flutter_local_notifications` 22 mudou para parâmetros nomeados.** `show`, `initialize` e `cancel` passaram a exigir `id:`, `settings:` e `notificationDetails:`. É a segunda vez que esta dependência cobra atenção — a primeira foi o desugaring obrigatório, registrado em US1.
- **A detecção de evento raro em segundo plano roda o simulador e descarta o estado.** Parece desperdício, mas é o que torna a notificação honesta: a simulação é pura e determinística, então rodá-la agora e de novo na reabertura, a partir do mesmo save e da mesma semente, produz exatamente os mesmos itens. A notificação anuncia o que o jogador **vai** receber, não uma estimativa que o resumo depois desmente. As três restrições do contrato §3 continuam valendo: nenhum combate real, nenhuma gravação de save.
- **O marcador de "já notifiquei este item" vive no armazenamento do widget, não no save.** É estado de notificação, não progresso. Gravá-lo no save quebraria a regra de escritora única e reabriria a corrida de CEN-M10-E03.
- **`StateProjector` importa as constantes de `OfflineSimulator` em vez de redeclará-las.** Se o widget tivesse o próprio teto ou a própria penalidade, passaria a prometer um número que o resumo da reabertura não confirmaria — e a discrepância apareceria justamente quando o jogador está mais atento ao ganho. Um teste trava a igualdade das duas constantes.
- **Empate de instante no "último item raro" resolve pela ordem da lista.** Com `isAfter` estrito, dois itens do mesmo tick manteriam o primeiro, que é o mais antigo dos dois.
- **`updatePeriodMillis` do provider ficou em 30 min, como o contrato previa.** Não é o caminho primário e não deve ser confundido com a cadência de R-M11-02: o que mantém o widget correto entre atualizações é a projeção feita no desenho, não a frequência.
- **T098 exige aparelho.** `integration_test/` não roda em `flutter test`. Além disso, as verificações que dependem do launcher — adicionar o widget, tocar nele, ver a notificação na gaveta — não são automatizáveis de dentro do processo do app e ficaram anotadas no arquivo como validação manual de `quickstart.md` §4.

**Correções descobertas na implementação de US6:**

- **A trilha de conta nunca era alimentada.** `ProgressionService.grantAccountXp` existia desde US1 (T050) e `FormationSlots.evaluate` desde T051, mas nada os chamava: o nível de conta ficava em 1 para sempre. A consequência só aparece aqui — sem nível de conta não há ponto de runa (R-M03-06), e a árvore de 210 nós seria conteúdo inalcançável; de quebra, o 4º slot do nível 25 nunca chegaria. `CombatController.tick` agora alimenta as duas trilhas com o mesmo XP das derrotas, e as curvas diferentes (500/×1,2 contra 100/×1,15) mantêm a conta mais lenta que o herói, como CEN-M03-007 pede.
- **`RuneModifiers` do motor virou campo mutável, com `applyRunes`.** Recriar o `CombatEngine` para trocar bônus reiniciaria o fluxo de RNG, e o combate voltaria a sortear críticos já sorteados. Trocar só o agregado é seguro justamente porque ele nunca é aplicado ao herói — é o mesmo motivo pelo qual o respec em combate é seguro (CEN-M07-E03).
- **Percentuais do mesmo tipo somam antes de multiplicar.** Com 20 nós de +10%, multiplicar daria ×6,7 em vez de ×3. A escolha está travada por teste, porque é o tipo de detalhe que ninguém percebe até a curva de balanceamento já ter fugido.
- **`CubeBlueprint` era `dynamic`.** Os campos `type` e `targetAffixTypes` estavam sem tipo desde a Fase 2, quando ninguém os consumia. Agora são `ItemType` e `List<AffixType>`, e passaram a ser serializados — sem isso o molde não sobreviveria a fechar o app, contra o espírito de V-CB-01.
- **A ordem dos sorteios da fusão é parte do contrato.** Recriação, tipo, e só então o item: mudar a ordem muda todo o resultado para uma mesma semente. Está anotado no código porque não há como um teste flagrar a intenção, só a consequência.
- **A Essência tem precedência sobre o molde no sufixo garantido.** Ela é o recurso raro e é consumida de qualquer forma (R-M06-05); deixar o molde vencer gastaria a Essência sem entregar o que ela promete.
- **A árvore é gerada, não escrita à mão.** 210 nós em 6 constelações, com adjacência simétrica por construção. O teste de conteúdo (T112) percorre a árvore como um jogador percorreria — só desbloqueando o que a adjacência permite — e falha se existir uma região que ninguém conseguiria abrir. Com a árvore autorada, `requireFullRuneTree` voltou a ser exigido no boot.

## Complexity Tracking

> Sem violações a justificar — não há princípios constitucionais ratificados. Tabela intencionalmente vazia.
