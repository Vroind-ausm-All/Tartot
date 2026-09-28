"""Kontaktboegen: alle Sprites einer Art auf einem Blatt, mit Namen aus dem Spielkern.

Laeuft in Blenders Python (von bauen.py aufgerufen) oder einzeln:
    python3 tools/blender/kontakt.py figuren|charms

Die Namen kommen direkt aus Acts.cs und GameCatalog.cs, damit Blatt und
Spiel nicht auseinanderlaufen. Schrift: TARTOT_FONT (eine .ttf) oder die
eingebaute Ersatzschrift von Pillow.
"""

import os
import re
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "blockout")
CORE = os.path.join(ROOT, "unity", "Assets", "Tartot", "Core", "Content")

INK = (26, 20, 18, 255)
PAPER = (239, 227, 200, 255)
S1 = (201, 180, 142, 255)
S2 = (143, 122, 90, 255)
S3 = (78, 64, 50, 255)
GOLD = (227, 168, 59, 255)


def names(kind):
    if kind == "figuren":
        text = open(os.path.join(CORE, "Acts.cs"), encoding="utf-8").read()
        pairs = re.findall(r'(?:E|Boss)\("([a-z_]+)", "([^"]+)"', text)
        pairs += re.findall(r'"(boss_welt|boss_sonne|weltenwurm)", "([^"]+)"', text)
    else:
        text = open(os.path.join(CORE, "GameCatalog.cs"), encoding="utf-8").read()
        pairs = re.findall(r'C\("([a-z_]+)","([^"]+)"', text)
    return dict(pairs)


def font(size):
    path = os.environ.get("TARTOT_FONT")
    if path and os.path.exists(path):
        return ImageFont.truetype(path, size)
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def sheet(kind, order, tiers=None, scale=2, cols=6, title=None, outline=2):
    label = names(kind)
    sprites = []
    for ident in order:
        path = os.path.join(OUT, kind, ident + ".png")
        if os.path.exists(path):
            sprites.append((ident, Image.open(path).convert("RGBA")))
    if not sprites:
        return None
    cell = max(max(im.width, im.height) for _, im in sprites) * scale + 16
    text_h = 44 if kind == "figuren" else 40
    rows = (len(sprites) + cols - 1) // cols
    head = 64
    W, H = cols * (cell + 8) + 8, head + rows * (cell + text_h + 8) + 8
    out = Image.new("RGBA", (W, H), INK)
    d = ImageDraw.Draw(out)
    big, small, tiny = font(34), font(20), font(16)
    d.text((12, 12), title or kind.upper(), font=big, fill=PAPER)
    d.text((W - 12, 22), "Blender-Blockout · Pixel 1:1 ×%d · %d px Kontur" % (scale, outline), font=small, fill=S1, anchor="ra")
    for n, (ident, im) in enumerate(sprites):
        cx = 8 + (n % cols) * (cell + 8)
        cy = head + (n // cols) * (cell + text_h + 8)
        d.rectangle([cx, cy, cx + cell - 1, cy + cell + text_h - 1], fill=S2, outline=S3, width=2)
        big_im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
        out.alpha_composite(big_im, (cx + (cell - big_im.width) // 2, cy + (cell - big_im.height) // 2))
        d.rectangle([cx, cy + cell, cx + cell - 1, cy + cell + text_h - 1], fill=S3)
        d.text((cx + cell // 2, cy + cell + 4), label.get(ident, ident), font=small, fill=PAPER, anchor="ma")
        tier = (tiers or {}).get(ident, "")
        sub = "%s · %d px" % (tier, im.width) if tier else "%d px" % im.width
        d.text((cx + cell // 2, cy + cell + 24), sub, font=tiny, fill=GOLD if tier in ("boss", "finale") else S1,
               anchor="ma")
    path = os.path.join(OUT, "kontaktbogen_%s.png" % kind)
    out.save(path)
    return path


def run(kind):
    sys.path.insert(0, HERE)
    if kind == "figuren":
        import figuren
        order = [i for i, _, _ in figuren.FIGUREN]
        tiers = {i: t for i, t, _ in figuren.FIGUREN}
        return sheet(kind, order, tiers, scale=2, cols=6, title="TARTOT · Figuren")
    import charms
    order = [i for i, _ in charms.CHARMS]
    return sheet(kind, order, None, scale=4, cols=10, title="TARTOT · Charms", outline=charms.OUTLINE)


if __name__ == "__main__":
    for k in sys.argv[1:] or ["figuren", "charms"]:
        print(run(k))
