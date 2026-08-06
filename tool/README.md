# tool/ — fonte da arte

Os sprites do jogo são desenhados em código, não em editor de imagem.

```bash
python tool/generate_sprites.py            # gera os 29 PNGs em assets/sprites/
python tool/generate_sprites.py --preview  # + contatos ampliados em tool/_preview/
```

| Arquivo | Conteúdo |
|---|---|
| `sprite_lib.py` | Paleta de 32 cores, composição de poses e derivação das animações |
| `heroes.py` | 6 heróis (16×24) |
| `monsters.py` | 9 monstros comuns (16×16) e 3 bosses (32×32) |
| `items.py` | 8 ícones de item (16×16, em cinza para tingir) |
| `backgrounds.py` | 3 cenários (320×180), estes procedurais |

Cada personagem é um **mapa de caracteres**: um caractere por pixel, sobre a
paleta compartilhada. As animações (idle, ataque, queda) são derivadas da pose
base por transformação — nunca desenhadas quadro a quadro, o que garante que os
4 quadros de um personagem não "tremam" entre si.

O formato de saída está fixado em
`specs/001-idle-rpg-mecanicas/contracts/assets-sprites.md`. Arte externa que
siga aquele contrato substitui estes PNGs sem tocar em código.

`_preview/` é descartável: serve para inspeção humana e não entra no app.
