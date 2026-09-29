"""Erzeugt die Klaenge des Kartentischs - prozedural, ohne Samples.

    python3 tools/klang/klaenge.py        # braucht nur numpy

Ausgabe: godot-karten/addons/tartot_karten/klang/*.wav (44,1 kHz, mono, 16 bit)

Wie die Klaenge gebaut sind
---------------------------
Karten sind Papier mit Koerper. Jeder Kartenklang setzt sich aus drei
Schichten zusammen, wie ein Foley-Kuenstler sie aufnehmen wuerde:

- **Blatt**: ein kurzer, gefilterter Rauschstoss (1,5-7 kHz) mit einer
  leichten Resonanz - das "Tschk" des Kartons.
- **Koerper**: ein tiefer, gedaempfter Ton (80-200 Hz) - die Hand, der Filz,
  der Tisch.
- **Raum**: ein kurzer Faltungshall, damit alles in einem Zimmer klingt und
  nicht im Kopfhoerer klebt.

Das Mischen ist ein echtes Riffle: zwei Haelften, 52 Blaetter, die erst
schnell, dann langsamer ineinander schnappen, danach die Bruecke (das
Rauschen, wenn die Karten zurueckfallen) und zwei Klopfer auf den Tisch.

Viele Klaenge gibt es in mehreren Varianten (name_1.wav, name_2.wav ...).
KartenKlang waehlt zufaellig - dieselbe Karte klingt nie zweimal gleich.

Die Angriffe klingen nach ihrer Absicht:
angriff (Hieb: Luft, dann Aufprall), raserei (drei schnelle Hiebe),
aussaugen (Schluerfen, das nach unten zieht), fluch (Tritonus-Chor und
Fluestern), abwehr (Holzschild), beschwoeren (aufsteigendes Glas),
supernova (Sog, dann Explosion).

Zufall hat einen festen Seed: dieselbe Datei bei jedem Lauf.
"""

import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "godot-karten", "addons", "tartot_karten", "klang")
SR = 44100
rng = np.random.default_rng(21)


# ------------------------------------------------------------------ Werkzeug
def n_of(dauer):
    return max(1, int(SR * dauer))


def t(dauer):
    return np.arange(n_of(dauer)) / SR


def rauschen(n):
    return rng.standard_normal(n)


def band(x, lo, hi, weich=0.25):
    """Bandpass im Frequenzbereich mit weichen Flanken (Anteil der Grenze)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X = np.fft.rfft(x)
    unten = 1 / (1 + np.exp(-(f - lo) / max(1.0, lo * weich)))
    oben = 1 / (1 + np.exp((f - hi) / max(1.0, hi * weich)))
    return np.fft.irfft(X * unten * oben, n)


def resonanz(x, freq, breite, gewinn):
    """Hebt eine Resonanz an (Gauss-Buckel im Spektrum)."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    X = np.fft.rfft(x)
    return np.fft.irfft(X * (1 + gewinn * np.exp(-((f - freq) / breite) ** 2)), n)


def ausblenden(x, anteil=0.15):
    """Weiches Ende (Viertelkosinus), damit nichts knackt, wo ein Klang aufhoert."""
    k = max(2, int(len(x) * anteil))
    x = x.copy()
    x[-k:] *= np.cos(np.linspace(0, np.pi / 2, k)) ** 2
    return x


def huelle(n, an=0.002, ab=0.1, form=1.0):
    x = np.arange(n) / SR
    return np.minimum(1.0, x / max(an, 1e-6)) ** form * np.exp(-x / ab)


def fenster_bogen(n, kurve=1.5):
    return np.sin(np.linspace(0, np.pi, n)) ** kurve


def wandernder_band(dauer, f0, f1, breite=0.6, kurve=1.0):
    """Rauschen, dessen Band von f0 nach f1 wandert (Luftzug, Schluerfen)."""
    n = n_of(dauer)
    blk = 1024
    hop = blk // 4
    aus = np.zeros(n + blk)
    win = np.hanning(blk)
    q = rauschen(n + blk)
    for start in range(0, n, hop):
        w = (start / max(1, n)) ** kurve
        fc = f0 * (f1 / f0) ** w
        stueck = band(q[start:start + blk] * win, fc * (1 - breite / 2), fc * (1 + breite / 2))
        aus[start:start + blk] += stueck * win
    return ausblenden(aus[:n] / 1.5, 0.08)


