# Phase 0 — Research: Mecânicas do Idle RPG

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-04 | **Plan**: [plan.md](plan.md)

Este documento resolve as incógnitas técnicas levantadas no Technical Context e registra as decisões que sustentam a Fase 1. Cada item segue o formato Decisão / Justificativa / Alternativas consideradas.

---

## R1 — Engine: Flutter + Flame

**Decisão**: Flutter 3.22+ com Flame 1.18+.

**Justificativa**: `specification.md` §4 já está inteiramente escrito sobre Flutter + Flame — stack, arquitetura de pastas, modelos e game loop. A carga de trabalho real deste jogo é UI e simulação numérica, não renderização pesada: são até 4 heróis e um punhado de monstros em sprites 16×16 a 30 FPS. Flame cobre isso com folga, e Flutter dá acesso nativo de primeira classe às três integrações Android que constituem o diferencial do produto (widget de tela inicial, notificação persistente, WorkManager) — que em Unity ou Godot exigiriam plugins ou código nativo adicional.

**Alternativas consideradas**: Unity 2D, recomendada por §1.1 para quem não conhece Flutter — descartada porque o ganho (workflow de pixel art e asset store) não compensa perder a integração Android nativa que é o diferencial declarado do jogo. Godot, descartada pelo mesmo motivo mais comunidade menor.

**Ressalva registrada**: §1.1 condiciona a recomendação ao conforto com Dart. Este plano assume esse conforto. Se a premissa não se sustentar, a decisão a revisar é esta — e ela deve ser revisada antes da Fase 2, não durante a implementação.

---

## R2 — Persistência: Hive

**Decisão**: Hive 2.2.3 com `hive_flutter`, um box por agregado (`account`, `heroes`, `inventory`, `meta`).

**Justificativa**: §4.5 já especifica Hive e o padrão de acesso descrito lá é key-value puro — `box.put('playerAccount', ...)`. Nada no conjunto de 180 cenários exige consulta relacional, índice secundário ou filtro no banco: o inventário tem teto de 50 itens e é filtrado em memória sem custo. Hive grava fora da thread de UI, o que atende diretamente SC-M10-03 (salvamento sem queda de fluidez).

**Alternativas consideradas**: Isar, citada em §4.1 como opção para "queries complexas" — descartada porque não há query complexa neste escopo, e ela traria geração de código e binários nativos maiores contra o alvo de APK < 30 MB. `shared_preferences`, descartada por não suportar objetos estruturados nem gravação assíncrona adequada.

---

## R3 — Simulação offline: forma fechada + blocos amortizados

**Decisão**: híbrida. Ouro por forma fechada analítica; XP, avanço de wave e loot por simulação em blocos de tamanho adaptativo. Nunca tick a tick.

**Justificativa**: SC-M09-01 exige o resumo em ≤3 s para 8 h de ausência. A 30 ticks por segundo, 8 h são 864.000 ticks — inviável em dispositivo de entrada dentro do orçamento. Mas as regras da spec permitem escapar disso:

- **Ouro**: R-M09-03 já define a forma fechada, `ouro_por_segundo × t × 0,8`. É uma multiplicação, custo constante.
- **Waves e XP**: o tempo para limpar uma wave é determinístico dado o poder do jogador congelado no save (assunção declarada em M09). Isso permite calcular quantas waves cabem em `t` resolvendo a soma acumulada dos tempos por wave, avançando por blocos e parando quando o tempo por wave excede o restante — o caso de estagnação de CEN-M09-011 cai naturalmente aqui.
- **Loot**: número esperado de drops por wave × waves simuladas, com os itens efetivamente gerados pelo `LootGenerator` a partir do RNG semeado (R5). Só se materializam os itens que sobrevivem à capacidade de 50 slots e à auto-venda de M05, o que limita o trabalho real a dezenas de itens, não milhares.

**Alternativas consideradas**: simulação tick a tick fiel — descartada pelo custo. Simulação em isolate de fundo com resumo progressivo — descartada por complexidade desproporcional, já que a forma fechada resolve em milissegundos; fica registrada como escape se o perfilamento mostrar o contrário.

**Consequência para a Fase 1**: `OfflineSimulator` e `CombatEngine` precisam compartilhar as mesmas funções de dano e de tempo-por-wave, senão os dois divergem. Isso é o que motiva o núcleo de domínio isolado.

---

## R4 — Atualização do widget: o piso de 15 minutos do Android

**Decisão**: três modos de atualização, com o widget renderizando estado **projetado** quando não pode ser atualizado.

