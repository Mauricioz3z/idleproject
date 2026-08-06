"""Poses base dos monstros (16x16 comuns, 32x32 bosses, olhando para a esquerda).

Os monstros ficam a direita da arena e encaram os herois, entao a leitura de
frente fica do lado esquerdo do quadro.

Cada ato tem uma familia cromatica propria, herdada dos cenarios: Floresta em
verde, Caverna em roxo mineral, Cidadela em ferrugem. E o que permite reconhecer
"em que ato estou" pelo inimigo, sem olhar a HUD.

Bosses ocupam o dobro da area (32x32) porque a wave de boss precisa mudar de
natureza a primeira vista (CEN-M08-002).
"""

from sprite_lib import Pose

_E16 = ["." * 16 for _ in range(16)]
_E32 = ["." * 32 for _ in range(32)]


# ----------------------------------------------------- Ato 1 -- Floresta

# Broto Rastejante -- o mais fraco do jogo. Pequeno, uma folha por cabeca.
FOREST_SPROUT = Pose(
    body=[
        "................",
        "................",
        "......kek.......",
        ".....ke4ek......",
        "....kle4elk.....",
        "....klleellk....",
        ".....klllk......",
        "....kleeelk.....",
        "...klekkelk.....",
        "...kle44elk.....",
        "...klleeellk....",
        "...kllllllk.....",
        "....klllllk.....",
        "...klk...klk....",
        "..kllk...kllk...",
        "..kkkk...kkkk...",
    ],
    weapon=_E16,
)

# Espreitador da Mata -- felino magro e rapido. Quatro patas, cauda erguida.
FOREST_STALKER = Pose(
    body=[
        "................",
        "................",
        "................",
        "..kkk........kk.",
        ".kfffk......kfk.",
        "kf3f3fk....kfk..",
        "kfkkkfkkkkkfk...",
        "kfffffffffffk...",
        ".kfllllllllfk...",
        ".kfllllllllfk...",
        "..kffllllffk....",
        "..kfk.kfk.kfk...",
        "..kfk.kfk.kfk...",
        "..kfk.kfk.kfk...",
        ".kffk.kffk.kfk..",
        ".kkkk.kkkk.kkk..",
    ],
    weapon=_E16,
)

# Sarca Torcida -- emaranhado de espinhos. Atarracado, mais defesa que ataque.
FOREST_BRAMBLE = Pose(
    body=[
        "................",
        "..k..k....k..k..",
        "..kk.kk..kk.kk..",
        "...klkkkkkklk...",
        "..klllfllfllk...",
        ".kllfllllllflk..",
        "kllfl3ll3lflllk.",
        "klllllkkllllllk.",
        "kllfllllllllflk.",
        ".klllfllllflllk.",
        ".kllllllllllllk.",
        "..klllfllfllk...",
        "...kllllllk.....",
        "...klk..klk.....",
        "..kilk..klik....",
        "..kkkk..kkkk....",
    ],
    weapon=_E16,
)

# Guardiao do Bosque -- primeiro boss. Ent de madeira e musgo, com olhos
# luminosos. Tem de impor: e a primeira wave que muda de natureza.
FOREST_WARDEN = Pose(
    body=[
        "................................",
        "..........kkkk..................",
        ".......kkkilllikkk..............",
        "......kllllllllllk..............",
        ".....klllikkkkillk..............",
        ".....kllik4444killk.............",
        "....klllk444444kllk.............",
        "....kllik4kkkk4killk............",
        "....kllk44kkkk44kllk............",
        "....kllik444444killk............",
        ".....kllik4444killlk............",
        ".....klllikkkkilllk.............",
        "......kllllllllllk..............",
        ".....kiillllllllik..............",
        "....killlllllllllik.............",
        "...kill3llllllll3llik...........",
        "..killllllllllllllllik..........",
        "..kiilllllllllllllliik..........",
        "..kilkilllllllllliklik..........",
        "..kilk.killllllik.kilk..........",
        "..kilk..killllik..kilk..........",
        "..kkk...kiillik...kkk...........",
        "........killlik.................",
        "........killlik.................",
        "........kiilkiik................",
        ".......killk.killk..............",
        ".......killk.killk..............",
        "......killlk.killlk.............",
        "......kiiilk.kiiilk.............",
        ".....kiillik.kiillik............",
        ".....kkkkkk..kkkkkk.............",
        "................................",
    ],
    weapon=_E32,
)


