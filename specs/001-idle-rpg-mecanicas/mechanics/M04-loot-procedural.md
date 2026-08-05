# M04 — Loot Procedural

**Origem**: `specification.md` §3.3.C (Sistema de Loot), §4.3 (modelos GameItem e Monster)

**Prioridade**: P1

**Status**: Draft

**Depende de**: [M01 Combate](M01-combate-automatico.md), [M08 Atos e Waves](M08-atos-waves-dificuldades.md)

## Objetivo

Gerar itens de equipamento proceduralmente a partir das mortes de monstros, com raridade, item level e afixos variáveis, criando o laço de recompensa contínua do jogo.

## Regras

- **R-M04-01**: Existem 7 tipos de item: Arma, Armadura, Elmo, Luvas, Botas, Amuleto e Anel.
- **R-M04-02**: Existem 8 raridades, em ordem crescente: Bronze → Prata → Ouro → Épico → Lendário → Mítico → Transcendental → Cósmico.
- **R-M04-03**: Todo item possui exatamente 1 prefixo principal (por exemplo +ATK, +DEF, +HP), determinado pelo seu tipo.
- **R-M04-04**: Todo item possui de 0 a 3 sufixos aleatórios (por exemplo +% crítico, +velocidade, +resistência a fogo).
- **R-M04-05**: O item level (iLv) do item escala com a wave em que ele foi obtido.
- **R-M04-06**: Um item de iLv mais alto tem atributo base superior ao de um item de mesmo tipo e raridade com iLv mais baixo.
- **R-M04-07**: Raridades mais altas admitem mais sufixos e valores maiores.
- **R-M04-08**: Cada monstro define as raridades possíveis de drop e um modificador de chance de drop.
- **R-M04-09**: Itens dropados entram no inventário automaticamente, sem ação do jogador.
- **R-M04-10**: Todo item registra o momento em que foi obtido.
- **R-M04-11**: Waves de boss concedem ao menos 1 item garantido.
- **R-M04-12**: Além de itens, monstros podem conceder **Essências** — consumíveis raros usados no Cubo ([M06](M06-cubo-crafting.md)). Cada Essência carrega o tipo de sufixo que garante.
- **R-M04-13**: A chance de drop de Essência é independente da chance de drop de item; um mesmo monstro pode conceder ambos, um só ou nenhum.

## Cenários

### CEN-M04-001 — Drop automático ao derrotar monstro

- **Given** um monstro cuja tabela de drops é avaliada com sucesso
- **When** o monstro é derrotado
- **Then** um item é gerado
- **And** o item entra no inventário automaticamente
- **And** o jogador não precisa tocar em nada para coletá-lo

### CEN-M04-002 — Estrutura mínima do item gerado

- **Given** um evento de drop confirmado
- **When** o item é gerado
- **Then** o item possui identificador único, tipo, raridade, item level, atributo base, lista de sufixos e momento do drop

### CEN-M04-003 — Prefixo coerente com o tipo

- **Given** um drop do tipo Arma
- **When** o item é gerado
- **Then** o prefixo principal é de ataque (+ATK)
- **And** um drop do tipo Armadura recebe prefixo de defesa (+DEF)

### CEN-M04-004 — Quantidade de sufixos dentro do intervalo

- **Given** qualquer item gerado por drop
- **When** os sufixos são sorteados
- **Then** a quantidade de sufixos está entre 0 e 3, inclusive
- **And** nenhum sufixo se repete no mesmo item

### CEN-M04-005 — Item level escala com a wave

- **Given** um item obtido na wave 10 e outro do mesmo tipo e raridade obtido na wave 500
- **When** os itens são comparados
- **Then** o item da wave 500 tem item level maior
- **And** seu atributo base é significativamente superior

### CEN-M04-006 — Raridade influencia o poder

- **Given** dois itens de mesmo tipo e mesmo item level, um Bronze e um Lendário
- **When** os itens são comparados
- **Then** o item Lendário tem atributo base maior
- **And** tende a ter mais sufixos

