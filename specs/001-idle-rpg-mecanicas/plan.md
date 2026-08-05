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

## Complexity Tracking

> Sem violações a justificar — não há princípios constitucionais ratificados. Tabela intencionalmente vazia.