# ------------------------------------------------------- Ato 2 -- Caverna

# Roedor das Fendas -- roedor grande e veloz, dentes a mostra.
CAVE_GNAWER = Pose(
    body=[
        "................",
        "................",
        "................",
        "..kk.........kk.",
        ".kzzk.......kzk.",
        "kz3zzk.....kzk..",
        "kzkzzzkkkkzzk...",
        "khhzzzzzzzzzk...",
        "kkkzzzzzzzzzk...",
        ".kzzzzzzzzzzk...",
        ".kzzzzzzzzzzk...",
        "..kzzkkkkzzk....",
        "..kzk...kzk.....",
        "..kzk...kzk.....",
        ".kzzk...kzzk....",
        ".kkkk...kkkk....",
    ],
    weapon=_E16,
)

# Cristalino -- criatura de cristal, angular e luminosa.
CAVE_SHARDLING = Pose(
    body=[
        "................",
        ".......kk.......",
        "......kaak......",
        ".....kaajak.....",
        "....kaajjaak....",
        "...kaajjjjaak...",
        "..kaajkkkkjaak..",
        "..kajk3ll3kjak..",
        "..kajkkkkkkjak..",
        "..kaajjjjjjaak..",
        "...kaajjjjaak...",
        "....kaajjaak....",
        ".....kaajak.....",
        "....kajk.kjak...",
        "...kaak...kaak..",
        "...kkkk...kkkk..",
    ],
    weapon=_E16,
)

# Bruto de Pedra -- bloco de rocha com bracos. Lento e duro.
CAVE_HULK = Pose(
    body=[
        "................",
        "................",
        "...kkkkkkkk.....",
        "..kxnnnnnnxk....",
        "..kn3nnnn3nk....",
        "..knnkkkknnk....",
        "kknnnnnnnnnnkk..",
        "kxnnnnnnnnnnxk..",
        "kxnnxxxxxxnnxk..",
        "kxnnnnnnnnnnxk..",
        "kknnnnnnnnnnkk..",
        "..knnnnnnnnk....",
        "..knnkkkknnk....",
        "..knnk..knnk....",
        ".kxnnk..knnxk...",
        ".kkkkk..kkkkk...",
    ],
    weapon=_E16,
)

# Fauce do Abismo -- boss do Ato 2. Uma boca que se abre no chao da caverna.
CAVE_MAW = Pose(
    body=[
        "................................",
        "................................",
        "....kkkk............kkkk........",
        "...kqqqqkk........kkqqqqk.......",
        "..kqppppqqkkkkkkqqppppqk........",
        "..kqppppppqqqqqqppppppqk........",
        "..kqppphhppppppppphhppqk........",
        "..kqpphjjhpppppphjjhppqk........",
        "..kqpphjjhpppppphjjhppqk........",
        "..kqppphhppppppppphhppqk........",
        "..kqppppppppppppppppppqk........",
        "..kqqppppppppppppppppqqk........",
        "...kkqqppppppppppppqqkk.........",
        "....kchcqqppppppqqchck..........",
        "....kchhcqqppppqqchhck..........",
        "....kcchhcqqppqqchhcck..........",
        "....kccchhcqqqqchhccck..........",
        "....kkccchhccchhcccckk..........",
        "......kkcchhhhhhccckk...........",
        "........kkcchhhhcckk............",
        "..........kkcchhckk.............",
        "...........kkcchkk..............",
        "............kkckk...............",
        "..........kqqqqqqk..............",
        ".........kqppppppqk.............",
        ".........kqppppppqk.............",
        "........kqqppppppqqk............",
        "........kqqqppppqqqk............",
        ".......kqqqqqqqqqqqqk...........",
        "......kqqqqqqqqqqqqqqk..........",
        "......kkkkkkkkkkkkkkkk..........",
        "................................",
    ],
    weapon=_E32,
)


# ----------------------------------------------------- Ato 3 -- Cidadela