def ton(freq, dauer, ab, obertoene=((1, 1.0),), glide=0.0):
    x = t(dauer)
    f_t = freq * (1 + glide * np.exp(-x * 30))
    phase = 2 * np.pi * np.cumsum(f_t) / SR
    anschlag = np.minimum(1.0, x / 0.0025)
    return ausblenden(anschlag * sum(g * np.sin(phase * f) * np.exp(-x / (ab / f ** 0.5)) for f, g in obertoene))


def sweep(f0, f1, dauer, ab, kurve=8.0):
    """Sinus, der exponentiell von f0 nach f1 faellt - Kick, Aufprall, Boom."""
    x = t(dauer)
    f_t = f1 + (f0 - f1) * np.exp(-x * kurve)
    anschlag = np.minimum(1.0, x / 0.0015)
    return ausblenden(anschlag * np.sin(2 * np.pi * np.cumsum(f_t) / SR) * np.exp(-x / ab), 0.25)


def plus(*teile):
    """Addiert Klaenge unterschiedlicher Laenge (kuerzere werden aufgefuellt)."""
    s = np.zeros(max(len(x) for x in teile))
    for x in teile:
        s[: len(x)] += x
    return s


def ein(ziel, klang, bei, pegel=1.0):
    i = int(bei * SR)
    if i >= len(ziel):
        return
    klang = ausblenden(klang, 0.05)
    e = min(len(ziel), i + len(klang))
    stueck = klang[: e - i]
    if len(stueck) < len(klang):
        # ragt ueber das Ende hinaus: weich enden statt abgeschnitten
        stueck = ausblenden(stueck, 0.2)
    ziel[i:e] += stueck * pegel


_hall_cache = {}


def hall(x, zeit=0.35, mix=0.14, hell=4000):
    """Faltungshall mit erzeugter Impulsantwort (kleiner Raum, Holz)."""
    key = (zeit, hell)
    if key not in _hall_cache:
        n = n_of(zeit * 3)
        ir = band(rauschen(n), 320, hell) * np.exp(-np.arange(n) / SR / zeit * 2.3)
        # fruehe Reflexionen: Tisch, Wand, Decke
        for d, g in ((0.011, 0.5), (0.019, 0.35), (0.031, 0.25), (0.047, 0.18)):
            ir[int(d * SR)] += g * 4
        _hall_cache[key] = ir / np.sqrt((ir ** 2).sum())
    ir = _hall_cache[key]
    n = len(x) + len(ir)
    nass = np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)
    trocken = np.concatenate([x, np.zeros(len(ir))])
    return trocken + nass * mix * 3


def saettigung(x, staerke=1.5):
    """Weiche Saettigung: macht Aufpralle dichter, ohne zu klirren."""
    return np.tanh(x * staerke) / np.tanh(staerke)


def normieren(x, spitze=0.9):
    m = np.max(np.abs(x))
    return x if m == 0 else x / m * spitze


def stille_kappen(x, schwelle=1e-3):
    """Hall-Auslauf abschneiden, sobald er unhoerbar ist."""
    laut = np.where(np.abs(x) > schwelle * np.max(np.abs(x)))[0]
    return x[: laut[-1] + 1] if len(laut) else x


def speichern(name, x, spitze=0.9):
    x = stille_kappen(normieren(x, spitze))
    x = x - np.mean(x[: min(len(x), 64)]) * 0  # kein Gleichanteil-Sprung
    fade_in = min(len(x), 16)
    x[:fade_in] *= np.linspace(0, 1, fade_in)
    fade = min(len(x), int(SR * 0.006))
    x[-fade:] *= np.linspace(1, 0, fade)
    daten = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(daten.tobytes())


