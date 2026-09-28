"""Die Gegner von TARTOT als Blockouts - Ids wie in ActCatalog (Acts.cs).

Jede Figur steht mit den Fuessen auf z = 0 und schaut nach -Y in die Kamera.
Masse grob: 2 Einheiten = eine Figur. Die Bauanleitungen folgen der
Stilbibel: Grundform Birne, Kreis oder Streichholz; Kuchenaugen; zu breiter
Mund; weisse Handschuhe, auch wo keine Haende sein sollten. Zahlenkarten-
Gegner bleiben sepia, Eliten tragen einen Akzent, nur Bosse volle Farbe.
"""

import math

from mathutils import Vector

R = math.radians


# ------------------------------------------------------------------ Helfer
def arm(k, a, b, pose="open", size=0.24, mirror=False, r=0.045, mat="ink2", sag=0.1, rot=None):
    """Gummischlauch-Arm ohne Ellbogen, Handschuh am Ende in Armrichtung."""
    a, b = Vector(a), Vector(b)
    mid = (a + b) / 2 + Vector((0, -0.02, -sag))
    k.hose([a, mid, b], r, mat)
    d = b - mid
    ang = math.atan2(d.x, d.z) if rot is None else R(rot)
    loc = b + 0.5 * size * Vector((math.sin(ang), 0, math.cos(ang)))
    return k.glove(loc, size, rot=(0, ang, 0), pose=pose, mirror=mirror)


def legs(k, hip=0.8, spread=0.12, foot=0.26, mat="ink2", r=0.05, shoe="ink2", splay=0.1):
    for s in (-1, 1):
        k.hose([(s * spread, 0, hip), (s * (spread + splay * 0.6), -0.02, hip * 0.55), (s * (spread + splay), 0, 0.14)],
               r, mat)
        k.shoe((s * (spread + splay), 0, 0.1), foot, material=shoe, mirror=s > 0)


def face(k, key, ez, esize, espread, gz, gw, gh, look=(0.0, 0.0), teeth=8, lower=0, tongue=False, angry=0.0,
         lid=0.0, curve=0.28, dx=0.0, mouth="mouth", white="paper", pupil="pupil", lid_mat="ink"):
    for s in (-1, 1):
        k.eye(key, dx + s * espread, ez, esize, look=look, angry=angry, lid=lid, white=white, pupil=pupil,
              lid_mat=lid_mat, name="auge_l" if s < 0 else "auge_r")
    k.grin(key, gz, gw, gh, teeth=teeth, lower=lower, curve=curve, tongue=tongue, dx=dx, mouth=mouth)


def head(k, key, center, radii, mat):
    if isinstance(radii, (int, float)):
        radii = (radii, radii, radii)
    k.ball(center, radii, mat, name="kopf_" + key)
    k.face_surface(key, center, radii)


# ------------------------------------------------------------------ Akt I
def lachender_henker(k, hood="ink2", tunic="s2"):
    """Streichholzkoerper, viel zu langer Hals, der Strick haengt lose."""
    legs(k, hip=0.78, spread=0.1, foot=0.24)
    k.cyl((0, 0, 1.04), 0.2, 0.56, tunic, r2=0.15, name="rumpf")
    k.cyl((0, 0, 0.8), 0.205, 0.08, "ink2", name="guertel")
    k.hose([(0, 0, 1.3), (0.05, -0.01, 1.6), (-0.04, 0, 1.85), (0, 0, 2.0)], 0.05, "s1")
    k.torus((0.02, -0.02, 1.62), 0.1, 0.028, "s2", rot=(R(70), R(20), 0), name="schlinge_hals")
    head(k, "kopf", (0, 0, 2.2), (0.33, 0.29, 0.31), hood)
    k.cyl((0, 0.03, 2.58), 0.2, 0.34, hood, r2=0.0, name="kapuzenspitze")
    head(k, "maske", (0, -0.12, 2.14), (0.27, 0.2, 0.22), "paper")
    face(k, "maske", 0.07, 0.11, 0.1, -0.06, 0.42, 0.17, look=(0.5, 0.2), teeth=9, lower=5, tongue=True)
    arm(k, (-0.16, 0, 1.24), (-0.5, -0.02, 1.5), pose="wave", mirror=False)
    arm(k, (0.16, 0, 1.24), (0.62, -0.02, 1.22), pose="fist", mirror=True, sag=-0.05)
    k.hose([(0.78, -0.04, 1.34), (0.84, -0.05, 1.52), (0.88, -0.05, 1.62)], 0.028, "s1")
    k.torus((0.9, -0.05, 1.84), 0.2, 0.03, "s1", rot=(R(90), 0, 0), name="lasso")


def zahnmuenze(k):
    """Rollt auf der Kante, klappt auf wie ein Gebiss, Handschuhe und ein kleiner Hut."""
    z = 0.86
    k.cyl((0, 0, z), 0.78, 0.24, "gold", rot=(R(90), 0, 0), name="muenze")
    k.torus((0, -0.12, z), 0.72, 0.05, "gold", rot=(R(90), 0, 0), name="rand")
    k.face_surface("muenze", (0, -0.12, z), (0.78, 0.02, 0.78))
    face(k, "muenze", 0.28, 0.24, 0.24, 0.02, 1.05, 0.62, look=(-0.2, 0.2), teeth=10, lower=8, tongue=True, curve=0.18)
    k.tophat((0.22, 0.05, z + 0.74), 0.32, tilt=R(-18))
    arm(k, (-0.72, 0, z - 0.1), (-1.0, -0.02, z - 0.5), pose="open")
    arm(k, (0.72, 0, z + 0.05), (1.05, -0.02, z + 0.4), pose="wave", mirror=True)


def kelchtrinker(k):
    """Trinkt aus einem Kelch, in dem ein Auge schwimmt. Das Auge sieht dich."""
    legs(k, hip=0.55, spread=0.18, foot=0.26)
    k.ball((0, 0, 1.05), (0.52, 0.45, 0.62), "s1", taper=0.25, name="bauch")
    head(k, "kopf", (0, -0.02, 1.62), (0.36, 0.33, 0.32), "paper")
    k.bowler((0, 0.02, 1.88), 0.46, tilt=R(8))
    face(k, "kopf", 0.1, 0.12, 0.12, -0.04, 0.46, 0.2, look=(0.0, -0.9), teeth=8, curve=0.35)
    # Kelch vor der Brust
    kz = 1.0
    k.cyl((0, -0.5, kz + 0.1), 0.16, 0.26, "s2", r2=0.26, name="kelch")
    k.cyl((0, -0.5, kz - 0.13), 0.04, 0.24, "s2", name="stiel")
    k.cyl((0, -0.5, kz - 0.26), 0.15, 0.04, "s2", name="fuss")
    k.ball((0, -0.52, kz + 0.2), (0.24, 0.1, 0.06), "blood", name="wein")
    k.face_surface("wein", (0, -0.62, kz + 0.25), (0.14, 0.1, 0.12))
    k.eye("wein", 0, 0.02, 0.1, look=(0, 0.3), name="kelchauge")
    arm(k, (-0.45, 0, 1.15), (-0.28, -0.45, 0.95), pose="open", sag=0.12)
    arm(k, (0.45, 0, 1.15), (0.28, -0.45, 0.95), pose="open", mirror=True, sag=0.12)