| Situação | Mecanismo | Cadência real |
|---|---|---|
| App em primeiro plano | Chamada direta ao `home_widget` | 1 min (atende FR-023) |
| App em segundo plano com serviço em primeiro plano ativo | `flutter_foreground_task` dispara a atualização | 1 min (atende FR-023) |
| App encerrado, sem serviço | `WorkManager` periódico | ≥15 min (piso da plataforma) |

**Justificativa**: esta é uma tensão real entre FR-023 ("atualizar a cada 1 minuto") e a plataforma. O Android impõe dois pisos independentes: `updatePeriodMillis` do `AppWidgetProvider` tem mínimo efetivo de 30 minutos, e tarefas periódicas do WorkManager têm mínimo de 15 minutos. Nenhum dos dois é contornável de forma legítima, e fabricantes com economia agressiva de bateria atrasam ainda mais — situação que a própria spec antecipa em CEN-M11-E02.

A saída não é atualizar mais vezes, é atualizar com informação melhor. Como o estado do jogo com o app fechado é uma função determinística de `(estado salvo, tempo decorrido)` — exatamente a fórmula de M09 —, o widget pode **calcular no momento em que é desenhado** onde o jogador estaria agora, em vez de exibir um retrato congelado do último save. O ouro por segundo e a wave projetada ficam corretos mesmo com atualização de 15 em 15 minutos, porque a projeção é feita na hora do render.

**Alternativas consideradas**: alarmes exatos (`setExactAndAllowWhileIdle`) para forçar 1 minuto — descartada; consome bateria de forma agressiva, exige permissão especial a partir do Android 12 e viola o espírito de §8 ("30 FPS economiza bateria"). Serviço em primeiro plano permanente — descartada como padrão porque força notificação persistente sempre visível, contra CEN-M11-010 que exige poder desativá-la.

**Impacto na spec**: FR-023 e SC-M11-01 são atendíveis apenas nos dois primeiros modos. SC-M11-01 já contém a ressalva "quando o sistema permite atualizações periódicas", e CEN-M11-E02 já cobre o comportamento degradado — a spec não precisa mudar, mas o limite precisa ficar explícito no `quickstart.md` e nos testes de integração.

---

## R5 — Aleatoriedade determinística e semeada

**Decisão**: PRNG próprio semeado (xorshift128+), com semente persistida na conta e um contador de sequência avançado a cada consumo. Nada de `dart:math Random()` sem semente no caminho de jogo.

**Justificativa**: dois requisitos da spec dependem disso. Primeiro, a simulação offline (R3) tem que gerar o mesmo loot que o combate ao vivo geraria — só é possível com fluxo de RNG reproduzível a partir do estado salvo. Segundo, CEN-M10-E03 exige que duas instâncias do jogo não dupliquem itens; com semente e contador persistidos, reprocessar o mesmo intervalo produz o mesmo resultado em vez de loot novo. Como efeito colateral, isso fecha a porta do save-scumming: fechar o app e reabrir não re-sorteia o drop.

**Alternativas consideradas**: `Random.secure()` — descartada, é o oposto do que se quer aqui (irreprodutível por definição). `Random(seed)` da biblioteca padrão — descartada porque o algoritmo não tem garantia de estabilidade entre versões do Dart, e um save de 6 meses atrás precisa continuar reproduzindo a mesma sequência.

---

## R6 — Representação numérica: mantissa com expoente

**Decisão**: tipo de valor `GameNumber` com mantissa `double` e expoente `int`, normalizado, para ouro, dano, HP e XP. `int` comum permanece apenas para contadores discretos (nível, wave, slots, pontos de runa).

**Justificativa**: R-M08-08 multiplica todos os atributos dos monstros por 1,5 a cada dificuldade, sem teto (R-M08-09). O crescimento é exponencial e estoura `int64` (máximo ≈ 9,22 × 10¹⁸):

- multiplicador isolado: `1,5ⁿ > 9,22×10¹⁸` em `n ≈ 108`;
- com base de 10⁶ de HP no fim do Ato 3: `10⁶ × 1,5ⁿ` estoura em `n ≈ 74`;
- ouro acumulado, que soma ao longo do tempo, estoura antes disso.

Ou seja, um jogador dedicado alcança o estouro. Em Dart nativo `int` é 64 bits e **transborda silenciosamente**, sem exceção — o ouro viraria negativo e a progressão quebraria sem erro visível. Isso torna a decisão obrigatória, não uma otimização prematura.

**Alternativas consideradas**: `BigInt` — descartada; é exata mas aloca no heap a cada operação, e o combate faz milhares de operações por segundo. `double` puro — descartada; perde precisão de inteiro acima de 2⁵³ e a formatação de números grandes fica instável. Teto artificial de dificuldade — descartada por contradizer R-M08-09 diretamente.