# ------------------------------------------------------------------ Karton
def blatt(laenge=0.012, hell=1.0, reso=2600):
    """Ein einzelnes Kartenblatt schnappt: das Grundatom aller Kartenklaenge."""
    n = n_of(laenge + 0.03)
    x = band(rauschen(n), 900 * hell, 7500 * hell)
    x = resonanz(x, reso * rng.uniform(0.85, 1.15), 500, 2.5)
    x *= huelle(n, 0.0006, laenge * 0.5)
    tick = ton(rng.uniform(180, 260), 0.03, 0.006) * 0.35
    x[: len(tick)] += tick
    return x


def koerper(freq=110, ab=0.05, glide=0.4):
    return ton(freq, ab * 5, ab, ((1, 1.0), (2.3, 0.25)), glide=glide)


def riffle(dauer=0.62, blaetter=52):
    """Zwei Haelften schnappen ineinander: schnell, dann langsamer, dann aus."""
    s = np.zeros(n_of(dauer + 0.1))
    # Abstaende: beschleunigt in die Mitte, am Ende laesst der Daumen nach
    w = np.linspace(0, 1, blaetter)
    abstaende = 0.006 + 0.012 * (1 - np.sin(w * np.pi)) ** 1.5
    zeiten = np.cumsum(abstaende)
    zeiten *= dauer / zeiten[-1]
    for i, z in enumerate(zeiten):
        pegel = 0.55 + 0.45 * np.sin(w[i] * np.pi) * rng.uniform(0.7, 1.0)
        # linke und rechte Haelfte klingen minimal anders
        reso = 2400 if i % 2 else 3000
        ein(s, blatt(rng.uniform(0.006, 0.014), rng.uniform(0.9, 1.15), reso), z, pegel)
    # das Surren der Karten unter dem Daumen
    surren = band(rauschen(len(s)), 500, 3500) * fenster_bogen(len(s), 0.8) * 0.25
    return s + surren


def bruecke(dauer=0.55):
    """Die gebogenen Karten fallen zurueck: ein weiches, schnelles Rieseln."""
    s = wandernder_band(dauer, 900, 3200, 0.9, 0.7) * fenster_bogen(n_of(dauer), 1.2) * 0.7
    zeiten = np.sort(rng.uniform(0.05, dauer * 0.9, 34))
    for z in zeiten:
        ein(s, blatt(0.006, 1.1, 3200), z, rng.uniform(0.15, 0.35))
    return s


def klopfen():
    """Stoss auf den Tisch: Stapel ausrichten."""
    s = koerper(145, 0.035, 0.3) * 0.9
    ein(s, band(rauschen(n_of(0.05)), 300, 2500) * huelle(n_of(0.05), 0.0005, 0.008), 0.0, 0.6)
    return s


def mischen():
    s = np.zeros(n_of(1.9))
    ein(s, riffle(), 0.0)
    ein(s, bruecke(), 0.68, 0.8)
    ein(s, klopfen(), 1.32, 0.9)
    ein(s, klopfen(), 1.46, 0.7)
    return hall(s, 0.3, 0.12)


def mischen_kurz():
    """Die Ablage wandert zurueck in den Stapel: ein halbes Riffle."""
    s = np.zeros(n_of(0.9))
    ein(s, riffle(0.34, 28), 0.0)
    ein(s, klopfen(), 0.44, 0.8)
    return hall(s, 0.3, 0.12)


def nehmen():
    """Karte vom Filz nehmen: Reibung, die schneller wird, dann frei."""
    d = rng.uniform(0.11, 0.16)
    n = n_of(d)
    reib = band(rauschen(n), 700, 5500) * fenster_bogen(n, 2.0)
    koernung = 1 + 0.6 * np.sign(np.sin(2 * np.pi * rng.uniform(140, 220) * t(d))) * np.linspace(1, 0, n)
    s = reib * koernung * 0.6
    ein(s, blatt(0.01, 1.05), d * 0.75, 0.6)
    return hall(s, 0.25, 0.1)


