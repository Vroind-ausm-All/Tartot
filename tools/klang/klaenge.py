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


# ------------------------------------------------------------------ Angriffe je Boss
def _gleiten(f0, f1, dauer, vib=0.0, vib_hz=6.0, form="exp"):
    x = t(dauer)
    if form == "exp":
        f = f0 * (f1 / f0) ** (x / dauer)
    else:
        f = f0 + (f1 - f0) * x / dauer
    f = f * (1 + vib * np.sin(2 * np.pi * vib_hz * x))
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def _metall(f, dauer, ab=0.25):
    return ton(f, dauer, ab, ((1, 1.0), (2.41, 0.6), (3.88, 0.4), (5.33, 0.25), (7.1, 0.12)))


def _vokal(freqs, dauer, formanten=((800, 1.0), (1150, 0.6), (2900, 0.25))):
    """Chor-Vokal "aah": Saegezahnstimmen durch Formanten."""
    n = n_of(dauer)
    x = t(dauer)
    s = np.zeros(n)
    for f in freqs:
        for verstimmt in (0.996, 1.0, 1.005):
            vib = 1 + 0.005 * np.sin(2 * np.pi * rng.uniform(4.5, 6) * x + rng.uniform(0, 6))
            ph = 2 * np.pi * np.cumsum(f * verstimmt * vib) / SR
            s += sum(np.sin(k * ph) / k for k in range(1, 18))
    aus = np.zeros(n)
    for ff, g in formanten:
        aus += band(s, ff * 0.8, ff * 1.25) * g
    return aus / (len(freqs) * 3)


def angriff_steine():
    s = np.zeros(n_of(2.0))
    grollen = band(rauschen(n_of(2.0)), 30, 260) * fenster_bogen(n_of(2.0), 0.8)
    s += grollen * 0.9
    for i in range(7):
        ein(s, aufprall(rng.uniform(0.6, 1.0)), 0.15 + i * 0.17 + rng.uniform(0, 0.08), rng.uniform(0.5, 0.9))
        ein(s, band(rauschen(n_of(0.15)), 900, 3500) * huelle(n_of(0.15), 0.001, 0.03), 0.17 + i * 0.17, 0.5)
    return hall(s, 0.6, 0.15)


def angriff_blitz():
    s = np.zeros(n_of(2.6))
    ein(s, band(rauschen(n_of(0.06)), 1500, 12000) * huelle(n_of(0.06), 0.0003, 0.012), 0.0, 1.2)
    for i in range(14):
        ein(s, band(rauschen(n_of(0.02)), 2000, 9000) * huelle(n_of(0.02), 0.0003, 0.004), rng.uniform(0.0, 0.25), rng.uniform(0.3, 0.8))
    donner = band(rauschen(n_of(2.4)), 25, 220)
    x = t(2.4)
    donner *= (np.minimum(1, x / 0.08) * np.exp(-x * 1.6)) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 2.3 * x)))
    ein(s, donner, 0.05, 2.2)
    return hall(saettigung(s, 1.8), 0.9, 0.2)


def angriff_segen():
    s = np.zeros(n_of(2.2))
    ein(s, _vokal([261.6, 329.6, 392.0, 523.3], 1.8) * fenster_bogen(n_of(1.8), 0.6), 0.0, 0.9)
    for i, f in enumerate((1046.5, 1318.5, 1568.0, 2093.0)):
        ein(s, spieluhr(f, 1.2, 0.5), 0.25 + i * 0.09, 0.45)
    return hall(s, 1.2, 0.3, 6000)


def angriff_chor():
    s = _vokal([220.0, 261.6, 329.6, 110.0], 2.2, ((650, 1.0), (1080, 0.5), (2650, 0.2))) * fenster_bogen(n_of(2.2), 0.5)
    s = plus(s, ton(196.0, 2.0, 1.0, ((1, 1.0), (2.76, 0.4), (5.4, 0.2))) * 0.6)
    return hall(s, 1.4, 0.32, 5000)


