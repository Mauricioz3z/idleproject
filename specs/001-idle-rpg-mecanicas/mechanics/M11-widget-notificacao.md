# M11 — Widget e Notificação Persistente

**Origem**: `specification.md` §1.1 (nota sobre a taskbar), §3.1 (Diferencial), §4.6 (Widget Android e Notificação Persistente)

**Prioridade**: P2

**Status**: Draft

**Depende de**: [M10 Persistência](M10-persistencia-salvamento.md), [M09 Progressão Offline](M09-progressao-offline.md)

## Objetivo

Tornar o estado do jogo visível fora do app — o equivalente Android da janela fixa na barra de tarefas —, permitindo que o jogador acompanhe o progresso sem abrir o jogo.

## Regras

- **R-M11-01**: O jogo oferece um widget para a tela inicial do dispositivo.
- **R-M11-02**: O widget é atualizado a cada 1 minuto.
- **R-M11-03**: O widget exibe: ouro por segundo, wave atual, melhor herói e o último item Lendário ou superior obtido.
- **R-M11-04**: Tocar no widget abre o app diretamente na tela de combate.
- **R-M11-05**: Com o app em segundo plano, uma notificação persistente é exibida.
- **R-M11-06**: A notificação persistente exibe título com nome do jogo, wave e ato, e subtexto com número de heróis em combate e ouro por minuto.
- **R-M11-07**: A notificação persistente oferece as ações "Abrir" e "Coletar Loot", ambas abrindo o app.
- **R-M11-08**: Notificações push são enviadas quando o inventário fica cheio ou quando um item Lendário ou superior é obtido.
- **R-M11-09**: O widget e a notificação refletem o estado salvo, não um combate em tempo real.
- **R-M11-10**: O jogador pode desativar a notificação persistente sem perder progresso.

## Cenários

### CEN-M11-001 — Conteúdo do widget

- **Given** o widget adicionado à tela inicial e um estado salvo válido
- **When** o ciclo de atualização ocorre
- **Then** o widget exibe ouro por segundo, wave atual, melhor herói e o último item Lendário ou superior obtido

### CEN-M11-002 — Frequência de atualização do widget

- **Given** o widget na tela inicial e o app em segundo plano
- **When** 1 minuto se passa
- **Then** o widget é atualizado com o estado mais recente
- **And** a defasagem em relação ao estado salvo nunca excede 1 minuto

### CEN-M11-003 — Toque no widget abre o combate

- **Given** o widget exibido na tela inicial
- **When** o jogador toca no widget
- **Then** o app é aberto
- **And** a tela exibida é a de combate, sem passar por menus intermediários

### CEN-M11-004 — Notificação persistente em segundo plano

- **Given** o app enviado para segundo plano
- **When** o jogador abre a gaveta de notificações
- **Then** existe uma notificação persistente com a wave e o ato atuais no título
- **And** o subtexto informa quantos heróis estão em combate e o ouro por minuto

### CEN-M11-005 — Ações da notificação

- **Given** a notificação persistente exibida
- **When** o jogador toca em "Abrir"
- **Then** o app é aberto na tela de combate

### CEN-M11-006 — Ação de coletar loot

- **Given** a notificação persistente exibida
- **When** o jogador toca em "Coletar Loot"
- **Then** o app é aberto
- **And** o resumo de ganhos offline é exibido, quando houver

### CEN-M11-007 — Notificação push de item raro

- **Given** um item de raridade Lendária ou superior obtido enquanto o app está fechado
- **When** o evento é detectado
- **Then** uma notificação push informa a raridade e o tipo do item

### CEN-M11-008 — Notificação push de inventário cheio

- **Given** o inventário atingindo a capacidade máxima sem candidatos à venda automática
- **When** o estado é detectado
- **Then** uma notificação push de inventário cheio é enviada

### CEN-M11-009 — Widget reflete estado salvo

- **Given** um estado salvo indicando wave 142 do Ato 2
- **When** o widget é atualizado
- **Then** ele exibe wave 142 e Ato 2
- **And** nenhum combate em tempo real é executado para produzir esse valor

### CEN-M11-010 — Desativar a notificação persistente

- **Given** um jogador que desativa a notificação persistente nas opções do jogo
- **When** o app vai para segundo plano
- **Then** nenhuma notificação persistente é exibida
- **And** o progresso e o cálculo offline continuam funcionando normalmente

### CEN-M11-011 — Widget sem estado salvo

- **Given** o widget adicionado antes da primeira abertura do jogo
- **When** ele tenta atualizar
- **Then** exibe um estado inicial neutro convidando o jogador a abrir o jogo
- **And** nenhum valor incorreto é apresentado

## Casos de Borda

### CEN-M11-E01 — Permissão de notificação negada

- **Given** um jogador que nega a permissão de notificações do sistema
- **When** eventos que gerariam notificação ocorrem
- **Then** nenhuma notificação é exibida
- **And** os eventos continuam registrados e visíveis no resumo ao abrir o app

### CEN-M11-E02 — Atualização em segundo plano restringida pelo sistema

- **Given** um dispositivo com economia de bateria agressiva que impede atualizações periódicas
- **When** o widget não consegue atualizar por vários minutos
- **Then** o widget continua exibindo o último estado conhecido
- **And** ao abrir o app, o estado correto é recuperado pelo cálculo offline

### CEN-M11-E03 — Múltiplos widgets na tela inicial

- **Given** dois widgets do jogo adicionados à tela inicial
- **When** o ciclo de atualização ocorre
- **Then** ambos exibem o mesmo estado consistente

## Critérios de Sucesso

- **SC-M11-01**: O widget reflete o estado do jogo com defasagem máxima de 1 minuto quando o sistema permite atualizações periódicas.
- **SC-M11-02**: Tocar no widget leva o jogador à tela de combate em no máximo 1 interação.
- **SC-M11-03**: O jogador consegue identificar wave, ato e taxa de ouro sem abrir o app.
- **SC-M11-04**: Negar permissões de notificação nunca bloqueia progresso ou recompensas.

## Suposições

- "Melhor herói" é definido como o herói de maior nível na formação ativa; o documento de origem não define o critério.
- O ouro por minuto exibido na notificação deriva da mesma taxa usada no cálculo offline de [M09](M09-progressao-offline.md).
- A ação "Coletar Loot" abre o app em vez de conceder recompensas diretamente pela notificação, conforme descrito no documento de origem.
- A confiabilidade da atualização periódica depende de restrições do sistema operacional e do fabricante, fora do controle do jogo.