def schreiende_klinge(k):
    """Ein Schwert mit einem Mund in der Schneide. Es schreit den eigenen Namen."""
    legs(k, hip=0.42, spread=0.1, foot=0.22)
    k.ball((0, 0, 0.42), 0.09, "gold", name="knauf")
    k.cyl((0, 0, 0.6), 0.07, 0.3, "ink2", name="griff")
    k.box((0, 0, 0.78), (0.7, 0.14, 0.1), "s2", bevel=0.03, name="parierstange")
    k.box((0, 0, 1.55), (0.34, 0.1, 1.45), "paper", name="klinge")
    k.poly([(-0.17, 0), (0.17, 0), (0, 0.4)], (0, -0.05, 2.27), "paper", depth=0.1, name="spitze")
    k.face_surface("klinge", (0, -0.05, 1.55), (0.17, 0.001, 0.8))
    k.eye("klinge", -0.075, 0.38, 0.1, look=(0, 0.6), angry=0.35, name="auge_l")
    k.eye("klinge", 0.075, 0.38, 0.1, look=(0, 0.6), angry=0.35, name="auge_r")
    k.grin("klinge", 0.12, 0.3, 0.62, teeth=5, lower=4, curve=-0.25, tongue=True)
    arm(k, (-0.35, 0, 0.78), (-0.72, -0.02, 1.15), pose="open")
    arm(k, (0.35, 0, 0.78), (0.72, -0.02, 1.15), pose="open", mirror=True)


def zwillingsschatten(k):
    """Zwei Schatten einer Figur, die es nicht gibt. Sie tun nicht dasselbe."""
    for s, h, look, pose in ((-1, 1.0, (0.6, 0), "wave"), (1, 0.86, (-0.6, -0.3), "fist")):
        x = s * 0.5
        k.ball((x, 0, 0.85 * h), (0.42 * h, 0.36 * h, 0.8 * h), "ink2", taper=0.3, name="schatten")
        k.face_surface("s%d" % s, (x, 0, 0.85 * h), (0.36 * h, 0.36 * h, 0.8 * h))
        for e in (-1, 1):
            k.eye("s%d" % s, e * 0.13 * h, 0.4 * h, 0.18 * h, look=look, name="auge")
        k.grin("s%d" % s, 0.18 * h, 0.46 * h, 0.24 * h, teeth=6, curve=0.3, mouth="blood")
        k.shoe((x - 0.14 * h, 0, 0.08), 0.22 * h, "ink")
        k.shoe((x + 0.14 * h, 0, 0.08), 0.22 * h, "ink", mirror=True)
        arm(k, (x + s * 0.3 * h, 0, 0.9 * h), (x + s * 0.72 * h, -0.02, (1.3 if pose == "wave" else 0.55) * h),
            pose=pose, mirror=s > 0, mat="ink", size=0.22 * h)


def kleiner_mond(k):
    """Haengt zu niedrig und grinst zu breit. Manchmal blinzelt er nicht."""
    z = 1.2
    moon = k.ball((0, 0, z), 0.75, "paper", name="mond")
    k.cut(moon, (0.4, 0.0, z + 0.12), (0.66, 1.2, 0.7))
    k.face_surface("mond", (0, 0, z), (0.75, 0.75, 0.75))
    k.eye("mond", -0.45, 0.22, 0.17, look=(0.5, 0), name="auge")
    k.grin("mond", -0.22, 0.3, 0.2, teeth=5, curve=0.2, dx=-0.5)
    k.nose("mond", -0.62, 0.0, 0.07, material="paper")
    k.hose([(-0.1, 0, z + 0.72), (-0.05, 0, z + 1.3)], 0.02, "s2")
    k.cyl((-0.34, 0.1, z + 0.62), 0.28, 0.5, "ink2", r2=0.0, rot=(0, R(-35), 0), name="schlafmuetze")
    k.ball((-0.12, 0.1, z + 0.85), 0.07, "paper", name="bommel")
    arm(k, (-0.62, 0, z - 0.35), (-0.95, -0.02, z - 0.75), pose="open")
    arm(k, (0.05, 0, z - 0.72), (0.4, -0.02, z - 1.0), pose="wave", mirror=True)


# ------------------------------------------------------------------ Akt II
def hutmann(k):
    """Unter dem Hut ist noch ein Hut. Und darunter wieder einer."""
    legs(k, hip=0.45, spread=0.12, foot=0.25)
    k.cyl((0, 0, 0.75), 0.42, 0.7, "ink2", r2=0.28, name="mantel")
    # der unterste Hut ist das Gesicht
    k.cyl((0, 0, 1.12), 0.72, 0.06, "ink2", name="krempe")
    k.cyl((0, 0, 1.5), 0.46, 0.72, "s3", r2=0.5, name="kopfhut")
    k.cyl((0, 0, 1.24), 0.47, 0.14, "blood2", name="hutband")
    k.face_surface("hut", (0, 0, 1.52), (0.48, 0.48, 0.36))
    face(k, "hut", 0.14, 0.12, 0.14, -0.02, 0.56, 0.22, look=(0, 0.1), teeth=9, curve=0.25)
    k.tophat((0.04, 0, 1.88), 0.46, tilt=R(-6))
    k.tophat((-0.03, 0, 2.38), 0.34, tilt=R(8), band="gold")
    k.tophat((0.02, 0, 2.74), 0.22, tilt=R(-10))
    arm(k, (-0.36, 0, 0.95), (-0.72, -0.02, 1.25), pose="wave")
    arm(k, (0.36, 0, 0.95), (0.7, -0.02, 0.6), pose="open", mirror=True)


def augensammlerin(k):
    """Traegt die Augen anderer an einer Schnur. Keines davon ist ihres."""
    k.cyl((0, 0, 0.5), 0.55, 0.9, "s3", r2=0.2, name="kleid")
    k.shoe((-0.18, 0, 0.06), 0.2)
    k.shoe((0.18, 0, 0.06), 0.2, mirror=True)
    k.ball((0, 0, 1.12), (0.26, 0.22, 0.34), "s3", name="mieder")
    k.hose([(0, 0, 1.4), (0.02, 0, 1.62)], 0.05, "s1")
    head(k, "kopf", (0, 0, 1.88), (0.28, 0.26, 0.32), "paper")
    k.ball((0, 0.1, 2.22), (0.2, 0.18, 0.18), "ink2", name="dutt")
    k.ball((0, 0.02, 2.06), (0.3, 0.26, 0.14), "ink2", name="haar")
    face(k, "kopf", 0.06, 0.1, 0.1, -0.1, 0.4, 0.16, lid=0.5, lid_mat="s1", teeth=8, curve=0.3)
    # Augenkette quer ueber die Brust
    k.face_surface("brust", (0, 0, 1.1), (0.3, 0.26, 0.4))
    for i in range(7):
        t = -1 + 2 * i / 6
        dx, dz = t * 0.34, -0.06 - 0.16 * (1 - t * t) + 0.12
        k.eye("brust", dx, dz, 0.075, look=(-t, 0.3 * (i % 2)), name="kettenauge", pie=True)
    arm(k, (-0.24, 0, 1.3), (-0.6, -0.02, 1.62), pose="open")
    arm(k, (0.24, 0, 1.3), (0.6, -0.02, 1.0), pose="open", mirror=True)
    k.face_surface("hand", (0.72, -0.2, 1.08), (0.1, 0.1, 0.1))
    k.eye("hand", 0, 0, 0.1, look=(-1, 0), name="gehaltenes_auge")


