"""Ferramentas de autoria de pixel art.

Os sprites deste projeto sao desenhados em codigo: cada entidade e um mapa de
caracteres, um caractere por pixel, sobre uma paleta compartilhada. E pixel art
de verdade -- autorada pixel a pixel --, so que em texto em vez de num editor.

A vantagem de manter a fonte assim: ajustar a paleta inteira, corrigir um
contorno em todos os sprites ou regerar as animacoes e uma edicao de uma linha,
nao um retrabalho manual em 29 arquivos.

As animacoes sao derivadas da pose base por transformacoes, e nao desenhadas
quadro a quadro, o que garante que os 4 quadros de um mesmo personagem nunca
"tremam" entre si -- o defeito mais comum de pixel art gerada por IA.
"""

from PIL import Image

# ---------------------------------------------------------------- paleta
#
# 32 cores no maximo, compartilhadas por todos os sprites (specification.md
# 7.1). E o que faz o conjunto parecer um jogo so, e nao 29 desenhos avulsos.

PALETTE = {
    ".": None,                 # transparente
    "k": (0x14, 0x12, 0x1C),   # contorno
    "s": (0x24, 0x1F, 0x30),   # sombra profunda
    "1": (0xE8, 0xB4, 0x8C),   # pele
    "2": (0xC0, 0x8A, 0x62),   # pele sombra
    "m": (0xB9, 0xBE, 0xC7),   # metal
    "n": (0x7C, 0x83, 0x8F),   # metal sombra
    "h": (0xED, 0xE7, 0xDA),   # brilho / branco osso
    "g": (0xE8, 0xB4, 0x4A),   # ouro
    "y": (0xA8, 0x7A, 0x28),   # ouro sombra
    "b": (0x8A, 0x5A, 0x38),   # couro
    "d": (0x5C, 0x3A, 0x24),   # couro sombra
    "u": (0x4A, 0x90, 0xD9),   # tecido azul
    "v": (0x2C, 0x5C, 0x90),   # azul sombra
    "p": (0x9B, 0x3F, 0xBF),   # tecido roxo
    "q": (0x66, 0x27, 0x7F),   # roxo sombra
    "e": (0x5F, 0xBF, 0x60),   # verde
    "f": (0x35, 0x7A, 0x38),   # verde sombra
    "r": (0xD2, 0x4B, 0x4B),   # vermelho
    "t": (0x8A, 0x2E, 0x2E),   # vermelho sombra
    "w": (0xED, 0xE7, 0xDA),   # tecido claro
    "x": (0xB4, 0xAA, 0xC6),   # cinza lilas
    "o": (0x8A, 0x6A, 0x3A),   # madeira
    "i": (0x5A, 0x44, 0x24),   # madeira sombra
    "c": (0xDC, 0xD6, 0xC0),   # osso
    "a": (0x4A, 0xC5, 0xE8),   # magia ciano
    "j": (0x2A, 0x7E, 0x99),   # ciano sombra
    "l": (0x3E, 0x6B, 0x45),   # folhagem
    "z": (0x6B, 0x4A, 0x3E),   # ferrugem
    "3": (0xE8, 0x70, 0x2A),   # laranja / fogo
    "4": (0x7B, 0xE8, 0x8C),   # verde claro / veneno
}


def rgba(char):
    """Converte um caractere do mapa em RGBA."""
    color = PALETTE.get(char)
    return (0, 0, 0, 0) if color is None else (*color, 255)


class Pose:
    """Uma pose: grade de caracteres, com camadas de corpo e de arma.

    A arma vive numa camada propria porque a animacao de ataque a move sozinha.
    Sem isso, o golpe teria de ser redesenhado quadro a quadro.
    """

    def __init__(self, body, weapon=None):
        self.body = [list(row) for row in body]
        self.height = len(self.body)
        self.width = len(self.body[0])
        for row in self.body:
            assert len(row) == self.width, "linhas de larguras diferentes"
        self.weapon = (
            [list(row) for row in weapon]
            if weapon
            else [["." for _ in range(self.width)] for _ in range(self.height)]
        )
        assert len(self.weapon) == self.height


def _blank(w, h):
    return [["." for _ in range(w)] for _ in range(h)]


def _stamp(dst, src, dx=0, dy=0):
    """Carimba `src` sobre `dst`, respeitando transparencia."""
    h, w = len(dst), len(dst[0])
    for y, row in enumerate(src):
        for x, char in enumerate(row):
            if char == ".":
                continue
            ty, tx = y + dy, x + dx
            if 0 <= ty < h and 0 <= tx < w:
                dst[ty][tx] = char
    return dst


def _compose(pose, body_dx=0, body_dy=0, weapon_dx=0, weapon_dy=0):
    grid = _blank(pose.width, pose.height)
    _stamp(grid, pose.body, body_dx, body_dy)
    _stamp(grid, pose.weapon, body_dx + weapon_dx, body_dy + weapon_dy)
    return grid