def angriff_wasser():
    s = wandernder_band(1.3, 250, 2800, 0.8, 0.7) * fenster_bogen(n_of(1.3), 0.6)
    for i in range(26):
        f0 = rng.uniform(300, 900)
        b = _gleiten(f0, f0 * 2.4, 0.05) * huelle(n_of(0.05), 0.001, 0.02)
        ein(s, b, rng.uniform(0.1, 1.1), rng.uniform(0.15, 0.4))
    ein(s, band(rauschen(n_of(0.4)), 300, 6000) * huelle(n_of(0.4), 0.002, 0.12), 0.35, 0.9)
    return hall(s, 0.7, 0.2)


def angriff_feuer():
    s = wandernder_band(1.4, 160, 1500, 0.9, 0.5) * fenster_bogen(n_of(1.4), 0.5) * 1.2
    s = plus(s, band(rauschen(n_of(1.4)), 40, 200) * fenster_bogen(n_of(1.4), 1.0) * 0.8)
    for _ in range(40):
        ein(s, band(rauschen(120), 1500, 9000) * np.exp(-np.arange(120) / 14), rng.uniform(0.05, 1.3), rng.uniform(0.2, 0.7))
    return hall(saettigung(s, 1.5), 0.5, 0.15)


def angriff_wuerfel():
    s = np.zeros(n_of(1.4))
    for i in range(30):
        klick = resonanz(band(rauschen(n_of(0.02)), 1500, 7000), rng.uniform(2500, 4500), 400, 3.0) * huelle(n_of(0.02), 0.0003, 0.004)
        ein(s, klick, i * 0.018 + rng.uniform(0, 0.01), rng.uniform(0.3, 0.7))
    for i, bei in enumerate((0.7, 0.86, 0.97, 1.05)):
        ein(s, plus(koerper(220, 0.02, 0.2) * 0.6, band(rauschen(n_of(0.03)), 1200, 6000) * huelle(n_of(0.03), 0.0005, 0.006)), bei, 0.9 - i * 0.18)
    return hall(s, 0.4, 0.14)


def angriff_kette():
    s = wandernder_band(0.6, 300, 1800, 0.7) * fenster_bogen(n_of(0.6), 1.0) * 0.5
    s = plus(s, np.zeros(n_of(1.2)))
    for i in range(36):
        ein(s, _metall(rng.uniform(2200, 5200), 0.25, 0.05), 0.08 + i * 0.02 + rng.uniform(0, 0.015), rng.uniform(0.1, 0.35))
    ein(s, aufprall(0.7), 0.45, 0.7)
    return hall(s, 0.5, 0.16)


def angriff_orakel():
    s = np.zeros(n_of(2.0))
    ein(s, wandernder_band(0.8, 600, 6000, 0.4, 2.0) * np.linspace(0, 1, n_of(0.8)) ** 2 * 0.4, 0.0)
    for i, f in enumerate((1318.5, 1760.0, 2093.0, 2637.0, 3136.0, 3520.0)):
        g = ton(f, 1.0, 0.45, ((1, 1.0), (2.0, 0.15)), glide=0.0) * (1 + 0.0 * i)
        ein(s, g, 0.7 + i * 0.07, 0.35)
    return hall(s, 1.1, 0.3, 9000)


def angriff_schleier():
    s = wandernder_band(1.4, 350, 2600, 0.5, 1.0) * fenster_bogen(n_of(1.4), 1.2) * 0.8
    for i in range(10):
        ein(s, ton(rng.uniform(2500, 4200), 0.4, 0.15), rng.uniform(0.3, 1.2), 0.08)
    return hall(s, 1.0, 0.3, 7000)