def blutorgel(k):
    """Jede Pfeife ein Finger. Sie spielt sich selbst und trifft nie denselben Ton."""
    k.box((0, 0, 0.75), (1.4, 0.7, 1.1), "s3", bevel=0.05, name="gehaeuse")
    k.box((0, -0.05, 0.25), (1.5, 0.75, 0.12), "ink2", bevel=0.02, name="sockel")
    for s in (-1, 1):
        k.ball((s * 0.55, 0, 0.1), (0.14, 0.14, 0.1), "ink2", name="fuss")
    heights = (0.55, 0.8, 1.05, 1.2, 1.0, 0.75, 0.5)
    for i, h in enumerate(heights):
        x = -0.54 + 0.18 * i
        k.cyl((x, 0.05, 1.3 + h / 2), 0.075, h, "s1", name="pfeife")
        k.ball((x, 0.05, 1.3 + h), (0.075, 0.075, 0.06), "blood", name="nagel")
    k.face_surface("front", (0, -0.36, 0.8), (0.7, 0.001, 0.55))
    k.eye("front", -0.28, 0.22, 0.17, look=(0.3, 0.2), angry=0.2, name="auge_l")
    k.eye("front", 0.28, 0.22, 0.17, look=(0.3, 0.2), angry=0.2, name="auge_r")
    k.grin("front", -0.02, 1.1, 0.42, teeth=12, lower=10, curve=0.08)
    arm(k, (-0.7, 0, 0.9), (-1.0, -0.2, 0.7), pose="open")
    arm(k, (0.7, 0, 0.9), (1.0, -0.2, 1.1), pose="wave", mirror=True)


def wachsbote(k):
    """Bringt eine Nachricht, die schmilzt, bevor man sie lesen kann."""
    legs(k, hip=0.4, spread=0.12, foot=0.24)
    k.cyl((0, 0, 1.05), 0.36, 1.3, "paper", name="kerze")
    for i, (a, l) in enumerate(((-0.25, 0.3), (0.05, 0.45), (0.28, 0.22))):
        k.ball((a, -0.3, 1.62 - l / 2), (0.07, 0.07, l / 2 + 0.04), "paper", name="tropfen")
    k.cyl((0, 0, 1.73), 0.02, 0.12, "ink", name="docht")
    k.ball((0, 0, 1.95), (0.12, 0.1, 0.2), "flame", taper=-0.4, name="flamme")
    k.ball((0, -0.02, 1.9), (0.06, 0.06, 0.1), "ember", name="flammkern")
    k.face_surface("kerze", (0, 0, 1.05), (0.36, 0.36, 0.7))
    face(k, "kerze", 0.3, 0.12, 0.12, 0.08, 0.44, 0.2, look=(0.4, 0), teeth=7, lid=0.25, lid_mat="s1", curve=0.3)
    arm(k, (-0.34, 0, 1.0), (-0.66, -0.02, 1.3), pose="wave")
    arm(k, (0.34, 0, 1.0), (0.66, -0.2, 0.95), pose="fist", mirror=True)
    k.box((0.72, -0.35, 1.2), (0.42, 0.04, 0.28), "paper", rot=(0, R(-12), 0), name="brief")
    k.ball((0.72, -0.38, 1.2), (0.07, 0.03, 0.07), "blood", name="siegel")


def mondfresser(k):
    """Unter halben HP wird er aggressiver und verbirgt, was er vorhat."""
    legs(k, hip=0.45, spread=0.22, foot=0.3)
    head(k, "koerper", (0, 0, 1.05), (0.75, 0.62, 0.7), "s2")
    k.eye("koerper", -0.18, 0.44, 0.11, look=(0.2, -0.4), name="auge_l")
    k.eye("koerper", 0.18, 0.44, 0.11, look=(0.2, -0.4), name="auge_r")
    k.grin("koerper", 0.22, 1.15, 0.7, teeth=11, lower=9, curve=0.12, tongue=True)
    moon = k.ball((0.95, -0.25, 1.05), 0.3, "paper", name="mondstueck")
    k.cut(moon, (0.8, -0.3, 1.2), (0.22, 0.4, 0.22))
    arm(k, (0.66, 0, 0.9), (0.85, -0.2, 0.8), pose="open", mirror=True, sag=0.05)
    arm(k, (-0.66, 0, 0.9), (-1.0, -0.02, 1.35), pose="wave")


def nadelwitwe(k):
    """Sie naeht zwischen den Stichen. Was sie naeht, traegt dein Gesicht."""
    k.ball((0, 0.2, 0.95), (0.55, 0.45, 0.48), "ink2", name="hinterleib")
    for s in (-1, 1):
        for i, (a, l) in enumerate(((20, 1.0), (45, 1.05), (70, 0.95))):
            ang = R(a)
            base = Vector((s * 0.25, 0.1, 0.95))
            knee = base + Vector((s * math.sin(ang) * 0.55, -0.05, 0.35))
            tip = Vector((s * (0.5 + 0.3 * i), -0.05 * i, 0.02))
            k.hose([base, knee], 0.035, "ink2")
            mid = (knee + tip) / 2
            d = tip - knee
            k.cyl(mid, 0.035, d.length, "s1", r2=0.004, rot=(0, math.atan2(d.x, d.z) + math.pi, 0), name="nadel")
    head(k, "kopf", (0, -0.1, 1.5), (0.3, 0.27, 0.3), "paper")
    k.cyl((0, -0.08, 1.78), 0.42, 0.04, "ink2", name="schleierkrempe")
    k.cyl((0, -0.08, 1.9), 0.2, 0.22, "ink2", name="huetchen")
    k.ball((0, -0.08, 1.62), (0.4, 0.3, 0.22), "s3", name="schleier")
    k.face_surface("gesicht", (0, -0.14, 1.44), (0.28, 0.22, 0.22))
    face(k, "gesicht", 0.02, 0.1, 0.1, -0.08, 0.38, 0.14, look=(0, 0.2), teeth=8, curve=0.3)
    arm(k, (-0.2, -0.1, 1.2), (-0.5, -0.3, 1.45), pose="point", size=0.2)
    arm(k, (0.2, -0.1, 1.2), (0.52, -0.3, 1.1), pose="fist", mirror=True, size=0.2)
    k.cyl((-0.62, -0.32, 1.75), 0.018, 0.5, "s1", r2=0.002, rot=(0, R(20), 0), name="naehnadel")
    k.hose([(-0.72, -0.33, 1.95), (-0.2, -0.4, 2.2), (0.5, -0.35, 1.3)], 0.012, "blood")


# ------------------------------------------------------------------ Akt III
def uhrenwurm(k):
    """Er frisst Minuten. In seinem Bauch schlaegt es immer eins."""
    pts = [(-0.9, 0.2, 0.25), (-0.55, 0.1, 0.3), (-0.2, 0.0, 0.38), (0.12, -0.05, 0.55), (0.3, -0.05, 0.85),
           (0.3, -0.05, 1.18)]
    for i, p in enumerate(pts):
        r = 0.2 + 0.05 * i
        k.ball(p, r, "s2" if i % 2 else "s1", name="glied")
    k.face_surface("bauch", (0.12, -0.05, 0.55), (0.35, 0.35, 0.35))
    k.decal("bauch", [(0.2 * math.cos(a), 0.2 * math.sin(a)) for a in [i * math.pi / 12 for i in range(24)]],
            (0, 0), "flat_paper", lift=0.01, name="zifferblatt")
    k.decal("bauch", [(-0.012, 0), (0.012, 0), (0.012, 0.16), (-0.012, 0.16)], (0, 0), "ink", lift=0.02, name="zeiger")
    k.decal("bauch", [(-0.012, 0), (0.1, 0.06), (0.1, 0.085), (-0.012, 0.024)], (0, 0), "ink", lift=0.02, name="zeiger")
    head(k, "kopf", (0.3, -0.12, 1.6), (0.46, 0.4, 0.42), "s1")
    face(k, "kopf", 0.12, 0.13, 0.15, -0.06, 0.62, 0.26, look=(-0.4, 0), teeth=10, lower=6, curve=0.2)
    k.bowler((0.34, -0.05, 1.96), 0.4, tilt=R(-12))
    arm(k, (0.05, -0.1, 0.62), (-0.35, -0.2, 0.95), pose="point", size=0.22)
    arm(k, (0.5, -0.1, 0.9), (0.9, -0.02, 1.2), pose="wave", mirror=True, size=0.22)


