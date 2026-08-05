# Feature Specification: Mecânicas do Idle RPG

**Feature Branch**: `001-idle-rpg-mecanicas`

**Created**: 2026-08-04

**Status**: Draft

**Input**: User description: "Leia o arquivo specification.md e converta todas as mecânicas dele em arquivos separados na pasta specs/ usando estritamente o formato estruturado de cenários com Given-When-Then."

## Visão Geral

Esta especificação converte as mecânicas de jogo descritas em `specification.md` (seções 3.3, 4.5, 4.6 e 5) em requisitos verificáveis. Cada mecânica vive em um arquivo próprio dentro de `mechanics/`, escrito estritamente no formato de cenários **Given / When / Then**.

Aspectos de `specification.md` que **não** são mecânicas de jogo — escolha de tecnologia (seção 1), diferenciação legal (seção 2), arquitetura de pastas (4.2), roadmap (6), assets (7), performance (8) e checklist anti-plágio (9) — estão fora do escopo desta especificação, por serem decisões de implementação ou de processo, não comportamentos observáveis pelo jogador.

### Catálogo de Mecânicas

| ID | Mecânica | Arquivo | Origem | Prioridade |
|----|----------|---------|--------|------------|
| M01 | Combate Automático | [mechanics/M01-combate-automatico.md](mechanics/M01-combate-automatico.md) | §3.3.A | P1 |
| M02 | Classes de Heróis | [mechanics/M02-classes-de-herois.md](mechanics/M02-classes-de-herois.md) | §3.3.B | P2 |
| M03 | Progressão de Herói e Conta | [mechanics/M03-progressao-heroi-conta.md](mechanics/M03-progressao-heroi-conta.md) | §3.3.B, §3.3.E, §4.3 | P1 |
| M04 | Loot Procedural | [mechanics/M04-loot-procedural.md](mechanics/M04-loot-procedural.md) | §3.3.C | P1 |
| M05 | Inventário e Equipamento | [mechanics/M05-inventario-equipamento.md](mechanics/M05-inventario-equipamento.md) | §3.2, §3.3.C | P1 |
| M06 | Cubo de Crafting | [mechanics/M06-cubo-crafting.md](mechanics/M06-cubo-crafting.md) | §3.3.D | P3 |
| M07 | Árvore de Runas | [mechanics/M07-arvore-de-runas.md](mechanics/M07-arvore-de-runas.md) | §3.3.E | P3 |
| M08 | Atos, Waves e Dificuldades | [mechanics/M08-atos-waves-dificuldades.md](mechanics/M08-atos-waves-dificuldades.md) | §3.3.A, §3.3.F | P1 |
| M09 | Progressão Offline | [mechanics/M09-progressao-offline.md](mechanics/M09-progressao-offline.md) | §3.3.G | P2 |
| M10 | Persistência e Salvamento | [mechanics/M10-persistencia-salvamento.md](mechanics/M10-persistencia-salvamento.md) | §4.5 | P1 |
| M11 | Widget e Notificação Persistente | [mechanics/M11-widget-notificacao.md](mechanics/M11-widget-notificacao.md) | §3.3.G, §4.6 | P2 |
| M12 | Monetização e Recompensas por Anúncio | [mechanics/M12-monetizacao-recompensas.md](mechanics/M12-monetizacao-recompensas.md) | §5 | P3 |

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Progredir sem tocar na tela (Priority: P1)

O jogador abre o jogo e vê seus heróis lutando sozinhos contra uma wave de monstros. Sem nenhuma entrada do jogador, os heróis derrotam monstros, ganham ouro e XP, e itens caem no inventário. Quando a wave é limpa, a próxima começa automaticamente. O jogador pode simplesmente assistir e o progresso acontece.

**Why this priority**: É o núcleo do gênero idle. Sem combate automático que gera recompensas e avança waves, não existe jogo — todas as outras mecânicas só adicionam profundidade sobre este laço.

