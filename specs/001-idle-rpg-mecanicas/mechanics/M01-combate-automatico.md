# M01 — Combate Automático

**Origem**: `specification.md` §3.3.A (Sistema de Combate), §3.2 (Loop Principal)

**Prioridade**: P1 — mecânica núcleo

**Status**: Draft

**Depende de**: [M02 Classes](M02-classes-de-herois.md), [M08 Atos e Waves](M08-atos-waves-dificuldades.md)

## Objetivo

Os heróis lutam sozinhos contra monstros, sem entrada do jogador. O combate é a fonte de todo ouro, XP e loot do jogo.

## Regras

- **R-M01-01**: A formação comporta 3 heróis simultâneos em combate por padrão.
- **R-M01-01b**: Um 4º slot de formação pode ser desbloqueado, elevando o limite para 4 heróis simultâneos. O desbloqueio ocorre gratuitamente no nível de conta 25 ou, antecipadamente, pelo Pacote de Início descrito em [M12](M12-monetizacao-recompensas.md).
- **R-M01-02**: Cada classe define sua regra de alvo: monstro mais próximo ou monstro com menor HP.
- **R-M01-03**: Dano por golpe = `ATK do herói + bônus de itens − DEF do monstro`, com mínimo de 1.
- **R-M01-04**: Chance base de crítico é 5%, somada aos bônus de itens e habilidades.
- **R-M01-05**: Um golpe crítico causa 2× o dano calculado.
- **R-M01-06**: Um herói com HP zerado fica incapacitado e revive automaticamente após 30 segundos com HP cheio.
- **R-M01-07**: O combate não exige nem aceita comandos de ataque do jogador.
- **R-M01-08**: Todo dano, cura e crítico é exibido como número flutuante sobre o alvo.

## Cenários

### CEN-M01-001 — Combate inicia sozinho

- **Given** uma formação com ao menos 1 herói vivo e uma wave ativa com monstros
- **When** o jogo está em execução em primeiro plano e o jogador não realiza nenhuma ação
- **Then** os heróis atacam os monstros automaticamente
- **And** números de dano são exibidos sobre os monstros atingidos

### CEN-M01-002 — Cálculo de dano normal

- **Given** um herói com ATK efetivo de 100 (base + bônus de itens) atacando um monstro com DEF 30
- **When** o golpe não é crítico
- **Then** o monstro perde exatamente 70 pontos de HP

### CEN-M01-003 — Dano mínimo garantido

- **Given** um herói com ATK efetivo de 20 atacando um monstro com DEF 50
- **When** o golpe é resolvido
- **Then** o monstro perde exatamente 1 ponto de HP
- **And** a progressão da wave não fica permanentemente travada

### CEN-M01-004 — Golpe crítico

- **Given** um herói cujo dano calculado contra o alvo é 70 e cuja chance de crítico é 5%
- **When** o golpe é sorteado como crítico
- **Then** o monstro perde 140 pontos de HP
- **And** o número de dano é exibido com destaque visual de crítico

### CEN-M01-005 — Bônus de crítico acumulado

- **Given** um herói com chance base de crítico de 5% e itens que somam +15% de chance de crítico
- **When** a chance de crítico efetiva é calculada
- **Then** o valor usado no sorteio é 20%

### CEN-M01-006 — Alvo por proximidade

- **Given** um herói de classe cuja regra de alvo é "monstro mais próximo"
- **And** dois monstros vivos em distâncias diferentes
- **When** o herói escolhe um alvo
- **Then** o monstro mais próximo é atacado

### CEN-M01-007 — Alvo por menor HP

- **Given** um herói de classe cuja regra de alvo é "monstro com menor HP"
- **And** dois monstros vivos com HP atual diferente
- **When** o herói escolhe um alvo
- **Then** o monstro com menor HP atual é atacado

### CEN-M01-008 — Troca de alvo após morte

- **Given** um herói atacando um monstro específico
- **And** ao menos um outro monstro vivo na wave
- **When** o monstro alvo é derrotado
- **Then** o herói seleciona um novo alvo pela regra de sua classe no golpe seguinte
- **And** nenhum tempo de combate é perdido além do intervalo normal entre golpes

