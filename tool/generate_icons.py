#!/usr/bin/env python3
"""Gera os ícones do MatchMaster a partir do mesmo emblema do app.

O desenho é o de `lib/widgets/brand.dart`: uma bola cortada pela diagonal da
rede, clay de um lado e teal do outro, com o ponto de saque no canto.

    python3 tool/generate_icons.py

Requer Pillow (`pip install Pillow`).
"""

from __future__ import annotations

import json
import math
import os
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent

INK = (12, 16, 21, 255)
CLAY = (255, 107, 53, 255)
TEAL = (20, 200, 166, 255)

# Renderiza grande e reduz: o antialiasing sai melhor que desenhando direto.
SUPERSAMPLE = 8


def emblem(size: int, *, inset: float = 0.0) -> Image.Image:
    """Emblema em RGBA, transparente fora da bola.

    `inset` encolhe o desenho dentro da tela — o ícone adaptativo do Android
    corta as bordas, então lá a bola precisa de folga.
    """
    big = size * SUPERSAMPLE
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    pad = big * inset
    box = (pad, pad, big - pad, big - pad)
    radius = (box[2] - box[0]) / 2
    cx, cy = big / 2, big / 2

    # Ângulos do PIL: 0° às 3h, crescendo no sentido horário (y cresce para
    # baixo). A rede vai de 135° (baixo-esquerda) a 315° (cima-direita), então
    # o clay fica na metade de cima-esquerda e o teal na de baixo-direita —
    # a mesma orientação de `BrandMark`.
    draw.pieslice(box, start=135, end=315, fill=CLAY)
    draw.pieslice(box, start=315, end=135, fill=TEAL)

    # A rede é um rasgo transparente. Fora do disco tudo já é transparente,
    # então a linha pode extrapolar sem estragar o desenho.
    angle = math.radians(-45)
    dx, dy = math.cos(angle), math.sin(angle)
    reach = radius * 2
    draw.line(
        [
            (cx - dx * reach, cy - dy * reach),
            (cx + dx * reach, cy + dy * reach),
        ],
        fill=(0, 0, 0, 0),
        width=max(1, int(radius * 0.22)),
    )

    # Ponto de saque, no lado do saibro.
    dot_r = radius * 0.17
    ox, oy = cx - radius * 0.36, cy - radius * 0.36
    draw.ellipse(
        [ox - dot_r, oy - dot_r, ox + dot_r, oy + dot_r],
        fill=(0, 0, 0, 0),
    )

    return canvas.resize((size, size), Image.LANCZOS)


def on_ink(size: int, *, scale: float = 0.62, radius_ratio: float | None = None) -> Image.Image:
    """Emblema sobre o fundo ink, para lojas e launchers que não recortam."""
    big = size * SUPERSAMPLE
    base = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(base)
    if radius_ratio is None:
        draw.rectangle([0, 0, big, big], fill=INK)
    else:
        draw.rounded_rectangle(
            [0, 0, big - 1, big - 1], radius=big * radius_ratio, fill=INK
        )
    base = base.resize((size, size), Image.LANCZOS)

    mark_size = int(size * scale)
    mark = emblem(mark_size)
    offset = (size - mark_size) // 2
    base.alpha_composite(mark, (offset, offset))
    return base


def write(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)
    print(f"  {path.relative_to(ROOT)}  {image.size[0]}x{image.size[1]}")


def android() -> None:
    print("Android")
    densities = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    res = ROOT / "android/app/src/main/res"
    for name, px in densities.items():
        write(on_ink(px, radius_ratio=0.22), res / f"mipmap-{name}/ic_launcher.png")
        # Camadas do ícone adaptativo: 108dp com 18dp de margem de segurança.
        adaptive = int(px * 108 / 48)
        write(
            emblem(adaptive, inset=0.28),
            res / f"mipmap-{name}/ic_launcher_foreground.png",
        )


def ios() -> None:
    print("iOS")
    base = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((base / "Contents.json").read_text())
    for entry in contents.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        scale = float(entry["scale"].rstrip("x"))
        px = int(round(float(entry["size"].split("x")[0]) * scale))
        # A App Store não aceita canal alfa no ícone.
        icon = on_ink(px).convert("RGB")
        path = base / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        icon.save(path)
        print(f"  {path.relative_to(ROOT)}  {px}x{px}")


def macos() -> None:
    print("macOS")
    base = ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset"
    if not base.exists():
        return
    contents = json.loads((base / "Contents.json").read_text())
    for entry in contents.get("images", []):
        filename = entry.get("filename")
        if not filename:
            continue
        scale = float(entry["scale"].rstrip("x"))
        px = int(round(float(entry["size"].split("x")[0]) * scale))
        write(on_ink(px, radius_ratio=0.22), base / filename)


def web() -> None:
    print("Web")
    icons = ROOT / "web/icons"
    write(on_ink(192, radius_ratio=0.22), icons / "Icon-192.png")
    write(on_ink(512, radius_ratio=0.22), icons / "Icon-512.png")
    # Maskable: o recorte pode ser circular, então a marca fica menor.
    write(on_ink(192, scale=0.46), icons / "Icon-maskable-192.png")
    write(on_ink(512, scale=0.46), icons / "Icon-maskable-512.png")
    write(on_ink(64, radius_ratio=0.22), ROOT / "web/favicon.png")


def windows() -> None:
    print("Windows")
    path = ROOT / "windows/runner/resources/app_icon.ico"
    if not path.parent.exists():
        return
    sizes = [16, 24, 32, 48, 64, 128, 256]
    frames = [on_ink(s, radius_ratio=0.22).convert("RGBA") for s in sizes]
    frames[-1].save(path, format="ICO", sizes=[(s, s) for s in sizes])
    print(f"  {path.relative_to(ROOT)}  {sizes}")


def docs() -> None:
    print("Documentação")
    write(emblem(512), ROOT / "docs/screenshots/emblem.png")


if __name__ == "__main__":
    os.chdir(ROOT)
    android()
    ios()
    macos()
    web()
    windows()
    docs()
    print("Pronto.")