**Independent Test**: Iniciar uma partida nova, não tocar em nada por 3 minutos, e verificar que houve monstros derrotados, ouro acumulado, XP ganho, pelo menos um item dropado e ao menos uma wave completada.

**Acceptance Scenarios**:

1. **Given** uma partida nova com 1 herói vivo na formação e uma wave ativa, **When** 60 segundos de jogo se passam sem entrada do jogador, **Then** ao menos um monstro foi derrotado, o ouro do jogador aumentou e o XP do herói aumentou.
2. **Given** uma wave com o último monstro vivo, **When** esse monstro é derrotado, **Then** a wave é marcada como completa e a wave seguinte inicia automaticamente com novos monstros.
3. **Given** um herói cuja vida chega a zero durante o combate, **When** 30 segundos se passam, **Then** o herói revive com vida cheia e volta a atacar, sem perder progresso da wave.

---

### User Story 2 - Ficar mais forte com o loot (Priority: P1)

O jogador recebe itens automaticamente enquanto luta. Ele abre o inventário, vê que um item novo é melhor que o equipado, equipa-o e observa os atributos do herói subirem — o que faz os monstros morrerem mais rápido.

**Why this priority**: É o laço de recompensa que dá sentido ao combate. Sem loot e equipamento, o combate automático não tem progressão perceptível.

**Independent Test**: Jogar até obter dois itens do mesmo slot com atributos diferentes, equipar o melhor e confirmar que o atributo correspondente do herói aumentou e que o item anterior voltou ao inventário.

**Acceptance Scenarios**:

1. **Given** um monstro que morre e concede um drop, **When** o item é gerado, **Then** ele entra no inventário automaticamente com raridade, item level e afixos definidos, sem exigir ação do jogador.
2. **Given** um herói com o slot de arma vazio e uma arma no inventário, **When** o jogador equipa essa arma, **Then** o ATK efetivo do herói aumenta no valor do item e o slot passa a exibir a arma.
3. **Given** um inventário com 50 slots ocupados, **When** um novo item é dropado, **Then** itens Bronze e Prata não equipados e não favoritados são vendidos automaticamente por ouro e o novo item é armazenado.

---

### User Story 3 - Avançar de wave, ato e dificuldade (Priority: P1)

O jogador percebe que a wave atual está trivial, avança para atos seguintes, enfrenta bosses a cada 10 waves e, ao terminar o Ato 3, desbloqueia uma nova dificuldade em que tudo é mais forte e o loot é melhor.

**Why this priority**: É a estrutura de longo prazo que dá direção ao grind e transforma o jogo em algo com fim de jogo aberto.

**Independent Test**: Progredir do início até a wave 10, verificar o boss e o loot garantido, e verificar que o registro de maior wave alcançada é atualizado.

**Acceptance Scenarios**:

1. **Given** o jogador na wave 9 de um ato, **When** a wave 9 é completada, **Then** a wave 10 inicia como wave de boss.
2. **Given** uma wave de boss em andamento, **When** o boss é derrotado, **Then** ao menos um item é concedido como drop garantido.
3. **Given** o jogador que derrotou o boss final da wave 100 do Ato 3 na dificuldade 1, **When** a vitória é registrada, **Then** a dificuldade 2 é desbloqueada com stats de monstros multiplicados por 1,5 e item level de loot acrescido de 10.

---

### User Story 4 - Continuar progredindo com o app fechado (Priority: P2)

O jogador fecha o app, vive sua vida e volta horas depois. Ao reabrir, recebe um resumo do que aconteceu: ouro acumulado, waves avançadas e itens obtidos durante a ausência.

**Why this priority**: É o diferencial do gênero idle e o principal motor de retenção, mas depende do combate e do loot já existirem para ter o que simular.

**Independent Test**: Salvar o estado, fechar o app, alterar o relógio para simular 2 horas de ausência, reabrir e conferir que o resumo offline exibe ganhos coerentes com a taxa de ouro por segundo aplicada a 2 horas com penalidade de 20%.

**Acceptance Scenarios**:

1. **Given** um jogador com estado salvo e taxa conhecida de ouro por segundo, **When** ele reabre o app após 2 horas de ausência, **Then** o ouro concedido equivale a `ouro_por_segundo × 7200 × 0,8` e um resumo dos ganhos é exibido antes do retorno ao combate.
2. **Given** um jogador ausente por 12 horas, **When** ele reabre o app, **Then** a simulação considera no máximo 8 horas de ausência.
3. **Given** um item de raridade Lendária ou superior dropado durante a simulação offline, **When** o resumo é gerado, **Then** o item aparece destacado no resumo.

---

### User Story 5 - Acompanhar o jogo sem abrir o app (Priority: P2)

O jogador coloca o widget na tela inicial e vê, sem abrir o jogo, a wave atual, o ouro por segundo e o último item raro obtido. Uma notificação persistente mostra o estado do combate enquanto o app está em segundo plano.

**Why this priority**: É o diferencial declarado do produto (equivalente Android da janela na taskbar), mas não é pré-requisito para jogar.

**Independent Test**: Adicionar o widget à tela inicial, deixar o app em segundo plano por 5 minutos e verificar que o widget refletiu ao menos uma atualização de estado e que tocá-lo abre o jogo na tela de combate.

**Acceptance Scenarios**:

1. **Given** o widget adicionado à tela inicial e um estado salvo válido, **When** o ciclo de atualização de 1 minuto ocorre, **Then** o widget exibe ouro por segundo, wave atual, melhor herói e o último item Lendário ou superior obtido.
2. **Given** o app em segundo plano, **When** o jogador abre a gaveta de notificações, **Then** existe uma notificação persistente com o ato e a wave atuais, o número de heróis em combate e a taxa de ouro por minuto.
3. **Given** o widget exibido na tela inicial, **When** o jogador toca no widget, **Then** o app abre diretamente na tela de combate.

---

### User Story 6 - Aprofundar a build (Priority: P3)

O jogador combina itens no Cubo para criar raridades superiores e gasta pontos de runa em uma árvore de passivas, moldando um estilo de jogo próprio.

**Why this priority**: Dá profundidade e retenção de longo prazo, mas o jogo é jogável e demonstrável sem essas mecânicas.

**Independent Test**: Reunir 3 itens de mesma raridade, fundi-los no Cubo e confirmar que o resultado é um item de raridade imediatamente superior com atributos re-rolados; separadamente, gastar 1 ponto de runa e confirmar que o bônus passa a valer no combate.

**Acceptance Scenarios**:

1. **Given** 3 itens de raridade Ouro no inventário, **When** o jogador os funde no Cubo, **Then** os 3 itens são consumidos e 1 item Épico com atributos re-rolados é criado.
2. **Given** um jogador com 1 ponto de runa disponível e um nó adjacente a um nó já desbloqueado, **When** ele desbloqueia esse nó, **Then** o ponto é consumido e o bônus do nó passa a ser aplicado no cálculo de combate.
3. **Given** um jogador que já fez 2 respecs, **When** ele solicita um terceiro respec, **Then** o custo em ouro cobrado é maior que o do respec anterior.

---

### User Story 7 - Acelerar opcionalmente, sem nada bloqueado (Priority: P3)

O jogador que quer ir mais rápido assiste a um anúncio para dobrar o ouro por algumas horas, revive um herói na hora ou compra gemas para não esperar o Cubo. O jogador que não quer gastar nada continua alcançando exatamente o mesmo conteúdo, só mais devagar.

**Why this priority**: sustenta o jogo comercialmente, mas nenhuma parte dela pode ser pré-requisito de progresso — por definição, é a última coisa a existir.

**Independent Test**: com uma conta que nunca pagou nem assistiu a anúncio, verificar que waves, atos, dificuldades, raridades, nós de runa e o 4º slot de formação permanecem alcançáveis, e que nenhuma tela exige pagamento para continuar.

**Acceptance Scenarios**:

