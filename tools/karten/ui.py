"""Erzeugt die Bedienelemente des Kartentischs im Stil der Boss-Blaetter.

    python3 tools/karten/ui.py        # braucht numpy und Pillow

Ausgabe nach godot-karten/addons/tartot_karten/kunst/:

    ui/tafel.png        dunkle Zierplatte mit Goldrahmen (9-Slice, Rand 30)
    ui/knopf.png        roter Knopf mit Goldrahmen (9-Slice, Rand 34), dazu
    ui/knopf_druck.png  gedrueckt, ui/knopf_aus.png gesperrt
    ui/reiter.png       Reiter fuer die Platznamen (9-Slice, Rand 26 x 18)
    ui/abzeichen.png    runde Plakette (Runde)
    ui/balken.png       Rahmen der Lebensleiste (9-Slice, Rand 14)
    ui/fuellung.png     Fuellung der Lebensleiste (9-Slice, Rand 6)
    ui/platz.png        Filmstreifen-Karte fuer einen Legeplatz (224 x 292, 2x)
    ui/herz.png, schild.png, stapel.png, glueck.png, zahnrad.png, siegel.png
    rahmen.png          Kartenvorderseite ohne Motiv und Schrift (240 x 360, 2x)
    rueckseite.png      Kartenrueckseite (2x)

Alles wird vierfach gross gezeichnet und dann verkleinert - so werden die
Linien glatt. Die Farben sind die Palette der Blaetter.
"""

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
KUNST = os.path.join(ROOT, "godot-karten", "addons", "tartot_karten", "kunst")
UI = os.path.join(KUNST, "ui")

TINTE = (26, 20, 18)
NACHT = (20, 15, 12)
PAPIER = (239, 227, 200)
PAPIER2 = (226, 209, 172)
SEPIA = (143, 122, 90)
GOLD = (201, 162, 88)
GOLD_HELL = (240, 205, 128)
GOLD_DUNKEL = (122, 92, 46)
BLUT = (179, 38, 43)
BLUT_DUNKEL = (110, 22, 24)
SS = 4  # Supersampling

rng = np.random.default_rng(7)


# ------------------------------------------------------------------ Werkzeug
def leinwand(w, h, farbe=(0, 0, 0, 0)):
    im = Image.new("RGBA", (w * SS, h * SS), farbe)
    return im, ImageDraw.Draw(im)


def fertig(im, w, h):
    return im.resize((w, h), Image.LANCZOS)


def rauschen(w, h, skala=24.0, oktaven=4):
    """Wertrauschen 0..1 (fbm), fuer Papier und Patina."""
    aus = np.zeros((h, w), np.float32)
    amp, summe = 1.0, 0.0
    for o in range(oktaven):
        s = skala / (2 ** o)
        gw, gh = int(w / s) + 3, int(h / s) + 3
        gitter = rng.random((gh, gw)).astype(np.float32)
        klein = Image.fromarray((gitter * 255).astype(np.uint8)).resize((int(gw * s), int(gh * s)), Image.BICUBIC)
        aus += np.asarray(klein, np.float32)[:h, :w] / 255.0 * amp
        summe += amp
        amp *= 0.5
    return aus / summe


def r(*v):
    return [x * SS for x in v]


def gerundet(d, box, rad, **kw):
    d.rounded_rectangle(r(*box), radius=rad * SS, **kw)


def schnoerkel(d, cx, cy, dx, dy, farbe, s=1.0):
    """Eckschnoerkel: ein Winkel mit eingerollter Spirale und Punkt."""
    w = max(1, int(1.6 * SS * s))
    L = 16 * s
    d.line(r(cx, cy, cx + dx * L, cy), fill=farbe, width=w)
    d.line(r(cx, cy, cx, cy + dy * L), fill=farbe, width=w)
    # Spirale nach innen
    pts = []
    for i in range(40):
        t = i / 39 * 1.6 * math.pi
        rad = (7 - 4.5 * i / 39) * s
        pts.append(((cx + dx * (9 * s) + dx * rad * math.cos(t)) * SS, (cy + dy * (9 * s) + dy * rad * math.sin(t)) * SS))
    d.line(pts, fill=farbe, width=w, joint="curve")
    rp = 1.8 * s
    d.ellipse(r(cx + dx * 4 * s - rp, cy + dy * 4 * s - rp, cx + dx * 4 * s + rp, cy + dy * 4 * s + rp), fill=farbe)


