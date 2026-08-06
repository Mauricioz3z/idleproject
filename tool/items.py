"""Icones de item e Essencia (16x16, quadro unico).

Desenhados em **tons de cinza** de proposito: o codigo aplica a cor da raridade
por cima. Sao 7 tipos + Essencia cobrindo as 8 raridades, em vez dos 56
arquivos que a combinacao exigiria (contracts/assets-sprites.md 4).

Por isso os mapas usam so `k` (contorno), `n`/`m`/`h` (cinza escuro, medio e
claro) e `b`/`d` para cabo de couro -- nada que brigue com a tintura.
"""

WEAPON = [
    "................",
    ".............kk.",
    "............khhk",
    "...........khmhk",
    "..........khmmhk",
    ".........khmmhk.",
    "........khmmhk..",
    ".......khmmhk...",
    "......khmmhk....",
    ".....khmmhk.....",
    "....kkmmhk......",
    "...kbbkhk.......",
    "..kbbbk.........",
    ".kdbbk..........",
    ".kdbk...........",
    "..kk............",
]

ARMOR = [
    "................",
    "..kkk......kkk..",
    ".khhmk....kmhhk.",
    "khhmmmkkkkmmmhhk",
    "khmmmmmmmmmmmmhk",
    "khmmmmmmmmmmmmhk",
    "kkmmmmmmmmmmmmkk",
    ".khmmmmmmmmmmhk.",
    ".khmmmnnnnmmmhk.",
    ".khmmmmmmmmmmhk.",
    ".khmmmmmmmmmmhk.",
    ".khmmmmmmmmmmhk.",
    "..khmmmmmmmmhk..",
    "..khmmmkkmmmhk..",
    "..kkmmk..kmmkk..",
    "...kkk....kkk...",
]

HELMET = [
    "................",
    ".....kkkkkk.....",
    "...kkhhhhhhkk...",
    "..khhmmmmmmhhk..",
    ".khhmmmmmmmmhhk.",
    ".khmmmmmmmmmmhk.",
    ".khmmmmmmmmmmhk.",
    ".khmkkkkkkkkmhk.",
    ".khmk......kmhk.",
    ".khmk......kmhk.",
    ".khmmkkkkkkmmhk.",
    ".khmmmmmmmmmmhk.",
    "..khmmmmmmmmhk..",
    "..kkmmmmmmmmkk..",
    "...kkmmmmmmkk...",
    ".....kkkkkk.....",
]

GLOVES = [
    "................",
    "....kk..kk......",
    "...khhkkhhk.....",
    "...khmmmmhk.kk..",
    "..kkhmmmmhkkhhk.",
    ".khhhmmmmmhhmmhk",
    ".khmmmmmmmmmmmhk",
    ".khmmmmmmmmmmmhk",
    ".khmmmmmmmmmmhk.",
    ".kbmmmmmmmmmhk..",
    ".kbbbbbmmmmmk...",
    ".kdbbbbbmmmk....",
    "..kdbbbbbkk.....",
    "...kdbbbk.......",
    "....kddk........",
    ".....kk.........",
]

BOOTS = [
    "................",
    "..kkk.....kkk...",
    ".khhk....khhk...",
    ".khmk....khmk...",
    ".khmk....khmk...",
    ".khmk....khmk...",
    ".khmk....khmk...",
    ".khmk....khmk...",
    ".khmk....khmk...",
    ".kbmk....kbmk...",
    ".kbbkk...kbbkk..",
    ".kbbbbk..kbbbbk.",
    ".kdbbbbk.kdbbbbk",
    ".kdbbbbk.kdbbbbk",
    ".kkdddkk.kkdddkk",
    "..kkkkk...kkkkk.",
]

AMULET = [
    "................",
    "...kkkkkkkkkk...",
    "..khhk......khk.",
    "..khk........khk",
    "..kk..........kk",
    "..k............k",
    "..k............k",
    "...k..........k.",
    "....k........k..",
    ".....kk....kk...",
    "......khhhhk....",
    ".....khmmmmhk...",
    ".....khmnnmhk...",
    ".....khmmmmhk...",
    "......khhhhk....",
    ".......kkkk.....",
]

RING = [
    "................",
    "................",
    ".......kk.......",
    "......khhk......",
    "......khhk......",
    "....kkkmmkkk....",
    "...khhmmmmhhk...",
    "..khhmk..kmhhk..",
    "..khmk....kmhk..",
    "..khmk....kmhk..",
    "..khmk....kmhk..",
    "..khhmk..kmhhk..",
    "...khhmmmmhhk...",
    "....kkkmmkkk....",
    "......kkkk......",
    "................",
]

# A Essencia nao e equipamento: e o insumo raro do Cubo. O frasco a distingue
# dos 7 slots sem precisar de cor propria.
ESSENCE = [
    "................",
    "......kkkk......",
    "......khhk......",
    "......kmmk......",
    "......kmmk......",
    ".....kkmmkk.....",
    "....khmmmmhk....",
    "...khmmmmmmhk...",
    "..khmmmmmmmmhk..",
    "..khmmhhhhmmhk..",
    "..khmhhhhhhmhk..",
    "..khmhhhhhhmhk..",
    "..khmmhhhhmmhk..",
    "...khmmmmmmhk...",
    "....khhhhhhk....",
    ".....kkkkkk.....",
]

ITEMS = {
    "weapon": WEAPON,
    "armor": ARMOR,
    "helmet": HELMET,
    "gloves": GLOVES,
    "boots": BOOTS,
    "amulet": AMULET,
    "ring": RING,
    "essence": ESSENCE,
}