1. **Given** um jogador sem bônus de ouro ativo, **When** ele assiste completamente a um anúncio recompensado de ouro, **Then** um bônus de +50% é ativado por 4 horas e o tempo restante é exibido.
2. **Given** um jogador que nunca realizou compras, **When** sua conta atinge o nível 25, **Then** o 4º slot de formação é desbloqueado gratuitamente, com a mesma capacidade de quem comprou o Pacote de Início.
3. **Given** um jogador com gemas e uma operação de Cubo em andamento, **When** ele gasta gemas para acelerar, **Then** a operação conclui antes do tempo normal e os resultados possíveis são idênticos aos da operação sem gemas.
4. **Given** um jogador que inicia um anúncio recompensado, **When** ele o fecha antes do fim, **Then** nenhuma recompensa é concedida, nenhum recurso é consumido e ele pode tentar de novo.

---

### Edge Cases

- **Given** todos os heróis da formação mortos ao mesmo tempo, **When** a wave continua, **Then** os monstros não avançam de wave e o jogo aguarda o revive automático em 30 segundos, sem game over permanente.
- **Given** o app encerrado abruptamente pelo sistema operacional entre dois auto-saves, **When** o jogador reabre, **Then** o estado restaurado é o do último save válido e o intervalo não salvo é tratado como tempo offline.
- **Given** um relógio de dispositivo ajustado para o futuro, **When** o cálculo offline é executado, **Then** o ganho concedido é limitado ao teto de 8 horas.
- **Given** um inventário cheio composto apenas por itens Ouro ou superiores (nenhum candidato a venda automática), **When** um novo item é dropado, **Then** o jogador é notificado de inventário cheio e o drop é retido até haver espaço.
- **Given** um jogador sem conexão de rede, **When** ele tenta assistir a um anúncio recompensado, **Then** a recompensa não é concedida e uma mensagem explicativa é exibida, sem afetar o progresso.
- **Given** um respec solicitado com ouro insuficiente, **When** o jogador confirma, **Then** a operação é recusada e nenhum ponto de runa é devolvido.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: O sistema MUST executar combate automático sem entrada do jogador, com 3 heróis simultâneos na formação por padrão, expansível para 4 conforme FR-028. (M01)
- **FR-002**: O sistema MUST calcular dano como `ATK do herói + bônus de itens − DEF do monstro`, com chance base de crítico de 5% acrescida de bônus de itens e habilidades. (M01)
- **FR-003**: O sistema MUST reviver automaticamente um herói morto após 30 segundos. (M01)
- **FR-004**: O sistema MUST oferecer 6 classes jogáveis, cada uma com papel, atributo principal e mecânica única distintos. (M02)
- **FR-005**: O sistema MUST conceder XP aos heróis por monstro derrotado e subir o nível do herói ao atingir o XP necessário. (M03)
- **FR-006**: O sistema MUST manter um nível de conta separado do nível dos heróis, concedendo pontos de runa a cada nível de conta. (M03, M07)
- **FR-007**: O sistema MUST gerar itens proceduralmente em 7 tipos de slot, 8 raridades (Bronze → Cósmico), com 1 prefixo principal e de 0 a 3 sufixos aleatórios. (M04)
- **FR-008**: O sistema MUST escalar o item level do loot com a wave em que ele é obtido. (M04)
- **FR-009**: O sistema MUST coletar itens dropados automaticamente para o inventário, sem ação do jogador. (M04, M05)
- **FR-010**: O sistema MUST vender automaticamente itens Bronze e Prata não equipados e não favoritados quando o inventário atingir 50 slots ocupados. (M05)
- **FR-011**: Os jogadores MUST ser capazes de equipar e desequipar itens por slot em cada herói, com efeito imediato nos atributos. (M05)
- **FR-012**: O sistema MUST permitir fundir 3 itens de mesma raridade em 1 item da raridade imediatamente superior com atributos re-rolados. (M06)
- **FR-013**: O sistema MUST conceder Essências como drop raro em combate e MUST permitir adicioná-las à fusão para garantir um sufixo específico no item resultante. (M04, M06)
- **FR-014**: Os jogadores MUST ser capazes de salvar um item como molde ("Imprimir") e usá-lo para tentar recriar sua combinação de atributos. (M06)
- **FR-015**: O sistema MUST oferecer uma árvore de runas com no mínimo 200 nós, desbloqueáveis apenas quando adjacentes a um nó já desbloqueado. (M07)
- **FR-016**: O sistema MUST permitir respec da árvore de runas por um custo em ouro que cresce a cada respec realizado. (M07)
- **FR-017**: O sistema MUST organizar o conteúdo em 3 atos de 100 waves cada, com boss a cada 10 waves e loot garantido em waves de boss. (M08)
- **FR-018**: O sistema MUST desbloquear uma nova dificuldade ao completar o Ato 3, multiplicando todos os atributos dos monstros por 1,5 e somando 10 ao item level do loot, sem limite superior de dificuldades. (M08)
- **FR-019**: O sistema MUST simular progresso offline de até 8 horas ao retornar, concedendo `ouro_por_segundo × tempo_offline × 0,8`. (M09)
- **FR-020**: O sistema MUST exibir um resumo dos ganhos offline antes de devolver o jogador ao combate. (M09)
- **FR-021**: O sistema MUST salvar o estado automaticamente a cada 30 segundos e sempre que o app for pausado. (M10)
- **FR-022**: O sistema MUST restaurar o último estado válido salvo na reabertura, sem perda de itens equipados, progresso de wave ou nível. (M10)
- **FR-023**: O sistema MUST exibir no widget da tela inicial ouro por segundo, wave atual, melhor herói e último item Lendário ou superior, atualizados a cada 1 minuto enquanto o app estiver em primeiro plano ou com serviço em primeiro plano ativo, e no menor intervalo que o sistema operacional permitir quando o app estiver encerrado. Em qualquer modo, os valores exibidos MUST corresponder ao estado projetado para o instante da exibição, não ao instante da última atualização. (M11)
- **FR-024**: O sistema MUST exibir notificação persistente com ato, wave, heróis em combate e ouro por minuto enquanto o app estiver em segundo plano. (M11)
- **FR-025**: O sistema MUST enviar notificação push quando o inventário ficar cheio ou quando um item Lendário ou superior for obtido. (M11)
- **FR-026**: O sistema MUST oferecer recompensas por anúncio opcionais (+50% de ouro por 4 horas, revive instantâneo, +1 slot de cubo) sem que nenhuma delas seja necessária para progredir. (M12)
- **FR-027**: O sistema MUST manter todo o conteúdo de progressão obtenível sem pagamento; compras MUST apenas acelerar ou adicionar conteúdo opcional. (M12)
- **FR-028**: O sistema MUST oferecer um 4º slot de formação, desbloqueado gratuitamente ao atingir o nível de conta 25; o Pacote de Início MUST apenas antecipar esse desbloqueio, nunca ser a única via de obtê-lo. (M01, M03, M12)
- **FR-029**: O sistema MUST permitir gastar gemas para acelerar operações do Cubo e o respec da árvore de runas, sem alterar os resultados possíveis e sem tornar qualquer nó, item ou raridade inacessível a quem não usa gemas. (M06, M07, M12)

