# M10 — Persistência e Salvamento

**Origem**: `specification.md` §4.5 (Sistema de Salvamento)

**Prioridade**: P1

**Status**: Draft

**Depende de**: nenhuma

## Objetivo

Garantir que o progresso do jogador nunca seja perdido por fechamento do app, encerramento pelo sistema operacional ou falha, e fornecer a base temporal para o cálculo offline.

## Regras

- **R-M10-01**: O estado é salvo automaticamente a cada 30 segundos.
- **R-M10-02**: O estado é salvo sempre que o app é pausado ou vai para segundo plano.
- **R-M10-03**: O salvamento persiste: conta do jogador, heróis, inventário e momento do último save.
- **R-M10-04**: O salvamento não deve interromper nem travar a interface do jogo.
- **R-M10-05**: Na abertura, o último save válido é restaurado integralmente.
- **R-M10-06**: Um save corrompido ou incompleto nunca substitui um save válido anterior.
- **R-M10-07**: O momento do último save é a referência para o cálculo de [M09](M09-progressao-offline.md).
- **R-M10-08**: A perda máxima de progresso em um encerramento inesperado é de 30 segundos.
- **R-M10-09**: Backup em nuvem é opcional e não substitui o salvamento local.

## Cenários

### CEN-M10-001 — Auto-save periódico

- **Given** o jogo em execução em primeiro plano
- **When** 30 segundos se passam desde o último salvamento
- **Then** um novo salvamento é realizado
- **And** o momento do último save é atualizado

### CEN-M10-002 — Salvamento ao pausar o app

- **Given** o jogo em execução em primeiro plano com alterações desde o último auto-save
- **When** o jogador envia o app para segundo plano
- **Then** um salvamento é realizado imediatamente
- **And** o momento do último save reflete esse instante

### CEN-M10-003 — Escopo do que é salvo

- **Given** um salvamento sendo realizado
- **When** o estado é gravado
- **Then** a conta do jogador, os heróis com seus níveis e equipamentos, o inventário e o momento do save são persistidos

### CEN-M10-004 — Restauração na abertura

- **Given** um save válido contendo 3 heróis equipados, 40 itens no inventário e wave 142 do Ato 2
- **When** o jogador abre o app
- **Then** os 3 heróis são restaurados com os mesmos equipamentos e níveis
- **And** os 40 itens estão no inventário
- **And** o jogador retorna ao Ato 2

### CEN-M10-005 — Salvamento não trava a interface

- **Given** um salvamento em andamento
- **When** o jogador interage com a interface
- **Then** a interface permanece responsiva
- **And** nenhuma queda perceptível de fluidez ocorre no combate

### CEN-M10-006 — Encerramento inesperado

- **Given** o app encerrado pelo sistema operacional 25 segundos após o último auto-save
- **When** o jogador reabre o app
- **Then** o estado do último save é restaurado
- **And** no máximo 30 segundos de progresso foram perdidos
- **And** o intervalo não salvo é tratado como tempo offline

### CEN-M10-007 — Save corrompido

- **Given** um salvamento interrompido no meio da gravação
- **When** o jogador reabre o app
- **Then** o último save íntegro anterior é carregado
- **And** o jogador não perde heróis, itens equipados nem progresso de ato

### CEN-M10-008 — Itens equipados persistem

- **Given** um herói com arma, armadura e amuleto equipados
- **When** o app é fechado e reaberto
- **Then** os três itens continuam equipados no mesmo herói
- **And** os atributos efetivos do herói são idênticos aos de antes do fechamento

### CEN-M10-009 — Nós de runa persistem

- **Given** um jogador com 12 nós de runa desbloqueados
- **When** o app é fechado e reaberto
- **Then** os 12 nós continuam desbloqueados
- **And** seus bônus continuam aplicados no combate

### CEN-M10-010 — Backup em nuvem opcional

- **Given** um jogador que não habilitou o backup em nuvem
- **When** ele joga normalmente
- **Then** todo o progresso é salvo e restaurado localmente
- **And** nenhuma funcionalidade de jogo fica indisponível por ausência de conta em nuvem

## Casos de Borda

### CEN-M10-E01 — Fechamento durante a resolução de uma wave

- **Given** uma wave parcialmente concluída
- **When** o app é fechado e reaberto
- **Then** o jogador retorna ao início dessa wave
- **And** ouro, XP e itens já concedidos na wave são preservados

### CEN-M10-E02 — Armazenamento cheio no dispositivo

- **Given** um dispositivo sem espaço disponível para gravação
- **When** o auto-save é acionado
- **Then** o save anterior permanece íntegro
- **And** o jogador é informado da falha ao salvar

### CEN-M10-E03 — Duas instâncias do jogo

- **Given** o jogo aberto e o sistema restaurando uma instância anterior
- **When** ambos tentam salvar
- **Then** apenas um estado consistente é persistido
- **And** nenhuma duplicação de itens ou de ouro ocorre

## Critérios de Sucesso

- **SC-M10-01**: Nenhum encerramento inesperado do app resulta em perda de mais de 30 segundos de progresso.
- **SC-M10-02**: 100% das reaberturas restauram heróis, equipamentos, inventário e progresso de ato sem intervenção do jogador.
- **SC-M10-03**: O salvamento nunca produz queda perceptível de fluidez durante o combate.
- **SC-M10-04**: Nenhum save corrompido substitui um save válido.

## Suposições

- Waves parcialmente concluídas não são persistidas em detalhe; a wave reinicia do começo, preservando as recompensas já concedidas.
- O salvamento é local ao dispositivo por padrão; sincronização em nuvem é opcional e fora do escopo desta especificação.
- O jogo mantém ao menos o save válido anterior para permitir recuperação de gravação corrompida.
