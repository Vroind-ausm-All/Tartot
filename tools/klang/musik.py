"""Erzeugt die Musik des Kartentischs - ein Jahrmarkts-Walzer wie von 1932.

    python3 tools/klang/musik.py        # braucht nur numpy

Ausgabe: godot-karten/addons/tartot_karten/klang/
    musik_walzer.wav        Grundschicht: Drehorgel (Calliope), Tuba, Glockenspiel
    musik_walzer_boss.wav   Bossschicht: Pauke, Posaunen, Streicher-Tremolo, Trommel
    sieg.wav, niederlage.wav  kurze Tusche (Sieg-Fanfare, Wah-wah-wah-waaah)

Beide Schichten sind gleich lang (16 Takte, 3/4, 138 Schlaege pro Minute)
und laufen gemeinsam; KartenKlang blendet die Bossschicht im Bosskampf ein.
Sie sind nahtlose Schleifen: der Nachhall des letzten Takts wird an den
Anfang gefaltet, die Gleichlaufschwankung (Wow) passt genau in die Schleife.

Alles klingt durch ein Grammophon: Bandbreite 110 Hz bis 6 kHz, leichte
Saettigung, Wow und Flutter, ganz leises Knistern.
"""

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot-karten", "addons", "tartot_karten", "klang")
SR = 44100
BPM = 138.0
SCHLAG = 60.0 / BPM
TAKTE = 16
LAENGE = int(round(TAKTE * 3 * SCHLAG * SR))
rng = np.random.default_rng(1932)


def hz(note):
    """'A4', 'G#5', 'Bb3' -> Frequenz."""
    namen = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = namen[note[0]]
    rest = note[1:]
    if rest.startswith("#"):
        n += 1
        rest = rest[1:]
    elif rest.startswith("b"):
        n -= 1
        rest = rest[1:]
    return 440.0 * 2 ** ((n + (int(rest) - 4) * 12) / 12)


def zeit(n):
    return np.arange(n) / SR


def huelle(n, an, ab, halten=1.0):
    x = zeit(n)
    a = np.minimum(1.0, x / max(an, 1e-4))
    ende = n / SR * halten
    return a * np.where(x < ende, 1.0, np.exp(-(x - ende) / max(ab, 1e-4)))


def band(x, lo, hi):
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X = np.fft.rfft(x)
    X *= 1 / (1 + np.exp(-(f - lo) / (lo * 0.3))) / (1 + np.exp((f - hi) / (hi * 0.3)))
    return np.fft.irfft(X, len(x))


def wah(x, grenze):
    """Tiefpass mit wandernder Grenzfrequenz (Daempfer der Posaune), blockweise."""
    blk, hop = 2048, 512
    fen = np.hanning(blk)
    aus = np.zeros(len(x) + blk)
    norm = np.zeros(len(x) + blk)
    f = np.fft.rfftfreq(blk, 1 / SR)
    pad = np.concatenate([x, np.zeros(blk)])
    for start in range(0, len(x), hop):
        g = float(np.mean(grenze[start:start + blk])) if start < len(grenze) else float(grenze[-1])
        X = np.fft.rfft(pad[start:start + blk] * fen)
        X *= 1 / (1 + np.exp((f - g) / (g * 0.35)))
        aus[start:start + blk] += np.fft.irfft(X, blk) * fen
        norm[start:start + blk] += fen ** 2
    return aus[:len(x)] / np.maximum(norm[:len(x)], 1e-3)


# ------------------------------------------------------------------ Instrumente
def calliope(f, dauer):
    """Dampforgel: Pfeifen mit Vibrato, zwei leicht verstimmte Stimmen, Luft."""
    n = int(dauer * SR)
    x = zeit(n)
    vib = 1 + 0.006 * np.sin(2 * np.pi * 6.2 * x + rng.uniform(0, 6)) * np.minimum(1, x / 0.12)
    s = np.zeros(n)
    for verstimmt, g in ((1.0, 1.0), (1.0035, 0.7)):
        ph = 2 * np.pi * np.cumsum(f * verstimmt * vib) / SR
        s += g * (np.sin(ph) + 0.45 * np.sin(2 * ph) + 0.22 * np.sin(3 * ph) + 0.08 * np.sin(4 * ph))
    luft = band(rng.standard_normal(n), f * 0.8, f * 3) * 0.06
    return (s + luft) * huelle(n, 0.025, 0.06, 0.82)


