# M12 — Monetização e Recompensas por Anúncio

**Origem**: `specification.md` §3.1 (Monetização), §5 (Monetização)

**Prioridade**: P3

**Status**: Draft

**Depende de**: [M01 Combate](M01-combate-automatico.md), [M06 Cubo](M06-cubo-crafting.md), [M07 Árvore de Runas](M07-arvore-de-runas.md)

## Objetivo

Oferecer aceleração e conteúdo opcional por anúncios e compras, sem jamais bloquear progressão central atrás de pagamento.

## Regras

- **R-M12-01**: Nenhum conteúdo de progressão central pode ser bloqueado atrás de pagamento; tudo deve ser obtenível jogando.
- **R-M12-02**: Gemas apenas aceleram processos, nunca desbloqueiam conteúdo inacessível de outra forma.
- **R-M12-03**: Anúncios recompensados são sempre opcionais e concedem: +50% de ouro por 4 horas, revive instantâneo ou +1 slot de cubo.
- **R-M12-04**: Anúncios intersticiais aparecem no máximo a cada 5 transições de ato.
- **R-M12-05**: A compra "Remover Ads" elimina os intersticiais e mantém os recompensados como opção.
- **R-M12-06**: Compras disponíveis: Remover Ads, Pacote de Início, Gemas e DLC de Classe.
- **R-M12-07**: Recusar ou não conseguir assistir a um anúncio nunca prejudica o progresso do jogador.
- **R-M12-08**: A recompensa só é concedida após a visualização completa do anúncio.
- **R-M12-09**: O "+1 herói extra" do Pacote de Início libera o 4º slot de formação, que também é desbloqueado gratuitamente no nível de conta 25. A compra apenas antecipa o desbloqueio.
- **R-M12-10**: O limite absoluto de heróis simultâneos é 4; nenhuma compra ou anúncio ultrapassa esse teto.
- **R-M12-11**: Quem já possui o 4º slot por compra recebe 500 gemas ao atingir o marco gratuito, em vez de um slot duplicado.
- **R-M12-12**: A skin exclusiva do Pacote de Início e as classes de DLC são conteúdo pós-lançamento; não fazem parte do escopo desta especificação além do registro da compra.

### Catálogo de Ofertas

| Tipo | Efeito | Modelo |
|------|--------|--------|
| Anúncio recompensado | +50% de ouro por 4 horas | Gratuito, opcional |
| Anúncio recompensado | Revive instantâneo de herói | Gratuito, opcional |
| Anúncio recompensado | +1 slot de cubo | Gratuito, opcional |
| Anúncio intersticial | Nenhum efeito de jogo | A cada 5 transições de ato |
| Compra — Remover Ads | Remove intersticiais | Pagamento único |
| Compra — Pacote de Início | Antecipa o 4º slot de formação (gratuito no nível de conta 25), skin exclusiva, 500 gemas | Pagamento único |
| Compra — Gemas | Moeda premium para acelerar cubo e respec | Pacotes variados |
| Compra — DLC de Classe | Desbloqueia classe extra | Pagamento por classe |

## Cenários

### CEN-M12-001 — Bônus de ouro por anúncio

- **Given** um jogador sem bônus de ouro ativo
- **When** ele assiste completamente a um anúncio recompensado de bônus de ouro
- **Then** um bônus de +50% de ouro é ativado por 4 horas
- **And** o tempo restante do bônus é exibido ao jogador

### CEN-M12-002 — Revive instantâneo por anúncio

- **Given** um herói incapacitado aguardando o revive automático de 30 segundos
- **When** o jogador assiste completamente a um anúncio recompensado de revive
- **Then** o herói revive imediatamente com HP cheio
- **And** o temporizador de 30 segundos é cancelado

### CEN-M12-003 — Slot de cubo extra por anúncio

- **Given** um jogador na tela do Cubo
- **When** ele assiste completamente a um anúncio recompensado de slot
- **Then** 1 slot adicional de cubo fica disponível

### CEN-M12-004 — Anúncio interrompido não concede recompensa

- **Given** um jogador que inicia um anúncio recompensado
- **When** ele fecha o anúncio antes do fim
- **Then** nenhuma recompensa é concedida
- **And** nenhum recurso do jogador é consumido
- **And** ele pode tentar novamente

### CEN-M12-005 — Recusar anúncio não prejudica o progresso

- **Given** um herói incapacitado e a oferta de revive por anúncio exibida
- **When** o jogador recusa a oferta
- **Then** o revive automático de 30 segundos ocorre normalmente
- **And** nenhum progresso, item ou recompensa é perdido

### CEN-M12-006 — Frequência de intersticiais

- **Given** um jogador que realizou 4 transições de ato desde o último intersticial
- **When** ele realiza a quinta transição de ato
- **Then** um anúncio intersticial pode ser exibido
- **And** nenhum intersticial é exibido durante o combate ou entre waves comuns

### CEN-M12-007 — Remover Ads elimina intersticiais

- **Given** um jogador que adquiriu "Remover Ads"
- **When** ele realiza qualquer número de transições de ato
- **Then** nenhum anúncio intersticial é exibido
- **And** os anúncios recompensados continuam disponíveis como opção

### CEN-M12-008 — Gemas aceleram o cubo