### CEN-M04-007 — Ordem das raridades

- **Given** a escala de raridades do jogo
- **When** duas raridades quaisquer são comparadas
- **Then** a ordem respeitada é Bronze < Prata < Ouro < Épico < Lendário < Mítico < Transcendental < Cósmico
- **And** cada raridade é apresentada com nome e cor próprios

### CEN-M04-008 — Tabela de drops do monstro é respeitada

- **Given** um monstro cuja lista de raridades possíveis vai de Bronze a Ouro
- **When** ele é derrotado repetidamente e gera drops
- **Then** nenhum item de raridade Épica ou superior é gerado por esse monstro

### CEN-M04-009 — Modificador de chance de drop

- **Given** dois monstros idênticos exceto pelo modificador de chance de drop
- **When** ambos são derrotados a mesma quantidade de vezes
- **Then** o monstro com modificador maior gera mais itens no total

### CEN-M04-010 — Drop garantido em boss

- **Given** uma wave de boss em andamento
- **When** o boss é derrotado
- **Then** ao menos 1 item é gerado independentemente do sorteio de chance

### CEN-M04-011 — Notificação de item raro

- **Given** um drop de raridade Lendária ou superior
- **When** o item é gerado
- **Then** um destaque visual de loot raro é exibido no jogo
- **And** o item é registrado como último item raro obtido para o widget descrito em [M11](M11-widget-notificacao.md)

### CEN-M04-012 — Dificuldade aumenta o item level

- **Given** a mesma wave jogada na dificuldade 1 e na dificuldade 2
- **When** itens são obtidos em ambas
- **Then** os itens da dificuldade 2 têm item level 10 pontos maior

### CEN-M04-013 — Drop de Essência

- **Given** um monstro cuja avaliação de chance de Essência é bem-sucedida
- **When** o monstro é derrotado
- **Then** uma Essência é gerada com um tipo de sufixo garantido definido
- **And** ela entra no inventário automaticamente, sem ocupar slot de equipamento
- **And** fica disponível para uso no Cubo conforme [M06](M06-cubo-crafting.md)

## Casos de Borda

### CEN-M04-E01 — Monstro derrotado sem drop

- **Given** um monstro cuja avaliação de chance de drop falha
- **When** ele é derrotado
- **Then** nenhum item é gerado
- **And** ouro e XP ainda são concedidos normalmente

### CEN-M04-E02 — Drop com inventário cheio

- **Given** um inventário sem espaço e sem itens elegíveis para venda automática
- **When** um item é dropado
- **Then** o item é retido em vez de descartado silenciosamente
- **And** o jogador é notificado de inventário cheio conforme [M05](M05-inventario-equipamento.md)

### CEN-M04-E03 — Item de raridade máxima

- **Given** um drop sorteado como Cósmico
- **When** o item é gerado
- **Then** ele é criado normalmente com a raridade máxima
- **And** nenhuma tentativa de promover a raridade além de Cósmico ocorre

## Critérios de Sucesso

- **SC-M04-01**: Um jogador obtém ao menos 1 item nos primeiros 3 minutos de jogo sem intervenção.
- **SC-M04-02**: Dois itens do mesmo tipo e raridade obtidos em sessões diferentes apresentam combinações de sufixos distintas em ao menos 80% dos casos.
- **SC-M04-03**: O jogador consegue distinguir a raridade de um item à primeira vista, por nome e cor.

## Suposições

- A fórmula exata de conversão de wave em item level não consta do documento de origem; assume-se relação monotônica crescente.
- A distribuição de probabilidade entre raridades não consta do documento de origem e é decisão de balanceamento.
- A taxa de drop de Essência não consta do documento de origem, que a descreve apenas como "drop raro" em §3.3.D; é decisão de balanceamento. Essências não ocupam slot do limite de 50 itens do inventário.
- Itens não são dropados no chão para coleta manual; o auto-loot é a única forma de aquisição por combate, conforme §3.3.C.
