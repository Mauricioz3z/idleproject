# M03 — Progressão de Herói e Conta

**Origem**: `specification.md` §3.2 (Loop Principal), §3.3.E (pontos por nível de conta), §4.3 (modelos Hero e PlayerAccount)

**Prioridade**: P1

**Status**: Draft

**Depende de**: [M01 Combate](M01-combate-automatico.md)

## Objetivo

Separar duas trilhas de progressão: o nível do herói (poder de combate e habilidades) e o nível de conta (pontos de runa e registros de recorde), de modo que o jogador sempre avance em alguma delas.

## Regras

- **R-M03-01**: Heróis ganham XP por monstro derrotado enquanto estiverem na formação.
- **R-M03-02**: Ao acumular XP igual ou superior ao XP necessário para o próximo nível, o herói sobe de nível e o excedente é mantido.
- **R-M03-03**: Subir de nível aumenta os atributos do herói (STR, DEX, INT, VIT, AGI) conforme sua classe.
- **R-M03-04**: Habilidades são desbloqueadas ao atingir níveis específicos do herói.
- **R-M03-05**: A conta possui nível próprio, independente do nível dos heróis.
- **R-M03-06**: Cada nível de conta concede pontos de runa, usados em [M07](M07-arvore-de-runas.md).
- **R-M03-07**: A conta registra maior wave, maior ato e maior dificuldade alcançados.
- **R-M03-08**: Registros de recorde nunca regridem.
- **R-M03-09**: A conta registra quantos slots de formação estão desbloqueados: 3 por padrão e 4 a partir do nível de conta 25.
- **R-M03-10**: O 4º slot, uma vez desbloqueado, é permanente e nunca é revogado.
- **R-M03-11**: Quem já possui o 4º slot por compra recebe 500 gemas ao atingir o nível 25, em vez de um slot duplicado.

## Cenários

### CEN-M03-001 — Ganho de XP por vitória

- **Given** um herói na formação com XP atual conhecido
- **When** um monstro é derrotado
- **Then** o XP do herói aumenta
- **And** a barra de XP exibida reflete o novo valor

### CEN-M03-002 — Subida de nível do herói

- **Given** um herói de nível 4 com XP a 1 ponto do XP necessário para o nível 5
- **When** ele recebe 10 pontos de XP
- **Then** o herói passa para o nível 5
- **And** o XP excedente de 9 pontos é mantido no novo nível
- **And** o XP necessário para o nível 6 é maior que o exigido para o nível 5

### CEN-M03-003 — Atributos aumentam ao subir de nível

- **Given** um herói prestes a subir de nível, com atributos registrados
- **When** ele sobe de nível
- **Then** ao menos um atributo aumenta
- **And** o atributo principal da classe do herói é o que mais aumenta

### CEN-M03-004 — Desbloqueio de habilidade

- **Given** um herói que atinge o nível exigido por uma habilidade ainda não desbloqueada
- **When** a subida de nível é concluída
- **Then** a habilidade passa a constar na lista de habilidades desbloqueadas do herói
- **And** passa a ser usada automaticamente em combate

### CEN-M03-005 — XP não é concedido a heróis fora da formação

- **Given** um herói possuído mas não atribuído à formação ativa
- **When** monstros são derrotados
- **Then** o XP desse herói permanece inalterado

### CEN-M03-006 — Herói incapacitado ainda recebe XP da wave

- **Given** um herói da formação com HP zerado aguardando revive
- **When** os demais heróis derrotam um monstro
- **Then** o herói incapacitado também recebe o XP correspondente

### CEN-M03-007 — Nível de conta é independente do nível de herói

- **Given** um herói que sobe do nível 9 para o nível 10
- **When** a subida de nível do herói é concluída
- **Then** o nível de conta permanece inalterado
- **And** nenhum ponto de runa é concedido por essa subida

### CEN-M03-008 — Ponto de runa por nível de conta