def _collapse(pose, amount):
    """Achata a pose contra a base -- a queda.

    `amount` vai de 0 (em pe) a 1 (pilha no chao). As linhas sao comprimidas
    para baixo e espalhadas para os lados, que e como um corpo caindo le em
    poucos pixels.
    """
    grid = _blank(pose.width, pose.height)
    if amount >= 1:
        # Pilha final: duas linhas de restos na base.
        source = _compose(pose)
        bottom = pose.height - 1
        for y, row in enumerate(source):
            for x, char in enumerate(row):
                if char == ".":
                    continue
                spread = x + (1 if x > pose.width // 2 else -1)
                target_x = max(0, min(pose.width - 1, spread))
                target_y = bottom if y % 2 == 0 else bottom - 1
                grid[target_y][target_x] = char
        return grid

    source = _compose(pose)
    keep = 1.0 - amount * 0.7
    base = pose.height - 1
    for y, row in enumerate(source):
        # Distancia ate a base, comprimida.
        new_y = int(round(base - (base - y) * keep))
        lean = int(round(amount * (base - y) * 0.35))
        for x, char in enumerate(row):
            if char == ".":
                continue
            tx = max(0, min(pose.width - 1, x + lean))
            if 0 <= new_y < pose.height:
                grid[new_y][tx] = char
    return grid


def build_frames(pose, facing=1):
    """Gera as 12 poses da folha: 4 idle, 4 attack, 4 die.

    `facing` e 1 para quem olha para a direita (herois) e -1 para a esquerda
    (monstros); define para que lado o golpe avanca.
    """
    frames = []

    # --- idle: respiracao. O torso sobe 1px e volta; os pes ficam plantados.
    #
    # `lower` precisa ser carimbado em `waist`, e nao em 0: ele e uma fatia que
    # comeca na linha `waist` do corpo, e `_stamp` conta a partir do indice 0 da
    # fatia. Carimbar em 0 joga as pernas em cima da cabeca -- o sprite sai
    # espremido no topo do quadro, com a metade de baixo vazia.
    waist = int(pose.height * 0.62)
    upper = [row[:] for row in pose.body[:waist]]
    lower = [row[:] for row in pose.body[waist:]]
    for offset in (0, -1, 0, -1):
        grid = _blank(pose.width, pose.height)
        _stamp(grid, upper, 0, offset)
        _stamp(grid, lower, 0, waist)
        _stamp(grid, pose.weapon, 0, offset)
        frames.append(grid)

    # --- attack: recuo, avanco, impacto, recuperacao. O impacto cai no quadro
    # 2, que e o que o codigo sincroniza com o numero de dano.
    for body_dx, weapon_dx, weapon_dy in (
        (-1, -1, 0),   # recuo
        (0, 1, 0),     # inicio do golpe
        (1, 3, 1),     # impacto
        (0, 1, 0),     # recuperacao
    ):
        frames.append(
            _compose(
                pose,
                body_dx=body_dx * facing,
                weapon_dx=weapon_dx * facing,
                weapon_dy=weapon_dy,
            )
        )

    # --- die: queda progressiva. O ultimo quadro fica congelado durante os
    # 30 s de revive, entao precisa ficar legivel parado.
    for amount in (0.25, 0.55, 0.85, 1.0):
        frames.append(_collapse(pose, amount))

    return frames


def write_sheet(path, frames, frame_w, frame_h, columns=4):
    """Grava a folha 4x3 conforme contracts/assets-sprites.md."""
    rows = (len(frames) + columns - 1) // columns
    sheet = Image.new("RGBA", (frame_w * columns, frame_h * rows), (0, 0, 0, 0))

    for index, grid in enumerate(frames):
        col, row = index % columns, index // columns
        for y, line in enumerate(grid):
            for x, char in enumerate(line):
                if char == ".":
                    continue
                sheet.putpixel(
                    (col * frame_w + x, row * frame_h + y), rgba(char)
                )

    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(path)
    return sheet


def write_single(path, grid):
    """Grava um sprite de quadro unico (icone, cenario)."""
    h, w = len(grid), len(grid[0])
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, line in enumerate(grid):
        for x, char in enumerate(line):
            if char != ".":
                img.putpixel((x, y), rgba(char))
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path)
    return img


def preview(images, path, scale=6, gap=4, background=(30, 27, 46, 255)):
    """Monta um contato ampliado, para inspecao humana.

    Ampliacao por vizinho mais proximo: o preview precisa mostrar exatamente os
    pixels gravados, nao uma versao suavizada deles.
    """
    if not images:
        return
    width = max(img.width for img in images) * scale
    total = sum(img.height * scale + gap for img in images) + gap

    canvas = Image.new("RGBA", (width + gap * 2, total), background)
    y = gap
    for img in images:
        scaled = img.resize(
            (img.width * scale, img.height * scale), Image.NEAREST
        )
        canvas.paste(scaled, (gap, y), scaled)
        y += scaled.height + gap

    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)