### Key Entities

- **Item**: Um equipamento obtido por drop. Possui identificador, tipo de slot, raridade, item level, atributo base, lista de sufixos, estado de equipado/favoritado e momento do drop.
- **Herói**: Um combatente controlado pelo sistema. Possui classe, nível, XP acumulado, XP para o próximo nível, atributos (força, destreza, inteligência, vitalidade, agilidade), slots de equipamento e habilidades desbloqueadas.
- **Monstro**: Um oponente gerado por wave. Possui tipo, nível, atributos e tabela de raridades possíveis de drop com modificador de chance.
- **Conta do Jogador**: O progresso persistente acima dos heróis. Possui nível de conta, pontos de runa, nós de runa desbloqueados, quantidade de slots de formação desbloqueados, maior wave, maior ato, maior dificuldade e momento do último acesso.
- **Wave**: Um encontro composto por um conjunto de monstros, identificado por número dentro de um ato, podendo ser wave normal ou de boss. Ver nota no modelo de dados: a posição na progressão é persistida, o estado do encontro em andamento não é.
- **Nó de Runa**: Uma passiva da árvore, com pré-requisitos de adjacência, custo em pontos e efeito (percentual de dano, ouro, XP ou regra especial de combate).
- **Essência**: Um consumível raro obtido por drop em combate, que ao ser adicionado a uma fusão do Cubo garante um sufixo específico no item resultante. Possui o tipo de sufixo que garante e é consumida na fusão.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Um jogador novo vê o primeiro monstro derrotado em até 10 segundos após o primeiro início do jogo, sem executar nenhuma ação.
- **SC-002**: Um jogador que não toca na tela por 5 minutos acumula ouro, XP e ao menos 1 item, e avança ao menos 1 wave.
- **SC-003**: O resumo de progresso offline é apresentado em até 3 segundos após a reabertura do app, para qualquer ausência de até 8 horas.
- **SC-004**: 100% dos itens, classes, nós de runa e dificuldades permanecem obteníveis sem qualquer compra ou visualização de anúncio.
- **SC-005**: Nenhum encerramento inesperado do app resulta em perda de mais de 30 segundos de progresso.
- **SC-006**: O widget da tela inicial exibe valores coerentes com o instante em que é consultado: atualização a cada 1 minuto com o app em primeiro plano ou com serviço ativo, e projeção correta do estado quando o sistema operacional restringe a frequência de atualização.
- **SC-007**: Um jogador consegue comparar e equipar um item recém-dropado em no máximo 3 interações a partir da tela de combate.
- **SC-008**: A progressão da wave 1 até a wave 100 do Ato 1 é possível sem qualquer decisão obrigatória do jogador além de equipar itens.
- **SC-009**: Todo critério de desempenho desta especificação é verificado no aparelho de referência definido no plano de implementação (4 GB de RAM, SoC de entrada, Android 10), não em aparelho de topo de linha.