- **Given** uma conta prestes a subir de nível, com N pontos de runa disponíveis
- **When** a conta sobe de nível
- **Then** os pontos de runa disponíveis passam a ser maiores que N
- **And** os pontos ficam imediatamente utilizáveis na árvore de runas

### CEN-M03-009 — Registro de maior wave

- **Given** uma conta cuja maior wave registrada é 142
- **When** o jogador completa a wave 143
- **Then** a maior wave registrada passa a ser 143

### CEN-M03-010 — Recordes não regridem

- **Given** uma conta cuja maior wave registrada é 143
- **When** o jogador reinicia o ato e passa a jogar a wave 5
- **Then** a maior wave registrada permanece 143

### CEN-M03-011 — Desbloqueio gratuito do 4º slot de formação

- **Given** um jogador de nível de conta 24 com 3 slots de formação e que nunca realizou nenhuma compra
- **When** a conta atinge o nível 25
- **Then** o 4º slot de formação é desbloqueado sem qualquer pagamento
- **And** o jogador é notificado do desbloqueio
- **And** ele pode posicionar um quarto herói na formação

### CEN-M03-012 — Slot já antecipado por compra

- **Given** um jogador que adquiriu o Pacote de Início e já possui o 4º slot antes do nível 25
- **When** a conta atinge o nível 25
- **Then** nenhum slot adicional é concedido
- **And** o limite de formação permanece 4
- **And** 500 gemas são concedidas como compensação no lugar do slot duplicado

### CEN-M03-013 — Permanência do 4º slot

- **Given** um jogador com o 4º slot desbloqueado
- **When** ele realiza um respec, avança de dificuldade ou reinstala o app restaurando o save
- **Then** o 4º slot permanece desbloqueado

### CEN-M03-014 — Registro de último acesso

- **Given** o jogador encerrando a sessão
- **When** o estado é salvo
- **Then** o momento do último acesso é registrado na conta
- **And** esse registro é a base do cálculo de [M09](M09-progressao-offline.md)

## Casos de Borda

### CEN-M03-E01 — Múltiplos níveis em um único ganho de XP

- **Given** um herói de nível 3 que recebe XP suficiente para ultrapassar os níveis 4 e 5
- **When** o XP é aplicado
- **Then** o herói passa diretamente para o nível 5
- **And** todos os ganhos de atributo dos níveis intermediários são aplicados
- **And** todas as habilidades dos níveis intermediários são desbloqueadas

### CEN-M03-E02 — XP ganho durante a simulação offline

- **Given** um jogador retornando após ausência
- **When** a simulação offline é resolvida
- **Then** o XP acumulado é aplicado aos heróis da formação e os níveis resultantes são concedidos
- **And** as subidas de nível aparecem no resumo offline

## Critérios de Sucesso

- **SC-M03-01**: Um jogador novo sobe o primeiro nível de herói em até 2 minutos de jogo sem intervenção.
- **SC-M03-02**: O jogador consegue identificar, em uma única tela, o nível de cada herói, o nível da conta e os pontos de runa disponíveis.
- **SC-M03-03**: Nenhum evento de progressão reduz um recorde registrado da conta.

## Suposições

- A fonte de XP da conta é derivada do progresso de combate (monstros derrotados e waves completadas); o documento de origem não define a fórmula.
- A quantidade de pontos de runa por nível de conta não consta do documento de origem; assume-se ao menos 1 por nível.
- O nível de conta 25 como marco do 4º slot é um valor de balanceamento inicial, ajustável; o documento de origem não define nenhum marco.
- A compensação por slot já antecipado via compra (CEN-M03-012) é de 500 gemas, mesmo valor concedido pelo Pacote de Início. Valor comercial ajustável, fixado para tornar o cenário verificável.
- Heróis fora da formação não acumulam XP — o documento de origem não trata do caso, e esta é a convenção do gênero.