def angriff_strahlen():
    s = band(rauschen(n_of(1.4)), 3000, 9000) * fenster_bogen(n_of(1.4), 0.8) * (0.6 + 0.4 * np.sin(2 * np.pi * 30 * t(1.4))) * 0.5
    s = plus(s, _gleiten(300, 1200, 0.9) * fenster_bogen(n_of(0.9), 1.0) * 0.4, _vokal([392.0, 523.3, 659.3], 1.4) * fenster_bogen(n_of(1.4), 0.7) * 0.6)
    return hall(s, 0.9, 0.25)


def angriff_rotation():
    s = np.zeros(n_of(1.4))
    for i in range(5):
        ein(s, wandernder_band(0.28, 500, 2500, 0.6) * fenster_bogen(n_of(0.28), 1.4), i * 0.22, 0.7)
    ein(s, _gleiten(220, 660, 1.1, 0.03, 9) * fenster_bogen(n_of(1.1), 1.0) * 0.35, 0.0)
    return hall(s, 0.5, 0.15)


def angriff_rad():
    """Gluecksrad: Ratsche, die langsamer wird, dann der Zeiger klackt ein."""
    s = np.zeros(n_of(2.2))
    bei, abstand = 0.0, 0.035
    while bei < 1.9:
        klick = resonanz(band(rauschen(n_of(0.015)), 1000, 6000), 2200, 300, 4.0) * huelle(n_of(0.015), 0.0003, 0.004)
        ein(s, plus(klick, koerper(380, 0.006, 0.0) * 0.5), bei, 0.7)
        bei += abstand
        abstand *= 1.09
    ein(s, ton(880, 0.8, 0.4, ((1, 1.0), (2.76, 0.4))), bei, 0.5)
    return hall(s, 0.5, 0.15)


def angriff_sense():
    s = np.zeros(n_of(1.6))
    ein(s, hieb(0.35, 0.8), 0.0, 1.0)
    ein(s, plus(_metall(2400, 1.3, 0.6) * 0.6, _metall(3610, 1.0, 0.4) * 0.3), 0.3, 0.7)
    return hall(s, 0.9, 0.2)


def angriff_geister():
    s = np.zeros(n_of(2.4))
    for i in range(3):
        x = t(1.6)
        f = 520 * (1 + 0.3 * np.sin(2 * np.pi * 0.6 * x + i)) * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * x))
        stimme = np.sin(2 * np.pi * np.cumsum(f * (1 + 0.15 * i)) / SR) * fenster_bogen(n_of(1.6), 1.0)
        ein(s, stimme, i * 0.3, 0.3)
    ein(s, wandernder_band(2.2, 300, 900, 0.8, 1.0) * fenster_bogen(n_of(2.2), 1.0) * 0.6, 0.0)
    return hall(s, 1.5, 0.35, 4000)


def angriff_zauber():
    s = np.zeros(n_of(1.4))
    ein(s, _gleiten(400, 2400, 0.3) * huelle(n_of(0.3), 0.005, 0.3) * 0.5, 0.0)
    for i in range(8):
        ein(s, spieluhr(rng.choice([1568.0, 2093.0, 2637.0, 3136.0]), 0.6, 0.2), 0.2 + i * 0.06, 0.3)
    ein(s, band(rauschen(n_of(0.2)), 3000, 10000) * huelle(n_of(0.2), 0.001, 0.05), 0.28, 0.5)
    return hall(s, 0.8, 0.25, 9000)


def angriff_schwert():
    s = np.zeros(n_of(1.4))
    ein(s, hieb(0.2, 1.3), 0.0, 1.0)
    ein(s, _metall(3200, 1.1, 0.5) * 0.5, 0.16, 0.8)
    ein(s, aufprall(0.6), 0.2, 0.5)
    return hall(s, 0.6, 0.18)


def angriff_muenzen():
    s = np.zeros(n_of(1.8))
    for i in range(40):
        ein(s, _metall(rng.uniform(3000, 6500), 0.35, 0.08), rng.uniform(0.0, 1.2) ** 1.4, rng.uniform(0.15, 0.4))
    return hall(s, 0.6, 0.18, 9000)


