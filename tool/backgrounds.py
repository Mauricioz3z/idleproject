"""Cenarios de fundo (320x180, quadro unico), um por ato.

Ao contrario dos personagens, os cenarios sao **procedurais**: 57.600 pixels nao
se autoram a mao em mapa de caracteres, e o que o fundo precisa entregar e
atmosfera, nao detalhe. As silhuetas sao construidas por funcao e desenhadas
com a mesma paleta dos sprites.

Regra do contrato: o chao ocupa a faixa inferior de ~46 px -- e sobre ela que os
combatentes pisam. Acima disso, nada pode competir com os sprites por atencao,
entao o fundo e deliberadamente de baixo contraste.
"""

import math

from PIL import Image

GROUND_HEIGHT = 46
WIDTH, HEIGHT = 320, 180


def _rgb(value):
    return (
        (value >> 16) & 0xFF,
        (value >> 8) & 0xFF,
        value & 0xFF,
        255,
    )


class Scenery:
    def __init__(self, sky, ground, silhouette, accent, deep_sky=None):
        self.sky = _rgb(sky)
        self.ground = _rgb(ground)
        self.silhouette = _rgb(silhouette)
        self.accent = _rgb(accent)
        self.deep_sky = _rgb(deep_sky) if deep_sky else self.sky


FOREST = Scenery(
    sky=0x16281C, ground=0x23422B, silhouette=0x1B3322, accent=0x3E6B45,
    deep_sky=0x0E1B13,
)
CAVE = Scenery(
    sky=0x1A1622, ground=0x2B2436, silhouette=0x221C2E, accent=0x4A3B63,
    deep_sky=0x110E17,
)
CITADEL = Scenery(
    sky=0x221A18, ground=0x3A2C27, silhouette=0x2C211D, accent=0x6B4A3E,
    deep_sky=0x160F0E,
)


def _base(scenery):
    img = Image.new("RGBA", (WIDTH, HEIGHT), scenery.sky)
    pixels = img.load()

    # Gradiente vertical do ceu: mais escuro em cima, para o olhar cair na
    # faixa de combate.
    horizon = HEIGHT - GROUND_HEIGHT
    for y in range(horizon):
        t = y / max(1, horizon - 1)
        color = tuple(
            int(scenery.deep_sky[i] + (scenery.sky[i] - scenery.deep_sky[i]) * t)
            for i in range(3)
        ) + (255,)
        for x in range(WIDTH):
            pixels[x, y] = color

    for y in range(horizon, HEIGHT):
        for x in range(WIDTH):
            pixels[x, y] = scenery.ground

    # Linha de horizonte: separa cenario de chao sem precisar de contorno.
    for x in range(WIDTH):
        pixels[x, horizon] = scenery.accent
        pixels[x, horizon + 1] = scenery.accent

    return img, pixels, horizon


def _mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def _rng(seed):
    """Congruencial linear: aleatorio de aparencia, saida sempre a mesma.

    Nao usa `random` para a arte nao mudar com a versao do Python -- um cenario
    diferente a cada regeracao tornaria impossivel revisar um diff de PNG.
    """
    state = seed & 0x7FFFFFFF

    def nxt(n):
        nonlocal state
        state = (state * 1103515245 + 12345) & 0x7FFFFFFF
        return state % n

    return nxt


