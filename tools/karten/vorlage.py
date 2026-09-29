"""Erzeugt die Bildteile der Kartenvorlage fuer das Godot-Addon tartot_karten.

    python3 tools/karten/vorlage.py [--motive <ordner mit den Boss-Blaettern>]

Ausgabe nach godot-karten/addons/tartot_karten/kunst/:
    rahmen.png          Vorderseite ohne Motiv, Zahl und Name (240 x 360)
    rueckseite.png      Rueckseite
    farben/<farbe>.png  kleine Farbsymbole fuer die Ecken (16 x 16)
    vorlage_2x.png      Mal-Vorlage in doppelter Groesse mit allen Massen
    motive/<id>.png     Beispielmotive (172 x 208), ausgeschnitten aus deinen
                        Entwuerfen - nur mit --motive, die Quellbilder liegen
                        nicht im Repository.

Ganz selbst gemalte Karten (240 x 360) liegen in kunst/karten/<id>.png und
ersetzen Rahmen, Motiv, Zahl und Name; dieses Skript fasst sie nicht an.

Alle Masse stehen in MASSE und in VORLAGE.md; das Godot-Addon liest sie aus
karte.gd. Wer die Karte anders schneiden will, aendert beides.
"""

import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "godot-karten", "addons", "tartot_karten", "kunst")
FONTS = os.path.join(ROOT, "godot-karten", "addons", "tartot_karten", "schrift")

INK = (26, 20, 18, 255)
INK2 = (43, 34, 28, 255)
PAPER = (239, 227, 200, 255)
PAPER2 = (221, 204, 168, 255)
S1 = (201, 180, 142, 255)
S2 = (143, 122, 90, 255)
S3 = (78, 64, 50, 255)
GOLD = (227, 168, 59, 255)
GOLD2 = (244, 210, 122, 255)
BLOOD = (179, 38, 43, 255)
INDIGO = (59, 74, 140, 255)

# Masse der Karte in Pixeln (1x). Das Addon zeigt die Karte in dieser Groesse.
MASSE = {
    "karte": (240, 360),
    "ecke": 16,
    "perforation_x": (9, 225),      # linke Kante der beiden Lochstreifen
    "perforation": (6, 9, 18),      # Breite, Hoehe, Abstand
    "motiv": (34, 52, 172, 208),    # x, y, b, h
    "zahl": (0, 12, 240, 36),       # Bereich der Zahl oben
    "name": (28, 268, 184, 60),     # Bereich des Namens unten
    "seltenheit": (120, 340),       # Mitte der Seltenheitsraute
}


def rounded(d, box, r, fill, outline=None, width=1):
    d.rounded_rectangle(box, r, fill=fill, outline=outline, width=width)


