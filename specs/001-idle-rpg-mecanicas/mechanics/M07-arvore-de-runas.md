# M07 — Árvore de Runas

**Origem**: `specification.md` §3.3.E (Árvore de Runas)

**Prioridade**: P3

**Status**: Draft

**Depende de**: [M03 Progressão de Conta](M03-progressao-heroi-conta.md)

## Objetivo

Oferecer progressão passiva permanente de conta, com escolhas de longo prazo que definem o estilo de jogo, reversíveis a um custo crescente.

## Regras

- **R-M07-01**: A árvore possui no mínimo 200 nós, dispostos em formato de constelação.
- **R-M07-02**: Pontos de runa são concedidos por nível de conta, nunca por nível de herói.
- **R-M07-03**: Um nó só pode ser desbloqueado se for adjacente a um nó já desbloqueado ou for um nó inicial.
- **R-M07-04**: Desbloquear um nó consome pontos de runa disponíveis.
- **R-M07-05**: Os efeitos dos nós incluem bônus percentuais de dano, ouro e XP, além de regras especiais de combate (por exemplo, "o primeiro ataque de cada wave é crítico").
- **R-M07-06**: Os bônus de nós desbloqueados são aplicados a todos os heróis da conta.
- **R-M07-07**: O respec devolve todos os pontos gastos e custa ouro.
- **R-M07-08**: O custo do respec cresce a cada respec já realizado pela conta.

## Cenários

### CEN-M07-001 — Ponto de runa disponível para gasto

- **Given** uma conta que acabou de subir de nível e recebeu pontos de runa
- **When** o jogador abre a árvore de runas
- **Then** a quantidade de pontos disponíveis é exibida
- **And** os nós desbloqueáveis no momento são destacados

### CEN-M07-002 — Desbloqueio de nó adjacente

- **Given** um jogador com 1 ponto de runa disponível e um nó adjacente a um nó já desbloqueado
- **When** ele desbloqueia esse nó
- **Then** o ponto é consumido
- **And** o nó passa ao estado desbloqueado
- **And** o efeito do nó passa a valer imediatamente em combate

### CEN-M07-003 — Nó não adjacente é recusado

- **Given** um jogador com pontos disponíveis e um nó isolado, sem vizinho desbloqueado
- **When** ele tenta desbloquear esse nó
- **Then** a operação é recusada
- **And** nenhum ponto é consumido
- **And** o jogador é informado do requisito de adjacência

### CEN-M07-004 — Pontos insuficientes

- **Given** um jogador com 0 pontos de runa disponíveis
- **When** ele tenta desbloquear qualquer nó
- **Then** a operação é recusada
- **And** nenhum nó muda de estado

### CEN-M07-005 — Bônus percentual afeta o combate

- **Given** um nó que concede +10% de dano e um herói causando 100 de dano por golpe
- **When** o nó é desbloqueado
- **Then** o mesmo herói passa a causar 110 de dano por golpe

### CEN-M07-006 — Bônus de ouro e XP

- **Given** nós desbloqueados que concedem +10% de ouro e +10% de XP
- **When** um monstro é derrotado
- **Then** o ouro e o XP concedidos são 10% maiores que os valores base

### CEN-M07-007 — Nó com regra especial de combate

- **Given** um nó desbloqueado com o efeito "o primeiro ataque de cada wave é crítico"
- **When** uma nova wave inicia e um herói realiza seu primeiro ataque
- **Then** esse ataque é resolvido como crítico, independentemente do sorteio de chance

### CEN-M07-008 — Bônus valem para toda a conta

- **Given** nós desbloqueados que concedem bônus de dano
- **When** o jogador troca os heróis da formação
- **Then** os novos heróis também recebem os bônus dos nós desbloqueados

### CEN-M07-009 — Respec devolve pontos

- **Given** um jogador com 12 pontos gastos na árvore e ouro suficiente para o respec
- **When** ele confirma o respec
- **Then** o ouro do custo é debitado
- **And** os 12 pontos voltam a ficar disponíveis
- **And** todos os nós antes desbloqueados voltam ao estado bloqueado

### CEN-M07-010 — Custo do respec cresce

- **Given** um jogador que já realizou 2 respecs
- **When** ele consulta o custo do terceiro respec
- **Then** o custo exibido é maior que o cobrado no segundo respec

### CEN-M07-011 — Respec sem ouro suficiente

- **Given** um jogador com ouro menor que o custo do respec
- **When** ele tenta confirmar o respec
- **Then** a operação é recusada
- **And** nenhum ouro é debitado
- **And** nenhum ponto de runa é devolvido

### CEN-M07-012 — Efeitos removidos após respec

- **Given** um jogador com +10% de dano ativo por um nó desbloqueado
- **When** ele realiza um respec
- **Then** o bônus de dano deixa de ser aplicado no combate imediatamente

## Casos de Borda

### CEN-M07-E01 — Desbloqueio que desconectaria a árvore

- **Given** uma sequência de nós desbloqueados formando um caminho
- **When** o jogador tenta desbloquear apenas o nó final sem os intermediários
- **Then** a operação é recusada por falta de adjacência
- **And** o caminho permanece intacto

### CEN-M07-E02 — Árvore totalmente desbloqueada

- **Given** um jogador que desbloqueou todos os nós da árvore
- **When** ele recebe novos pontos de runa por nível de conta
- **Then** os pontos permanecem acumulados como disponíveis
- **And** nenhum erro ocorre ao abrir a árvore

### CEN-M07-E03 — Respec durante combate ativo

- **Given** um combate em andamento
- **When** o jogador conclui um respec
- **Then** os atributos e regras especiais são recalculados sem interromper a wave
- **And** nenhum herói é morto ou revivido pelo recálculo

## Critérios de Sucesso

- **SC-M07-01**: A árvore disponibiliza no mínimo 200 nós desbloqueáveis.
- **SC-M07-02**: O efeito de um nó recém-desbloqueado é observável no combate em até 1 wave.
- **SC-M07-03**: Nenhum respec resulta em pontos perdidos ou nós presos em estado inconsistente.
- **SC-M07-04**: O custo do respec é sempre exibido antes da confirmação.

## Suposições

- Nós iniciais (raízes) existem e não exigem adjacência; o documento de origem não descreve o ponto de entrada da árvore.
- Cada nó custa 1 ponto de runa por padrão; o documento de origem não define custos por nó.
- A progressão do custo de respec é crescente e monotônica; a fórmula exata não consta do documento de origem.
- Gemas premium podem acelerar ou baratear o respec conforme [M12](M12-monetizacao-recompensas.md), sem tornar nós inacessíveis a jogadores não pagantes.
