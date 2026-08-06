# Contract — Sprites e Assets Visuais

**Feature**: `001-idle-rpg-mecanicas` | **Date**: 2026-08-06 | **Tarefa**: T143

Contrato entre a arte e o código. Seguindo isto, um `.zip` descompactado sobre
`assets/` funciona sem nenhuma alteração de código: nomes, grades e âncoras já
são o que o carregador espera.

**Regra que vale para tudo**: arquivo ausente **não quebra o jogo**. O
componente cai no retângulo colorido atual. Dá para entregar a arte em levas —
começar pelos 6 heróis, por exemplo — e o resto continua jogável.

---

## 1. Regras gerais

| Propriedade | Valor | Por quê |
|---|---|---|
| Formato de entrega | **PNG** com alfa, fundo transparente | Converto para WebP no build (T145) |
| Escala | **1:1**, sem anti-aliasing, sem sombra suave | `specification.md` §7.1; a tela amplia por número inteiro |
| Paleta | Até **32 cores**, compartilhada entre todos os sprites | §7.1 — é o que faz o conjunto parecer um jogo só |
| Resolução base do jogo | 320×180 | §7.1 |
| Âncora | **Base-centro**: os pés/base ocupam a última linha de pixels do quadro, centralizados | O código posiciona por `Anchor.bottomCenter`; sprite flutuando ou cortado vem daqui |
| Direção | Heróis olham para a **direita**; monstros olham para a **esquerda** | Heróis ficam à esquerda da arena, monstros à direita |
| Quadro vazio | Permitido (para animações mais curtas), repita o último quadro | Simplifica a grade fixa |

### Layout de folha (sprite sheet)

Toda folha de personagem é uma **grade fixa de 4 colunas × 3 linhas**, sem
espaçamento nem margem:

```
coluna:    0        1        2        3
linha 0:  idle_0   idle_1   idle_2   idle_3     ← ciclo contínuo
linha 1:  atk_0    atk_1    atk_2    atk_3      ← dispara a cada golpe
linha 2:  die_0    die_1    die_2    die_3      ← o último quadro fica congelado
```

- **idle**: respiração/oscilação sutil. Roda em loop, ~0,5 s o ciclo inteiro.
- **attack**: um golpe completo, tocado uma vez. O impacto deve cair no quadro 2.
- **die**: queda. Para heróis é a incapacitação — o **quadro 3 fica parado** os
  30 s até o revive, então ele precisa ficar legível estático.
- **hit** (piscada branca ao levar dano) é feito em código. **Não desenhe.**

---

## 2. Heróis — 6 arquivos

**Quadro 16×24 px** → folha de **64×72 px** cada.

> Desvio consciente de §7.1, que diz 16×16: humanoide em 16×16 fica ilegível
> com 4 heróis lado a lado. 16 de largura mantém o alinhamento com os monstros.

Pasta: `assets/sprites/heroes/`

| Arquivo | Classe | Papel | Leitura visual pretendida |
|---|---|---|---|
| `vanguard.png` | Vanguard | Tanque | Escudo grande, armadura pesada, postura baixa. É quem provoca — precisa parecer o mais sólido do time |
| `elementalist.png` | Elementalist | Dano mágico | Cajado/orbe, manto, silhueta estreita. Ataque em área elemental |
| `sharpshooter.png` | Sharpshooter | Dano à distância | Arco ou besta, capuz, postura de mira |
| `medtech.png` | Medtech | Suporte | Maleta/frasco, tons claros, sem arma pesada. Cura e acelera o time |
| `tracker.png` | Tracker | Corpo a corpo | Adagas gêmeas, leve, ágil. Bate **2× mais rápido** que os outros — a animação de ataque precisa funcionar curta |
| `berserker.png` | Berserker | Bruto | Machado grande, sem armadura, massa. Fica mais forte com HP baixo |

As cores de destaque atuais por posição na formação são azul, roxo, verde e
âmbar — não precisam ser seguidas; a arte manda.

---

## 3. Monstros — 12 arquivos

Pasta: `assets/sprites/monsters/`

**Comuns: quadro 16×16 px** → folha de **64×48 px**.
**Bosses: quadro 32×32 px** → folha de **128×96 px**.

### Ato 1 — Floresta (verde, orgânico)