def sieben_finger(k):
    """Sieben Finger ohne Hand. Sie zaehlen mit, wie oft du getroffen hast."""
    c = Vector((0, 0, 0.95))
    for i in range(7):
        a = R(-72 + 24 * i)
        l = 0.75 + 0.12 * math.cos(a * 1.2)
        base = c + Vector((math.sin(a) * 0.3, 0, math.cos(a) * 0.3))
        tip = c + Vector((math.sin(a) * (0.3 + l), 0, math.cos(a) * (0.3 + l)))
        mid = (base + tip) / 2
        k.ball(mid, (0.1, 0.1, l / 2 + 0.05), "glove", rot=(0, a, 0), name="finger")
        k.ball(tip - (tip - c).normalized() * 0.07 + Vector((0, -0.07, 0)), (0.06, 0.03, 0.05), "s1",
               rot=(0, a, 0), name="nagel")
        ring = base + (tip - base) * 0.42
        k.torus(ring, 0.11, 0.028, "gold", rot=(0, a, 0), name="ring")
    k.torus(c + Vector((0, 0, -0.35)), 0.3, 0.07, "glove", rot=(R(90), 0, 0), name="stulpe")
    k.face_surface("mitte", c + Vector((0, -0.05, 0)), (0.2, 0.15, 0.2))
    k.eye("mitte", 0, 0.0, 0.22, look=(0, 0), name="auge")


def laecheln_ohne_gesicht(k):
    """Nur ein Mund, frei schwebend. Er wird breiter, je laenger der Kampf dauert."""
    z = 1.0
    n = 30
    lips = []
    for i in range(n + 1):
        t = -1 + 2 * i / n
        lips.append((t * 1.0, 0.2 - 0.16 * (1 - t * t) + 0.18 * t * t))
    for i in range(n, -1, -1):
        t = -1 + 2 * i / n
        lips.append((t * 1.0, -0.72 * (1 - t * t) + 0.18 * t * t - 0.08))
    k.poly(lips, (0, 0.05, z), "blood", depth=0.12, name="lippen")
    k.face_surface("luft", (0, -0.02, z + 0.08), (1.2, 0.001, 1.0))
    k.grin("luft", 0.02, 1.7, 0.66, teeth=13, lower=11, curve=0.2, tongue=True)
    arm(k, (-1.0, 0.05, z + 0.15), (-1.25, -0.02, z + 0.55), pose="wave", r=0.03)
    arm(k, (1.0, 0.05, z + 0.15), (1.25, -0.02, z - 0.35), pose="open", mirror=True, r=0.03)


def gerichtsdiener(k):
    """Stellt dir deine eigene Vorladung zu. Er hat sie selbst geschrieben."""
    legs(k, hip=0.62, spread=0.1, foot=0.26)
    k.cyl((0, 0, 1.05), 0.34, 1.0, "ink2", r2=0.24, name="rock")
    k.box((0, -0.25, 1.2), (0.16, 0.02, 0.5), "paper", name="hemd")
    k.torus((0, 0, 1.55), 0.26, 0.07, "paper", name="kragen")
    k.hose([(0, 0, 1.55), (0, 0, 1.75)], 0.06, "s1")
    head(k, "kopf", (0, -0.02, 1.95), (0.27, 0.25, 0.34), "s1")
    k.bowler((0, 0, 2.26), 0.42)
    face(k, "kopf", 0.08, 0.1, 0.1, -0.1, 0.4, 0.15, look=(0, 0), teeth=9, lid=0.3, lid_mat="s2", curve=0.35)
    arm(k, (-0.3, 0, 1.45), (-0.62, -0.25, 1.35), pose="fist", sag=0.15)
    k.cyl((-0.7, -0.4, 1.4), 0.07, 0.62, "paper", rot=(0, R(80), 0), name="rolle")
    k.torus((-0.7, -0.4, 1.4), 0.075, 0.018, "blood", rot=(0, R(80), 0), name="band")
    arm(k, (0.3, 0, 1.45), (0.55, -0.02, 0.9), pose="open", mirror=True)


# ------------------------------------------------------------------ Eliten
def papierpriester(k):
    """Sein Gewand ist aus Vertraegen. Er liest laut, aber niemand hoert Worte."""
    k.cyl((0, 0, 0.72), 0.62, 1.4, "paper", r2=0.26, name="gewand")
    k.face_surface("gewand", (0, 0, 0.7), (0.5, 0.5, 0.7))
    for i in range(9):
        z = -0.45 + 0.1 * i
        w = 0.22 + 0.03 * (8 - i)
        k.decal("gewand", [(-w, z), (w * 0.8, z), (w * 0.8, z + 0.018), (-w, z + 0.018)], (0, 0), "s2",
                lift=0.012, name="zeile")
    k.ball((0.1, -0.5, 0.25), (0.08, 0.02, 0.08), "blood", name="siegel")
    head(k, "kopf", (0, -0.02, 1.62), (0.27, 0.25, 0.3), "s1")
    k.box((0, 0, 2.08), (0.34, 0.2, 0.56), "paper", rot=(0, 0, 0), name="mitra")
    k.poly([(-0.17, 0), (0.17, 0), (0, 0.22)], (0, -0.1, 2.36), "paper", depth=0.2, name="mitraspitze")
    k.box((0, -0.105, 2.08), (0.05, 0.01, 0.3), "gold", name="kreuz")
    k.box((0, -0.105, 2.12), (0.18, 0.01, 0.05), "gold", name="kreuzbalken")
    face(k, "kopf", 0.06, 0.1, 0.1, -0.1, 0.36, 0.2, look=(0, -0.8), teeth=7, curve=-0.15, lid=0.35, lid_mat="s2")
    arm(k, (-0.3, 0, 1.3), (-0.45, -0.4, 1.1), pose="open", mat="paper", sag=0.1)
    arm(k, (0.3, 0, 1.3), (0.45, -0.4, 1.1), pose="open", mirror=True, mat="paper", sag=0.1)
    k.box((0, -0.55, 1.12), (0.9, 0.02, 0.5), "paper", rot=(R(-12), 0, 0), name="vertrag")
    k.cyl((-0.46, -0.55, 1.12), 0.06, 0.55, "paper", name="rolle_l")
    k.cyl((0.46, -0.55, 1.12), 0.06, 0.55, "paper", name="rolle_r")