# Sentinela Enferrujada -- armadura vazia animada. Nada dentro do elmo.
CITADEL_SENTRY = Pose(
    body=[
        "................",
        "....kkkkkk......",
        "...kzmmmmzk.....",
        "...kzkkkkzk.....",
        "...kz3kk3zk.....",
        "...kzmmmmzk.....",
        "....kzmmzk......",
        "..kkkzzzzkkk....",
        ".kzmmmmmmmmzk...",
        ".kzmzmmmmzmzk...",
        ".kzmzmmmmzmzk...",
        "..kzmmmmmmzk....",
        "..kzmkkkkmzk....",
        "..kzmk..kmzk....",
        ".kzmmk..kmmzk...",
        ".kkkkk..kkkkk...",
    ],
    weapon=_E16,
)

# Carcereiro Palido -- espectro carcereiro, corrente pendurada.
CITADEL_WARDEN = Pose(
    body=[
        "................",
        "....kkkkk.......",
        "...kccccck......",
        "...kckkkck......",
        "...kc3kk3k......",
        "...kccckck......",
        "....kcccck......",
        "..kkxccccxkk....",
        ".kxxccccccxxk...",
        ".kxccccccccck.k.",
        ".kxcccccccccknk.",
        ".kxxcccccccxk.k.",
        "..kxcccccccxk.k.",
        "..kxcckkccxk.nk.",
        "..kxxk..kxxk.k..",
        "..kkkk..kkkk....",
    ],
    weapon=_E16,
)

# Espectro de Guerra -- guerreiro fantasma, translucido e veloz.
CITADEL_REVENANT = Pose(
    body=[
        "................",
        "....kkkk........",
        "...kajjak.......",
        "...kakkak.......",
        "...ka4k4ak......",
        "...kajjjak......",
        "....kajak.......",
        "..kkajjjakk.....",
        ".kajjjjjjjak....",
        ".kajajjjajak....",
        ".kajjjjjjjak....",
        "..kajjjjjak.....",
        "..kajjjjjak.....",
        "...kajjjak......",
        "....kajak.......",
        ".....kkk........",
    ],
    weapon=_E16,
)

# Tirano da Cidadela -- chefe final. Armadura escura, coroa e capa: o inimigo
# mais imponente do jogo.
CITADEL_TYRANT = Pose(
    body=[
        "................................",
        "......kgk..kgk..kgk.............",
        "......kgkkkkgkkkkgk.............",
        ".....kgggggggggggggk............",
        ".....kkkkkkkkkkkkkkk............",
        "......kzsssssssszk..............",
        "......kzskkkkkkszk..............",
        "......kzsk3kk3kszk..............",
        "......kzskkkkkkszk..............",
        "......kzsssssssszk..............",
        ".......kzssssszk................",
        "....kkkkzsssszkkkk..............",
        "...ktrrkzsssszkrrtk.............",
        "..ktrrrkzsssszkrrrtk............",
        "..ktrrkzssssssszkrrtk...........",
        "..ktrkzsssssssssszkrtk..........",
        "..ktrkzssgggggssszkrtk..........",
        "..ktrkzssgkkkgssszkrtk..........",
        "..ktrkzssgggggssszkrtk..........",
        "..ktrkzsssssssssszkrtk..........",
        "..ktrrkzsssssssszkrrtk..........",
        "..ktrrrkzsssssszkrrrtk..........",
        "..ktrrrrkzsssszkrrrrtk..........",
        "..kttrrrkzsssszkrrrttk..........",
        "...kkttrkzssssszkrttkk..........",
        ".....kkkkzskkkszkkkk............",
        "........kzsk.kszk...............",
        "........kzsk.kszk...............",
        ".......kzssk.kzssk..............",
        "......kzsssk.kzsssk.............",
        "......kkkkkk.kkkkkk.............",
        "................................",
    ],
    weapon=_E32,
)


COMMON_MONSTERS = {
    "forest_sprout": FOREST_SPROUT,
    "forest_stalker": FOREST_STALKER,
    "forest_bramble": FOREST_BRAMBLE,
    "cave_gnawer": CAVE_GNAWER,
    "cave_shardling": CAVE_SHARDLING,
    "cave_hulk": CAVE_HULK,
    "citadel_sentry": CITADEL_SENTRY,
    "citadel_warden": CITADEL_WARDEN,
    "citadel_revenant": CITADEL_REVENANT,
}

BOSSES = {
    "forest_warden": FOREST_WARDEN,
    "cave_maw": CAVE_MAW,
    "citadel_tyrant": CITADEL_TYRANT,
}