| Arquivo | Nome | Tamanho | Ideia |
|---|---|---|---|
| `forest_sprout.png` | Broto Rastejante | 16×16 | Muda animada, frágil, o mais fraco do jogo |
| `forest_stalker.png` | Espreitador da Mata | 16×16 | Felino/lupino magro, rápido |
| `forest_bramble.png` | Sarça Torcida | 16×16 | Emaranhado de espinhos, atarracado, mais defesa |
| `forest_warden.png` | **Guardião do Bosque** | **32×32** | Ent/golem de madeira. Primeiro boss — tem de impor |

### Ato 2 — Caverna (roxo, mineral)

| Arquivo | Nome | Tamanho | Ideia |
|---|---|---|---|
| `cave_gnawer.png` | Roedor das Fendas | 16×16 | Roedor grande, dentes, veloz |
| `cave_shardling.png` | Cristalino | 16×16 | Criatura de cristal, angular, luminosa |
| `cave_hulk.png` | Bruto de Pedra | 16×16 | Bloco de rocha com braços, lento e duro |
| `cave_maw.png` | **Fauce do Abismo** | **32×32** | Boca/abismo com dentes. Boss do Ato 2 |

### Ato 3 — Cidadela (ferrugem, marcial)

| Arquivo | Nome | Tamanho | Ideia |
|---|---|---|---|
| `citadel_sentry.png` | Sentinela Enferrujada | 16×16 | Armadura vazia animada, enferrujada |
| `citadel_warden.png` | Carcereiro Pálido | 16×16 | Carcereiro espectral, chaves, corrente |
| `citadel_revenant.png` | Espectro de Guerra | 16×16 | Guerreiro fantasma, translúcido, veloz |
| `citadel_tyrant.png` | **Tirano da Cidadela** | **32×32** | Chefe final. O inimigo mais imponente do jogo |

---

## 4. Ícones de item — 8 arquivos

Pasta: `assets/sprites/items/`

**16×16 px, quadro único** (sem animação, sem grade).

`weapon.png`, `armor.png`, `helmet.png`, `gloves.png`, `boots.png`,
`amulet.png`, `ring.png`, `essence.png`

Desenhe em **tons de cinza claro com contorno definido**. O código aplica a cor
da raridade por cima — assim 7 ícones cobrem as 8 raridades em vez de exigir 56
arquivos. As cores são:

| Raridade | Cor | | Raridade | Cor |
|---|---|---|---|---|
| Bronze | `#9C7A55` | | Lendário | `#E8702A` |
| Prata | `#B9BEC7` | | Mítico | `#D24B4B` |
| Ouro | `#E8B44A` | | Transcendental | `#4AC5E8` |
| Épico | `#9B3FBF` | | Cósmico | `#7BE88C` |

---

## 5. Cenários — 3 arquivos

Pasta: `assets/sprites/backgrounds/`

**320×180 px, quadro único.** Substituem as silhuetas desenhadas em código.

| Arquivo | Ato | Paleta atual (referência) |
|---|---|---|
| `forest.png` | 1 — Floresta | céu `#16281C`, chão `#23422B`, destaque `#3E6B45` |
| `cave.png` | 2 — Caverna | céu `#1A1622`, chão `#2B2436`, destaque `#4A3B63` |
| `citadel.png` | 3 — Cidadela | céu `#221A18`, chão `#3A2C27`, destaque `#6B4A3E` |

O chão precisa ocupar a **faixa inferior de ~46 px** — é sobre ela que os
combatentes pisam. Acima disso, cenário de fundo sem elementos que disputem
atenção com os sprites.

---

## 6. Fonte — 1 arquivo (opcional)

`assets/fonts/PressStart2P-Regular.ttf` — Google Fonts, licença SIL Open Font,
uso comercial liberado. §7.1 pede fonte pixelada; hoje o jogo usa a padrão do
sistema.

---

## 7. Resumo da entrega

```
assets/
├── sprites/
│   ├── heroes/          6 arquivos   64×72 cada
│   ├── monsters/        12 arquivos  64×48 (comuns) ou 128×96 (bosses)
│   ├── items/           8 arquivos   16×16
│   └── backgrounds/     3 arquivos   320×180
└── fonts/               1 arquivo    (opcional)
```

**29 PNGs + 1 fonte.** Se preferir entregar em partes, a ordem de maior impacto
visual é: heróis → bosses → cenários → monstros comuns → ícones.

## 8. O que **não** entra na entrega

- Números de dano, barras de vida, aura e coroa de boss: tudo desenhado em
  código, e continua assim.
- Piscada branca de dano: efeito de código sobre o sprite.
- Ícones de UI (botões, abas): a interface é deliberadamente sem ícones.
- Tilesets: o cenário é uma imagem única por ato, não um mapa em blocos.