def glocke(f, dauer=0.9):
    n = int(dauer * SR)
    x = zeit(n)
    s = sum(g * np.sin(2 * np.pi * f * m * x) * np.exp(-x * (3.5 * m ** 0.6)) for m, g in ((1, 1.0), (2.76, 0.4), (5.4, 0.2), (8.93, 0.08)))
    return s * np.minimum(1, x / 0.002)


def tuba(f, dauer):
    n = int(dauer * SR)
    x = zeit(n)
    ph = 2 * np.pi * f * x
    s = np.sin(ph) + 0.5 * np.sin(2 * ph) + 0.25 * np.sin(3 * ph) + 0.12 * np.sin(4 * ph)
    s = np.tanh(s * 1.3)
    return s * huelle(n, 0.03, 0.08, 0.7)


def akkord_stoss(freqs, dauer):
    """Das "pah" im Oom-pah-pah: kurzer Orgelakkord."""
    n = int(dauer * SR)
    s = np.zeros(n)
    for f in freqs:
        x = zeit(n)
        ph = 2 * np.pi * f * x
        s += np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.15 * np.sin(3 * ph)
    return s / len(freqs) * huelle(n, 0.01, 0.05, 0.35)


def basstrommel():
    n = int(0.35 * SR)
    x = zeit(n)
    f = 52 + 70 * np.exp(-x * 30)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 9)


def pauke(f, dauer=1.2, wirbel=False):
    n = int(dauer * SR)
    x = zeit(n)
    s = sum(g * np.sin(2 * np.pi * f * m * x) for m, g in ((1, 1.0), (1.5, 0.5), (1.98, 0.3), (2.44, 0.15)))
    if wirbel:
        anschlag = 0.6 + 0.4 * (np.sin(2 * np.pi * 14 * x) > 0)
        return s * anschlag * np.minimum(1, x / dauer) ** 1.5 * np.exp(-np.maximum(0, x - dauer * 0.85) * 20)
    return (s + band(rng.standard_normal(n), 80, 600) * 0.4 * np.exp(-x * 40)) * np.exp(-x * 3.2)


def posaune(f, dauer):
    n = int(dauer * SR)
    x = zeit(n)
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5 * x) * np.minimum(1, x / 0.3)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    saege = sum(np.sin(k * ph) / k for k in range(1, 12))
    hell = np.minimum(1, x / 0.15)
    s = band(saege, 60, 1200 + 1400 * 0.5) * (0.6 + 0.4 * hell)
    return np.tanh(s * 1.4) * huelle(n, 0.06, 0.15, 0.85)


def streicher_tremolo(freqs, dauer):
    n = int(dauer * SR)
    x = zeit(n)
    s = np.zeros(n)
    for f in freqs:
        for verstimmt in (0.997, 1.0, 1.004):
            ph = 2 * np.pi * f * verstimmt * x + rng.uniform(0, 6)
            s += sum(np.sin(k * ph) / k for k in range(1, 7))
    trem = 0.55 + 0.45 * np.sin(2 * np.pi * 9.5 * x) ** 2
    return band(s, 150, 4000) / (len(freqs) * 3) * trem * huelle(n, 0.15, 0.2, 0.9)


def kleine_trommel_wirbel(dauer):
    n = int(dauer * SR)
    x = zeit(n)
    schlaege = (np.sin(2 * np.pi * 22 * x) > 0.6).astype(float)
    return band(rng.standard_normal(n), 900, 7000) * schlaege * (x / dauer) ** 2 * 0.6


