"""Zerlegt die Boss-Blaetter in spielbare Teile.

    python tools/buehne/zerlegen.py [boss ...]

Braucht: numpy, pillow, opencv-python-headless und rembg (mit dem
SAM-Modell, das rembg beim ersten Lauf laedt). Am einfachsten in einer
eigenen Umgebung:

    python3 -m venv .venv && .venv/bin/pip install numpy pillow opencv-python-headless "rembg[cpu]"

Quelle: assets/bossblaetter/<name>.jpg (die Blaetter wie entworfen).
Ausgabe je Boss nach godot-karten/buehnen/<boss-id>/:

    hintergrund.jpg   die Buehne; wo die Figur stand, bleibt ihr weicher Schattenriss
    figur.png         die freigestellte Figur (RGBA, auf ihr Rechteck zugeschnitten)
    figur.json        wo die Figur im Buehnenbild sitzt (x, y, b, h) und ihr Fusspunkt
    platz_0..2.png    die drei Platzbilder (Vergangenheit, Gegenwart, Zukunft)

Ausserdem die Kartenmotive aus den Handkarten nach
godot-karten/addons/tartot_karten/kunst/motive/<karten-id>.png.

Freigestellt wird mit Segment Anything: je Boss eine Handvoll Punkte auf
der Figur (positiv) und auf dem Hintergrund (negativ). Die Punkte stehen
unten in BOSSE, in Koordinaten des Blatts - wer eine Figur neu zeichnet,
passt dort die Punkte an oder legt figur.png und hintergrund.png direkt
von Hand ab (dann dieses Skript fuer den Boss nicht mehr laufen lassen).
"""

import json
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
QUELLE = os.path.join(ROOT, "assets", "bossblaetter")
BUEHNEN = os.path.join(ROOT, "godot-karten", "buehnen")
MOTIVE = os.path.join(ROOT, "godot-karten", "addons", "tartot_karten", "kunst", "motive")

# Breite, auf die jede Buehne gebracht wird (Hoehe folgt dem Seitenverhaeltnis).
BUEHNE_BREITE = 1000