def ablegen():
    """Karte klatscht auf den Platz: Blatt, Filz, Tisch."""
    s = np.zeros(n_of(0.25))
    ein(s, blatt(rng.uniform(0.012, 0.02), 0.85), 0.0, 1.0)
    ein(s, koerper(rng.uniform(85, 110), 0.04), 0.001, 0.9)
    ein(s, band(rauschen(n_of(0.08)), 150, 900) * huelle(n_of(0.08), 0.001, 0.015), 0.0, 0.5)
    return hall(saettigung(s, 1.3), 0.28, 0.13)


def austeilen():
    """Vom Stapel geschnippt: Daumen-Klick, Luftzug, leises Landen."""
    s = np.zeros(n_of(0.3))
    ein(s, blatt(0.006, 1.2, 3400), 0.0, 0.8)
    ein(s, wandernder_band(0.14, 2400, 700, 0.8) * fenster_bogen(n_of(0.14), 1.0), 0.005, 0.7)
    ein(s, blatt(0.012, 0.8), 0.15, 0.45)
    ein(s, koerper(120, 0.02), 0.15, 0.3)
    return hall(s, 0.25, 0.1)


def umdrehen():
    """Kante hoch, Luft, Karte faellt auf die andere Seite."""
    s = np.zeros(n_of(0.22))
    ein(s, blatt(0.008, 1.0), 0.0, 0.6)
    ein(s, wandernder_band(0.07, 1500, 3500, 0.7) * fenster_bogen(n_of(0.07)), 0.01, 0.5)
    ein(s, blatt(0.014, 0.9), 0.085, 0.9)
    ein(s, koerper(130, 0.02), 0.085, 0.35)
    return hall(s, 0.25, 0.1)


def schweben():
    """Finger streift die Kante - kaum hoerbar, aber man spuert es."""
    n = n_of(0.05)
    x = band(rauschen(n), 2500, 8000) * fenster_bogen(n, 3) * 0.5
    x += ton(rng.uniform(1700, 2100), 0.05, 0.008) * 0.25
    return x


def waehlen():
    s = np.zeros(n_of(0.2))
    ein(s, blatt(0.01, 1.0), 0.0, 0.7)
    ein(s, ton(1320, 0.18, 0.06, ((1, 1.0), (2.0, 0.3))), 0.0, 0.35)
    return hall(s, 0.25, 0.1)


# ------------------------------------------------------------------ Kaskade
def spieluhr(freq, dauer=0.5, ab=0.22):
    """Kamm einer Spieluhr: unharmonische Obertoene, metallischer Anschlag."""
    s = ton(freq, dauer, ab, ((1, 1.0), (2.0, 0.28), (3.0, 0.09), (5.4, 0.12), (8.9, 0.05)))
    s[:n_of(0.004)] += band(rauschen(n_of(0.004)), 4000, 12000) * 0.25
    return s


def zaehlen():
    # C6; die Kaskade transponiert ihn Schritt fuer Schritt (KartenKlang.leiter)
    return hall(plus(spieluhr(1046.5), koerper(262, 0.02, 0.0) * 0.2), 0.4, 0.16, 6000)


def mult():
    # G5 mit einem gezupften Unterton - der rote Kasten klingt waermer
    s = plus(spieluhr(784.0, 0.5, 0.2), ton(392, 0.3, 0.05, ((1, 1.0), (2, 0.4))) * 0.4)
    return hall(s, 0.4, 0.16, 5000)


def faktor():
    """Das ×: Schlag auf die Pauke, Blech klingt nach."""
    s = sweep(160, 48, 1.0, 0.28, 18) * 1.1
    blech = ausblenden(sum(np.sin(2 * np.pi * f * t(1.0) + rng.uniform(0, 6)) for f in (311, 467, 623, 829, 1033, 1377)) * np.exp(-t(1.0) * 3.5) * 0.09, 0.3)
    s += blech + band(rauschen(len(s)), 2000, 9000) * huelle(len(s), 0.001, 0.03) * 0.4
    return hall(saettigung(s, 1.8), 0.6, 0.18)