def _ground_texture(pixels, horizon, scenery, seed, tufts=True):
    """Textura da faixa de chao. E o que faz a rolagem **aparecer**.

    Sem ela o chao e uma cor chapada -- 320 pixels identicos por linha -- e um
    campo uniforme nao mostra deslocamento nenhum por mais rapido que role. Era
    a causa de o jogo parecer parado no lugar com o cenario andando atras.

    Tudo aqui e pontual: pedra, tufo, trinco. Faixa horizontal nao serve, porque
    ela desliza sobre si mesma e continua lendo como parada.

    Os elementos crescem em direcao a base: o que esta perto do olho e maior. E
    o unico sinal de profundidade que uma faixa vista de lado admite.
    """
    nxt = _rng(seed)
    dark = _mix(scenery.ground, scenery.silhouette, 0.55)
    darker = _mix(scenery.ground, scenery.silhouette, 0.85)
    light = _mix(scenery.ground, scenery.accent, 0.30)

    def depth(y):
        return (y - horizon) / GROUND_HEIGHT

    # Pedras: o grosso da textura.
    for _ in range(150):
        x = nxt(WIDTH)
        y = horizon + 3 + nxt(GROUND_HEIGHT - 4)
        radius = 1 + int(depth(y) * 1.6)
        color = dark if nxt(3) else darker
        for dy in range(radius):
            for dx in range(radius + 1):
                tx, ty = x + dx, y + dy
                if 0 <= tx < WIDTH and horizon < ty < HEIGHT:
                    pixels[tx, ty] = color
        # Topo iluminado: e o que faz a pedra ter volume em 2 pixels.
        if radius > 1 and 0 <= x < WIDTH and horizon < y - 1 < HEIGHT:
            pixels[x, y - 1] = light

    # Tufos de vegetacao (ou cristais/escombros, conforme o ato).
    if tufts:
        for _ in range(70):
            x = nxt(WIDTH)
            y = horizon + 4 + nxt(GROUND_HEIGHT - 6)
            height = 1 + int(depth(y) * 3)
            for dy in range(height):
                ty = y - dy
                if 0 <= x < WIDTH and horizon < ty < HEIGHT:
                    pixels[x, ty] = light
                if dy and 0 <= x + 1 < WIDTH and horizon < ty < HEIGHT:
                    pixels[x + 1, ty] = light

    # Trincos: risco curto na diagonal, para o chao nao virar so bolinhas.
    for _ in range(45):
        x = nxt(WIDTH)
        y = horizon + 6 + nxt(GROUND_HEIGHT - 8)
        for step in range(2 + nxt(4)):
            tx, ty = x + step, y + (step // 2)
            if 0 <= tx < WIDTH and horizon < ty < HEIGHT:
                pixels[tx, ty] = darker


def _column(pixels, x, top, bottom, color, width=1):
    for dx in range(width):
        px = x + dx
        if 0 <= px < WIDTH:
            for y in range(max(0, top), min(HEIGHT, bottom)):
                pixels[px, y] = color


def _disc(pixels, cx, cy, radius, color):
    for y in range(cy - radius, cy + radius + 1):
        for x in range(cx - radius, cx + radius + 1):
            if 0 <= x < WIDTH and 0 <= y < HEIGHT:
                if (x - cx) ** 2 + (y - cy) ** 2 <= radius * radius:
                    pixels[x, y] = color


def _canopy(px, cx, cy, radius, color):
    """Copa em aglomerado, nao em circulo perfeito.

    Tres discos deslocados quebram a silhueta redonda. Um disco unico le como
    pirulito -- foi o que a primeira versao produziu.
    """
    _disc(px, cx, cy, radius, color)
    _disc(px, cx - radius, cy + radius // 3, int(radius * 0.72), color)
    _disc(px, cx + radius, cy + radius // 4, int(radius * 0.66), color)
    _disc(px, cx - radius // 3, cy - radius // 2, int(radius * 0.6), color)


def forest():
    """Floresta: troncos e copas aglomeradas em duas profundidades."""
    img, px, horizon = _base(FOREST)

    # Camada distante: massa de folhagem quase continua no alto, para o ceu
    # nao aparecer em faixas entre as arvores.
    for i, x in enumerate(range(-16, WIDTH + 24, 34)):
        height = 66 + (i % 4) * 12
        _column(px, x, horizon - height, horizon, FOREST.silhouette, 8)
        _canopy(px, x + 3, horizon - height, 15 + (i % 3) * 3,
                FOREST.silhouette)

    # Camada proxima: troncos grossos e copas maiores, um tom mais claro.
    for i, x in enumerate(range(-8, WIDTH + 24, 63)):
        height = 96 + (i % 3) * 16
        _column(px, x, horizon - height, horizon, FOREST.accent, 14)
        _canopy(px, x + 6, horizon - height, 22, FOREST.accent)

    # Raizes e moitas quebram a linha reta do horizonte.
    for i, x in enumerate(range(0, WIDTH, 17)):
        _disc(px, x, horizon + 2 + (i % 3), 4 + (i % 2), FOREST.silhouette)

    _ground_texture(px, horizon, FOREST, seed=0x5EED01)

    return img


def cave():
    """Caverna: estalactites do teto e estalagmites do chao."""
    img, px, horizon = _base(CAVE)

    for i, x in enumerate(range(0, WIDTH, 23)):
        drop = 26 + (i % 5) * 13
        for y in range(drop):
            half = max(1, int((drop - y) * 0.30))
            for dx in range(-half, half + 1):
                if 0 <= x + dx < WIDTH:
                    px[x + dx, y] = CAVE.silhouette

    for i, x in enumerate(range(12, WIDTH, 31)):
        rise = 18 + (i % 4) * 9
        for y in range(rise):
            half = max(1, int((rise - y) * 0.34))
            ty = horizon - y
            for dx in range(-half, half + 1):
                if 0 <= x + dx < WIDTH and 0 <= ty < HEIGHT:
                    px[x + dx, ty] = CAVE.accent

    # Veios de cristal no fundo, o unico ponto luminoso do ato.
    for i, x in enumerate(range(30, WIDTH, 88)):
        cy = horizon - 54 - (i % 2) * 16
        _disc(px, x, cy, 3, _rgb(0x4AC5E8))
        _disc(px, x + 7, cy + 6, 2, _rgb(0x2A7E99))

    _ground_texture(px, horizon, CAVE, seed=0x5EED02)

    return img


def citadel():
    """Cidadela: torres com ameias contra o ceu."""
    img, px, horizon = _base(CITADEL)

    for i, x in enumerate(range(-6, WIDTH + 20, 46)):
        height = 74 + (i % 3) * 22
        width = 26
        _column(px, x, horizon - height, horizon, CITADEL.silhouette, width)

        # Ameias.
        for merlon in range(0, width, 8):
            _column(
                px, x + merlon, horizon - height - 7, horizon - height,
                CITADEL.silhouette, 5,
            )

        # Janelas acesas: a unica luz quente do ato.
        for row in range(2):
            wy = horizon - height + 18 + row * 24
            for col in range(2):
                wx = x + 7 + col * 11
                if 0 <= wx < WIDTH and wy < horizon:
                    for dy in range(5):
                        for dx in range(3):
                            if 0 <= wx + dx < WIDTH:
                                px[wx + dx, wy + dy] = _rgb(0xE8B44A)

    # Escombros na base.
    for i, x in enumerate(range(8, WIDTH, 26)):
        _disc(px, x, horizon + 4 + (i % 2) * 3, 3, CITADEL.accent)

    _ground_texture(px, horizon, CITADEL, seed=0x5EED03, tufts=False)

    return img


BACKGROUNDS = {"forest": forest, "cave": cave, "citadel": citadel}