# ------------------------------------------------------------------ Satz
# Harmonie je Takt (a-Moll, Jahrmarkt mit Schatten)
AKKORDE = ["Am", "Am", "E7", "E7", "Am", "Am", "Dm", "E7", "F", "C", "Dm", "Am", "Dm", "Am", "E7", "Am"]
TOENE = {
    "Am": ("A2", ["A3", "C4", "E4"]), "E7": ("E2", ["G#3", "B3", "D4"]), "Dm": ("D2", ["D4", "F4", "A3"]),
    "F": ("F2", ["F3", "A3", "C4"]), "C": ("C3", ["E3", "G3", "C4"]),
}
# Melodie: (Note, Schlaege) - ein schiefer Walzer, der sich nach oben schraubt
MELODIE = [
    [("A4", 1), ("C5", 1), ("E5", 1)], [("A5", 2), ("G#5", 1)], [("B5", 1.5), ("A5", 0.5), ("G#5", 1)], [("E5", 3)],
    [("A4", 1), ("C5", 1), ("E5", 1)], [("A5", 2), ("B5", 1)], [("C6", 1), ("B5", 1), ("A5", 1)], [("G#5", 2), ("E5", 1)],
    [("F5", 1), ("A5", 1), ("C6", 1)], [("E5", 2), ("G5", 1)], [("F5", 1), ("E5", 1), ("D5", 1)], [("C5", 2), ("E5", 1)],
    [("D5", 1), ("F5", 1), ("A5", 1)], [("C6", 1.5), ("B5", 0.5), ("A5", 1)], [("G#5", 1), ("B5", 1), ("D6", 1)], [("A5", 3)],
]


def einfuegen(spur, klang, beginn):
    i = int(round(beginn * SR))
    e = min(len(spur), i + len(klang))
    if i < len(spur):
        spur[i:e] += klang[: e - i]


def grundschicht():
    n = LAENGE + int(4 * SCHLAG * SR)  # Auslauf, wird an den Anfang gefaltet
    orgel = np.zeros(n)
    bass = np.zeros(n)
    stoesse = np.zeros(n)
    glocken = np.zeros(n)
    trommel = np.zeros(n)
    for takt, akkord in enumerate(AKKORDE):
        t0 = takt * 3 * SCHLAG
        grundton, stimmen = TOENE[akkord]
        b = hz(grundton) * (1.5 if takt % 2 else 1.0)
        einfuegen(bass, tuba(b, SCHLAG * 0.9), t0)
        for s in (1, 2):
            einfuegen(stoesse, akkord_stoss([hz(v) for v in stimmen], SCHLAG * 0.6), t0 + s * SCHLAG)
        einfuegen(trommel, basstrommel(), t0)
        pos = t0
        for note, dauer in MELODIE[takt]:
            einfuegen(orgel, calliope(hz(note), dauer * SCHLAG * 0.97), pos)
            if takt in (3, 7, 11, 15) or dauer >= 2:
                einfuegen(glocken, glocke(hz(note) * 2, 1.2) * 0.35, pos)
            pos += dauer * SCHLAG
    mix = orgel * 0.55 + bass * 0.5 + stoesse * 0.3 + glocken * 0.25 + trommel * 0.35
    return mix


def bossschicht():
    n = LAENGE + int(4 * SCHLAG * SR)
    s = np.zeros(n)
    for takt, akkord in enumerate(AKKORDE):
        t0 = takt * 3 * SCHLAG
        grundton, stimmen = TOENE[akkord]
        if takt % 4 == 0:
            einfuegen(s, pauke(hz(grundton) * 2, 2.6 * SCHLAG, wirbel=True) * 0.35, t0 - 2.6 * SCHLAG if takt else t0)
        einfuegen(s, pauke(hz(grundton) * 2) * 0.55, t0)
        if takt % 2 == 0:
            einfuegen(s, posaune(hz(grundton) * 2, 5.6 * SCHLAG) * 0.32, t0)
            einfuegen(s, posaune(hz(stimmen[0]) * 0.5 * 2, 5.6 * SCHLAG) * 0.18, t0 + 0.02)
        einfuegen(s, streicher_tremolo([hz(v) * 2 for v in stimmen], 3 * SCHLAG) * 0.35, t0)
        if takt % 4 == 3:
            einfuegen(s, kleine_trommel_wirbel(3 * SCHLAG) * 0.5, t0)
    return s


# ------------------------------------------------------------------ Grammophon
def falten(x):
    """Auslauf an den Anfang falten - die Schleife hat keine Naht."""
    aus = x[:LAENGE].copy()
    rest = x[LAENGE:]
    aus[: len(rest)] += rest
    return aus