def ecken(d, x0, y0, x1, y1, farbe, s=1.0):
    schnoerkel(d, x0, y0, 1, 1, farbe, s)
    schnoerkel(d, x1, y0, -1, 1, farbe, s)
    schnoerkel(d, x0, y1, 1, -1, farbe, s)
    schnoerkel(d, x1, y1, -1, -1, farbe, s)


def patina(im, staerke=0.18, skala=18.0):
    """Ungleichmaessige, fleckige Oberflaeche - nichts soll flach wirken."""
    a = np.asarray(im).astype(np.float32)
    h, w = a.shape[:2]
    n = rauschen(w, h, skala * SS / 2)
    korn = rng.random((h, w)).astype(np.float32)
    f = 1.0 + (n - 0.5) * staerke * 2 + (korn - 0.5) * 0.05
    a[..., :3] = np.clip(a[..., :3] * f[..., None], 0, 255)
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ Tafel
def tafel(w=120, h=120):
    im, d = leinwand(w, h)
    gerundet(d, (1, 1, w - 1, h - 1), 6, fill=NACHT + (255,), outline=(8, 6, 5, 255), width=3 * SS)
    im = patina(im, 0.22)
    d = ImageDraw.Draw(im)
    gerundet(d, (5, 5, w - 5, h - 5), 4, outline=GOLD + (255,), width=int(2 * SS))
    gerundet(d, (10, 10, w - 10, h - 10), 2, outline=GOLD_DUNKEL + (255,), width=int(1 * SS))
    ecken(d, 13, 13, w - 13, h - 13, GOLD + (255,), 0.8)
    return fertig(im, w, h)


# ------------------------------------------------------------------ Knopf
def knopf(art="normal", w=200, h=120):
    im, d = leinwand(w, h)
    oben, unten = (BLUT, BLUT_DUNKEL)
    if art == "druck":
        oben, unten = (138, 28, 32), (82, 16, 18)
    elif art == "aus":
        oben, unten = (92, 66, 58), (58, 42, 36)
    # Schatten unter dem Knopf
    gerundet(d, (4, 8, w - 2, h - 1), 14, fill=(0, 0, 0, 150))
    # Koerper mit Verlauf
    koerper = Image.new("RGBA", im.size)
    a = np.zeros((h * SS, w * SS, 4), np.float32)
    t = np.linspace(0, 1, h * SS)[:, None]
    for i in range(3):
        a[..., i] = oben[i] * (1 - t) + unten[i] * t
    a[..., 3] = 255
    koerper = Image.fromarray(a.astype(np.uint8), "RGBA")
    maske = Image.new("L", im.size, 0)
    md = ImageDraw.Draw(maske)
    md.rounded_rectangle(r(2, 2, w - 3, h - 6), radius=14 * SS, fill=255)
    im.paste(koerper, (0, 0), maske)
    im = patina(im, 0.12)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle(r(2, 2, w - 3, h - 6), radius=14 * SS, outline=(10, 6, 5, 255), width=3 * SS)
    d.rounded_rectangle(r(8, 8, w - 9, h - 12), radius=9 * SS, outline=(GOLD if art != "aus" else SEPIA) + (255,), width=2 * SS)
    d.rounded_rectangle(r(12, 12, w - 13, h - 16), radius=6 * SS, outline=(GOLD_DUNKEL if art != "aus" else (70, 56, 44)) + (230,), width=1 * SS)
    # Glanzkante oben
    d.line(r(22, 6, w - 22, 6), fill=(255, 210, 190, 110 if art == "normal" else 50), width=2 * SS)
    ecken(d, 15, 15, w - 15, h - 19, (GOLD_HELL if art == "normal" else SEPIA) + (255,), 0.7)
    return fertig(im, w, h)


# ------------------------------------------------------------------ Reiter
def reiter(w=160, h=44):
    im, d = leinwand(w, h)
    pts = [(10, 2), (w - 10, 2), (w - 2, h / 2), (w - 10, h - 2), (10, h - 2), (2, h / 2)]
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=NACHT + (255,))
    im = patina(im, 0.2)
    d = ImageDraw.Draw(im)
    d.line([(x * SS, y * SS) for x, y in pts + [pts[0]]], fill=GOLD + (255,), width=2 * SS, joint="curve")
    inn = [(13, 6), (w - 13, 6), (w - 7, h / 2), (w - 13, h - 6), (13, h - 6), (7, h / 2)]
    d.line([(x * SS, y * SS) for x, y in inn + [inn[0]]], fill=GOLD_DUNKEL + (255,), width=1 * SS)
    return fertig(im, w, h)