def fette_ratte(k):
    """Sie hat Muenzen gefressen. Man hoert sie klimpern, wenn sie atmet."""
    k.hose([(0.45, 0.2, 0.3), (1.0, 0.25, 0.25), (1.1, 0.2, 0.7), (0.85, 0.2, 0.9)], 0.04, "s1")
    k.shoe((-0.28, 0, 0.1), 0.3)
    k.shoe((0.28, 0, 0.1), 0.3, mirror=True)
    k.ball((0, 0, 0.8), (0.72, 0.6, 0.75), "s2", taper=0.35, name="bauch")
    k.ball((0, -0.35, 0.65), (0.42, 0.3, 0.45), "s1", name="bauchfleck")
    head(k, "kopf", (0, -0.1, 1.55), (0.42, 0.38, 0.36), "s2")
    for s in (-1, 1):
        k.cyl((s * 0.36, 0.0, 1.92), 0.2, 0.05, "s2", rot=(R(90), 0, 0), name="ohr")
        k.cyl((s * 0.36, -0.03, 1.92), 0.13, 0.05, "blood2", rot=(R(90), 0, 0), name="ohrinnen")
    k.face_surface("kopf", (0, -0.1, 1.55), (0.42, 0.38, 0.36))
    k.eye("kopf", -0.14, 0.14, 0.12, look=(0.3, 0.2), name="auge_l")
    k.eye("kopf", 0.14, 0.14, 0.12, look=(0.3, 0.2), name="auge_r")
    k.ball(k.front("kopf", 0, -0.08) - k.offset + Vector((0, -0.05, 0)), (0.16, 0.14, 0.12), "s1", name="schnauze")
    k.ball(k.front("kopf", 0, -0.02) - k.offset + Vector((0, -0.18, 0)), 0.06, "ink", name="nase")
    k.face_surface("schnauze", k.front("kopf", 0, -0.08) - k.offset + Vector((0, -0.05, 0)), (0.16, 0.14, 0.12))
    k.grin("schnauze", -0.05, 0.3, 0.12, teeth=2, curve=0.3)
    for s in (-1, 1):
        for dz in (0.0, 0.05):
            k.hose([(s * 0.12, -0.6, 1.47 + dz), (s * 0.4, -0.55, 1.5 + dz * 2)], 0.008, "ink")
    arm(k, (-0.55, 0, 1.0), (-0.52, -0.45, 0.95), pose="fist", sag=0.1)
    arm(k, (0.55, 0, 1.0), (0.9, -0.02, 1.4), pose="open", mirror=True)
    k.cyl((-0.5, -0.62, 1.12), 0.16, 0.04, "gold", rot=(R(90), 0, 0), name="muenze")


def spiegelschwester(k):
    """Sie ahmt dich nach, aber immer eine Sekunde zu spaet - und etwas zu genau."""
    k.shoe((-0.15, 0, 0.08), 0.22, "s3")
    k.shoe((0.15, 0, 0.08), 0.22, "s3", mirror=True)
    k.cyl((0, 0, 0.55), 0.09, 0.9, "gold", name="griff")
    k.ball((0, 0, 1.05), 0.12, "gold", name="knoten")
    k.ball((0, 0.02, 1.7), (0.52, 0.1, 0.66), "gold", name="rahmen")
    k.ball((0, -0.03, 1.7), (0.44, 0.1, 0.58), "indigo2", name="glas")
    k.face_surface("glas", (0, -0.03, 1.7), (0.44, 0.1, 0.58))
    k.decal("glas", [(0.18, 0.25), (0.3, 0.1), (0.1, 0.34)], (0, 0), "flat_paper", lift=0.01, name="glanz")
    face(k, "glas", 0.1, 0.14, 0.14, -0.14, 0.44, 0.2, look=(-0.6, 0), teeth=8, curve=0.3, lid=0.3,
         lid_mat="indigo")
    k.ball((0, 0.02, 2.42), (0.22, 0.1, 0.12), "blood", name="schleife")
    k.ball((-0.2, 0.02, 2.46), (0.12, 0.08, 0.12), "blood", name="schleife_l")
    k.ball((0.2, 0.02, 2.46), (0.12, 0.08, 0.12), "blood", name="schleife_r")
    arm(k, (-0.5, 0, 1.55), (-0.85, -0.02, 1.85), pose="wave", mat="ink2")
    arm(k, (0.5, 0, 1.55), (0.85, -0.02, 1.85), pose="wave", mirror=True, mat="ink2")


def muenzmaul(k):
    """Es bestraft lange Kaempfe und spuckt am Ende alles aus, was es gefressen hat."""
    legs(k, hip=0.4, spread=0.3, foot=0.3)
    head(k, "beutel", (0, 0, 1.0), (0.8, 0.62, 0.72), "s3")
    k.cyl((0, 0, 1.72), 0.34, 0.08, "gold", name="buegel")
    k.ball((-0.12, 0, 1.84), 0.09, "gold", name="kugel_l")
    k.ball((0.12, 0, 1.84), 0.09, "gold", name="kugel_r")
    k.eye("beutel", -0.2, 0.46, 0.12, look=(0, 0.6), angry=0.3, name="auge_l")
    k.eye("beutel", 0.2, 0.46, 0.12, look=(0, 0.6), angry=0.3, name="auge_r")
    k.grin("beutel", 0.28, 1.25, 0.74, teeth=10, lower=8, curve=0.1, tooth="teeth")
    for i, (x, zz) in enumerate(((-0.25, 0.72), (0.05, 0.64), (0.3, 0.74), (-0.05, 0.8))):
        k.cyl((x, -0.66, zz), 0.1, 0.03, "gold", rot=(R(70), R(20 * i), 0), name="muenze")
    arm(k, (-0.72, 0, 0.9), (-1.05, -0.02, 1.3), pose="open")
    arm(k, (0.72, 0, 0.9), (1.05, -0.02, 0.6), pose="fist", mirror=True)


def henker_verkehrt(k):
    """Derselbe Hals, dasselbe Grinsen - aber der Strick haelt jetzt ihn."""
    lachender_henker(k, hood="blood2", tunic="s3")
    k.turn((0, 0, 1.3), (0, R(180), 0))
    # Er haengt an den Fuessen vom Balken
    k.box((0, 0, 2.95), (1.2, 0.18, 0.14), "s3", name="balken")
    k.hose([(-0.2, 0, 2.5), (-0.2, 0, 2.88)], 0.025, "s1")
    k.hose([(0.2, 0, 2.5), (0.2, 0, 2.88)], 0.025, "s1")


def rote_sonne(k):
    """Sie geht nicht unter. Sie wartet nur, bis du muede wirst."""
    z = 1.1
    for i in range(12):
        a = 2 * math.pi * i / 12
        l = 0.32 if i % 2 else 0.45
        p = Vector((math.cos(a) * (0.72 + l / 2), 0.05, z + math.sin(a) * (0.72 + l / 2)))
        k.cyl(p, 0.14, l, "gold", r2=0.0, rot=(0, math.pi / 2 - a, 0), name="strahl")
    head(k, "sonne", (0, 0, z), 0.72, "blood")
    face(k, "sonne", 0.2, 0.17, 0.2, 0.0, 0.8, 0.36, look=(0, -0.2), teeth=10, lower=7, angry=0.35, curve=0.2)
    k.cyl((0, -0.45, z + 0.12), 0.06, 0.1, "ember", rot=(R(90), 0, 0), name="nase")
    arm(k, (-0.6, 0, z - 0.4), (-1.1, -0.1, z - 0.9), pose="open", mat="ink2")
    arm(k, (0.6, 0, z - 0.4), (1.1, -0.1, z - 0.9), pose="open", mirror=True, mat="ink2")


def kartenspieler(k):
    """Er spielt deine Karten. Besser als du."""
    legs(k, hip=0.6, spread=0.14, foot=0.26)
    k.ball((0, 0, 1.1), (0.48, 0.4, 0.58), "paper", taper=0.2, name="hemd")
    weste = k.ball((0, 0.02, 1.08), (0.5, 0.38, 0.56), "blood2", taper=0.2, name="weste")
    k.cut(weste, (0, -0.4, 1.2), (0.18, 0.3, 0.6))
    for dz in (0.95, 1.1, 1.25):
        k.ball((0, -0.36, dz), 0.03, "gold", name="knopf")
    head(k, "kopf", (0, -0.02, 1.82), (0.32, 0.29, 0.3), "s1")
    k.cyl((0, -0.02, 2.02), 0.33, 0.12, "indigo", name="schirmband")
    k.poly([(-0.34, 0), (0.34, 0), (0.22, -0.14), (-0.22, -0.14)], (0, -0.32, 2.0), "indigo2", depth=0.3,
           rot=(R(-25), 0, 0), name="schirm")
    face(k, "kopf", 0.06, 0.1, 0.11, -0.08, 0.44, 0.16, look=(0.5, 0), teeth=9, curve=0.35, lid=0.35,
         lid_mat="s2")
    # vier Arme: zwei faechern Karten, zwei mischen
    for s, hz, pose in ((-1, 1.45, "open"), (1, 1.45, "open")):
        a = arm(k, (s * 0.4, 0, 1.3), (s * 0.78, -0.1, hz), pose=pose, mirror=s > 0)
        for j in range(4):
            ang = R(-30 + 20 * j) * s
            k.box((s * 0.84 + math.sin(ang) * 0.14, -0.2, hz + 0.24 + math.cos(ang) * 0.1), (0.16, 0.01, 0.24),
                  "paper", rot=(0, ang, 0), name="karte")
    for s in (-1, 1):
        arm(k, (s * 0.38, 0, 0.95), (s * 0.2, -0.45, 0.8), pose="fist", mirror=s > 0, sag=0.1, size=0.2)
    k.box((0, -0.5, 0.86), (0.18, 0.16, 0.24), "blood", name="stapel")