# blatt, buehne (x0, y0, x1, y1), platzbilder [(x0, y0, x1, y1) x3], figur: positiv / negativ (Blattkoordinaten)
BOSSE = {
    "boss_turm": dict(
        blatt="turm", buehne=(42, 139, 901, 791),
        plaetze=[(133, 858, 270, 1028), (403, 858, 545, 1028), (676, 858, 812, 1028)],
        pos=[(460, 450), (470, 620), (465, 185), (250, 330), (735, 570), (290, 420), (520, 300), (400, 690)],
        neg=[(100, 400), (850, 400), (150, 180), (820, 200), (120, 700)]),
    "boss_mond": dict(
        blatt="mond", buehne=(42, 139, 901, 796),
        plaetze=[(133, 858, 270, 1028), (403, 858, 545, 1028), (676, 858, 812, 1028)],
        pos=[(470, 380), (400, 250), (560, 300), (700, 250), (740, 300), (180, 390), (750, 560), (470, 520)],
        neg=[(170, 660), (790, 700), (850, 420), (100, 520), (470, 740), (310, 180)]),
    "boss_sonne": dict(
        blatt="sonne", buehne=(39, 99, 621, 586),
        plaetze=[(88, 637, 188, 742), (275, 637, 375, 742), (465, 637, 565, 742)],
        pos=[(325, 260), (250, 175), (400, 175), (330, 120), (255, 330), (400, 330), (200, 250), (450, 250), (175, 215), (545, 320), (330, 360)],
        neg=[(80, 500), (560, 520), (110, 170), (520, 150), (120, 330), (560, 420)]),
    "boss_maessigkeit": dict(
        blatt="maessigkeit", buehne=(39, 94, 641, 581),
        plaetze=[(95, 628, 195, 725), (280, 628, 380, 725), (470, 628, 565, 725)],
        pos=[(300, 200), (300, 140), (310, 330), (150, 230), (450, 230), (250, 280), (460, 310), (180, 450), (420, 450), (300, 420)],
        neg=[(100, 140), (590, 150), (60, 330), (620, 400), (80, 520)]),
    "boss_hierophant": dict(
        blatt="hierophant", buehne=(39, 99, 641, 586),
        plaetze=[(92, 630, 195, 745), (285, 630, 385, 745), (478, 630, 580, 745)],
        pos=[(300, 190), (300, 140), (300, 330), (210, 170), (250, 300), (480, 260), (310, 430), (360, 250)],
        neg=[(90, 420), (520, 470), (200, 480), (60, 260), (610, 260), (430, 520)]),
    "boss_teufel": dict(
        blatt="teufel", buehne=(39, 104, 626, 591),
        plaetze=[(95, 650, 200, 750), (282, 650, 385, 750), (468, 650, 570, 750)],
        pos=[(330, 250), (330, 360), (300, 195), (390, 205), (210, 240), (560, 250), (500, 330), (280, 470), (440, 470)],
        neg=[(160, 560), (390, 570), (80, 250), (600, 500), (100, 450)]),
    "boss_rad": dict(
        blatt="rad", buehne=(39, 99, 626, 596),
        plaetze=[(95, 670, 195, 780), (280, 670, 380, 780), (465, 670, 565, 780)],
        rahmen=(100, 100, 600, 520),
        pos=[(340, 330), (220, 300), (470, 260), (340, 200), (340, 430), (140, 140), (540, 450), (330, 115)],
        neg=[(160, 470), (500, 560), (250, 480), (130, 250), (600, 380), (90, 560)]),
    "boss_tod": dict(
        blatt="tod", buehne=(34, 99, 596, 586),
        plaetze=[(92, 635, 185, 735), (265, 635, 360, 735), (440, 635, 535, 735)],
        pos=[(330, 190), (370, 140), (330, 330), (230, 130), (230, 400), (180, 280), (470, 300), (330, 480)],
        neg=[(130, 420), (440, 480), (540, 430), (180, 510), (560, 200), (80, 200)]),
    "boss_magier": dict(
        blatt="magier", buehne=(39, 99, 641, 586),
        plaetze=[(92, 625, 195, 730), (280, 625, 385, 730), (470, 625, 570, 730)],
        pos=[(330, 230), (340, 140), (360, 330), (420, 410), (300, 420), (240, 230), (480, 250)],
        neg=[(120, 280), (600, 300), (520, 450), (100, 500), (580, 520)]),
    "boss_hohepriesterin": dict(
        blatt="hohepriesterin", buehne=(39, 99, 641, 586),
        plaetze=[(95, 625, 195, 725), (283, 625, 383, 725), (473, 625, 573, 725)],
        pos=[(300, 230), (320, 150), (330, 330), (230, 260), (480, 270), (330, 470), (400, 420)],
        neg=[(90, 420), (590, 450), (130, 250), (560, 250), (110, 480)]),
    "boss_herrscherin": dict(
        blatt="herrscherin", buehne=(39, 99, 641, 586),
        plaetze=[(95, 628, 195, 725), (283, 628, 383, 725), (473, 628, 573, 725)],
        rahmen=(200, 105, 560, 560),
        pos=[(330, 200), (330, 135), (330, 330), (350, 450), (300, 450), (380, 400), (260, 280), (440, 290), (520, 180), (480, 250)],
        neg=[(110, 450), (570, 480), (100, 200), (580, 250), (210, 520), (90, 560)]),
    "boss_wagen": dict(
        blatt="wagen", buehne=(39, 99, 641, 586),
        plaetze=[(95, 628, 195, 730), (283, 628, 383, 730), (470, 628, 570, 730)],
        pos=[(330, 210), (330, 160), (330, 280), (330, 390), (200, 420), (520, 430), (330, 480)],
        neg=[(110, 230), (560, 230), (100, 560), (600, 560)]),
    "boss_kraft": dict(
        blatt="kraft", buehne=(39, 99, 626, 596),
        plaetze=[(95, 645, 200, 750), (282, 645, 385, 750), (468, 645, 570, 750)],
        pos=[(310, 200), (290, 290), (230, 220), (500, 420), (480, 350), (250, 420), (170, 530), (420, 530)],
        neg=[(110, 250), (560, 250), (100, 450), (590, 530)]),
}

