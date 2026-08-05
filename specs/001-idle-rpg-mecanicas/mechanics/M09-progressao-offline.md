# M09 — Progressão Offline

**Origem**: `specification.md` §3.3.G (Sistema de Conta/Progressão Offline), §8 (o jogo não roda em background)

**Prioridade**: P2

**Status**: Draft

**Depende de**: [M10 Persistência](M10-persistencia-salvamento.md), [M01 Combate](M01-combate-automatico.md)

## Objetivo

Recompensar o tempo em que o jogador esteve ausente, simulando o combate ocorrido nesse intervalo, com penalidade que mantenha o jogo ativo mais vantajoso que o jogo passivo.

## Regras

- **R-M09-01**: O tempo offline é a diferença entre o momento atual e o último acesso registrado.
- **R-M09-02**: A simulação considera no máximo 8 horas de ausência.
- **R-M09-03**: O ouro concedido é `ouro_por_segundo × tempo_offline_em_segundos × 0,8`.
- **R-M09-04**: A penalidade de 20% existe para não incentivar o jogo exclusivamente offline.
- **R-M09-05**: A simulação também concede XP, avanço de wave e itens proporcionais ao intervalo.
- **R-M09-06**: Um resumo dos ganhos é exibido ao jogador antes do retorno ao combate.
- **R-M09-07**: Nenhum combate real é executado com o app fechado; tudo é resolvido no retorno.
- **R-M09-08**: Uma notificação push é enviada quando o inventário fica cheio ou quando um item Lendário ou superior é obtido.
- **R-M09-09**: Heróis não morrem permanentemente durante a simulação offline.

## Cenários

### CEN-M09-001 — Cálculo do ouro offline

- **Given** um jogador com taxa de 10 de ouro por segundo no último save
- **And** uma ausência de exatamente 2 horas (7200 segundos)
- **When** ele reabre o app
- **Then** o ouro concedido é `10 × 7200 × 0,8` = 57.600
- **And** esse valor é somado ao ouro existente

### CEN-M09-002 — Penalidade de 20% aplicada

- **Given** um jogador com ganho offline bruto calculado em 100.000 de ouro
- **When** o valor final é apurado
- **Then** o ouro concedido é 80.000

### CEN-M09-003 — Teto de 8 horas

- **Given** um jogador ausente por 12 horas
- **When** ele reabre o app
- **Then** a simulação considera exatamente 8 horas
- **And** o ouro concedido corresponde a 8 horas com a penalidade de 20%

### CEN-M09-004 — Ausência curta

- **Given** um jogador ausente por 45 segundos
- **When** ele reabre o app
- **Then** os ganhos são calculados proporcionalmente a 45 segundos
- **And** nenhum arredondamento concede mais que o proporcional

### CEN-M09-005 — Resumo antes do retorno ao combate

- **Given** uma simulação offline concluída
- **When** o jogador reabre o app
- **Then** um resumo é exibido com ouro ganho, XP ganho, waves avançadas e itens obtidos
- **And** o combate ao vivo só retoma após o jogador dispensar o resumo

### CEN-M09-006 — XP e níveis na simulação

- **Given** uma simulação offline que concede XP suficiente para subir 2 níveis de um herói
- **When** o resumo é gerado
- **Then** os 2 níveis são aplicados ao herói
- **And** as subidas de nível constam do resumo

### CEN-M09-007 — Itens obtidos offline

- **Given** uma simulação offline em que itens foram gerados
- **When** o resumo é exibido
- **Then** os itens estão no inventário, respeitando o limite de 50 slots e a venda automática de [M05](M05-inventario-equipamento.md)
- **And** os itens Lendários ou superiores aparecem destacados no resumo

### CEN-M09-008 — Notificação de item raro

- **Given** um item de raridade Lendária ou superior obtido durante a ausência
- **When** o evento é detectado pelo processamento em segundo plano
- **Then** uma notificação push é enviada ao jogador

### CEN-M09-009 — Notificação de inventário cheio

- **Given** um inventário que atinge a capacidade máxima sem candidatos à venda automática
- **When** o estado é detectado
- **Then** uma notificação push de inventário cheio é enviada

### CEN-M09-010 — Nenhum combate real em segundo plano

- **Given** o app encerrado pelo sistema operacional
- **When** o tempo passa sem que o jogador reabra o app
- **Then** nenhum combate é processado em tempo real
- **And** o estado do jogo permanece o do último save até a próxima reabertura

### CEN-M09-011 — Sem morte permanente offline

- **Given** uma simulação offline em que os heróis enfrentam monstros mais fortes que eles
- **When** a simulação é resolvida
- **Then** nenhum herói é perdido
- **And** o avanço de wave simplesmente estagna no ponto em que o poder deixou de ser suficiente

## Casos de Borda

### CEN-M09-E01 — Relógio adiantado pelo jogador

- **Given** um jogador que adianta o relógio do dispositivo em 30 dias
- **When** ele reabre o app
- **Then** os ganhos concedidos são limitados ao teto de 8 horas

### CEN-M09-E02 — Relógio atrasado pelo jogador

- **Given** um jogador que atrasa o relógio do dispositivo, gerando tempo offline negativo
- **When** ele reabre o app
- **Then** nenhum ganho offline é concedido
- **And** nenhum recurso é subtraído do jogador
- **And** o registro de último acesso é atualizado para o momento atual

### CEN-M09-E03 — Primeira abertura do jogo

- **Given** uma conta recém-criada sem registro de último acesso
- **When** o jogo é aberto pela primeira vez
- **Then** nenhuma simulação offline é executada
- **And** nenhum resumo é exibido

### CEN-M09-E04 — Encerramento entre auto-saves

- **Given** o app encerrado abruptamente 20 segundos após o último auto-save
- **When** o jogador reabre
- **Then** o estado restaurado é o do último save válido
- **And** os 20 segundos não salvos são tratados como tempo offline no cálculo

## Critérios de Sucesso

- **SC-M09-01**: O resumo de progresso offline é apresentado em até 3 segundos após a reabertura, para qualquer ausência de até 8 horas.
- **SC-M09-02**: O ouro concedido offline por hora é sempre menor que o ouro obtido em 1 hora de jogo ativo equivalente.
- **SC-M09-03**: Nenhuma manipulação do relógio do dispositivo concede ganhos acima do teto de 8 horas.
- **SC-M09-04**: 100% dos itens obtidos offline estão disponíveis no inventário após o resumo.

## Suposições

- A taxa de ouro por segundo usada é a apurada no momento do último save, com base no desempenho recente em combate.
- O teto de 8 horas é fixo e não é estendido por anúncios ou compras.
- O avanço de wave offline é limitado pelo poder do jogador no último save; a simulação não assume progressão de equipamento durante a ausência.
- A detecção de eventos para notificação push durante a ausência depende de processamento periódico em segundo plano, sujeito às restrições do sistema operacional.
