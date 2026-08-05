# M02 — Classes de Heróis

**Origem**: `specification.md` §3.3.B (Sistema de Classes)

**Prioridade**: P2

**Status**: Draft

**Depende de**: [M01 Combate](M01-combate-automatico.md)

## Objetivo

Seis classes com papéis, atributos principais e mecânicas únicas distintos, para que a composição da formação seja uma decisão significativa do jogador.

## Regras

- **R-M02-01**: Existem 6 classes jogáveis: Vanguard, Elementalist, Sharpshooter, Medtech, Tracker e Berserker.
- **R-M02-02**: Cada classe tem um papel, um ou dois atributos principais e uma mecânica única.
- **R-M02-03**: Os atributos de personagem são: STR (força), DEX (destreza), INT (inteligência), VIT (vitalidade) e AGI (agilidade).
- **R-M02-04**: A mecânica única de cada classe está sempre ativa em combate, sem ativação manual.
- **R-M02-05**: As 6 classes estão disponíveis desde o início da conta.

### Tabela de Classes

| Classe | Papel | Atributo Principal | Mecânica Única |
|--------|-------|--------------------|----------------|
| Vanguard | Tanque | DEF/VIT | Provoca inimigos e reduz dano em área |
| Elementalist | Dano mágico | INT | Ataques em área com elementos (fogo/gelo/raio) |
| Sharpshooter | Dano físico à distância | DEX | Alta chance de crítico e ignora parte da DEF |
| Medtech | Suporte | INT/VIT | Cura o time e concede buff de velocidade de ataque |
| Tracker | Dano físico corpo a corpo | AGI | Ataques rápidos e sangramento (dano ao longo do tempo) |
| Berserker | Dano bruto | STR | Dano aumenta conforme o HP diminui |

## Cenários

### CEN-M02-001 — Classes disponíveis desde o início

- **Given** uma conta recém-criada
- **When** o jogador abre a tela de seleção de heróis
- **Then** as 6 classes são exibidas como disponíveis
- **And** nenhuma delas exige pagamento, anúncio ou progressão para ser usada

### CEN-M02-002 — Vanguard atrai o dano

- **Given** uma formação com um Vanguard e ao menos um herói não-tanque
- **When** os monstros escolhem alvos
- **Then** o Vanguard é priorizado como alvo pelos monstros
- **And** o dano em área recebido pelos demais heróis da formação é reduzido

### CEN-M02-003 — Elementalist atinge múltiplos alvos

- **Given** um Elementalist na formação e 3 monstros vivos agrupados na wave
- **When** o Elementalist realiza um ataque
- **Then** os 3 monstros na área do ataque recebem dano
- **And** o efeito elemental correspondente é aplicado

### CEN-M02-004 — Sharpshooter ignora parte da defesa

- **Given** um Sharpshooter atacando um monstro com DEF 50
- **When** o dano é calculado
- **Then** apenas uma parcela da DEF do monstro é subtraída do dano
- **And** o dano resultante é maior que o de uma classe sem penetração de defesa com o mesmo ATK

### CEN-M02-005 — Sharpshooter tem crítico elevado

- **Given** um Sharpshooter e um Tracker com os mesmos itens equipados
- **When** as chances de crítico efetivas são comparadas
- **Then** a chance do Sharpshooter é maior

### CEN-M02-006 — Medtech cura e acelera o time

- **Given** um Medtech na formação e ao menos um herói aliado com HP abaixo do máximo
- **When** o Medtech age em combate
- **Then** o herói ferido recupera HP
- **And** os heróis da formação recebem buff de velocidade de ataque

### CEN-M02-007 — Tracker aplica sangramento

- **Given** um Tracker atacando um monstro
- **When** o golpe acerta
- **Then** o monstro recebe dano imediato
- **And** passa a sofrer dano ao longo do tempo por sangramento
- **And** o dano do sangramento é exibido como número flutuante enquanto durar

### CEN-M02-008 — Berserker escala com HP baixo

- **Given** um Berserker com 100% de HP causando dano X por golpe
- **When** o HP do Berserker cai para 30% do máximo
- **Then** o dano por golpe passa a ser maior que X
- **And** o aumento é proporcional à perda de HP

### CEN-M02-009 — Atributo principal influencia o desempenho

- **Given** dois heróis da mesma classe com níveis iguais
- **When** um deles tem o atributo principal da classe mais alto por equipamento
- **Then** o herói com o atributo principal mais alto apresenta desempenho superior no papel da sua classe

### CEN-M02-010 — Composição livre da formação

- **Given** as 6 classes disponíveis e o limite de slots de formação atual do jogador
- **When** o jogador monta a formação
- **Then** qualquer combinação de classes até o limite de slots é aceita
- **And** classes repetidas são permitidas
- **And** nenhuma classe é obrigatória na formação

## Casos de Borda

### CEN-M02-E01 — Formação sem tanque

- **Given** uma formação de 3 heróis sem nenhum Vanguard
- **When** o combate ocorre
- **Then** o combate prossegue normalmente
- **And** os monstros escolhem alvos pela sua regra padrão, sem priorização por provocação

### CEN-M02-E02 — Medtech sozinho na formação

- **Given** uma formação contendo apenas um Medtech
- **When** o combate ocorre
- **Then** o Medtech ainda ataca monstros e cura a si mesmo
- **And** a wave progride, ainda que mais lentamente

## Critérios de Sucesso

- **SC-M02-01**: Cada uma das 6 classes tem ao menos um efeito observável em combate que nenhuma outra classe produz.
- **SC-M02-02**: Trocar uma classe da formação por outra altera de forma perceptível o tempo médio para limpar uma wave.
- **SC-M02-03**: 100% das classes iniciais são jogáveis sem pagamento ou visualização de anúncio.

## Suposições

- Todas as 6 classes começam desbloqueadas; o documento de origem as descreve como "6 iniciais" e reserva classes adicionais para DLC pós-lançamento.
- A regra de alvo de cada classe (mais próximo ou menor HP) é definida por classe, conforme §3.3.A; os valores exatos por classe não constam do documento de origem e serão definidos no balanceamento.
- Valores numéricos de cura, duração de sangramento, penetração de defesa e escala do Berserker não constam do documento de origem e são decisões de balanceamento.