- **Given** um jogador com gemas e uma operação de cubo em andamento
- **When** ele gasta gemas para acelerar
- **Then** a operação é concluída antes do tempo normal
- **And** os resultados possíveis são idênticos aos da operação sem gemas

### CEN-M12-009 — Gemas aceleram o respec

- **Given** um jogador com gemas
- **When** ele usa gemas em um respec da árvore de runas
- **Then** o respec é concluído mais rapidamente ou com custo reduzido em ouro
- **And** nenhum nó de runa se torna inacessível a quem não usa gemas

### CEN-M12-010 — Nenhum bloqueio de progressão

- **Given** um jogador que nunca gastou dinheiro nem assistiu a anúncios
- **When** ele progride pelo jogo
- **Then** todas as waves, atos, dificuldades, raridades de item e nós de runa permanecem alcançáveis
- **And** nenhuma tela exige pagamento para continuar

### CEN-M12-011 — DLC de classe é conteúdo adicional

- **Given** um jogador que não adquiriu nenhuma DLC de classe
- **When** ele monta sua formação
- **Then** as 6 classes iniciais continuam disponíveis
- **And** a ausência das classes de DLC não impede completar nenhum ato ou dificuldade

### CEN-M12-012 — Pacote de Início antecipa o 4º slot

- **Given** um jogador de nível de conta 8 com 3 slots de formação
- **When** ele adquire o Pacote de Início
- **Then** o 4º slot de formação é desbloqueado imediatamente
- **And** a skin exclusiva e as 500 gemas são concedidas

### CEN-M12-013 — O 4º slot também é gratuito

- **Given** um jogador que nunca realizou nenhuma compra
- **When** sua conta atinge o nível 25
- **Then** o 4º slot de formação é desbloqueado sem pagamento
- **And** ele passa a ter exatamente a mesma capacidade de formação de quem comprou o Pacote de Início

### CEN-M12-014 — Compra não ultrapassa o teto de 4

- **Given** um jogador que já possui o 4º slot e adquire todos os pacotes disponíveis
- **When** ele monta a formação
- **Then** o limite permanece 4 heróis simultâneos

### CEN-M12-015 — Compensação por slot duplicado

- **Given** um jogador que comprou o Pacote de Início no nível de conta 8
- **When** sua conta atinge o nível 25
- **Then** nenhum quinto slot é concedido
- **And** ele recebe 500 gemas como compensação no lugar do slot duplicado

### CEN-M12-016 — Bônus de ouro expira

- **Given** um jogador com bônus de +50% de ouro ativo
- **When** as 4 horas se esgotam
- **Then** o bônus deixa de ser aplicado
- **And** o jogador é informado do término

## Casos de Borda

### CEN-M12-E01 — Sem conexão de rede

- **Given** um jogador sem conexão de rede
- **When** ele tenta assistir a um anúncio recompensado
- **Then** nenhuma recompensa é concedida
- **And** uma mensagem explicativa é exibida
- **And** o progresso do jogo continua normalmente

### CEN-M12-E02 — Acúmulo de bônus de ouro

- **Given** um jogador com bônus de +50% de ouro com 1 hora restante
- **When** ele assiste a outro anúncio de bônus de ouro
- **Then** a duração é estendida em vez de o percentual ser multiplicado
- **And** o percentual permanece +50%

### CEN-M12-E03 — Falha na compra

- **Given** uma compra iniciada que falha no processamento
- **When** o resultado é retornado
- **Then** nenhum valor é cobrado do jogador
- **And** nenhum item ou benefício da compra é concedido

### CEN-M12-E04 — Restauração de compras

- **Given** um jogador que reinstala o app após ter adquirido "Remover Ads"
- **When** ele restaura suas compras
- **Then** o benefício de remoção de intersticiais volta a valer

## Critérios de Sucesso

- **SC-M12-01**: 100% do conteúdo de progressão (waves, atos, dificuldades, itens, nós de runa e slots de formação) permanece alcançável sem qualquer compra ou anúncio.
- **SC-M12-02**: Nenhum anúncio interrompe o combate em andamento.
- **SC-M12-03**: Um jogador que nunca assiste a anúncios progride pelo Ato 1 sem qualquer bloqueio ou solicitação obrigatória.
- **SC-M12-04**: Toda recompensa por anúncio é concedida em até 5 segundos após a visualização completa.

## Suposições

- O bônus de ouro por anúncio não é acumulável em percentual; visualizações adicionais estendem a duração.
- Anúncios recompensados possuem limite diário de visualizações para evitar abuso; o documento de origem não define o limite.
- As classes de DLC são conteúdo adicional, não substituem nem superam as 6 classes iniciais em poder.
- O nível de conta 25 como marco gratuito do 4º slot é um valor de balanceamento inicial, ajustável. O documento de origem lista "+1 herói extra" no Pacote de Início sem definir marco gratuito; a via gratuita foi adicionada para respeitar a regra "nunca bloquear progressão core atrás de paywall".
- A compensação por slot já antecipado é de 500 gemas, mesmo valor concedido pelo Pacote de Início. Valor comercial ajustável, fixado para tornar CEN-M12-015 verificável.
- Os preços listados no documento de origem são referências comerciais, não requisitos funcionais desta especificação.
