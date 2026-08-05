# M06 — Cubo de Crafting

**Origem**: `specification.md` §3.3.D (Sistema de Cubo)

**Prioridade**: P3

**Status**: Draft

**Depende de**: [M04 Loot Procedural](M04-loot-procedural.md), [M05 Inventário](M05-inventario-equipamento.md)

## Objetivo

Dar utilidade a itens excedentes convertendo-os em raridades superiores, com controle parcial sobre os atributos resultantes.

## Regras

- **R-M06-01**: A fusão consome exatamente 3 itens da mesma raridade e produz 1 item da raridade imediatamente superior.
- **R-M06-02**: O item resultante tem todos os seus atributos re-rolados; nada dos itens consumidos é preservado, exceto a categoria de raridade resultante.
- **R-M06-03**: Itens de raridade Cósmica não podem ser fundidos, por ser a raridade máxima.
- **R-M06-04**: Adicionar uma Essência à fusão garante 1 sufixo específico no item resultante.
- **R-M06-05**: A Essência é um drop raro e é consumida na fusão, independentemente do resultado.
- **R-M06-06**: O jogador pode salvar um item como molde por meio da função "Imprimir".
- **R-M06-07**: Um molde registra a combinação de atributos do item e pode ser usado em fusões para tentar recriar essa combinação.
- **R-M06-08**: Itens equipados não podem ser usados como material de fusão.
- **R-M06-09**: A fusão é irreversível e exige confirmação explícita do jogador.

## Cenários

### CEN-M06-001 — Fusão eleva a raridade

- **Given** 3 itens de raridade Ouro no inventário, nenhum equipado
- **When** o jogador confirma a fusão no Cubo
- **Then** os 3 itens são removidos do inventário
- **And** 1 item de raridade Épica é criado e adicionado ao inventário

### CEN-M06-002 — Atributos são re-rolados

- **Given** 3 itens de raridade Ouro com sufixos conhecidos
- **When** a fusão é concluída
- **Then** o item resultante tem prefixo e sufixos sorteados novamente
- **And** não há garantia de que qualquer sufixo dos itens consumidos apareça no resultado

### CEN-M06-003 — Raridades diferentes são recusadas

- **Given** 2 itens Ouro e 1 item Prata selecionados no Cubo
- **When** o jogador tenta confirmar a fusão
- **Then** a fusão é recusada
- **And** nenhum item é consumido
- **And** o jogador é informado de que os 3 itens precisam ter a mesma raridade

### CEN-M06-004 — Quantidade insuficiente de materiais

- **Given** apenas 2 itens de raridade Ouro selecionados
- **When** o jogador tenta confirmar a fusão
- **Then** a fusão é recusada
- **And** nenhum item é consumido

### CEN-M06-005 — Essência garante sufixo

- **Given** 3 itens Épicos e 1 Essência que garante o sufixo de +% crítico
- **When** a fusão é concluída
- **Then** o item Lendário resultante possui o sufixo de +% crítico
- **And** os demais sufixos são sorteados normalmente
- **And** a Essência é consumida

### CEN-M06-006 — Essência é consumida mesmo em resultado ruim

- **Given** uma fusão com Essência cujo item resultante tem apenas o sufixo garantido
- **When** a fusão é concluída
- **Then** a Essência não é devolvida ao inventário

### CEN-M06-007 — Salvar molde com "Imprimir"

- **Given** um item com uma combinação de atributos desejada
- **When** o jogador usa a função "Imprimir" nesse item
- **Then** a combinação de atributos é registrada como molde
- **And** o molde fica disponível para uso em fusões futuras

### CEN-M06-008 — Usar molde em uma fusão

- **Given** um molde salvo e 3 itens da mesma raridade selecionados
- **When** o jogador aplica o molde e confirma a fusão
- **Then** o item resultante tenta reproduzir a combinação de atributos do molde
- **And** o resultado é informado ao jogador como sucesso ou falha na recriação

### CEN-M06-009 — Item equipado não pode ser material

- **Given** um item atualmente equipado em um herói
- **When** o jogador tenta selecioná-lo como material de fusão
- **Then** a seleção é recusada
- **And** o jogador é informado de que precisa desequipar o item antes

### CEN-M06-010 — Confirmação obrigatória

- **Given** 3 itens válidos selecionados no Cubo
- **When** o jogador aciona a fusão
- **Then** uma confirmação explícita é solicitada antes do consumo dos itens
- **And** cancelar a confirmação mantém todos os itens intactos

## Casos de Borda

### CEN-M06-E01 — Fusão de itens Cósmicos

- **Given** 3 itens de raridade Cósmica
- **When** o jogador tenta fundi-los
- **Then** a fusão é recusada
- **And** o jogador é informado de que Cósmico é a raridade máxima

### CEN-M06-E02 — Fusão com inventário cheio

- **Given** um inventário cheio e 3 itens válidos selecionados para fusão
- **When** a fusão é concluída
- **Then** os 3 materiais são removidos, liberando espaço
- **And** o item resultante é armazenado com sucesso

### CEN-M06-E03 — Interrupção durante a fusão

- **Given** uma fusão confirmada
- **When** o app é encerrado antes da conclusão da operação
- **Then** ao reabrir, o estado é consistente: ou os 3 materiais permanecem no inventário, ou o item resultante existe
- **And** em nenhuma hipótese os materiais são perdidos sem produzir resultado

## Critérios de Sucesso

- **SC-M06-01**: Nenhuma fusão consome materiais sem produzir um item ou devolvê-los integralmente.
- **SC-M06-02**: O jogador consegue converter 3 itens em 1 de raridade superior em no máximo 4 interações.
- **SC-M06-03**: A taxa de sucesso na recriação por molde é comunicada ao jogador antes da confirmação.

## Suposições

- Os 3 materiais podem ser de tipos de slot diferentes; o documento de origem exige apenas raridade igual. O tipo do item resultante é sorteado.
- O item level do resultado deriva dos materiais consumidos; a fórmula não consta do documento de origem.
- A recriação por molde é probabilística, não garantida — o documento de origem descreve "tentar recriar".
- O número de moldes que podem ser salvos simultaneamente não consta do documento de origem.
- Gemas premium podem acelerar operações do Cubo conforme [M12](M12-monetizacao-recompensas.md), sem alterar os resultados possíveis.