# ------------------------------------------------------------------ Bosse
def boss_turm(k):
    """XVI - Er waechst hinter dir hoch. Jeder Blitz nimmt dir eine Moeglichkeit."""
    k.cyl((0, 0, 1.2), 0.85, 2.4, "s1", r2=0.62, name="turm")
    k.face_surface("turm", (0, 0, 1.2), (0.74, 0.74, 1.2))
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.box((math.cos(a) * 0.62, math.sin(a) * 0.62, 2.5), (0.26, 0.22, 0.26), "s1", rot=(0, 0, a), name="zinne")
    k.cyl((0, 0, 2.42), 0.72, 0.1, "s2", name="gesims")
    k.cyl((0, 0, 3.05), 0.6, 0.9, "blood", r2=0.0, name="dach")
    k.cyl((0, 0, 3.58), 0.02, 0.3, "ink", name="stange")
    k.poly([(0, 0), (0.3, -0.08), (0, -0.16)], (0.02, 0, 3.72), "flat_blood", depth=0.02, name="wimpel")
    # Fenster, Risse, Gesicht
    for dx, dz in ((-0.25, 0.85), (0.3, -0.75), (0.0, 1.1)):
        pts = [(-0.07, -0.1), (0.07, -0.1), (0.07, 0.05)] + [(0.07 * math.cos(a), 0.05 + 0.07 * math.sin(a))
                                                              for a in [i * math.pi / 8 for i in range(1, 8)]] + [(-0.07, 0.05)]
        k.decal("turm", pts, (dx, dz), "ink", lift=0.01, name="fenster")
    for path in (((-0.5, 0.6), (-0.4, 0.4), (-0.46, 0.2), (-0.35, 0.0)), ((0.45, -0.1), (0.52, -0.35), (0.42, -0.55)),
                 ((0.1, -0.9), (0.18, -0.7), (0.08, -0.55))):
        for (x0, z0), (x1, z1) in zip(path, path[1:]):
            nx, nz = -(z1 - z0), x1 - x0
            ln = math.hypot(nx, nz) or 1
            w = 0.025
            nx, nz = nx / ln * w, nz / ln * w
            k.decal("turm", [(x0 - nx, z0 - nz), (x1 - nx, z1 - nz), (x1 + nx, z1 + nz), (x0 + nx, z0 + nz)], (0, 0),
                    "crack", lift=0.012, name="riss")
    face(k, "turm", 0.42, 0.24, 0.26, 0.05, 0.95, 0.5, look=(0.2, -0.2), teeth=10, lower=8, angry=0.45, curve=0.15,
         tongue=True)
    arm(k, (-0.72, 0, 1.3), (-1.45, -0.1, 2.0), pose="open", r=0.07, size=0.42)
    arm(k, (0.72, 0, 0.9), (1.45, -0.1, 0.55), pose="open", mirror=True, r=0.07, size=0.42)
    k.bolt((-1.2, -0.2, 3.1), 0.45, rot=(0, R(15), 0))
    k.bolt((1.25, -0.2, 2.5), 0.38, rot=(0, R(-20), 0))
    for x, zz, s in ((-0.9, 0.12, 0.2), (0.85, 0.1, 0.24), (-0.4, 0.05, 0.16), (0.3, 0.06, 0.18)):
        k.ball((x, -0.4, zz), (s, s * 0.8, s * 0.7), "s2", name="truemmer")


def boss_mond(k):
    """XVIII - Du siehst sein Grinsen. Sonst siehst du nichts."""
    z = 1.3
    head(k, "mond", (0, 0, z), 1.0, "paper")
    k.decal("mond", [(0.2 + 0.8 * math.cos(a), 0.95 * math.sin(a)) for a in [-math.pi / 2 + i * math.pi / 16 for i in range(17)]]
            + [(0.1 + 0.55 * math.cos(a), 0.95 * math.sin(a)) for a in [math.pi / 2 - i * math.pi / 16 for i in range(17)]],
            (0, 0), "indigo", lift=0.005, name="schatten")
    for x, zz, r in ((-0.45, 0.45, 0.12), (-0.55, -0.3, 0.08), (0.05, 0.6, 0.07)):
        k.decal("mond", [(r * math.cos(a), r * math.sin(a)) for a in [i * math.pi / 8 for i in range(16)]], (x, zz),
                "s1", lift=0.008, name="krater")
    face(k, "mond", 0.2, 0.2, 0.26, -0.12, 1.1, 0.5, look=(0.7, -0.2), teeth=12, lower=9, lid=0.45, lid_mat="s1",
         curve=0.22)
    k.cyl((0.45, 0.2, z + 1.05), 0.55, 0.8, "indigo", r2=0.0, rot=(0, R(35), 0), name="schlafmuetze")
    k.ball((0.95, 0.2, z + 1.25), 0.13, "gold2", name="bommel")
    arm(k, (-0.9, 0, z - 0.3), (-1.4, -0.2, z + 0.3), pose="open", r=0.06, size=0.36)
    arm(k, (0.9, 0, z - 0.3), (1.35, -0.2, z - 0.8), pose="wave", mirror=True, r=0.06, size=0.36)
    for x, zz, s in ((-1.3, 2.6, 0.12), (1.4, 2.2, 0.09), (-1.5, 0.3, 0.08), (1.2, 0.1, 0.1)):
        pts = []
        for i in range(10):
            a = math.pi / 2 + i * math.pi / 5
            rr = s if i % 2 == 0 else s * 0.45
            pts.append((rr * math.cos(a), rr * math.sin(a)))
        k.poly(pts, (x, -0.2, zz), "flat_gold", depth=0.02, name="stern")