def toedlich():
    """Dur-Arpeggio auf der Spieluhr, Pauke, Gong - der goldene Schluss."""
    s = np.zeros(n_of(2.4))
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5, 1318.5, 1568.0)):
        ein(s, spieluhr(f, 1.8, 0.7), 0.05 * i, 1.0 - i * 0.07)
    ein(s, sweep(120, 40, 1.4, 0.5, 10), 0.0, 1.0)
    gong = ton(98, 2.2, 1.2, ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.9, 0.1)))
    ein(s, gong, 0.02, 0.35)
    return hall(saettigung(s, 1.3), 0.9, 0.2)


def treffer():
    """Die Legung trifft: dumpf und satt."""
    s = sweep(180, 55, 0.4, 0.12, 30) + band(rauschen(n_of(0.4)), 400, 3000) * huelle(n_of(0.4), 0.0008, 0.03) * 0.8
    return hall(saettigung(s, 2.0), 0.4, 0.14)


# ------------------------------------------------------------------ Gegner
def hieb(dauer=0.24, hoch=1.0):
    """Luftzug einer Klinge/Klaue: Band wandert rasch nach oben."""
    return wandernder_band(dauer, 350 * hoch, 2600 * hoch, 0.5, 1.6) * np.linspace(0.2, 1, n_of(dauer)) ** 2


def aufprall(schwer=1.0):
    n = n_of(0.5)
    s = sweep(150 * schwer, 42, 0.5, 0.16 * schwer, 22)
    s += band(rauschen(n), 250, 4000) * huelle(n, 0.0005, 0.04) * 0.9
    s += band(rauschen(n), 60, 300) * huelle(n, 0.002, 0.08) * 0.6
    return saettigung(s, 2.2)


def angriff_attack():
    s = np.zeros(n_of(0.9))
    ein(s, hieb(0.24), 0.0, 0.8)
    ein(s, aufprall(1.0), 0.22, 1.0)
    return hall(s, 0.45, 0.16)


def angriff_frenzy():
    """Raserei: drei Hiebe, jeder etwas anders, der letzte am haertesten."""
    s = np.zeros(n_of(1.1))
    for i, (bei, h, sw) in enumerate(((0.0, 1.1, 0.6), (0.17, 0.9, 0.7), (0.32, 1.25, 1.0))):
        ein(s, hieb(0.13, h), bei, 0.7)
        ein(s, aufprall(sw), bei + 0.11, 0.55 + 0.25 * i)
    return hall(s, 0.45, 0.16)


def angriff_drain():
    """Aussaugen: feuchtes Schluerfen, das nach unten zieht, ein Herzschlag."""
    d = 1.3
    x = t(d)
    s = wandernder_band(d, 2200, 260, 0.45, 0.8)
    s *= (0.55 + 0.45 * np.sin(2 * np.pi * 16 * x)) * fenster_bogen(len(s), 0.7)
    glide = np.sin(2 * np.pi * np.cumsum(210 * (80 / 210) ** (x / d) * (1 + 0.04 * np.sin(2 * np.pi * 6 * x))) / SR)
    s += glide * fenster_bogen(len(s), 1.2) * 0.45
    for bei in (0.7, 0.9):
        ein(s, koerper(58, 0.07, 0.2), bei, 0.8)
    return hall(s, 0.6, 0.18)


def angriff_hex():
    """Fluch: Tritonus-Chor, der anschwillt, dazu ein Fluestern."""
    d = 1.5
    x = t(d)
    s = np.zeros(len(x))
    for f in (110.0, 155.56, 220.0 * 1.012, 311.1 * 0.991):
        for verstimmt in (0.997, 1.003):
            s += np.sin(2 * np.pi * f * verstimmt * x + rng.uniform(0, 6)) * 0.18
            s += np.sin(2 * np.pi * 2 * f * verstimmt * x) * 0.05
    s *= np.minimum(1, x / 0.9) ** 2 * np.exp(-np.maximum(0, x - 1.1) / 0.15)
    fluestern = band(rauschen(len(x)), 1200, 5000) * (0.5 + 0.5 * np.sin(2 * np.pi * 5.2 * x) ** 2)
    s += fluestern * fenster_bogen(len(x), 1.5) * 0.35
    s += wandernder_band(d, 3000, 9000, 0.3, 2.0) * np.linspace(0, 1, len(x)) ** 3 * 0.3
    s = ausblenden(s, 0.25)
    return hall(s, 1.0, 0.25, 3000)


