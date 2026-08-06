"""Gera todos os sprites do jogo a partir das fontes em `tool/`.

    python tool/generate_sprites.py [--preview]

Os PNGs saem em `assets/sprites/`, exatamente com os nomes, tamanhos e grades
de `specs/001-idle-rpg-mecanicas/contracts/assets-sprites.md`. Regerar e sempre
seguro: a saida e determinada pela fonte, nunca acumulativa.

`--preview` grava contatos ampliados em `tool/_preview/` para inspecao humana.
Eles nao entram no app.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from PIL import Image  # noqa: E402

import backgrounds as B  # noqa: E402
import heroes as H  # noqa: E402
import items as I  # noqa: E402
import monsters as M  # noqa: E402
import sprite_lib as S  # noqa: E402

ROOT = Path(__file__).parent.parent
SPRITES = ROOT / "assets" / "sprites"
PREVIEW = Path(__file__).parent / "_preview"


def _strip(images, scale, path, background=(30, 27, 46, 255)):
    gap = 6
    width = sum(i.width * scale + gap for i in images) + gap
    height = max(i.height for i in images) * scale + gap * 2
    canvas = Image.new("RGBA", (width, height), background)
    x = gap
    for img in images:
        scaled = img.resize(
            (img.width * scale, img.height * scale), Image.NEAREST
        )
        canvas.paste(scaled, (x, gap), scaled)
        x += scaled.width + gap
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def main(with_preview=False):
    made = 0
    heroes, commons, bosses, icons, scenes = [], [], [], [], []

    for name, pose in H.HEROES.items():
        frames = S.build_frames(pose, facing=1)
        img = S.write_sheet(SPRITES / "heroes" / f"{name}.png", frames, 16, 24)
        heroes.append(img.crop((0, 0, 16, 24)))
        made += 1

    for name, pose in M.COMMON_MONSTERS.items():
        frames = S.build_frames(pose, facing=-1)
        img = S.write_sheet(
            SPRITES / "monsters" / f"{name}.png", frames, 16, 16
        )
        commons.append(img.crop((0, 0, 16, 16)))
        made += 1

    for name, pose in M.BOSSES.items():
        frames = S.build_frames(pose, facing=-1)
        img = S.write_sheet(
            SPRITES / "monsters" / f"{name}.png", frames, 32, 32
        )
        bosses.append(img.crop((0, 0, 32, 32)))
        made += 1

    for name, grid in I.ITEMS.items():
        icons.append(S.write_single(SPRITES / "items" / f"{name}.png", grid))
        made += 1

    for name, build in B.BACKGROUNDS.items():
        img = build()
        path = SPRITES / "backgrounds" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        img.save(path)
        scenes.append(img)
        made += 1

    print(f"{made} sprites gerados em {SPRITES.relative_to(ROOT)}")

    if with_preview:
        _strip(heroes, 7, PREVIEW / "heroes.png")
        _strip(commons, 8, PREVIEW / "monsters_common.png")
        _strip(bosses, 6, PREVIEW / "monsters_boss.png")
        _strip(icons, 8, PREVIEW / "items.png")
        for name, img in zip(B.BACKGROUNDS, scenes):
            img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(
                PREVIEW / f"bg_{name}.png"
            )
        print(f"previews em {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main(with_preview="--preview" in sys.argv)