### CEN-M01-009 — Morte e revive automático

- **Given** um herói cujo HP chega a zero durante a wave
- **When** 30 segundos se passam
- **Then** o herói revive com HP cheio
- **And** volta a atacar automaticamente
- **And** nenhum item equipado, XP ou progresso de wave é perdido

### CEN-M01-010 — Formação inteira incapacitada

- **Given** todos os heróis da formação com HP zerado ao mesmo tempo
- **When** o combate continua
- **Then** nenhum monstro é derrotado e a wave não avança
- **And** os monstros permanecem com o HP que tinham
- **And** o jogo aguarda o revive automático, sem exibir estado de derrota permanente

### CEN-M01-011 — Recompensas por monstro derrotado

- **Given** um monstro com HP restante menor que o dano do próximo golpe
- **When** o golpe é resolvido
- **Then** o monstro é removido do campo
- **And** o ouro do jogador aumenta
- **And** os heróis vivos da formação recebem XP
- **And** a tabela de drops do monstro é avaliada conforme [M04](M04-loot-procedural.md)

### CEN-M01-012 — Limite da formação sem o 4º slot

- **Given** uma formação já com 3 heróis e o 4º slot ainda bloqueado
- **When** o jogador tenta adicionar um quarto herói à formação
- **Then** a adição é recusada
- **And** o jogador é informado de que o 4º slot é desbloqueado no nível de conta 25

### CEN-M01-012b — Combate com o 4º slot desbloqueado

- **Given** um jogador com o 4º slot de formação desbloqueado
- **When** ele posiciona 4 heróis na formação e o combate ocorre
- **Then** os 4 heróis atacam simultaneamente
- **And** todos os 4 recebem XP pelos monstros derrotados
- **And** o revive automático de 30 segundos vale igualmente para o 4º herói

### CEN-M01-012c — Limite absoluto de 4 heróis

- **Given** uma formação com 4 heróis e o 4º slot desbloqueado
- **When** o jogador tenta adicionar um quinto herói
- **Then** a adição é recusada
- **And** nenhuma compra ou anúncio permite ultrapassar 4 heróis simultâneos

### CEN-M01-013 — Combate suspenso com o app fechado

- **Given** o jogo em combate ativo
- **When** o jogador fecha o app ou o sistema encerra o processo
- **Then** nenhum combate real continua sendo processado
- **And** o intervalo de ausência é resolvido pela simulação offline descrita em [M09](M09-progressao-offline.md)

## Casos de Borda

### CEN-M01-E01 — Herói morre no mesmo golpe que derrota o último monstro

- **Given** o último monstro vivo da wave e um herói ambos com HP suficiente apenas para um golpe
- **When** ambos morrem na mesma resolução de combate
- **Then** a wave é considerada completa e as recompensas são concedidas
- **And** o herói morto ainda recebe o XP da wave
- **And** o revive de 30 segundos ocorre normalmente durante a wave seguinte

### CEN-M01-E02 — Formação vazia

- **Given** uma formação sem nenhum herói atribuído
- **When** uma wave está ativa
- **Then** nenhum ataque ocorre
- **And** o jogador é instruído a colocar ao menos 1 herói na formação

## Critérios de Sucesso

- **SC-M01-01**: A partir de um início de jogo novo, o primeiro monstro é derrotado em até 10 segundos sem nenhuma ação do jogador.
- **SC-M01-02**: Em 5 minutos de combate sem intervenção, o jogador acumula ouro, XP e avança ao menos 1 wave.
- **SC-M01-03**: Nenhuma sequência de eventos de combate leva a um estado de derrota permanente ou reinício forçado do progresso.

## Suposições

- Multiplicador de crítico de 2× — não especificado no documento de origem.
- O limite máximo de heróis simultâneos é 4, mesmo com compras; não há progressão paga além desse teto.
- O balanceamento das waves considera formações de 3 heróis como referência; formações de 4 encurtam o tempo de limpeza sem tornar nenhum conteúdo trivial.
- Dano mínimo de 1 por golpe — não especificado, adotado para impedir travamento de progressão.
- A cadência de ataque é derivada do atributo de velocidade de ataque da classe e de bônus de itens; o documento de origem não define valores numéricos.
