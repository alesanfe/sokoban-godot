"""Ensambla user://gif_frames/*.png en docs/assets/demo.gif.

Tras ejecutar: godot --path . -s res://tools/gif_demo.gd
(python tools/make_gif.py — usa PIL, resize a 640px de ancho)
"""
from pathlib import Path
from PIL import Image

frames_dir = Path(__file__).parent.parent / "docs" / "assets" / "_frames"
out = Path(__file__).parent.parent / "docs" / "assets" / "demo.gif"

frames = sorted(frames_dir.glob("f*.png"))
if not frames:
    raise SystemExit(f"sin frames en {frames_dir} — corre primero gif_demo.gd")

imgs = []
W = 800
for f in frames:
    im = Image.open(f).convert("RGB")
    # quantize por frame con paleta amplia — la UI es dark-theme y una
    # paleta adaptativa de 128 colores aplastaba los grises a rojo
    q = im.quantize(colors=256, method=Image.Quantize.FASTOCTREE,
                    dither=Image.Dither.FLOYDSTEINBERG)
    imgs.append(q.resize((W, int(im.height * W / im.width))))

imgs[0].save(
    out,
    save_all=True,
    append_images=imgs[1:],
    duration=110,
    loop=0,
    optimize=True,
)
print(f"OK: {out} — {len(imgs)} frames, {out.stat().st_size // 1024} KB")

# limpieza
for f in frames:
    f.unlink()
frames_dir.rmdir()
