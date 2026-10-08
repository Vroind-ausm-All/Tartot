"""Erzeugt die Mal-Vorlage und die Farbsymbole der Karten.

    python3 tools/karten/ui.py         # zuerst: Rahmen, Rueckseite, Bedienelemente
    python3 tools/karten/vorlage.py    # dann: Vorlage mit allen Massen, Farbsymbole

Ausgabe nach godot-karten/addons/tartot_karten/kunst/:
    farben/<farbe>.png  kleine Farbsymbole fuer die Ecken (16 x 16)
    vorlage_2x.png      Mal-Vorlage in doppelter Groesse mit allen Massen

Die Kartenmotive schneidet tools/buehne/zerlegen.py aus den Boss-Blaettern;
eigene Motive (kunst/motive/<id>.png) und ganz gemalte Karten
(kunst/karten/<id>.png) ersetzen sie.

Alle Masse stehen in MASSE und in VORLAGE.md; das Godot-Addon liest sie aus
karte.gd. Wer die Karte anders schneiden will, aendert beides.
"""

import os

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
    # Der Rahmen kommt aus tools/karten/ui.py und liegt schon in 2x vor.
    base = Image.open(os.path.join(OUT, "rahmen.png")).convert("RGBA").resize((w * s, h * s), Image.LANCZOS)
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


def main():
    os.makedirs(os.path.join(OUT, "farben"), exist_ok=True)
    for name in ("schwerter", "kelche", "muenzen", "staebe", "arkana"):
        farbe(name).save(os.path.join(OUT, "farben", name + ".png"))
    vorlage().save(os.path.join(OUT, "vorlage_2x.png"))
    print("Vorlage geschrieben nach", OUT)


main()