**Consequência**: a formatação para exibição (`1,2K`, `3,4M`, `5,6aa`) é responsabilidade de `core/numeric/`, e todos os valores serializados no save precisam gravar mantissa e expoente, não um inteiro — ver `contracts/persistence-save-schema.md`.

---

## R7 — Tempo e resistência a manipulação de relógio

**Decisão**: relógio duplo. `DateTime.now()` (relógio de parede) para o intervalo offline, cruzado com um contador monotônico persistido; delta negativo é tratado como zero, delta positivo é limitado ao teto de 8 h.

**Justificativa**: CEN-M09-E01 e CEN-M09-E02 exigem exatamente este comportamento — adiantar o relógio não pode render mais que 8 h, atrasar não pode subtrair recursos. O teto de 8 h já neutraliza a maior parte do abuso, o que dispensa validação por servidor nesta feature. O contador monotônico serve para detectar a inconsistência e registrar o evento em analytics, não para punir o jogador.

**Alternativas consideradas**: validação por horário de servidor — descartada por exigir rede e contradizer a natureza offline-first do jogo. Ignorar o problema — descartada por haver cenários explícitos na spec.

---

## R8 — Árvore de runas: dados declarativos

**Decisão**: os 200+ nós vivem em um asset JSON versionado, carregado e validado no boot; o save persiste apenas o conjunto de IDs desbloqueados.

**Justificativa**: 200 nós escritos em Dart seriam 200 blocos de código a recompilar a cada ajuste de balanceamento. Como JSON, o balanceamento vira edição de dados e os efeitos ficam expressos como pares `(tipo de efeito, valor)` que o motor interpreta — sem `switch` gigante. A adjacência de R-M07-03 é uma lista de arestas validada no carregamento, o que permite detectar árvore desconexa em teste em vez de em produção. Persistir só os IDs mantém o save pequeno e faz o respec (R-M07-07) virar o esvaziamento de um conjunto.

**Alternativas consideradas**: nós codificados em Dart — descartada pelo ciclo de iteração. Nós em banco Hive — descartada; são dados de conteúdo imutáveis, não estado do jogador.

---

## R9 — Estratégia de teste: cenários GWT como testes de domínio

**Decisão**: cada cenário `CEN-Mxx-nnn` da spec vira um caso de teste nomeado pelo próprio ID, em Dart puro sobre o núcleo de domínio, sem Flutter e sem Hive. Plataforma e render ficam para `integration_test`.

**Justificativa**: os 180 cenários já estão escritos em forma de arranjo, ação e asserção — é a estrutura de um teste. Testá-los contra o núcleo headless os torna rápidos (milissegundos, sem bombear frames nem tocar disco) e determinísticos (R5 dá o RNG semeado, R7 dá o relógio injetável). O ID no nome do teste cria rastreabilidade direta: uma falha aponta para o parágrafo exato da spec que foi violado, e a cobertura de mecânica passa a ser mensurável por contagem.

Os cenários que **não** cabem nesse molde e precisam de `integration_test` real são os de plataforma: CEN-M11-001 a 011 (widget e notificação), CEN-M10-E02 (armazenamento cheio), CEN-M12-E01/E04 (rede e restauração de compras).

**Alternativas consideradas**: framework BDD com `.feature` em Gherkin — descartada; adicionaria dependência e uma camada de tradução para ganhar pouco, já que os arquivos de mecânica em Markdown já são a fonte legível. Testar contra a camada Flame — descartada pela lentidão e pela dependência de render.

---

## R10 — Orçamento de frame e bateria

**Decisão**: alvo de 30 FPS fixo, com a lógica de domínio rodando em passo fixo desacoplado do render, e sprite sheets únicos por classe e por tipo de monstro.

**Justificativa**: §8 fixa 30 FPS como suficiente para pixel art idle e como economia de bateria. Passo fixo no domínio (acumulador de tempo) evita que o resultado do combate dependa da taxa de quadros do aparelho — um jogo que dá loot diferente em aparelho rápido e lento é um bug de justiça, não de performance. Sprite sheets seguem §8 diretamente.

**Alternativas consideradas**: 60 FPS — descartada; dobra o custo de bateria sem ganho perceptível em pixel art de combate automático. Lógica atrelada ao `dt` do render — descartada pelo problema de determinismo acima.

---

## Incógnitas remanescentes

Nenhuma incógnita bloqueia a Fase 1. Ficam registrados três pontos que são **decisões de balanceamento**, não técnicas, e que a spec já marca como suposições ajustáveis:

- curva de conversão de wave para item level (M04);
- distribuição de probabilidade entre as 8 raridades (M04);
- nível de conta 25 como marco do 4º slot de formação (M03, M12).

Nenhum deles muda a arquitetura; todos são valores em `core/constants/` ou em assets de dados.