# Kartenmotive aus den Handkarten: karten-id -> (blatt, x0, y0, x1, y1)
MOTIV_AUSSCHNITTE = {
    "major_1": ("magier", 175, 820, 255, 915),
    "major_2": ("hohepriesterin", 162, 812, 262, 930),
    "major_3": ("herrscherin", 175, 830, 260, 920),
    "major_4": ("hierophant", 60, 865, 140, 935),
    "major_5": ("hierophant", 170, 850, 250, 935),
    "major_6": ("mond", 90, 1200, 210, 1345),
    "major_7": ("wagen", 290, 820, 375, 915),
    "major_8": ("kraft", 290, 840, 375, 940),
    "major_10": ("mond", 580, 1205, 690, 1335),
    "major_11": ("kraft", 405, 860, 485, 945),
    "major_13": ("tod", 280, 840, 345, 935),
    "major_14": ("maessigkeit", 170, 830, 255, 915),
    "major_15": ("mond", 255, 1200, 350, 1345),
    "major_16": ("turm", 420, 1185, 528, 1340),
    "major_17": ("mond", 748, 1210, 865, 1345),
    "major_18": ("mond", 415, 1185, 530, 1340),
    "major_19": ("sonne", 280, 840, 370, 935),
    "major_20": ("hierophant", 520, 848, 625, 965),
    "major_21": ("sonne", 395, 845, 480, 935),
    "swords_1": ("turm", 95, 1205, 195, 1355),
    "swords_7": ("turm", 250, 1195, 385, 1345),
    "cups_2": ("tod", 380, 832, 472, 940),
    "cups_3": ("turm", 595, 1205, 685, 1350),
    "pentacles_10": ("turm", 748, 1215, 862, 1360),
    "wands_1": ("magier", 525, 830, 595, 925),
    "wands_5": ("tod", 165, 840, 245, 935),
    "wands_7": ("hierophant", 405, 865, 490, 945),
}

# 2x der Motivflaeche (172 x 208) - die Karte wird doppelt so fein gerendert.
MOTIV_GROESSE = (344, 416)


def blatt(name, _cache={}):
    if name not in _cache:
        _cache[name] = Image.open(os.path.join(QUELLE, name + ".jpg")).convert("RGB")
    return _cache[name]


def maske_aufraeumen(alpha):
    """Binaer, kleine Splitter weg, Loecher fuellen, Rand leicht weich."""
    m = (alpha > 110).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m)
    if n > 1:
        groesste = stats[1:, cv2.CC_STAT_AREA].max()
        behalten = np.zeros_like(m)
        for i in range(1, n):
            if stats[i, cv2.CC_STAT_AREA] >= groesste * 0.04:
                behalten[lab == i] = 1
        m = behalten
    # Loecher: Hintergrundflecken, die den Bildrand nicht beruehren, gehoeren zur Figur
    n, lab, stats, _ = cv2.connectedComponentsWithStats((1 - m).astype(np.uint8))
    h, w = m.shape
    for i in range(1, n):
        x, y, bw, bh, _a = stats[i]
        if x > 0 and y > 0 and x + bw < w and y + bh < h:
            m[lab == i] = 1
    weich = cv2.GaussianBlur(m.astype(np.float32), (0, 0), 1.2)
    return np.clip(weich * 255, 0, 255).astype(np.uint8), m


