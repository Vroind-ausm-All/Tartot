"""Erzeugt die Klaenge des Kartentischs - prozedural, ohne Samples.

    python3 tools/klang/klaenge.py        # braucht numpy

Ausgabe: godot-karten/addons/tartot_karten/klang/*.wav (44,1 kHz, mono, 16 bit)

Der Klang folgt dem Stil "Schicksal auf Zelluloid": Papier, Holz, eine
Spieluhr, ein Filmprojektor. Alles ist kurz und trocken; die Tonleiter der
Kaskade entsteht erst im Spiel ueber pitch_scale (ein Halbton je Schritt),
darum liegen zaehlen.wav und mult.wav auf einem festen Grundton.

Zufall hat einen festen Seed: dieselbe Datei bei jedem Lauf.
"""

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot-karten", "addons", "tartot_karten", "klang")
SR = 44100
rng = np.random.default_rng(21)


def t(dauer):
    return np.arange(int(SR * dauer)) / SR


def huellkurve(n, an=0.002, ab=0.1):
    """Schneller Anschlag, exponentielles Ausklingen."""
    x = np.arange(n) / SR
    return np.minimum(1.0, x / max(an, 1e-6)) * np.exp(-x / ab)


def rauschen(n):
    return rng.uniform(-1, 1, n)


def tiefpass(x, staerke):
    """Einfacher Einpol-Tiefpass; staerke 0..1 (1 = kaum Filter)."""
    y = np.zeros_like(x)
    a = staerke
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def hochpass(x, staerke):
    return x - tiefpass(x, staerke)


def glocke(freq, dauer, ab, obertoene=((1, 1.0), (2.0, 0.35), (3.01, 0.18), (4.2, 0.08))):
    x = t(dauer)
    s = sum(g * np.sin(2 * np.pi * freq * f * x) * np.exp(-x / (ab / f ** 0.5)) for f, g in obertoene)
    return s * huellkurve(len(x), 0.001, dauer)


def zelluloid(x, menge=0.012):
    """Leises Knistern darunter - wie eine Filmspur."""
    k = np.zeros_like(x)
    for _ in range(max(1, int(len(x) / SR * 30))):
        i = rng.integers(0, len(x))
        k[i] = rng.uniform(-1, 1)
    return x + tiefpass(k, 0.5) * menge * 20


def normieren(x, spitze=0.9):
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * spitze


def speichern(name, x, spitze=0.9):
    x = normieren(x, spitze)
    # kurzer Ausblender gegen Knacken am Ende
    fade = min(len(x), int(SR * 0.004))
    x[-fade:] *= np.linspace(1, 0, fade)
    daten = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(daten.tobytes())


# ------------------------------------------------------------------ Karten
def papier(dauer, hell, ab):
    n = int(SR * dauer)
    x = tiefpass(hochpass(rauschen(n), 0.08), 0.35) if hell else tiefpass(rauschen(n), 0.25)
    return x * huellkurve(n, 0.003, ab)


def nehmen():
    # Papier gleitet: Rauschen, das heller wird
    n = int(SR * 0.16)
    x = rauschen(n)
    tief = tiefpass(x, 0.05)
    hoch = hochpass(x, 0.3)
    mix = np.linspace(0, 1, n)
    return tiefpass((tief * (1 - mix) + hoch * mix * 0.6) * np.sin(np.linspace(0, np.pi, n)) ** 1.5, 0.3)


def ablegen():
    # Karte klatscht auf Filz: dumpfer Schlag plus kurzer Papierrand
    x = t(0.18)
    schlag = np.sin(2 * np.pi * 95 * x * np.exp(-x * 18)) * np.exp(-x * 30)
    return schlag * 0.9 + papier(0.18, True, 0.012) * 0.5


def schweben():
    # Winziger Holz-Tick
    return glocke(1850, 0.05, 0.01, ((1, 1.0), (2.7, 0.3))) * 0.6 + papier(0.05, True, 0.004) * 0.3


def austeilen():
    # Schnipp: kurzer, heller Papierstoss mit etwas Luft
    n = int(SR * 0.11)
    luft = tiefpass(rauschen(n), 0.35) * np.exp(-np.arange(n) / SR / 0.04)
    return papier(0.11, True, 0.008) * 0.8 + luft * 0.5


def umdrehen():
    n = int(SR * 0.14)
    x = tiefpass(hochpass(rauschen(n), 0.15), 0.3)
    # zwei Buckel: Kante hoch, Karte faellt
    k = np.exp(-((np.arange(n) / SR - 0.03) / 0.012) ** 2) + 0.7 * np.exp(-((np.arange(n) / SR - 0.09) / 0.015) ** 2)
    return x * k


def waehlen():
    return glocke(1320, 0.12, 0.05) * 0.5 + papier(0.12, True, 0.006) * 0.3


# ------------------------------------------------------------------ Kaskade
def zaehlen():
    # Spieluhr-Ton auf C6; die Kaskade transponiert ihn Schritt fuer Schritt
    return zelluloid(glocke(1046.5, 0.35, 0.18), 0.004)


def mult():
    # Waermer und tiefer (G5) - der rote Kasten
    x = t(0.35)
    ton = glocke(784.0, 0.35, 0.16, ((1, 1.0), (2.0, 0.5), (3.0, 0.25), (5.0, 0.1)))
    zupf = np.sin(2 * np.pi * 392 * x) * np.exp(-x * 22) * 0.4
    return ton + zupf