def angriff_ranken():
    s = np.zeros(n_of(1.8))
    knarzen = np.zeros(n_of(1.4))
    bei, rate = 0.0, 0.012
    while bei < 1.35:
        ein(knarzen, band(rauschen(n_of(0.006)), 300, 1600) * huelle(n_of(0.006), 0.0005, 0.002), bei, 1.0)
        bei += rate * rng.uniform(0.8, 1.3)
        rate = 0.008 + 0.01 * abs(np.sin(bei * 4))
    ein(s, resonanz(knarzen, 420, 120, 3.0) * fenster_bogen(n_of(1.4), 0.5), 0.0, 0.9)
    ein(s, band(rauschen(n_of(1.6)), 1500, 6000) * fenster_bogen(n_of(1.6), 1.2) * 0.25, 0.1)
    return hall(s, 0.6, 0.18)


def angriff_fruechte():
    s = np.zeros(n_of(1.6))
    for i in range(9):
        plopp = plus(sweep(260, 80, 0.12, 0.04, 40), band(rauschen(n_of(0.02)), 800, 4000) * huelle(n_of(0.02), 0.0005, 0.005) * 0.6)
        ein(s, plopp, 0.1 + i * 0.13 + rng.uniform(0, 0.05), rng.uniform(0.5, 0.9))
    return hall(s, 0.4, 0.14)


def angriff_galopp():
    s = np.zeros(n_of(2.0))
    for takt in range(5):
        for j, versatz in enumerate((0.0, 0.08, 0.2)):
            huf = resonanz(band(rauschen(n_of(0.05)), 300, 3000), 900, 200, 4.0) * huelle(n_of(0.05), 0.0005, 0.012)
            ein(s, plus(huf, koerper(140, 0.015, 0.2) * 0.6), takt * 0.34 + versatz, 0.9 - j * 0.15)
    s = plus(s, band(rauschen(n_of(2.0)), 40, 220) * fenster_bogen(n_of(2.0), 0.8) * 0.5)
    ein(s, aufprall(1.0), 1.6, 1.0)
    return hall(s, 0.5, 0.14)


def angriff_peitsche():
    s = np.zeros(n_of(1.0))
    ein(s, wandernder_band(0.22, 300, 4000, 0.5, 2.0) * np.linspace(0.1, 1, n_of(0.22)) ** 2, 0.0, 0.8)
    knall = band(rauschen(n_of(0.012)), 800, 14000) * huelle(n_of(0.012), 0.0001, 0.002)
    ein(s, knall, 0.22, 1.6)
    return hall(saettigung(s, 2.0), 0.5, 0.18)