def buehne_zerlegen(boss_id, cfg, sitzung):
    from rembg import remove

    x0, y0, x1, y1 = cfg["buehne"]
    bild = blatt(cfg["blatt"]).crop((x0, y0, x1, y1))
    skala = BUEHNE_BREITE / bild.width
    gross = bild.resize((BUEHNE_BREITE, round(bild.height * skala)), Image.LANCZOS)
    gross = gross.filter(ImageFilter.UnsharpMask(radius=2, percent=60, threshold=2))

    punkte = [{"type": "point", "data": [round((px - x0) * skala), round((py - y0) * skala)], "label": 1} for px, py in cfg["pos"]]
    punkte += [{"type": "point", "data": [round((px - x0) * skala), round((py - y0) * skala)], "label": 0} for px, py in cfg["neg"]]
    if "rahmen" in cfg:
        rx0, ry0, rx1, ry1 = cfg["rahmen"]
        punkte.append({"type": "rectangle", "label": 1, "data": [round((rx0 - x0) * skala), round((ry0 - y0) * skala),
                                                                round((rx1 - x0) * skala), round((ry1 - y0) * skala)]})
    frei = remove(gross, session=sitzung, sam_prompt=punkte)
    alpha, hart = maske_aufraeumen(np.array(frei)[..., 3])

    ziel = os.path.join(BUEHNEN, boss_id)
    os.makedirs(ziel, exist_ok=True)

    # Hintergrund: Figur grosszuegig ausschneiden und auffuellen. Was dort
    # entsteht, ist verschwommen - es wird nur sichtbar, wenn die Figur sich
    # weit bewegt, und dann liegt ein Schatten darauf.
    rgb = np.array(gross)
    # Hinter der Figur bleibt ihr weicher, dunkler Schattenriss - wie ein
    # Schatten auf dem Buehnenprospekt. Bewegt sich die Figur, sieht man
    # einen Schatten statt eines Lochs.
    loch = cv2.dilate(hart, np.ones((9, 9), np.uint8)).astype(np.float32)
    gewicht = cv2.GaussianBlur(loch, (0, 0), 10)[..., None]
    schatten = cv2.GaussianBlur(rgb, (0, 0), 14).astype(np.float32) * 0.32
    hinter = (rgb * (1 - gewicht) + schatten * gewicht).astype(np.uint8)
    Image.fromarray(hinter).save(os.path.join(ziel, "hintergrund.jpg"), quality=90, optimize=True)

    ys, xs = np.where(hart > 0)
    bx0, by0, bx1, by1 = xs.min(), ys.min(), xs.max() + 1, ys.max() + 1
    rgba = np.dstack([rgb, alpha])[by0:by1, bx0:bx1]
    Image.fromarray(rgba, "RGBA").save(os.path.join(ziel, "figur.png"), optimize=True)
    # Fusspunkt: Mitte der untersten Zeilen der Figur
    unten = hart[max(by0, by1 - 30):by1, bx0:bx1]
    spalten = np.where(unten.any(axis=0))[0]
    fuss_x = int(bx0 + (spalten.mean() if len(spalten) else (bx1 - bx0) / 2))
    with open(os.path.join(ziel, "figur.json"), "w") as f:
        json.dump({"buehne": [gross.width, gross.height], "figur": [int(bx0), int(by0), int(bx1 - bx0), int(by1 - by0)],
                   "fuss": [fuss_x, int(by1)], "schwerpunkt": [int(xs.mean()), int(ys.mean())]}, f, indent=1)

    for i, box in enumerate(cfg["plaetze"]):
        blatt(cfg["blatt"]).crop(box).resize((200, 240), Image.LANCZOS).save(os.path.join(ziel, f"platz_{i}.png"))
    print(f"{boss_id}: Buehne {gross.size}, Figur {bx1 - bx0}x{by1 - by0}")


def motive():
    os.makedirs(MOTIVE, exist_ok=True)
    mw, mh = MOTIV_GROESSE
    for karte, (name, x0, y0, x1, y1) in MOTIV_AUSSCHNITTE.items():
        stueck = blatt(name).crop((x0, y0, x1, y1))
        # auf das Motivformat bringen, ohne zu verzerren (mittig beschneiden)
        verh = mw / mh
        w, h = stueck.size
        if w / h > verh:
            neu = round(h * verh)
            stueck = stueck.crop(((w - neu) // 2, 0, (w - neu) // 2 + neu, h))
        else:
            neu = round(w / verh)
            stueck = stueck.crop((0, (h - neu) // 2, w, (h - neu) // 2 + neu))
        stueck = stueck.resize((mw, mh), Image.LANCZOS).filter(ImageFilter.UnsharpMask(radius=1.5, percent=50, threshold=2))
        stueck.save(os.path.join(MOTIVE, karte + ".png"))
    print(f"{len(MOTIV_AUSSCHNITTE)} Kartenmotive")


def main():
    from rembg import new_session

    wahl = [a for a in sys.argv[1:] if not a.startswith("-")]
    if "--nur-motive" not in sys.argv:
        sitzung = new_session("sam")
        for boss_id, cfg in BOSSE.items():
            if wahl and boss_id not in wahl and cfg["blatt"] not in wahl:
                continue
            buehne_zerlegen(boss_id, cfg, sitzung)
    if not wahl:
        motive()


main()