def grammophon(x, knistern=0.004):
    x = band(x, 110, 6000)
    x = x / max(1e-9, np.max(np.abs(x))) * 0.75
    x = np.tanh(x * 1.25) / np.tanh(1.25)
    # Wow (genau 3 Zyklen pro Schleife) und Flutter: Zeitachse leicht verbiegen
    i = np.arange(len(x), dtype=np.float64)
    wow = np.sin(2 * np.pi * 3 * i / len(x)) * 0.0021 * SR / (2 * np.pi * 3 / (len(x) / SR))
    flutter = np.sin(2 * np.pi * 7.3 * i / SR) * 0.00012 * SR / (2 * np.pi * 7.3)
    quelle = (i + wow * 0.02 + flutter) % len(x)
    x = np.interp(quelle, i, x, period=len(x))
    k = np.zeros(len(x))
    stellen = rng.integers(0, len(x), int(len(x) / SR * 18))
    k[stellen] = rng.uniform(-1, 1, len(stellen))
    k = band(k, 1500, 9000) * 12
    return x + k * knistern + band(rng.standard_normal(len(x)), 800, 5000) * 0.002


# ------------------------------------------------------------------ Tusche
def sieg():
    s = np.zeros(int(2.6 * SR))
    for i, note in enumerate(["C5", "E5", "G5", "C6"]):
        einfuegen(s, calliope(hz(note), 0.16 if i < 3 else 1.2) * 0.8, i * 0.13)
        einfuegen(s, posaune(hz(note) / 2, 0.16 if i < 3 else 1.2) * 0.4, i * 0.13)
    einfuegen(s, glocke(hz("C7"), 1.5) * 0.4, 0.39)
    einfuegen(s, pauke(hz("C3")) * 0.6, 0.39)
    return s


def niederlage():
    """Das klassische Wah-wah-wah-waaah der Zeichentrick-Posaune."""
    s = np.zeros(int(3.6 * SR))
    for i, (note, dauer) in enumerate([("G3", 0.45), ("F#3", 0.45), ("F3", 0.45), ("E3", 1.6)]):
        f = hz(note)
        n = int(dauer * SR)
        x = zeit(n)
        daempfer = 0.5 + 0.5 * np.sin(2 * np.pi * (5.5 if i == 3 else 2.2) * x - np.pi / 2)
        glide = f * (1 - 0.03 * (x / dauer) * (i == 3))
        ph = 2 * np.pi * np.cumsum(glide) / SR
        saege = sum(np.sin(k * ph) / k for k in range(1, 14))
        klang = wah(band(saege, 70, 8000), 500 + 2200 * daempfer) * huelle(n, 0.04, 0.2, 0.85)
        klang = klang / max(1e-9, np.max(np.abs(klang)))
        einfuegen(s, np.tanh(klang * 1.3) * 0.7, sum(d for _, d in [("G3", 0.45), ("F#3", 0.45), ("F3", 0.45)][:i]) + i * 0.05)
    return s


def speichern(name, x, spitze=0.85):
    x = x / max(1e-9, np.max(np.abs(x))) * spitze
    daten = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(daten.tobytes())


def main():
    os.makedirs(OUT, exist_ok=True)
    grund = grammophon(falten(grundschicht()))
    boss = grammophon(falten(bossschicht()), 0.0)
    # gemeinsamer Pegel: die Bossschicht relativ zur Grundschicht
    spitze = max(np.max(np.abs(grund)), np.max(np.abs(boss)))
    speichern("musik_walzer", grund / spitze, 0.8 * np.max(np.abs(grund)) / spitze)
    speichern("musik_walzer_boss", boss / spitze, 0.8 * np.max(np.abs(boss)) / spitze)
    speichern("sieg", grammophon(sieg()), 0.85)
    speichern("niederlage", grammophon(niederlage()), 0.85)
    print(f"Musik: {LAENGE / SR:.2f} s je Schleife, {TAKTE} Takte bei {BPM:.0f} BPM -> {os.path.abspath(OUT)}")


main()
