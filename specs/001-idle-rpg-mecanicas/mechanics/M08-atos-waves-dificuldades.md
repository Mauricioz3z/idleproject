# M08 — Atos, Waves e Dificuldades

**Origem**: `specification.md` §3.3.A (Progressão de Wave), §3.3.F (Sistema de Ato e Dificuldade)

**Prioridade**: P1

**Status**: Draft

**Depende de**: [M01 Combate](M01-combate-automatico.md)

## Objetivo

Estruturar o conteúdo em waves, atos e dificuldades encadeadas, criando progressão de curto prazo (wave), médio prazo (ato) e longo prazo (dificuldade infinita).

## Regras

- **R-M08-01**: Existem 3 atos: Floresta, Caverna e Castelo/Cidadela.
- **R-M08-02**: Cada ato contém 100 waves.
- **R-M08-03**: A cada 10 waves ocorre uma wave de boss, com loot garantido.
- **R-M08-04**: A wave 100 de cada ato é a wave de boss final do ato.
- **R-M08-05**: Uma wave é concluída quando todos os seus monstros são derrotados; a wave seguinte inicia automaticamente.
- **R-M08-06**: Os atributos dos monstros crescem conforme o número da wave e o ato.
- **R-M08-07**: Completar a wave 100 do Ato 3 desbloqueia a dificuldade seguinte.
- **R-M08-08**: A cada dificuldade, todos os atributos dos monstros são multiplicados por 1,5 e o item level do loot recebe +10.
- **R-M08-09**: Não há limite superior de dificuldades; o escalonamento é procedural.
- **R-M08-10**: Ao iniciar uma nova dificuldade, o jogador retorna ao Ato 1, wave 1, mantendo heróis, itens, níveis e runas.
- **R-M08-11**: O jogador pode retornar a atos e dificuldades já concluídos.

## Cenários

### CEN-M08-001 — Avanço automático de wave

- **Given** uma wave com o último monstro vivo
- **When** esse monstro é derrotado
- **Then** a wave é marcada como concluída
- **And** a wave seguinte inicia automaticamente com novos monstros
- **And** nenhuma ação do jogador é exigida entre as waves

### CEN-M08-002 — Wave de boss a cada 10 waves

- **Given** o jogador na wave 9 do Ato 1
- **When** a wave 9 é concluída
- **Then** a wave 10 inicia como wave de boss
- **And** o boss é visualmente distinto dos monstros comuns

### CEN-M08-003 — Loot garantido em boss

- **Given** uma wave de boss em andamento
- **When** o boss é derrotado
- **Then** ao menos 1 item é concedido independentemente do sorteio de chance de drop

### CEN-M08-004 — Escalonamento de monstros dentro do ato

- **Given** um monstro do mesmo tipo enfrentado na wave 5 e na wave 95 do mesmo ato
- **When** seus atributos são comparados
- **Then** o monstro da wave 95 tem HP, ATK e DEF maiores

### CEN-M08-005 — Transição entre atos

- **Given** o jogador concluindo a wave 100 do Ato 1
- **When** o boss final do ato é derrotado
- **Then** o Ato 2 é desbloqueado e inicia na wave 1
- **And** o cenário muda para o ambiente do Ato 2

### CEN-M08-006 — Desbloqueio de nova dificuldade

- **Given** o jogador na dificuldade 1 concluindo a wave 100 do Ato 3
- **When** o boss final é derrotado
- **Then** a dificuldade 2 é desbloqueada
- **And** o registro de maior dificuldade da conta é atualizado

### CEN-M08-007 — Escalonamento de monstros por dificuldade

- **Given** um monstro da wave 10 do Ato 1 na dificuldade 1 com HP 100, ATK 20 e DEF 10
- **When** o mesmo monstro é enfrentado na dificuldade 2
- **Then** seus atributos passam a ser HP 150, ATK 30 e DEF 15

### CEN-M08-008 — Melhoria de loot por dificuldade

- **Given** um item obtido na wave 10 do Ato 1 na dificuldade 1 com item level X
- **When** um item é obtido na mesma wave na dificuldade 2
- **Then** o item level é X + 10

### CEN-M08-009 — Progresso preservado na nova dificuldade

- **Given** o jogador iniciando a dificuldade 2
- **When** ele retorna ao Ato 1, wave 1
- **Then** os níveis dos heróis, os itens do inventário, os equipamentos e os nós de runa permanecem inalterados

### CEN-M08-010 — Dificuldades ilimitadas

- **Given** um jogador que concluiu a dificuldade 10
- **When** o boss final do Ato 3 é derrotado
- **Then** a dificuldade 11 é desbloqueada com o mesmo escalonamento aplicado sobre a anterior
- **And** nenhum teto de dificuldade impede a progressão

### CEN-M08-011 — Retorno a conteúdo já concluído

- **Given** um jogador com Ato 3 e dificuldade 2 desbloqueados
- **When** ele escolhe jogar o Ato 1 na dificuldade 1
- **Then** o combate ocorre com os atributos correspondentes a esse ato e dificuldade
- **And** os registros de maior ato e maior dificuldade da conta não regridem

### CEN-M08-012 — Registro de maior wave

- **Given** um jogador que alcança uma wave superior ao seu recorde
- **When** a wave é concluída
- **Then** o recorde de maior wave da conta é atualizado

## Casos de Borda

### CEN-M08-E01 — Wave travada por poder insuficiente

- **Given** uma wave cujos monstros têm DEF superior ao ATK de todos os heróis
- **When** o combate prossegue
- **Then** o dano mínimo de 1 por golpe garante progresso lento, sem travamento absoluto
- **And** o jogador pode retornar a um ato ou dificuldade anterior para farmar

### CEN-M08-E02 — Boss derrotado com todos os heróis mortos em seguida

- **Given** o boss final de um ato derrotado no mesmo instante em que todos os heróis morrem
- **When** o resultado é resolvido
- **Then** a conclusão do ato é registrada
- **And** o loot garantido é concedido
- **And** o revive automático ocorre normalmente

### CEN-M08-E03 — Fechamento do app no meio de uma wave

- **Given** uma wave parcialmente concluída
- **When** o app é fechado e reaberto
- **Then** o jogador retorna ao início da wave em que estava
- **And** o progresso de ato e dificuldade é preservado

## Critérios de Sucesso

- **SC-M08-01**: A progressão da wave 1 até a wave 100 do Ato 1 é possível sem qualquer decisão obrigatória do jogador além de equipar itens.
- **SC-M08-02**: O jogador identifica ato, wave atual e dificuldade em uma única tela, sem navegação adicional.
- **SC-M08-03**: Cada wave múltipla de 10 apresenta um boss, sem exceção, em todos os atos e dificuldades.
- **SC-M08-04**: Não existe wave, ato ou dificuldade que impeça permanentemente o avanço do jogador.

## Suposições

- Ao entrar em uma nova dificuldade, o jogador reinicia no Ato 1 wave 1 — o documento de origem descreve o desbloqueio, mas não o ponto de entrada.
- Waves parcialmente concluídas não são persistidas; a wave reinicia do começo após reabertura, conforme [M10](M10-persistencia-salvamento.md).
- A composição de monstros por wave e a curva exata de escalonamento dentro do ato são decisões de balanceamento não definidas no documento de origem.
- O multiplicador de 1,5 por dificuldade é cumulativo em relação à dificuldade imediatamente anterior.