def rahmen():
    w, h = MASSE["karte"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rounded(d, (0, 0, w - 1, h - 1), MASSE["ecke"], INK)
    rounded(d, (3, 3, w - 4, h - 4), MASSE["ecke"] - 3, PAPER2)
    rounded(d, (7, 7, w - 8, h - 8), MASSE["ecke"] - 6, PAPER)
    # Lochstreifen: die Karte ist ein Filmbild
    pw, ph, step = MASSE["perforation"]
    for x in MASSE["perforation_x"]:
        for y in range(30, h - 30, step):
            rounded(d, (x, y, x + pw - 1, y + ph - 1), 2, S3)
    # Motivfenster
    mx, my, mw, mh = MASSE["motiv"]
    d.rectangle((mx - 3, my - 3, mx + mw + 2, my + mh + 2), fill=INK)
    d.rectangle((mx - 1, my - 1, mx + mw, my + mh), fill=S1)
    d.rectangle((mx, my, mx + mw - 1, my + mh - 1), fill=PAPER2)
    # Namensband mit zwei Linien
    nx, ny, nw, nh = MASSE["name"]
    d.line((nx, ny, nx + nw, ny), fill=INK, width=2)
    d.line((nx + 16, ny + nh, nx + nw - 16, ny + nh), fill=S2, width=1)
    # Zierlinien an der Zahl
    zy = MASSE["zahl"][1] + MASSE["zahl"][3] // 2 + 2
    d.line((30, zy, 84, zy), fill=S2, width=1)
    d.line((156, zy, 210, zy), fill=S2, width=1)
    return im


def rueckseite():
    w, h = MASSE["karte"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    rounded(d, (0, 0, w - 1, h - 1), MASSE["ecke"], INK)
    rounded(d, (8, 8, w - 9, h - 9), MASSE["ecke"] - 8, INK2, outline=GOLD, width=2)
    rounded(d, (16, 16, w - 17, h - 17), 4, None, outline=S3, width=1)
    pw, ph, step = MASSE["perforation"]
    for x in MASSE["perforation_x"]:
        for y in range(30, h - 30, step):
            rounded(d, (x, y, x + pw - 1, y + ph - 1), 2, S3)
    cx, cy = w // 2, h // 2
    d.polygon([(cx, cy - 70), (cx + 62, cy + 40), (cx - 62, cy + 40)], outline=GOLD, width=3)
    d.ellipse((cx - 30, cy - 8, cx + 30, cy + 24), fill=PAPER, outline=GOLD, width=2)
    d.ellipse((cx - 11, cy - 3, cx + 11, cy + 19), fill=INK)
    d.pieslice((cx - 11, cy - 3, cx + 11, cy + 19), -80, -30, fill=PAPER)
    for i in range(12):
        import math
        a = i * math.pi / 6
        d.line((cx + math.cos(a) * 84, cy + 8 + math.sin(a) * 84, cx + math.cos(a) * 100, cy + 8 + math.sin(a) * 100),
               fill=GOLD, width=2)
    try:
        f = ImageFont.truetype(os.path.join(FONTS, "AbrilFatface.ttf"), 22)
        d.text((cx, h - 44), "TARTOT", font=f, fill=GOLD, anchor="mm")
    except OSError:
        pass
    return im


def farbe(name):
    im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if name == "schwerter":
        d.polygon([(8, 1), (10, 4), (10, 10), (6, 10), (6, 4)], fill=PAPER, outline=INK)
        d.rectangle((3, 10, 12, 11), fill=INK)
        d.rectangle((7, 12, 8, 15), fill=INK)
    elif name == "kelche":
        d.polygon([(2, 2), (13, 2), (11, 7), (4, 7)], fill=GOLD, outline=INK)
        d.rectangle((7, 8, 8, 11), fill=INK)
        d.rectangle((4, 12, 11, 14), fill=INK)
    elif name == "muenzen":
        d.ellipse((1, 1, 14, 14), fill=GOLD, outline=INK, width=2)
        d.polygon([(8, 4), (9, 7), (12, 7), (9, 9), (10, 12), (8, 10), (5, 12), (6, 9), (3, 7), (6, 7)], fill=INK)
    elif name == "staebe":
        d.line((3, 14, 12, 2), fill=INK, width=4)
        d.line((3, 14, 12, 2), fill=S2, width=2)
        d.ellipse((10, 0, 14, 4), fill=BLOOD)
    else:  # Grosse Arkana: Stern
        d.polygon([(8, 0), (10, 6), (16, 6), (11, 10), (13, 16), (8, 12), (3, 16), (5, 10), (0, 6), (6, 6)],
                  fill=GOLD2, outline=INK)
    return im


def vorlage():
    """Mal-Vorlage in doppelter Groesse: jede Zone farbig markiert und bemasst."""
    s = 2
    w, h = MASSE["karte"]
    base = rahmen().resize((w * s, h * s), Image.NEAREST)
    im = Image.new("RGBA", (w * s + 420, h * s + 40), (30, 26, 23, 255))
    im.alpha_composite(base, (20, 20))
    over = Image.new("RGBA", im.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    try:
        f = ImageFont.truetype(os.path.join(FONTS, "Jersey10.ttf"), 26)
        fs = ImageFont.truetype(os.path.join(FONTS, "Jersey10.ttf"), 22)
    except OSError:
        f = fs = ImageFont.load_default()

    def zone(box, color, label, lines, ty):
        x, y, bw, bh = box
        d.rectangle((20 + x * s, 20 + y * s, 20 + (x + bw) * s - 1, 20 + (y + bh) * s - 1),
                    fill=color[:3] + (70,), outline=color[:3] + (255,), width=3)
        tx = w * s + 50
        d.rectangle((tx - 16, ty + 6, tx - 4, ty + 18), fill=color[:3] + (255,))
        d.text((tx, ty), label, font=f, fill=PAPER)
        for i, line in enumerate(lines):
            d.text((tx, ty + 30 + i * 24), line, font=fs, fill=S1)

    mx, my, mw, mh = MASSE["motiv"]
    zone(MASSE["motiv"], INDIGO, "MOTIV (deine Zeichnung)",
         [f"{mw} x {mh} px, bei 2x: {mw*2} x {mh*2}", f"Position x {mx}, y {my}", "PNG mit oder ohne Transparenz",
          "Datei: kunst/motive/<karten-id>.png"], 30)
    zone(MASSE["zahl"], GOLD, "ZAHL", ["setzt das Addon (Abril Fatface)", "Arkana römisch, Zahlen arabisch"], 200)
    zone(MASSE["name"], BLOOD, "NAME", ["setzt das Addon (Alfa Slab One)", "zweizeilig, zentriert"], 310)
    for x in MASSE["perforation_x"]:
        zone((x, 30, MASSE["perforation"][0], h - 60), S2, "", [], -1000)
    zone((MASSE["perforation_x"][0], 30, MASSE["perforation"][0], h - 60), S2, "LOCHSTREIFEN",
         ["Teil des Rahmens (rahmen.png)", "frei bemalbar, Abstand beibehalten"], 420)
    d.ellipse((20 + (MASSE["seltenheit"][0] - 6) * s, 20 + (MASSE["seltenheit"][1] - 6) * s,
               20 + (MASSE["seltenheit"][0] + 6) * s, 20 + (MASSE["seltenheit"][1] + 6) * s), outline=GOLD2, width=3)
    tx = w * s + 50
    d.text((tx, 530), "SELTENHEIT", font=f, fill=PAPER)
    d.text((tx, 560), "Raute unten, Farbe setzt das Addon", font=fs, fill=S1)
    d.text((tx, 600), f"KARTE {w} x {h} px (1x)", font=f, fill=PAPER)
    d.text((tx, 630), "Ecken r = 16, Rand 3 px Tinte", font=fs, fill=S1)
    d.text((tx, 654), "Editionen (Glanz, Leuchten, Feuer,", font=fs, fill=S1)
    d.text((tx, 678), "Glas) legt ein Shader darüber.", font=fs, fill=S1)
    d.text((tx, 708), "Ganze Karte selbst malen:", font=fs, fill=GOLD2)
    d.text((tx, 732), "kunst/karten/<karten-id>.png", font=fs, fill=GOLD2)
    im.alpha_composite(over)
    return im


def motive(quelle):
    """Beispielmotive aus den Entwuerfen: (id, bild, x-mitte, y-oben, y-unten) im Streifen."""
    s = 1.029
    cuts = [
        ('major_10', 3, 95, 55, 135), ('major_14', 3, 207, 45, 132), ('cups_2', 3, 325, 50, 135),
        ('major_19', 3, 557, 62, 140), ('major_4', 4, 92, 72, 150), ('major_5', 4, 205, 72, 160),
        ('wands_7', 4, 435, 72, 160), ('major_20', 4, 555, 78, 165), ('wands_5', 5, 95, 72, 157),
        ('major_6', 5, 205, 72, 150), ('major_15', 5, 320, 68, 158), ('major_17', 6, 95, 70, 158),
        ('major_18', 6, 206, 60, 160), ('major_13', 6, 305, 55, 150), ('swords_1', 6, 518, 68, 152),
        ('major_21', 7, 430, 70, 156),
    ]
    mw, mh = MASSE["motiv"][2:]
    os.makedirs(os.path.join(OUT, "motive"), exist_ok=True)
    bilder = {}
    for cid, n, xc, yt, yb in cuts:
        img = bilder.setdefault(n, Image.open(os.path.join(quelle, f"{n}.webp")).convert("RGB"))
        x, y1, y2 = xc * s, 780 + yt * s, 780 + yb * s
        hh = y2 - y1
        ww = hh * mw / mh
        c = img.crop((int(x - ww / 2), int(y1), int(x + ww / 2), int(y2)))
        speichern(c, cid)
    # aus dem Kampfentwurf (941 x 1672): Hand und Legung
    kampf = Image.open(os.path.join(quelle, "2.webp")).convert("RGB")
    for cid, box in (("swords_7", (250, 1200, 375, 1350)), ("cups_3", (588, 1200, 700, 1336)),
                     ("pentacles_10", (744, 1206, 862, 1349)), ("major_16", (426, 1208, 526, 1330))):
        speichern(kampf.crop(box), cid)


def speichern(img, cid):
    """Auf halbe Motivgroesse, dann ohne Glaettung verdoppelt: Pixel wie im Spiel."""
    mw, mh = MASSE["motiv"][2:]
    klein = img.resize((mw // 2, mh // 2), Image.LANCZOS).quantize(48, method=Image.Quantize.MEDIANCUT).convert("RGBA")
    klein.resize((mw, mh), Image.NEAREST).save(os.path.join(OUT, "motive", cid + ".png"))


def main():
    os.makedirs(os.path.join(OUT, "farben"), exist_ok=True)
    rahmen().save(os.path.join(OUT, "rahmen.png"))
    rueckseite().save(os.path.join(OUT, "rueckseite.png"))
    for name in ("schwerter", "kelche", "muenzen", "staebe", "arkana"):
        farbe(name).save(os.path.join(OUT, "farben", name + ".png"))
    vorlage().save(os.path.join(OUT, "vorlage_2x.png"))
    if "--motive" in sys.argv:
        motive(sys.argv[sys.argv.index("--motive") + 1])
    print("Vorlage geschrieben nach", OUT)


main()