def boss_tod(k):
    """XIII - Ein weisses Gesicht, ein roter Schnitt. Er nimmt nicht dich - er nimmt deine Karten."""
    legs(k, hip=0.95, spread=0.1, foot=0.3, r=0.045)
    k.cyl((0, 0, 1.35), 0.34, 0.9, "ink2", r2=0.26, name="frack")
    k.poly([(-0.16, 0), (0.16, 0), (0, -0.55)], (0, -0.3, 1.78), "paper", depth=0.05, name="hemdbrust")
    k.ball((0, -0.34, 1.72), (0.15, 0.05, 0.06), "blood", name="fliege")
    k.poly([(-0.34, 0), (-0.05, 0), (-0.25, -0.7)], (0, 0.1, 1.0), "ink2", depth=0.05, name="schoss_l")
    k.poly([(0.34, 0), (0.05, 0), (0.25, -0.7)], (0, 0.1, 1.0), "ink2", depth=0.05, name="schoss_r")
    head(k, "kopf", (0, -0.02, 2.1), (0.3, 0.28, 0.34), "paper")
    for s in (-1, 1):
        k.eye("kopf", s * 0.11, 0.06, 0.12, white="ink2", pupil="flat_paper", look=(-0.3, 0.1), name="hoehle")
    k.grin("kopf", -0.12, 0.42, 0.08, teeth=10, curve=0.5, mouth="blood")
    k.nose("kopf", 0, -0.04, 0.035, material="ink2")
    k.tophat((0, 0, 2.42), 0.44, band="blood", tilt=R(-8))
    arm(k, (-0.3, 0, 1.7), (-0.55, -0.1, 2.1), pose="wave")
    arm(k, (0.3, 0, 1.7), (0.62, -0.1, 1.3), pose="fist", mirror=True)
    k.cyl((0.68, -0.12, 1.4), 0.03, 2.6, "s3", name="sensenstab")
    ts = [i / 12 for i in range(13)]
    outer = [(-0.95 * t, 0.28 * math.sin(math.pi * t * 0.9)) for t in ts]
    inner = [(-0.95 * t, 0.28 * math.sin(math.pi * t * 0.9) - 0.16 * (1 - t) ** 0.8) for t in ts[::-1]][1:]
    blade = outer + inner
    k.poly(blade, (0.68, -0.14, 2.66), "s1", depth=0.04, name="sensenblatt")


def boss_rad(k):
    """X - Es dreht. Deine Positionen bleiben nicht, wo du sie gelegt hast."""
    z = 1.2
    k.torus((0, 0, z), 1.0, 0.1, "gold", rot=(R(90), 0, 0), name="felge")
    k.torus((0, 0, z), 0.86, 0.04, "blood", rot=(R(90), 0, 0), name="innenring")
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.cyl((math.cos(a) * 0.62, 0.02, z + math.sin(a) * 0.62), 0.04, 0.6, "s2",
              rot=(0, math.pi / 2 - a, 0), name="speiche")
        k.ball((math.cos(a) * 1.0, -0.1, z + math.sin(a) * 1.0), 0.09, "blood" if i % 2 else "indigo", name="zeichen")
    head(k, "nabe", (0, -0.05, z), (0.45, 0.3, 0.45), "gold2")
    face(k, "nabe", 0.1, 0.13, 0.15, -0.08, 0.6, 0.26, look=(0.6, 0.3), teeth=9, lower=6, curve=0.2)
    k.shoe((-0.25, 0, 0.1), 0.3, "ink2")
    k.shoe((0.25, 0, 0.1), 0.3, "ink2", mirror=True)
    k.hose([(-0.2, 0, 0.3), (-0.25, 0, 0.14)], 0.05, "ink2")
    k.hose([(0.2, 0, 0.3), (0.25, 0, 0.14)], 0.05, "ink2")
    arm(k, (-0.98, -0.05, z + 0.25), (-1.4, -0.1, z + 0.75), pose="open", r=0.05, size=0.32)
    arm(k, (0.98, -0.05, z - 0.25), (1.4, -0.1, z - 0.7), pose="point", mirror=True, r=0.05, size=0.32)


def boss_teufel(k):
    """XV - Er kaempft nicht gern. Er verhandelt. Und er gewinnt fast immer."""
    k.hose([(0.3, 0.2, 0.7), (0.9, 0.3, 0.5), (1.0, 0.25, 1.1), (0.8, 0.2, 1.3)], 0.04, "blood")
    k.poly([(-0.12, 0), (0.12, 0), (0, 0.22)], (0.8, 0.15, 1.3), "blood", depth=0.04, name="schwanzspitze")
    legs(k, hip=0.62, spread=0.14, foot=0.26, shoe="ink")
    k.ball((0, 0, 1.12), (0.55, 0.45, 0.62), "blood", taper=0.25, name="bauch")
    head(k, "kopf", (0, -0.03, 1.9), (0.4, 0.36, 0.4), "blood")
    for s in (-1, 1):
        k.cyl((s * 0.32, 0.0, 2.35), 0.1, 0.42, "paper", r2=0.0, rot=(0, R(22) * s, 0), name="horn")
        k.cyl((s * 0.42, 0.0, 1.95), 0.08, 0.26, "blood", r2=0.0, rot=(0, R(-70) * s, 0), name="ohr")
    face(k, "kopf", 0.12, 0.13, 0.14, -0.06, 0.6, 0.22, look=(-0.5, 0), teeth=10, lid=0.35, lid_mat="blood2",
         angry=0.25, curve=0.35)
    k.cyl((0, -0.3, 1.46), 0.1, 0.24, "ink2", r2=0.0, rot=(R(180), 0, 0), name="bart")
    arm(k, (-0.48, 0, 1.3), (-0.8, -0.1, 1.55), pose="open")
    k.box((-0.95, -0.2, 1.85), (0.4, 0.02, 0.52), "paper", rot=(0, R(10), 0), name="vertrag")
    for i in range(5):
        k.box((-0.95, -0.22, 1.72 + 0.07 * i), (0.28, 0.01, 0.015), "s2", rot=(0, R(10), 0), name="zeile")
    arm(k, (0.48, 0, 1.3), (0.8, -0.1, 1.0), pose="fist", mirror=True)
    k.cyl((0.86, -0.12, 1.25), 0.03, 2.1, "s3", name="gabelstab")
    k.box((0.86, -0.12, 2.3), (0.4, 0.05, 0.05), "gold", name="gabelquer")
    for dx in (-0.18, 0, 0.18):
        k.cyl((0.86 + dx, -0.12, 2.47), 0.03, 0.34, "gold", r2=0.0, name="zinke")


def boss_gehaengter(k):
    """XII - Er haengt verkehrt. Von seiner Seite aus liegt deine Zukunft links."""
    # zuerst aufrecht bauen, dann umdrehen
    k.shoe((-0.1, 0, 0.1), 0.26, "ink2")
    k.hose([(-0.08, 0, 0.8), (-0.12, -0.02, 0.45), (-0.1, 0, 0.14)], 0.05, "s3")
    k.hose([(0.08, 0, 0.8), (0.38, -0.02, 0.62), (0.05, -0.02, 0.45)], 0.05, "s3")
    k.shoe((0.05, -0.05, 0.42), 0.22, "ink2")
    k.cyl((0, 0, 1.15), 0.3, 0.75, "indigo", r2=0.22, name="kittel")
    k.cyl((0, 0, 0.8), 0.305, 0.08, "gold", name="guertel")
    k.hose([(0, 0, 1.52), (0, 0, 1.62)], 0.06, "s1")
    head(k, "kopf", (0, -0.02, 1.88), (0.3, 0.28, 0.3), "paper")
    k.ball((0, 0.05, 2.04), (0.32, 0.28, 0.18), "gold2", name="haar")
    k.torus((0, 0.1, 1.9), 0.46, 0.04, "gold2", rot=(R(90), 0, 0), name="heiligenschein")
    face(k, "kopf", 0.06, 0.11, 0.11, -0.08, 0.42, 0.16, look=(0, 0.6), teeth=8, lid=0.4, lid_mat="s1", curve=0.3)
    arm(k, (-0.26, 0, 1.4), (-0.34, 0.2, 1.05), pose="fist", sag=0.05)
    arm(k, (0.26, 0, 1.4), (0.34, 0.2, 1.05), pose="fist", mirror=True, sag=0.05)
    k.turn((0, 0, 1.1), (0, R(180), 0))
    k.box((0, 0.1, 2.72), (1.6, 0.2, 0.18), "s3", name="querbalken")
    k.box((-0.72, 0.1, 1.35), (0.18, 0.2, 2.9), "s3", name="pfosten_l")
    k.box((0.72, 0.1, 1.35), (0.18, 0.2, 2.9), "s3", name="pfosten_r")
    k.hose([(-0.1, 0, 2.63), (0.1, -0.02, 2.2), (0.1, 0, 2.05)], 0.025, "s1")


