# M05 — Inventário e Equipamento

**Origem**: `specification.md` §3.2 (Loop Principal, passo 4), §3.3.C (Auto-loot e limpeza de inventário), §4.3 (slots do modelo Hero)

**Prioridade**: P1

**Status**: Draft

**Depende de**: [M04 Loot Procedural](M04-loot-procedural.md)

## Objetivo

Armazenar os itens obtidos, permitir que o jogador equipe os melhores em cada herói e manter o inventário sob controle sem exigir microgestão.

## Regras

- **R-M05-01**: O inventário tem capacidade de 50 slots.
- **R-M05-02**: Cada herói possui um slot de equipamento por tipo de item: Arma, Armadura, Elmo, Luvas, Botas, Amuleto e Anel.
- **R-M05-03**: Equipar um item aplica imediatamente seu prefixo principal e seus sufixos aos atributos efetivos do herói.
- **R-M05-04**: Equipar um item em um slot ocupado devolve o item anterior ao inventário.
- **R-M05-05**: Itens equipados não ocupam slot de inventário e não podem ser vendidos automaticamente.
- **R-M05-06**: Ao atingir 50 slots ocupados, itens Bronze e Prata não equipados e não favoritados são vendidos automaticamente por ouro.
- **R-M05-07**: O jogador pode marcar itens como favoritos para protegê-los da venda automática.
- **R-M05-08**: O jogador pode vender itens manualmente a qualquer momento.
- **R-M05-09**: Ao inspecionar um item, o jogador vê a comparação com o item atualmente equipado no mesmo slot.

## Cenários

### CEN-M05-001 — Item dropado entra no inventário

- **Given** um inventário com 10 de 50 slots ocupados
- **When** um item é dropado
- **Then** o inventário passa a ter 11 slots ocupados
- **And** o item aparece na lista com raridade, tipo e item level visíveis

### CEN-M05-002 — Equipar em slot vazio

- **Given** um herói com o slot de Arma vazio e uma arma de +50 ATK no inventário
- **When** o jogador equipa essa arma no herói
- **Then** o ATK efetivo do herói aumenta em 50
- **And** o slot de Arma passa a exibir a arma
- **And** o inventário perde 1 slot ocupado

### CEN-M05-003 — Substituir item equipado

- **Given** um herói com uma arma de +50 ATK equipada e uma arma de +80 ATK no inventário
- **When** o jogador equipa a arma de +80 ATK
- **Then** o ATK efetivo do herói passa a refletir +80 em vez de +50
- **And** a arma de +50 ATK retorna ao inventário
- **And** a contagem de slots ocupados do inventário permanece a mesma

### CEN-M05-004 — Sufixos são aplicados ao equipar

- **Given** uma armadura com prefixo +DEF e sufixos de +% crítico e +velocidade de ataque
- **When** o item é equipado
- **Then** a DEF, a chance de crítico e a velocidade de ataque efetivas do herói aumentam de acordo

### CEN-M05-005 — Desequipar remove os bônus

- **Given** um herói com um item equipado que concede +80 ATK
- **When** o jogador desequipa o item
- **Then** o ATK efetivo volta ao valor anterior ao item
- **And** o item retorna ao inventário

### CEN-M05-006 — Comparação com o item equipado

- **Given** um item no inventário e outro do mesmo tipo equipado em um herói
- **When** o jogador inspeciona o item do inventário
- **Then** a diferença de cada atributo em relação ao item equipado é exibida
- **And** ganhos e perdas são visualmente distinguíveis

### CEN-M05-007 — Venda automática ao encher o inventário

- **Given** um inventário com 50 de 50 slots ocupados contendo itens Bronze e Prata não equipados e não favoritados
- **When** um novo item é dropado
- **Then** os itens Bronze e Prata elegíveis são vendidos automaticamente
- **And** o ouro do jogador aumenta pelo valor da venda
- **And** o novo item é armazenado no inventário

### CEN-M05-008 — Venda automática preserva itens de raridade alta

- **Given** um inventário cheio com itens Bronze, Prata e Épicos
- **When** a venda automática é acionada
- **Then** apenas os itens Bronze e Prata são vendidos
- **And** os itens Épicos permanecem no inventário

### CEN-M05-009 — Favorito é protegido da venda automática

- **Given** um item Prata marcado como favorito em um inventário cheio
- **When** a venda automática é acionada
- **Then** o item favoritado não é vendido
- **And** permanece disponível no inventário

### CEN-M05-010 — Item equipado nunca é vendido automaticamente

- **Given** um herói com uma arma Bronze equipada e um inventário cheio
- **When** a venda automática é acionada
- **Then** a arma equipada permanece equipada
- **And** não é convertida em ouro

### CEN-M05-011 — Venda manual

- **Given** um item qualquer não equipado no inventário
- **When** o jogador o vende manualmente
- **Then** o item é removido do inventário
- **And** o ouro do jogador aumenta pelo valor do item

### CEN-M05-012 — Um item por slot por herói

- **Given** um herói já com um Anel equipado
- **When** o jogador equipa outro Anel no mesmo herói
- **Then** o anel anterior é devolvido ao inventário
- **And** o herói permanece com exatamente 1 anel equipado

## Casos de Borda

### CEN-M05-E01 — Inventário cheio sem candidatos à venda automática

- **Given** um inventário com 50 de 50 slots, todos ocupados por itens Ouro ou superiores, ou favoritados
- **When** um novo item é dropado
- **Then** nenhum item é vendido automaticamente
- **And** o jogador recebe notificação de inventário cheio
- **And** o drop é retido até que haja espaço

### CEN-M05-E02 — Equipar item já equipado em outro herói

- **Given** um item equipado no herói A
- **When** o jogador equipa esse item no herói B
- **Then** o item é removido do herói A e equipado no herói B
- **And** os atributos de ambos os heróis são recalculados

### CEN-M05-E03 — Venda de item usado como molde

- **Given** um item salvo como molde no Cubo conforme [M06](M06-cubo-crafting.md)
- **When** o item original é vendido
- **Then** o molde permanece registrado
- **And** continua utilizável no Cubo

## Critérios de Sucesso

- **SC-M05-01**: O jogador consegue comparar e equipar um item recém-dropado em no máximo 3 interações a partir da tela de combate.
- **SC-M05-02**: Nenhum item Ouro ou superior é perdido por venda automática em qualquer situação.
- **SC-M05-03**: O inventário nunca ultrapassa 50 slots ocupados durante a jogatina contínua.
- **SC-M05-04**: O efeito de equipar um item é refletido nos atributos exibidos imediatamente, sem necessidade de reiniciar a wave.

## Suposições

- A regra de venda automática atinge apenas itens não equipados e não favoritados — o documento de origem menciona apenas "venda automática de Bronze/Prata".
- O mecanismo de favoritos não consta do documento de origem; foi adotado para evitar perda involuntária de itens.
- O valor de venda de um item é derivado de sua raridade e item level; o documento de origem não define a fórmula.
- Os 50 slots referem-se apenas a itens não equipados; equipamentos em uso não contam para o limite.