def angriff_guard():
    """Abwehr: der Gegner hebt ein Holzschild - dumpfes Klonk mit Holzmoden."""
    s = ton(310, 0.6, 0.07, ((1, 1.0), (2.34, 0.6), (3.81, 0.35), (5.6, 0.15)))
    s = plus(s, koerper(95, 0.05))
    s[: n_of(0.02)] += band(rauschen(n_of(0.02)), 800, 5000) * 0.5
    return hall(s, 0.35, 0.14)


def beschwoeren():
    """Beschwoeren: Glas steigt auf, Luft wird hell."""
    s = np.zeros(n_of(1.6))
    for i, f in enumerate((440, 554.4, 659.3, 880, 1108.7, 1318.5, 1760)):
        ein(s, ton(f, 0.9, 0.35, ((1, 1.0), (2.76, 0.2), (5.4, 0.08))), 0.09 * i, 0.5)
    ein(s, wandernder_band(1.0, 600, 6000, 0.5, 1.2) * np.linspace(0, 1, n_of(1.0)) ** 1.5, 0.0, 0.5)
    return hall(s, 0.8, 0.22, 7000)


def supernova():
    """Sog nach innen, eine Sekunde Stille im Kopf, dann alles auf einmal."""
    s = np.zeros(n_of(3.6))
    sog = wandernder_band(0.9, 200, 5000, 0.8, 2.5) * np.linspace(0, 1, n_of(0.9)) ** 3
    ein(s, sog, 0.0, 0.8)
    boom = sweep(90, 28, 2.4, 0.9, 5) * 1.2 + band(rauschen(n_of(2.4)), 40, 1800) * huelle(n_of(2.4), 0.003, 0.6)
    boom += band(rauschen(n_of(2.4)), 2000, 9000) * huelle(n_of(2.4), 0.001, 0.08) * 0.6
    ein(s, saettigung(boom, 2.5), 0.9, 1.0)
    return hall(s, 1.4, 0.25)


def gegner_getroffen():
    """Etwas Weiches wird getroffen: dumpfer Schlag mit Knirschen."""
    s = plus(koerper(95, 0.06, 0.8), band(rauschen(n_of(0.3)), 500, 2400) * huelle(n_of(0.3), 0.001, 0.035) * 0.7)
    return hall(saettigung(s, 1.6), 0.35, 0.12)


def spieler_getroffen():
    """Du wirst getroffen: tief, nah, mit Nachklingen im Ohr."""
    s = sweep(120, 38, 0.8, 0.22, 14) + ton(2900, 0.8, 0.35) * 0.04
    s += band(rauschen(n_of(0.8)), 80, 700) * huelle(n_of(0.8), 0.001, 0.06) * 0.7
    return hall(saettigung(s, 2.0), 0.4, 0.12)


# ------------------------------------------------------------------ Editionen
def glas():
    """Zerspringen: Knall, dann Splitter, die auf den Tisch rieseln."""
    s = np.zeros(n_of(1.4))
    ein(s, band(rauschen(n_of(0.1)), 1500, 12000) * huelle(n_of(0.1), 0.0003, 0.02), 0.0, 1.0)
    for _ in range(60):
        bei = rng.uniform(0.0, 0.25) + rng.exponential(0.12)
        f = rng.uniform(2500, 9000)
        d = rng.uniform(0.03, 0.2)
        ein(s, ton(f, d, d / 3, ((1, 1.0), (2.41, 0.4), (3.9, 0.2))), bei, rng.uniform(0.08, 0.3))
    return hall(s, 0.4, 0.15, 9000)