# ------------------------------------------------------------------ Abzeichen
def abzeichen(g=150):
    im, d = leinwand(g, g)
    d.ellipse(r(3, 3, g - 3, g - 3), fill=NACHT + (255,), outline=(8, 6, 5, 255), width=3 * SS)
    im = patina(im, 0.22)
    d = ImageDraw.Draw(im)
    d.ellipse(r(8, 8, g - 8, g - 8), outline=GOLD + (255,), width=3 * SS)
    d.ellipse(r(14, 14, g - 14, g - 14), outline=GOLD_DUNKEL + (255,), width=1 * SS)
    for i in range(24):
        a = i / 24 * math.tau
        x, y = g / 2 + math.cos(a) * (g / 2 - 11), g / 2 + math.sin(a) * (g / 2 - 11)
        d.ellipse(r(x - 1.3, y - 1.3, x + 1.3, y + 1.3), fill=GOLD_HELL + (255,))
    return fertig(im, g, g)


# ------------------------------------------------------------------ Leiste
def balken(w=200, h=34):
    im, d = leinwand(w, h)
    gerundet(d, (1, 1, w - 1, h - 1), 8, fill=(10, 7, 6, 255), outline=GOLD_DUNKEL + (255,), width=2 * SS)
    gerundet(d, (4, 4, w - 4, h - 4), 6, outline=(0, 0, 0, 255), width=2 * SS)
    return fertig(im, w, h)