def angriff_bruellen():
    d = 1.8
    x = t(d)
    f = 95 * (1 + 0.35 * np.sin(np.pi * x / d)) * (1 + 0.04 * rng.standard_normal(len(x)).cumsum() / np.sqrt(len(x)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    stimme = sum(np.sin(k * ph) / k for k in range(1, 30))
    s = band(stimme, 80, 700) * 1.0 + band(stimme, 900, 1300) * 0.5 + band(rauschen(len(x)), 300, 2500) * 0.4
    s *= fenster_bogen(len(x), 0.6) * (0.7 + 0.3 * np.abs(np.sin(2 * np.pi * 11 * x)))
    return hall(saettigung(s, 2.5), 0.7, 0.2)


# ------------------------------------------------------------------ Zeichentrick-Foley
def ausholen():
    """Lotterpfeife nach oben: der Gegner holt aus."""
    return hall(_gleiten(520, 1560, 0.36, 0.012, 7) * huelle(n_of(0.36), 0.02, 0.3, 1.0) * fenster_bogen(n_of(0.36), 0.3), 0.3, 0.1)


def sprung():
    """Boing."""
    x = t(0.5)
    f = 170 + 260 * (1 - np.exp(-x * 9)) + 60 * np.sin(2 * np.pi * 16 * x) * np.exp(-x * 5)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-x * 5)
    return hall(s, 0.3, 0.1)


def landen():
    return hall(saettigung(plus(sweep(110, 35, 0.6, 0.18, 18), band(rauschen(n_of(0.4)), 60, 900) * huelle(n_of(0.4), 0.001, 0.07)), 2.0), 0.5, 0.14)


def drehung():
    s = _gleiten(700, 1700, 0.25, 0.0) * fenster_bogen(n_of(0.25), 1.0)
    s = np.concatenate([s, _gleiten(1700, 700, 0.25) * fenster_bogen(n_of(0.25), 1.0)])
    return hall(plus(s * 0.5, wandernder_band(0.5, 400, 2400, 0.6) * fenster_bogen(n_of(0.5), 1.0)), 0.4, 0.14)


def recken():
    s = np.zeros(n_of(1.0))
    for i, f in enumerate((523.3, 659.3, 784.0, 1046.5)):
        ein(s, ton(f, 0.8, 0.35, ((1, 1.0), (2.0, 0.3))) * np.linspace(0.3, 1, n_of(0.8)), i * 0.06, 0.25)
    ein(s, wandernder_band(0.6, 800, 5000, 0.5, 2.0) * np.linspace(0, 1, n_of(0.6)) ** 2 * 0.4, 0.0)
    return hall(s, 0.8, 0.25, 8000)


def auftritt():
    """Beckenwirbel, Tusch, Plopp."""
    s = np.zeros(n_of(2.2))
    becken = band(rauschen(n_of(1.0)), 4000, 12000) * np.linspace(0, 1, n_of(1.0)) ** 2 * 0.5
    ein(s, becken, 0.0)
    for note, bei in ((392.0, 1.0), (523.3, 1.12)):
        x = t(0.9 if bei > 1.1 else 0.11)
        ph = 2 * np.pi * note * x
        blech = band(sum(np.sin(k * ph) / k for k in range(1, 14)), 120, 3500) * huelle(len(x), 0.01, 0.2, 0.8)
        ein(s, np.tanh(blech * 2), bei, 0.7)
    ein(s, sweep(600, 180, 0.12, 0.05, 30), 1.0, 0.6)
    ein(s, band(rauschen(n_of(1.0)), 3000, 12000) * huelle(n_of(1.0), 0.002, 0.4) * 0.6, 1.12)
    return hall(s, 0.9, 0.22)


def phase():
    """Gong, Gebruell, schiefe Posaunen: die wahre Gestalt."""
    s = np.zeros(n_of(3.0))
    gong = ton(98, 3.0, 1.6, ((1, 1.0), (1.47, 0.6), (2.09, 0.5), (2.76, 0.35), (3.9, 0.2), (5.4, 0.1)))
    ein(s, gong, 0.0, 1.0)
    ein(s, angriff_bruellen()[: n_of(1.8)] * 0.6, 0.15)
    for f in (110.0, 116.5, 155.6):
        x = t(1.6)
        ph = 2 * np.pi * f * x
        ein(s, np.tanh(band(sum(np.sin(k * ph) / k for k in range(1, 12)), 60, 1500) * 1.6) * fenster_bogen(len(x), 0.5) * 0.25, 0.2)
    return hall(s, 1.4, 0.25)


def tod():
    """Absteigende Pfeife, Krach, Rauch-Puff."""
    s = np.zeros(n_of(2.6))
    ein(s, _gleiten(1500, 260, 1.1, 0.015, 7) * fenster_bogen(n_of(1.1), 0.4) * 0.5, 0.0)
    ein(s, aufprall(1.2) * 1.0, 1.05)
    ein(s, band(rauschen(n_of(1.2)), 3000, 11000) * huelle(n_of(1.2), 0.001, 0.4) * 0.5, 1.05)
    for i in range(6):
        ein(s, koerper(rng.uniform(180, 400), 0.03, 0.2) * 0.4, 1.15 + i * 0.07)
    ein(s, wandernder_band(0.6, 1200, 300, 0.8) * fenster_bogen(n_of(0.6), 1.0) * 0.5, 1.4)
    return hall(s, 0.9, 0.22)


def iris():
    """Projektor: Surren und der Schlag der Blende."""
    x = t(0.7)
    surren = (band(rauschen(len(x)), 200, 1500) * 0.3 + np.sin(2 * np.pi * 96 * x) * 0.2) * fenster_bogen(len(x), 0.6)
    s = plus(surren, np.zeros(n_of(0.8)))
    ein(s, resonanz(band(rauschen(n_of(0.03)), 500, 5000), 1800, 300, 3.0) * huelle(n_of(0.03), 0.0005, 0.008), 0.62, 0.8)
    return hall(s, 0.4, 0.12)


# ------------------------------------------------------------------ Ausgabe
def main():
    os.makedirs(OUT, exist_ok=True)
    for alt in os.listdir(OUT):
        if alt.endswith(".wav") and not alt.startswith(("musik_", "sieg", "niederlage")):
            os.remove(os.path.join(OUT, alt))
    einzeln = {
        "mischen": (mischen, 0.85), "mischen_kurz": (mischen_kurz, 0.8),
        "zaehlen": (zaehlen, 0.75), "mult": (mult, 0.75), "faktor": (faktor, 0.9),
        "toedlich": (toedlich, 0.9), "treffer": (treffer, 0.85),
        "angriff_attack": (angriff_attack, 0.9), "angriff_frenzy": (angriff_frenzy, 0.9),
        "angriff_drain": (angriff_drain, 0.85), "angriff_hex": (angriff_hex, 0.8),
        "angriff_guard": (angriff_guard, 0.8), "gegner_getroffen": (gegner_getroffen, 0.85),
        "spieler_getroffen": (spieler_getroffen, 0.9),
        "glas": (glas, 0.85), "brennen": (brennen, 0.8), "schimmer": (schimmer, 0.6),
        "knopf": (knopf, 0.7), "projektor": (projektor, 0.35),
        "angriff_beschwoeren": (beschwoeren, 0.8), "angriff_supernova": (supernova, 0.95),
        "angriff_steine": (angriff_steine, 0.9), "angriff_blitz": (angriff_blitz, 0.95),
        "angriff_segen": (angriff_segen, 0.8), "angriff_chor": (angriff_chor, 0.8),
        "angriff_wasser": (angriff_wasser, 0.85), "angriff_feuer": (angriff_feuer, 0.85),
        "angriff_wuerfel": (angriff_wuerfel, 0.85), "angriff_kette": (angriff_kette, 0.85),
        "angriff_orakel": (angriff_orakel, 0.75), "angriff_schleier": (angriff_schleier, 0.75),
        "angriff_strahlen": (angriff_strahlen, 0.85), "angriff_rotation": (angriff_rotation, 0.8),
        "angriff_rad": (angriff_rad, 0.8), "angriff_sense": (angriff_sense, 0.9),
        "angriff_geister": (angriff_geister, 0.8), "angriff_zauber": (angriff_zauber, 0.8),
        "angriff_schwert": (angriff_schwert, 0.9), "angriff_muenzen": (angriff_muenzen, 0.8),
        "angriff_ranken": (angriff_ranken, 0.8), "angriff_fruechte": (angriff_fruechte, 0.85),
        "angriff_galopp": (angriff_galopp, 0.9), "angriff_peitsche": (angriff_peitsche, 0.95),
        "angriff_bruellen": (angriff_bruellen, 0.95),
        "ausholen": (ausholen, 0.6), "sprung": (sprung, 0.75), "landen": (landen, 0.9),
        "drehung": (drehung, 0.7), "recken": (recken, 0.7), "auftritt": (auftritt, 0.85),
        "phase": (phase, 0.95), "tod": (tod, 0.9), "iris": (iris, 0.6),
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