def brennen():
    """Aufflammen: Fauchen, Knacken, ein kurzer Sog."""
    d = 1.3
    x = t(d)
    s = band(rauschen(len(x)), 150, 2500) * np.minimum(1, x / 0.06) * np.exp(-x * 2.2) * 0.9
    for _ in range(55):
        ein(s, band(rauschen(120), 1500, 9000) * np.exp(-np.arange(120) / 14), rng.uniform(0, d * 0.9), rng.uniform(0.2, 0.8))
    ein(s, wandernder_band(0.25, 300, 1400, 0.8) * fenster_bogen(n_of(0.25)), 0.0, 0.7)
    return hall(s, 0.4, 0.12)


def schimmer():
    s = np.zeros(n_of(0.9))
    for i, f in enumerate((2093, 2637, 3136, 4186, 5274)):
        ein(s, spieluhr(f, 0.5, 0.15), 0.045 * i, 0.4)
    return hall(s, 0.6, 0.2, 9000)


# ------------------------------------------------------------------ Tisch
def knopf():
    s = ton(420, 0.25, 0.04, ((1, 1.0), (2.76, 0.5), (5.4, 0.2)))
    s = plus(s, koerper(70, 0.03, 0.5) * 0.8)
    return hall(s, 0.3, 0.1)


def projektor():
    """Nahtlose Schleife (2 s): Filmprojektor, 24 Bilder/s, Motor, Knistern."""
    n = n_of(2.0)
    x = t(2.0)
    s = band(rauschen(n), 80, 900) * 0.35
    for k in range(48):
        i = int(k * SR / 24)
        klick = band(rauschen(260), 600, 5000) * np.exp(-np.arange(260) / 45)
        s[i:i + 260] += klick * (0.7 if k % 2 == 0 else 0.45)
    s += np.sin(2 * np.pi * 48 * x) * 0.1 + np.sin(2 * np.pi * 96 * x) * 0.04
    for _ in range(40):
        i = rng.integers(0, n - 50)
        s[i:i + 50] += band(rauschen(50), 1000, 8000) * rng.uniform(0.1, 0.4)
    return s


# ------------------------------------------------------------------ Ausgabe
def main():
    os.makedirs(OUT, exist_ok=True)
    for alt in os.listdir(OUT):
        if alt.endswith(".wav"):
            os.remove(os.path.join(OUT, alt))
    einzeln = {
        "mischen": (mischen, 0.85), "mischen_kurz": (mischen_kurz, 0.8),
        "zaehlen": (zaehlen, 0.75), "mult": (mult, 0.75), "faktor": (faktor, 0.9),
        "toedlich": (toedlich, 0.9), "treffer": (treffer, 0.85),
        "angriff_attack": (angriff_attack, 0.9), "angriff_frenzy": (angriff_frenzy, 0.9),
        "angriff_drain": (angriff_drain, 0.85), "angriff_hex": (angriff_hex, 0.8),
        "angriff_guard": (angriff_guard, 0.8), "beschwoeren": (beschwoeren, 0.8),
        "supernova": (supernova, 0.95), "gegner_getroffen": (gegner_getroffen, 0.85),
        "spieler_getroffen": (spieler_getroffen, 0.9),
        "glas": (glas, 0.85), "brennen": (brennen, 0.8), "schimmer": (schimmer, 0.6),
        "knopf": (knopf, 0.7), "projektor": (projektor, 0.35),
    }
    varianten = {
        "nehmen": (nehmen, 0.7, 3), "ablegen": (ablegen, 0.8, 4), "austeilen": (austeilen, 0.7, 4),
        "umdrehen": (umdrehen, 0.6, 3), "schweben": (schweben, 0.45, 3), "waehlen": (waehlen, 0.6, 2),
    }
    zahl = 0
    for name, (erzeuger, spitze) in einzeln.items():
        speichern(name, erzeuger(), spitze)
        zahl += 1
    for name, (erzeuger, spitze, anzahl) in varianten.items():
        for i in range(1, anzahl + 1):
            speichern(f"{name}_{i}", erzeuger(), spitze)
            zahl += 1
    print(f"{zahl} Klaenge geschrieben nach {os.path.abspath(OUT)}")


main()