## Assumptions

- As 6 classes listadas estão disponíveis desde o início da conta; a formação limita quantos heróis lutam ao mesmo tempo, não quantos o jogador possui. Classes adicionais são conteúdo pós-lançamento.
- O 4º slot de formação é desbloqueado no nível de conta 25 — marco escolhido como valor de balanceamento inicial, ajustável. O documento de origem não define nenhum marco; define apenas que o Pacote de Início concede "+1 herói extra" e que nada de progressão core pode ficar atrás de paywall.
- A compensação a quem já possuía o 4º slot por compra ao atingir o nível 25 é de **500 gemas**, mesmo valor que o Pacote de Início concede. Valor comercial ajustável, fixado aqui para que os cenários correspondentes sejam verificáveis.
- Critérios de desempenho são medidos em aparelho de referência de entrada (4 GB de RAM, SoC classe Snapdragon 400 ou Helio G, Android 10), não no aparelho de desenvolvimento.
- O multiplicador de dano crítico é 2× o dano calculado, valor não especificado no documento de origem.
- O dano mínimo por golpe é 1, mesmo quando a DEF do monstro excede o ATK do atacante, para evitar travamento de progressão.
- A venda automática ao atingir 50 slots atinge apenas itens Bronze e Prata não equipados e não marcados como favoritos; o jogador pode favoritar itens para protegê-los.
- A taxa de ouro por segundo usada no cálculo offline é derivada do desempenho recente em combate no momento do último save.
- O teto de 8 horas de progresso offline é fixo e não é estendido por anúncios ou compras.
- Não existe estado de derrota permanente: a morte de todos os heróis apenas pausa o avanço até o revive automático.
- O progresso é local ao dispositivo; sincronização em nuvem é opcional e não é requisito desta especificação.
- O jogo não executa combate real em segundo plano; tudo o que ocorre com o app fechado é resolvido pela simulação offline (M09).
- Alvo de plataforma Android API 24+, conforme o documento de origem.