def faktor():
    # Tiefer Schlag mit Blechnachhall: das ×
    x = t(0.9)
    kick = np.sin(2 * np.pi * 70 * x * (1 + 1.5 * np.exp(-x * 25))) * np.exp(-x * 7)
    blech = sum(np.sin(2 * np.pi * f * x + rng.uniform(0, 6)) for f in (311, 467, 623, 829, 1033)) * np.exp(-x * 4) * 0.12
    return kick + blech + papier(0.9, False, 0.03) * 0.3


def toedlich():
    # Dur-Akkord als Arpeggio (C E G C), darunter der Projektor
    x = t(1.8)
    s = np.zeros_like(x)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.5)):
        start = int(SR * 0.055 * i)
        g = glocke(f, 1.8 - 0.055 * i, 0.7)
        s[start:start + len(g)] += g[: len(s) - start] * (1.0 - i * 0.08)
    kick = np.sin(2 * np.pi * 55 * x * (1 + 2 * np.exp(-x * 20))) * np.exp(-x * 5)
    return zelluloid(s * 0.8 + kick * 0.7, 0.01)


def treffer():
    x = t(0.3)
    schlag = np.sin(2 * np.pi * 120 * x * (1 + 3 * np.exp(-x * 40))) * np.exp(-x * 14)
    return schlag + tiefpass(rauschen(len(x)), 0.4) * np.exp(-x * 30) * 0.6


# ------------------------------------------------------------------ Editionen
def glas():
    # Zerspringen: Klirren aus vielen hohen Splittern, dazu ein Knall
    dauer = 1.0
    n = int(SR * dauer)
    x = t(dauer)
    s = hochpass(rauschen(n), 0.5) * np.exp(-x * 12) * 0.8
    for _ in range(38):
        start = int(rng.uniform(0, 0.35) * SR)
        f = rng.uniform(2200, 7800)
        d = rng.uniform(0.05, 0.3)
        g = np.sin(2 * np.pi * f * t(d)) * np.exp(-t(d) / (d / 4))
        ende = min(n, start + len(g))
        s[start:ende] += g[: ende - start] * rng.uniform(0.1, 0.35)
    return s


def brennen():
    # Fauchen und Knacken: Feuer, das kurz aufflammt
    dauer = 1.1
    n = int(SR * dauer)
    x = t(dauer)
    fauchen = tiefpass(rauschen(n), 0.12) * (np.minimum(1, x / 0.08) * np.exp(-x * 2.5))
    knacken = np.zeros(n)
    for _ in range(45):
        i = rng.integers(0, int(n * 0.85))
        knacken[i:i + 60] += rauschen(60) * np.exp(-np.arange(60) / 12) * rng.uniform(0.3, 1.0)
    return fauchen * 1.2 + hochpass(knacken, 0.4) * 0.8


def schimmer():
    # Glitzern beim Aufdecken einer Edition
    s = np.zeros(int(SR * 0.7))
    for i, f in enumerate((2093, 2637, 3136, 4186)):
        g = glocke(f, 0.5, 0.15, ((1, 1.0), (2.0, 0.2)))
        start = int(SR * 0.05 * i)
        s[start:start + len(g)] += g * 0.5
    return s


# ------------------------------------------------------------------ Tisch
def knopf():
    x = t(0.2)
    holz = glocke(420, 0.2, 0.04, ((1, 1.0), (2.76, 0.5), (5.4, 0.2)))
    return holz + papier(0.2, False, 0.01) * 0.4 + np.sin(2 * np.pi * 60 * x) * np.exp(-x * 40) * 0.5


def projektor():
    """Nahtlose Schleife (2 s): das Rattern eines Filmprojektors, 24 Bilder/s."""
    dauer = 2.0
    n = int(SR * dauer)
    x = t(dauer)
    s = tiefpass(rauschen(n), 0.03) * 0.5
    for k in range(48):
        i = int(k * SR / 24)
        klick = tiefpass(hochpass(rauschen(220), 0.4), 0.3) * np.exp(-np.arange(220) / 40)
        s[i:i + 220] += klick * (0.8 if k % 2 == 0 else 0.5)
    s += np.sin(2 * np.pi * 48 * x) * 0.08  # Motorbrummen, passt 96-mal in die Schleife
    return zelluloid(s, 0.02)


def main():
    os.makedirs(OUT, exist_ok=True)
    klaenge = {
        "nehmen": (nehmen, 0.7), "ablegen": (ablegen, 0.8), "schweben": (schweben, 0.5),
        "austeilen": (austeilen, 0.7), "umdrehen": (umdrehen, 0.6), "waehlen": (waehlen, 0.6),
        "zaehlen": (zaehlen, 0.75), "mult": (mult, 0.75), "faktor": (faktor, 0.9),
        "toedlich": (toedlich, 0.9), "treffer": (treffer, 0.85),
        "glas": (glas, 0.85), "brennen": (brennen, 0.8), "schimmer": (schimmer, 0.6),
        "knopf": (knopf, 0.7), "projektor": (projektor, 0.35),
    }
    for name, (erzeuger, spitze) in klaenge.items():
        speichern(name, erzeuger(), spitze)
    print(f"{len(klaenge)} Klaenge geschrieben nach {os.path.abspath(OUT)}")


main()