def boss_welt(k):
    """XXI - Alles, was du besiegt hast, ist noch da. Es sieht nur jetzt zusammen aus."""
    z = 1.45
    # Lorbeerkranz
    for i in range(36):
        a = 2 * math.pi * i / 36
        p = Vector((math.cos(a) * 1.05, 0.1, z + math.sin(a) * 1.35))
        k.ball(p, (0.09, 0.05, 0.17), "moss", rot=(0, math.pi / 2 - a + (0.5 if i % 2 else -0.5), 0), name="blatt")
    for zz in (z + 1.35, z - 1.35):
        k.ball((0, 0.02, zz), (0.2, 0.08, 0.1), "blood", name="schleife")
    head(k, "welt", (0, 0, z), 0.8, "indigo")
    for x, zz, s in ((-0.35, 0.3, 0.22), (0.3, -0.35, 0.18), (0.35, 0.45, 0.12), (-0.4, -0.4, 0.14)):
        k.decal("welt", [(s * (1 + 0.3 * math.sin(3 * a)) * math.cos(a), s * math.sin(a)) for a in
                         [i * math.pi / 8 for i in range(16)]], (x, zz), "moss", lift=0.006, name="kontinent")
    face(k, "welt", 0.15, 0.18, 0.22, -0.12, 0.95, 0.42, look=(0, 0), teeth=12, lower=9, tongue=True, curve=0.2)
    arm(k, (-0.75, 0, z - 0.2), (-1.5, -0.2, z + 0.4), pose="fist", r=0.06, size=0.34, mat="ink2")
    arm(k, (0.75, 0, z - 0.2), (1.5, -0.2, z - 0.6), pose="fist", mirror=True, r=0.06, size=0.34, mat="ink2")
    k.cyl((-1.55, -0.3, z + 0.45), 0.04, 0.9, "gold", rot=(0, R(-20), 0), name="stab_l")
    k.cyl((1.55, -0.3, z - 0.55), 0.04, 0.9, "gold", rot=(0, R(20), 0), name="stab_r")
    # vier Ecken: die geschlagenen Omen
    corners = ((-1.35, z + 1.25), (1.35, z + 1.25), (-1.35, z - 1.35), (1.35, z - 1.35))
    x, zz = corners[0]
    k.cyl((x, 0, zz), 0.16, 0.42, "s1", r2=0.12, name="mini_turm")
    k.cyl((x, 0, zz + 0.32), 0.14, 0.22, "blood", r2=0.0, name="mini_dach")
    x, zz = corners[1]
    m = k.ball((x, 0, zz), 0.24, "paper", name="mini_mond")
    k.cut(m, (x + 0.14, -0.1, zz + 0.06), (0.2, 0.3, 0.2))
    x, zz = corners[2]
    k.ball((x, 0, zz), (0.2, 0.18, 0.22), "paper", name="mini_schaedel")
    k.face_surface("schaedel", (x, 0, zz), (0.2, 0.18, 0.22))
    for s in (-1, 1):
        k.decal("schaedel", [(0.05 * math.cos(a), 0.06 * math.sin(a)) for a in [i * math.pi / 6 for i in range(12)]],
                (s * 0.07, 0.03), "ink", lift=0.01, name="hoehle")
    x, zz = corners[3]
    k.torus((x, 0, zz), 0.2, 0.04, "gold", rot=(R(90), 0, 0), name="mini_rad")
    k.ball((x, -0.02, zz), 0.07, "blood", name="mini_nabe")


def weltenwurm(k):
    """Die Welt ist nicht das Ende. Er frisst sie von hinten und waechst mit jeder Schleife."""
    pts = [(-1.3, 0.3, 0.3), (-0.9, 0.2, 0.25), (-0.45, 0.1, 0.35), (-0.05, 0.0, 0.55), (0.25, 0.0, 0.9),
           (0.35, -0.05, 1.3), (0.2, -0.05, 1.7)]
    for i, p in enumerate(pts):
        r = 0.22 + 0.06 * i
        k.ball(p, r, "indigo" if i % 2 else "indigo2", name="glied")
        if i % 2 == 0 and i > 0:
            k.torus(p, r * 0.98, 0.04, "gold", rot=(R(90) if i < 4 else 0, R(60), 0), name="ring")
    head(k, "kopf", (0.1, -0.15, 2.25), (0.7, 0.55, 0.62), "indigo")
    k.eye("kopf", -0.25, 0.4, 0.14, look=(0.2, -0.5), angry=0.4, name="auge_l")
    k.eye("kopf", 0.25, 0.4, 0.14, look=(0.2, -0.5), angry=0.4, name="auge_r")
    k.grin("kopf", 0.18, 1.05, 0.7, teeth=11, lower=9, curve=0.12)
    k.ball((0.1, -0.6, 1.95), 0.28, "indigo2", name="welt")
    k.face_surface("welt", (0.1, -0.6, 1.95), (0.28, 0.28, 0.28))
    k.decal("welt", [(0.1 * math.cos(a), 0.08 * math.sin(a)) for a in [i * math.pi / 6 for i in range(12)]], (-0.05, 0.05),
            "moss", lift=0.008, name="kontinent")
    k.decal("welt", [(0.07 * math.cos(a), 0.06 * math.sin(a)) for a in [i * math.pi / 6 for i in range(12)]], (0.1, -0.1),
            "moss", lift=0.008, name="kontinent")
    arm(k, (-0.5, -0.1, 1.9), (-1.05, -0.2, 2.5), pose="open", r=0.06, size=0.34)
    arm(k, (0.65, -0.1, 1.85), (1.15, -0.2, 1.4), pose="point", mirror=True, r=0.06, size=0.34)


# (Id, Stufe, Bauanleitung). Die Stufe bestimmt die Spritegroesse.
FIGUREN = [
    ("lachender_henker", "normal", lachender_henker),
    ("zahnmuenze", "normal", zahnmuenze),
    ("kelchtrinker", "normal", kelchtrinker),
    ("schreiende_klinge", "normal", schreiende_klinge),
    ("zwillingsschatten", "normal", zwillingsschatten),
    ("kleiner_mond", "normal", kleiner_mond),
    ("hutmann", "normal", hutmann),
    ("augensammlerin", "normal", augensammlerin),
    ("blutorgel", "normal", blutorgel),
    ("wachsbote", "normal", wachsbote),
    ("mondfresser", "normal", mondfresser),
    ("nadelwitwe", "normal", nadelwitwe),
    ("uhrenwurm", "normal", uhrenwurm),
    ("sieben_finger", "normal", sieben_finger),
    ("laecheln_ohne_gesicht", "normal", laecheln_ohne_gesicht),
    ("gerichtsdiener", "normal", gerichtsdiener),
    ("papierpriester", "elite", papierpriester),
    ("fette_ratte", "elite", fette_ratte),
    ("spiegelschwester", "elite", spiegelschwester),
    ("muenzmaul", "elite", muenzmaul),
    ("henker_verkehrt", "elite", henker_verkehrt),
    ("rote_sonne", "elite", rote_sonne),
    ("kartenspieler", "elite", kartenspieler),
    ("boss_turm", "boss", boss_turm),
    ("boss_mond", "boss", boss_mond),
    ("boss_tod", "boss", boss_tod),
    ("boss_rad", "boss", boss_rad),
    ("boss_teufel", "boss", boss_teufel),
    ("boss_gehaengter", "boss", boss_gehaengter),
    ("boss_welt", "finale", boss_welt),
    ("weltenwurm", "boss", weltenwurm),
]

SIZE = {"normal": 96, "elite": 112, "boss": 160, "finale": 176}