def fuellung(w=60, h=24):
    a = np.zeros((h, w, 4), np.float32)
    t = np.linspace(0, 1, h)[:, None]
    oben = np.array([224, 84, 58], np.float32)
    unten = np.array([140, 22, 24], np.float32)
    a[..., :3] = oben * (1 - t[..., None]) + unten * t[..., None]
    a[: max(1, h // 4), :, :3] = np.minimum(255, a[: max(1, h // 4), :, :3] + 50)
    a[..., 3] = 255
    a[0, :, 3] = a[-1, :, 3] = 160
    return Image.fromarray(a.astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ Papier
def papier(w, h, alt=1.0):
    """Pergament: Grundton, Flecken, Altersraender, Korn."""
    n = rauschen(w, h, 36.0)
    n2 = rauschen(w, h, 9.0)
    a = np.zeros((h, w, 4), np.float32)
    basis = np.array(PAPIER, np.float32)
    dunkel = np.array((196, 168, 120), np.float32)
    y, x = np.mgrid[0:h, 0:w]
    rand = np.minimum.reduce([x, y, w - 1 - x, h - 1 - y]).astype(np.float32)
    rand_f = np.clip(1 - rand / (min(w, h) * 0.16), 0, 1) ** 1.6
    fleck = np.clip((n - 0.58) * 3.0, 0, 1) * 0.36 * alt
    mix = np.clip(rand_f * 0.8 * alt + fleck + (n2 - 0.5) * 0.12, 0, 1)
    a[..., :3] = basis * (1 - mix[..., None]) + dunkel * mix[..., None]
    a[..., :3] *= (0.97 + rng.random((h, w, 1)) * 0.05)
    a[..., 3] = 255
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


# ------------------------------------------------------------------ Karte
# Masse in 1x; gezeichnet wird 2x (480 x 720), das Addon zeigt 240 x 360.
K = 2


def karte_rahmen():
    w, h = 240 * K, 360 * K
    grund = papier(w, h)
    maske = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(maske).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius=16 * K * SS, fill=255)
    maske = maske.resize((w, h), Image.LANCZOS)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    im.paste(grund, (0, 0), maske)
    hoch = im.resize((w * SS, h * SS), Image.BICUBIC)
    d = ImageDraw.Draw(hoch)
    s = K * SS
    d.rounded_rectangle((1.5 * s, 1.5 * s, w * SS - 1.5 * s, h * SS - 1.5 * s), radius=15 * s, outline=TINTE + (255,), width=int(3 * s))
    d.rounded_rectangle((9 * s, 9 * s, w * SS - 9 * s, h * SS - 9 * s), radius=8 * s, outline=TINTE + (235,), width=int(1.6 * s))
    d.rounded_rectangle((12 * s, 12 * s, w * SS - 12 * s, h * SS - 12 * s), radius=6 * s, outline=TINTE + (150,), width=int(0.8 * s))
    # Motivfenster (34, 52, 172 x 208) mit doppelter Linie
    mx, my, mw, mh = 34, 52, 172, 208
    d.rectangle(((mx - 3) * s, (my - 3) * s, (mx + mw + 3) * s, (my + mh + 3) * s), outline=TINTE + (255,), width=int(2 * s))
    d.rectangle(((mx - 6) * s, (my - 6) * s, (mx + mw + 6) * s, (my + mh + 6) * s), outline=TINTE + (130,), width=int(0.8 * s))
    # Trennlinien zu Zahl und Name, mit Raute in der Mitte
    for yy in (40, 273):
        d.line((30 * s, yy * s, 105 * s, yy * s), fill=TINTE + (170,), width=int(1 * s))
        d.line((135 * s, yy * s, 210 * s, yy * s), fill=TINTE + (170,), width=int(1 * s))
        d.polygon([(120 * s, (yy - 4) * s), (124 * s, yy * s), (120 * s, (yy + 4) * s), (116 * s, yy * s)], fill=TINTE + (200,))
    # Eckschnoerkel
    for cx, cy, dx, dy in ((17, 17, 1, 1), (223, 17, -1, 1), (17, 343, 1, -1), (223, 343, -1, -1)):
        schnoerkel(d, cx * K, cy * K, dx, dy, TINTE + (230,), 0.62 * K)
    fertig_ = hoch.resize((w, h), Image.LANCZOS)
    # Das Motivfenster ist offen: das Motiv liegt darunter, die Fensterlinie darueber.
    a = np.asarray(fertig_).copy()
    x0, y0, x1, y1 = (mx - 1) * K, (my - 1) * K, (mx + mw + 1) * K, (my + mh + 1) * K
    a[y0:y1, x0:x1, 3] = 0
    return Image.fromarray(a, "RGBA")


def rueckseite():
    w, h = 240 * K, 360 * K
    im, d = leinwand(w, h)
    s = SS
    d.rounded_rectangle((0, 0, w * s - 1, h * s - 1), radius=16 * K * s, fill=(24, 18, 15, 255))
    im = patina(im, 0.25, 28)
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((3 * K * s, 3 * K * s, w * s - 3 * K * s, h * s - 3 * K * s), radius=14 * K * s, outline=GOLD + (255,), width=int(2.4 * K * s))
    d.rounded_rectangle((11 * K * s, 11 * K * s, w * s - 11 * K * s, h * s - 11 * K * s), radius=7 * K * s, outline=GOLD_DUNKEL + (255,), width=int(1 * K * s))
    cx, cy = w / 2, h / 2
    # Strahlen
    for i in range(36):
        a = i / 36 * math.tau
        r0, r1 = 46 * K, (118 if i % 2 == 0 else 92) * K
        d.line(((cx + math.cos(a) * r0) * s, (cy + math.sin(a) * r0) * s, (cx + math.cos(a) * r1) * s, (cy + math.sin(a) * r1) * s),
               fill=GOLD_DUNKEL + (255,), width=int(1.4 * K * s))
    # Sonne mit Mondsichel
    d.ellipse(((cx - 40 * K) * s, (cy - 40 * K) * s, (cx + 40 * K) * s, (cy + 40 * K) * s), outline=GOLD + (255,), width=int(3 * K * s))
    d.ellipse(((cx - 30 * K) * s, (cy - 30 * K) * s, (cx + 30 * K) * s, (cy + 30 * K) * s), fill=GOLD + (255,))
    d.ellipse(((cx - 18 * K) * s, (cy - 34 * K) * s, (cx + 40 * K) * s, (cy + 26 * K) * s), fill=(24, 18, 15, 255))
    # Auge in der Sichel
    d.ellipse(((cx - 20 * K) * s, (cy - 6 * K) * s, (cx - 4 * K) * s, (cy + 6 * K) * s), fill=(24, 18, 15, 255), outline=GOLD_HELL + (255,), width=int(1.2 * K * s))
    d.ellipse(((cx - 14 * K) * s, (cy - 3 * K) * s, (cx - 8 * K) * s, (cy + 3 * K) * s), fill=GOLD_HELL + (255,))
    # Sterne
    for _ in range(46):
        x, y = rng.uniform(20, 220) * K, rng.uniform(20, 340) * K
        if (x - cx) ** 2 + (y - cy) ** 2 < (125 * K) ** 2:
            continue
        g = rng.uniform(0.8, 2.2) * K
        d.ellipse(((x - g) * s, (y - g) * s, (x + g) * s, (y + g) * s), fill=GOLD_DUNKEL + (255,))
    for cx2, cy2, dx, dy in ((18, 18, 1, 1), (222, 18, -1, 1), (18, 342, 1, -1), (222, 342, -1, -1)):
        schnoerkel(d, cx2 * K, cy2 * K, dx, dy, GOLD + (255,), 0.7 * K)
    return fertig(im, w, h)


# ------------------------------------------------------------------ Platz
def platz():
    """Filmstreifen-Karte fuer einen Legeplatz: Bildfenster oben, Text unten."""
    w, h = 224 * K, 292 * K
    grund = papier(w, h, 1.2)
    maske = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(maske).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius=10 * K * SS, fill=255)
    maske = maske.resize((w, h), Image.LANCZOS)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    im.paste(grund, (0, 0), maske)
    hoch = im.resize((w * SS, h * SS), Image.BICUBIC)
    d = ImageDraw.Draw(hoch)
    s = K * SS
    d.rounded_rectangle((1.5 * s, 1.5 * s, w * SS - 1.5 * s, h * SS - 1.5 * s), radius=9 * s, outline=TINTE + (255,), width=int(3 * s))
    # Lochstreifen links und rechts neben dem Bildfenster
    for x in (9, 205):
        for i in range(10):
            y = 16 + i * 19
            d.rounded_rectangle((x * s, y * s, (x + 10) * s, (y + 11) * s), radius=2 * s, fill=TINTE + (255,))
    # Bildfenster (26..198, 14..206) - hier liegt das Bild des Bosses
    d.rectangle((25 * s, 13 * s, 199 * s, 207 * s), outline=TINTE + (255,), width=int(2.5 * s))
    d.line((14 * s, 214 * s, 210 * s, 214 * s), fill=TINTE + (160,), width=int(1 * s))
    for cx, cy, dx, dy in ((12, 280, 1, -1), (212, 280, -1, -1)):
        schnoerkel(d, cx * K, cy * K, dx, dy, TINTE + (200,), 0.5 * K)
    return hoch.resize((w, h), Image.LANCZOS)


# ------------------------------------------------------------------ Icons
def herz(g=64):
    im, d = leinwand(g, g)
    pts = []
    for i in range(120):
        t = i / 120 * math.tau
        x = 16 * math.sin(t) ** 3
        y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
        pts.append(((g / 2 + x * g / 38) * SS, (g / 2 + 2 + y * g / 38) * SS))
    d.polygon(pts, fill=(196, 34, 36, 255), outline=TINTE + (255,), width=int(2.5 * SS))
    d.ellipse(r(g * 0.27, g * 0.28, g * 0.41, g * 0.42), fill=(255, 150, 140, 200))
    return fertig(im, g, g)


def schild(g=64):
    im, d = leinwand(g, g)
    pts = [(g * 0.5, g * 0.08), (g * 0.86, g * 0.2), (g * 0.82, g * 0.55), (g * 0.5, g * 0.92), (g * 0.18, g * 0.55), (g * 0.14, g * 0.2)]
    d.polygon([(x * SS, y * SS) for x, y in pts], fill=PAPIER + (255,), outline=TINTE + (255,), width=int(2.5 * SS))
    d.line(r(g * 0.5, g * 0.24, g * 0.5, g * 0.74), fill=TINTE + (255,), width=int(5 * SS))
    d.line(r(g * 0.32, g * 0.44, g * 0.68, g * 0.44), fill=TINTE + (255,), width=int(5 * SS))
    return fertig(im, g, g)


def stapel(g=64):
    im, d = leinwand(g, g)
    for i, (dx, rot) in enumerate(((-8, -0.25), (0, 0.0), (8, 0.25))):
        cx, cy = g / 2 + dx, g / 2 + 2
        bw, bh = g * 0.36, g * 0.52
        ecken_ = [(-bw / 2, -bh / 2), (bw / 2, -bh / 2), (bw / 2, bh / 2), (-bw / 2, bh / 2)]
        p = [((cx + x * math.cos(rot) - y * math.sin(rot)) * SS, (cy + x * math.sin(rot) + y * math.cos(rot)) * SS) for x, y in ecken_]
        d.polygon(p, fill=PAPIER + (255,), outline=TINTE + (255,), width=int(2 * SS))
    return fertig(im, g, g)


def glueck(g=64):
    im, d = leinwand(g, g)
    d.ellipse(r(5, 5, g - 5, g - 5), fill=(212, 160, 60, 255), outline=TINTE + (255,), width=int(2.5 * SS))
    d.ellipse(r(12, 12, g - 12, g - 12), outline=GOLD_DUNKEL + (255,), width=int(1.6 * SS))
    pts = []
    for i in range(60):
        t = i / 59 * 3.2 * math.pi
        rad = 2 + i / 59 * (g / 2 - 17)
        pts.append(((g / 2 + rad * math.cos(t)) * SS, (g / 2 + rad * math.sin(t)) * SS))
    d.line(pts, fill=TINTE + (230,), width=int(2 * SS), joint="curve")
    return fertig(im, g, g)


def zahnrad(g=64):
    im, d = leinwand(g, g)
    pts = []
    for i in range(16):
        a0 = i / 16 * math.tau
        for k, (da, rr) in enumerate(((-0.12, 0.30), (-0.09, 0.42), (0.09, 0.42), (0.12, 0.30))):
            a = a0 + da
            pts.append(((g / 2 + math.cos(a) * rr * g) * SS, (g / 2 + math.sin(a) * rr * g) * SS))
    d.polygon(pts, fill=PAPIER2 + (255,), outline=TINTE + (255,), width=int(2 * SS))
    d.ellipse(r(g * 0.38, g * 0.38, g * 0.62, g * 0.62), fill=NACHT + (255,), outline=TINTE + (255,), width=int(2 * SS))
    return fertig(im, g, g)


def siegel(g=64):
    im, d = leinwand(g, g)
    pts = []
    for i in range(36):
        a = i / 36 * math.tau
        rr = (0.44 if i % 2 == 0 else 0.38) * g
        pts.append(((g / 2 + math.cos(a) * rr) * SS, (g / 2 + math.sin(a) * rr) * SS))
    d.polygon(pts, fill=BLUT + (255,), outline=TINTE + (255,), width=int(2 * SS))
    d.ellipse(r(g * 0.28, g * 0.28, g * 0.72, g * 0.72), outline=(230, 120, 110, 255), width=int(2 * SS))
    d.polygon([(g * 0.5 * SS, g * 0.34 * SS), (g * 0.6 * SS, g * 0.5 * SS), (g * 0.5 * SS, g * 0.66 * SS), (g * 0.4 * SS, g * 0.5 * SS)], fill=(240, 160, 150, 255))
    return fertig(im, g, g)


def main():
    os.makedirs(UI, exist_ok=True)
    tafel().save(os.path.join(UI, "tafel.png"))
    knopf().save(os.path.join(UI, "knopf.png"))
    knopf("druck").save(os.path.join(UI, "knopf_druck.png"))
    knopf("aus").save(os.path.join(UI, "knopf_aus.png"))
    reiter().save(os.path.join(UI, "reiter.png"))
    abzeichen().save(os.path.join(UI, "abzeichen.png"))
    balken().save(os.path.join(UI, "balken.png"))
    fuellung().save(os.path.join(UI, "fuellung.png"))
    platz().save(os.path.join(UI, "platz.png"))
    for name, f in (("herz", herz), ("schild", schild), ("stapel", stapel), ("glueck", glueck), ("zahnrad", zahnrad), ("siegel", siegel)):
        f().save(os.path.join(UI, name + ".png"))
    karte_rahmen().save(os.path.join(KUNST, "rahmen.png"))
    rueckseite().save(os.path.join(KUNST, "rueckseite.png"))
    print("Bedienelemente geschrieben nach", UI)


main()
