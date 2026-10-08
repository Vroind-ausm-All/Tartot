"""Die 50 Charms aus GameCatalog.Charms als 32-px-Blockouts.

Charms sind Dinge, keine Figuren: sie grinsen nicht. Sie bleiben in der
Palette - Sepia fuer Alltagsdinge, Gold fuer Glueck und Muenzen, Blut fuer
Risiko, Indigo fuer Schild und Mond. Kontur 1 px, weil 2 px bei 32 px das
Motiv auffressen wuerden.
"""

import math

from mathutils import Vector

R = math.radians
FRONT = (R(90), 0, 0)  # Scheiben und Ringe zur Kamera drehen


# ------------------------------------------------------------------ Helfer
def star(r, inner=0.45, n=5):
    pts = []
    for i in range(2 * n):
        a = math.pi / 2 + i * math.pi / n
        rr = r if i % 2 == 0 else r * inner
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    return pts


def circle(r, n=20, sx=1.0, sz=1.0):
    return [(r * sx * math.cos(2 * math.pi * i / n), r * sz * math.sin(2 * math.pi * i / n)) for i in range(n)]


def coin(k, loc=(0, 0, 0), r=0.8, mat="gold", emblem=None, rot=FRONT):
    k.cyl(loc, r, 0.16, mat, rot=rot, name="muenze")
    k.torus(Vector(loc) + Vector((0, -0.08, 0)), r * 0.86, r * 0.07, mat, rot=rot, name="muenzrand")
    key = "muenze%d" % k.next_index
    k.face_surface(key, Vector(loc) + Vector((0, -0.09, 0)), (r, 0.001, r))
    if emblem == "stern":
        k.decal(key, star(r * 0.6), (0, 0), "ink2" if mat != "s2" else "ink", lift=0.01, name="stern")
    elif emblem == "loch":
        k.decal(key, [(-0.15, -0.15), (0.15, -0.15), (0.15, 0.15), (-0.15, 0.15)], (0, 0), "ink", lift=0.01, name="loch")
    return key


def chalice(k, loc=(0, 0, 0), s=1.0, cup="s2", rim=None, fill=None):
    x, y, z = loc
    k.cyl((x, y, z + 0.35 * s), 0.3 * s, 0.5 * s, cup, r2=0.55 * s, name="kelch")
    k.cyl((x, y, z - 0.15 * s), 0.08 * s, 0.5 * s, cup, name="stiel")
    k.cyl((x, y, z - 0.42 * s), 0.35 * s, 0.08 * s, cup, name="fuss")
    if rim:
        k.torus((x, y, z + 0.6 * s), 0.55 * s, 0.06 * s, rim, name="kelchrand")
    if fill:
        k.cyl((x, y, z + 0.55 * s), 0.5 * s, 0.04 * s, fill, name="inhalt")


def eyeball(k, loc=(0, 0, 0), r=0.6, pupil="pupil", iris=None, look=(0, 0)):
    k.ball(loc, (r, r * 0.8, r * 0.75), "paper", name="augapfel")
    key = "auge%d" % k.next_index
    k.face_surface(key, loc, (r, r * 0.8, r * 0.75))
    if iris:
        k.decal(key, circle(r * 0.5), look, iris, lift=0.005, name="iris")
    pr = r * 0.3
    pts = [(look[0], look[1])] + [(look[0] + pr * math.cos(a), look[1] + pr * 1.2 * math.sin(a))
                                  for a in [R(75) + i * R(305) / 14 for i in range(15)]]
    k.decal(key, pts, (0, 0), pupil, lift=0.008, name="pupille")
    return key


def chain_loop(k, top=(0, 0, 0.95), mat="s2", links=2):
    for i in range(links):
        rot = FRONT if i % 2 == 0 else (0, 0, R(90))
        k.torus((top[0], top[1], top[2] + 0.22 * i), 0.14, 0.04, mat, rot=rot, name="glied")


def feather(k, mat="ember", vane2=None, quill="s1", tilt=-25):
    rot = (0, R(tilt), 0)
    k.ball((0, 0, 0.15), (0.32, 0.08, 0.95), mat, rot=rot, name="fahne")
    if vane2:
        k.ball((0.05, -0.02, -0.25), (0.22, 0.08, 0.5), vane2, rot=rot, name="fahne2")
    a = R(tilt)
    k.cyl((math.sin(a) * 0.05, -0.1, 0.05), 0.03, 2.0, quill, rot=rot, name="kiel")


def bell(k, mat="gold", bow=None):
    k.cyl((0, 0, 0.05), 0.72, 0.9, mat, r2=0.35, name="glocke")
    k.ball((0, 0, 0.5), (0.36, 0.36, 0.25), mat, name="haube")
    k.torus((0, 0, -0.4), 0.72, 0.07, mat, name="glockenrand")
    k.ball((0, -0.3, -0.52), 0.16, "ink2", name="kloeppel")
    k.torus((0, 0, 0.82), 0.16, 0.05, mat, rot=FRONT, name="oese")
    if bow:
        k.ball((0, -0.35, 0.55), (0.3, 0.1, 0.12), bow, name="schleife")


# ------------------------------------------------------------------ Charms
def blade_pendant(k):
    chain_loop(k, (0, 0, 1.05))
    k.box((0, 0, 0.62), (0.7, 0.12, 0.14), "gold", bevel=0.03, name="parierstange")
    k.box((0, 0, -0.1), (0.32, 0.08, 1.3), "paper", name="klinge")
    k.poly([(-0.16, 0), (0.16, 0), (0, -0.35)], (0, -0.04, -0.75), "paper", depth=0.08, name="spitze")
    k.cyl((0, 0, 0.8), 0.07, 0.25, "ink2", name="griff")


def ember_knot(k):
    k.torus((-0.25, 0, 0), 0.45, 0.12, "ember", rot=(R(90), R(30), 0), name="schlinge")
    k.torus((0.25, 0, 0), 0.45, 0.12, "blood", rot=(R(90), R(-30), 0), name="schlinge")
    k.ball((0, -0.2, 0.75), (0.18, 0.12, 0.3), "flame", taper=-0.4, name="glut")


def blood_moon(k):
    m = k.ball((0, 0, 0), 0.9, "blood", name="splitter")
    k.cut(m, (0.45, 0, 0.2), (0.75, 1.3, 0.8))


def predator_fang(k):
    k.hose([(-0.6, 0, 0.8), (0, -0.05, 0.55), (0.6, 0, 0.8)], 0.05, "blood2")
    k.cyl((0, 0, -0.05), 0.28, 1.1, "paper", r2=0.0, rot=(0, R(180 - 12), 0), name="zahn")
    k.ball((0, 0, 0.5), (0.3, 0.2, 0.14), "paper", name="zahnwurzel")


def hunt_bell(k):
    bell(k, "gold")
    k.hose([(-0.7, 0.05, 0.95), (0, 0, 0.85), (0.7, 0.05, 0.95)], 0.05, "s3")


def black_nail(k):
    k.cyl((0, 0, 0.8), 0.4, 0.12, "ink2", name="nagelkopf")
    k.cyl((0, 0, 0.0), 0.12, 1.5, "ink2", name="schaft")
    k.cyl((0, 0, -0.9), 0.12, 0.35, "ink2", r2=0.0, rot=(0, R(180), 0), name="spitze")


def falcon_eye(k):
    k.torus((0, 0.05, 0), 0.72, 0.1, "gold", rot=FRONT, name="fassung")
    eyeball(k, (0, 0, 0), 0.62, iris="flat_gold", look=(0.1, 0))
    k.ball((0.7, 0.05, 0.55), (0.12, 0.05, 0.4), "s2", rot=(0, R(-40), 0), name="feder")


def ash_wreath(k):
    for i in range(18):
        a = 2 * math.pi * i / 18
        k.ball((math.cos(a) * 0.7, 0, math.sin(a) * 0.7), (0.1, 0.06, 0.2), "s2" if i % 2 else "s3",
               rot=(0, math.pi / 2 - a + 0.5, 0), name="blatt")
    k.ball((0, -0.05, -0.75), (0.2, 0.08, 0.1), "s1", name="knoten")


def thorn_ring(k):
    k.torus((0, 0, 0), 0.62, 0.12, "s2", rot=FRONT, name="ring")
    for i in range(10):
        a = 2 * math.pi * i / 10 + 0.3
        p = Vector((math.cos(a) * 0.8, -0.02, math.sin(a) * 0.8))
        k.cyl(p, 0.07, 0.25, "s3", r2=0.0, rot=(0, math.pi / 2 - a, 0), name="dorn")


def hangman_chain(k):
    for i in range(4):
        rot = FRONT if i % 2 == 0 else (0, 0, R(90))
        k.torus((0, 0, 0.9 - 0.36 * i), 0.2, 0.06, "s2", rot=rot, name="glied")
    k.hose([(0, 0, -0.35), (0.1, -0.03, -0.5)], 0.05, "s1")
    k.torus((0.12, -0.03, -0.72), 0.25, 0.06, "s1", rot=FRONT, name="schlinge")


def iron_coin(k):
    coin(k, r=0.85, mat="s2", emblem="loch")


def cup_rim(k):
    chalice(k, (0, 0, -0.1), 1.3, cup="s2", rim="gold")


def white_thread(k):
    pts = [(-0.8, 0, -0.6), (-0.3, -0.05, 0.1), (0.4, -0.05, 0.5), (0.6, 0, 0.0), (0.1, -0.05, -0.2),
           (-0.2, 0, 0.3), (0.3, -0.05, 0.8)]
    k.hose(pts, 0.06, "paper")
    k.cyl((-0.85, -0.1, -0.7), 0.03, 0.55, "s1", r2=0.01, rot=(0, R(40), 0), name="nadel")


def salt_seal(k):
    k.cyl((0, 0, 0), 0.8, 0.2, "paper", rot=FRONT, name="siegel")
    key = "salz"
    k.face_surface(key, (0, -0.1, 0), (0.8, 0.001, 0.8))
    k.decal(key, star(0.45, 0.5, 6), (0, 0), "s1", lift=0.01, name="stern")
    for x, z in ((-0.5, 0.6), (0.55, 0.5), (0.1, 0.8)):
        k.box((x, -0.1, z), (0.2, 0.2, 0.2), "paper", rot=(R(30), R(20), R(45)), name="kristall")


def bone_pearl(k):
    k.hose([(-0.7, 0, 0.7), (0, -0.05, 0.35), (0.7, 0, 0.7)], 0.035, "s3")
    k.ball((0, 0, -0.1), 0.5, "paper", name="perle")
    k.ball((-0.18, -0.35, 0.08), 0.1, "flat_paper", name="glanz")
    for s in (-1, 1):
        k.ball((s * 0.55, 0, 0.45), 0.12, "s1", name="knochenkugel")


def moon_brooch(k):
    k.ball((0, 0.05, 0), (0.85, 0.1, 0.95), "gold", name="fassung")
    k.ball((0, 0.0, 0), (0.7, 0.1, 0.8), "indigo", name="grund")
    m = k.ball((0, -0.1, 0), 0.5, "paper", name="mond")
    k.cut(m, (0.25, -0.1, 0.12), (0.42, 0.8, 0.45))


def emperor_seal(k):
    k.cyl((0, 0, -0.1), 0.8, 0.2, "blood", rot=FRONT, name="wachs")
    for i in range(8):
        a = 2 * math.pi * i / 8
        k.ball((math.cos(a) * 0.78, 0, math.sin(a) * 0.78 - 0.1), 0.14, "blood", name="wachsrand")
    k.crown((0, -0.2, -0.2), 0.7, spikes=5)


def saint_needle(k):
    k.cyl((0, 0, -0.15), 0.06, 1.8, "s1", r2=0.01, rot=(0, R(180), 0), name="nadel")
    k.torus((0, 0, 0.72), 0.08, 0.025, "s1", rot=FRONT, name="oehr")
    k.torus((0, 0.05, 0.95), 0.35, 0.05, "gold2", rot=(R(75), 0, 0), name="heiligenschein")


def phoenix_feather(k):
    feather(k, "ember", vane2="gold", quill="gold2")


def glass_heart(k):
    k.ball((-0.32, 0, 0.25), 0.45, "indigo2", name="herz_l")
    k.ball((0.32, 0, 0.25), 0.45, "indigo2", name="herz_r")
    k.cyl((0, 0, -0.35), 0.62, 0.9, "indigo2", r2=0.0, rot=(0, R(180), 0), name="herzspitze")
    k.ball((-0.35, -0.4, 0.45), (0.1, 0.04, 0.16), "flat_paper", name="glanz")


def silver_mirror(k):
    k.cyl((0, 0, -0.7), 0.1, 0.7, "s1", name="griff")
    k.ball((0, 0.02, 0.25), (0.6, 0.1, 0.7), "s1", name="rahmen")
    k.ball((0, -0.03, 0.25), (0.48, 0.1, 0.58), "indigo2", name="glas")
    k.ball((-0.18, -0.12, 0.45), (0.08, 0.02, 0.18), "flat_paper", rot=(0, R(-30), 0), name="glanz")


def razor_charm(k):
    chain_loop(k, (-0.45, 0, 0.75), links=1)
    k.box((0.1, 0, 0.1), (1.2, 0.08, 0.38), "paper", rot=(0, R(-25), 0), name="klinge")
    k.box((-0.55, 0, 0.45), (0.4, 0.12, 0.2), "ink2", rot=(0, R(-25), 0), name="heft")


def blank_card(k):
    k.box((0, 0, 0), (1.1, 0.06, 1.6), "paper", rot=(0, R(8), 0), name="karte")
    k.box((0, 0.01, 0), (1.18, 0.05, 1.68), "s2", rot=(0, R(8), 0), name="kartenrand")


def thread_spool(k):
    k.cyl((0, 0, 0.62), 0.6, 0.14, "s2", name="scheibe_o")
    k.cyl((0, 0, -0.62), 0.6, 0.14, "s2", name="scheibe_u")
    k.cyl((0, 0, 0), 0.42, 1.1, "blood", name="faden")
    k.hose([(0.4, -0.1, 0.1), (0.7, -0.2, -0.3), (0.9, -0.1, -0.8)], 0.03, "blood")


def wax_seal(k):
    k.ball((0, 0, 0), (0.85, 0.2, 0.78), "blood", name="wachs")
    k.face_surface("wachs", (0, 0, 0), (0.85, 0.2, 0.78))
    k.decal("wachs", circle(0.5), (0, 0), "blood2", lift=0.01, name="praegung")
    k.decal("wachs", star(0.3), (0, 0), "blood", lift=0.02, name="stern")


def crow_feather(k):
    feather(k, "ink2", vane2="s3", quill="s3", tilt=20)


def memory_shard(k):
    k.poly([(-0.4, -0.9), (0.5, -0.6), (0.3, 0.9), (-0.2, 0.5), (-0.55, 0.0)], (0, 0, 0), "indigo2", depth=0.12,
           name="splitter")
    k.poly([(-0.2, -0.5), (0.2, -0.35), (0.1, 0.4)], (0, -0.02, 0), "flat_paper", name="glanz")


def twin_coin(k):
    coin(k, (-0.3, 0.1, 0.2), 0.6, "gold", emblem="stern")
    coin(k, (0.3, -0.1, -0.2), 0.6, "gold", emblem="stern")


def empty_frame(k):
    for loc, size in (((0, 0, 0.8), (1.4, 0.16, 0.2)), ((0, 0, -0.8), (1.4, 0.16, 0.2)),
                      ((-0.6, 0, 0), (0.2, 0.16, 1.8)), ((0.6, 0, 0), (0.2, 0.16, 1.8))):
        k.box(loc, size, "gold", bevel=0.03, name="rahmen")
    for x, z in ((-0.6, 0.8), (0.6, 0.8), (-0.6, -0.8), (0.6, -0.8)):
        k.ball((x, -0.05, z), 0.16, "gold2", name="eckknauf")


def oracle_eye(k):
    k.poly([(0, 1.0), (0.95, -0.7), (-0.95, -0.7)], (0, 0.1, 0), "gold", depth=0.1, name="dreieck")
    eyeball(k, (0, -0.05, -0.12), 0.42, iris="indigo")
    for i in range(7):
        a = R(30 + 20 * i)
        k.box((math.cos(a) * 1.1, 0.12, math.sin(a) * 1.1), (0.06, 0.02, 0.3), "gold2", rot=(0, math.pi / 2 - a, 0),
              name="strahl")


def blade_rose(k):
    k.box((0, 0, -0.45), (0.12, 0.06, 1.1), "paper", name="stiel_klinge")
    k.box((0, 0, 0.12), (0.5, 0.1, 0.1), "s2", name="parier")
    for i, (x, z, r) in enumerate(((0, 0.55, 0.3), (-0.25, 0.45, 0.25), (0.25, 0.45, 0.25), (0, 0.75, 0.2))):
        k.ball((x, -0.05 * i, z), r, "blood" if i % 2 == 0 else "blood2", name="bluete")
    k.ball((-0.3, 0, -0.3), (0.22, 0.05, 0.1), "moss", rot=(0, R(30), 0), name="blatt")


def wand_weave(k):
    for i, a in enumerate((-35, 0, 35)):
        k.cyl((0, -0.05 * i, 0), 0.08, 1.9, "s1" if i != 1 else "s2", rot=(0, R(a), 0), name="stab")
        k.ball((math.sin(R(a)) * 0.95, -0.05 * i, math.cos(R(a)) * 0.95), 0.12, "ember", name="glut")
    k.torus((0, -0.1, -0.1), 0.2, 0.05, "blood", rot=FRONT, name="band")


def cup_pearl(k):
    chalice(k, (0, 0, -0.25), 1.1, cup="s1")
    k.ball((0, -0.05, 0.62), 0.28, "paper", name="perle")


def pentacle_chain(k):
    chain_loop(k, (0, 0, 0.9), links=2)
    coin(k, (0, 0, -0.1), 0.72, "gold", emblem="stern")


def fourfold_knot(k):
    for (x, z), mat in zip(((0, 0.42), (0.42, 0), (0, -0.42), (-0.42, 0)), ("blood", "gold", "indigo", "s1")):
        k.torus((x, 0, z), 0.34, 0.09, mat, rot=FRONT, name="schlaufe")


def black_cup(k):
    chalice(k, (0, 0, -0.1), 1.3, cup="ink2", fill="blood")


def brass_wand(k):
    k.cyl((0, 0, 0), 0.1, 1.8, "gold", rot=(0, R(-30), 0), name="stab")
    k.torus((math.sin(R(-30)) * -0.3, 0, -0.52), 0.12, 0.04, "gold2", rot=(0, R(-30), 0),
            name="ring")
    tip = Vector((math.sin(R(-30)) * 0.95, -0.05, math.cos(R(-30)) * 0.95))
    k.ball(tip + Vector((0, 0, 0.15)), (0.18, 0.12, 0.3), "flame", taper=-0.4, name="flamme")
    k.ball(tip + Vector((0, -0.05, 0.1)), (0.09, 0.06, 0.14), "ember", name="flammkern")


def silver_blade(k):
    k.box((0, 0, 0.2), (0.3, 0.06, 1.3), "s1", rot=(0, R(-35), 0), name="klinge")
    k.poly([(-0.15, 0), (0.15, 0), (0, 0.35)], (math.sin(R(-35)) * 0.85, -0.03, 0.2 + math.cos(R(-35)) * 0.85),
           "s1", rot=(0, R(-35), 0), depth=0.06, name="spitze")
    k.box((math.sin(R(-35)) * -0.5, 0, 0.2 - math.cos(R(-35)) * 0.5), (0.6, 0.1, 0.1), "s3", rot=(0, R(-35), 0),
          name="parier")
    k.cyl((math.sin(R(-35)) * -0.75, 0, 0.2 - math.cos(R(-35)) * 0.75), 0.07, 0.4, "ink2", rot=(0, R(-35), 0),
          name="griff")


def gold_pentacle(k):
    coin(k, r=0.9, mat="gold", emblem="stern")


def blue_ribbon(k):
    k.ball((-0.45, 0, 0.2), (0.45, 0.12, 0.3), "indigo", rot=(0, R(-15), 0), name="schlaufe_l")
    k.ball((0.45, 0, 0.2), (0.45, 0.12, 0.3), "indigo", rot=(0, R(15), 0), name="schlaufe_r")
    k.ball((0, -0.08, 0.2), 0.16, "indigo2", name="knoten")
    k.poly([(-0.05, 0), (0.1, 0), (-0.25, -0.9), (-0.4, -0.75)], (0, 0, 0.1), "indigo", depth=0.05, name="band_l")
    k.poly([(0.05, 0), (-0.1, 0), (0.25, -0.9), (0.4, -0.75)], (0, 0, 0.1), "indigo", depth=0.05, name="band_r")


def lucky_clover(k):
    for a in (45, 135, 225, 315):
        x, z = math.cos(R(a)) * 0.38, math.sin(R(a)) * 0.38 + 0.15
        k.ball((x - 0.12 * math.cos(R(a + 90)), 0, z - 0.12 * math.sin(R(a + 90))), 0.24, "moss", name="blatt")
        k.ball((x + 0.12 * math.cos(R(a + 90)), 0, z + 0.12 * math.sin(R(a + 90))), 0.24, "moss", name="blatt")
    k.hose([(0, 0, 0.1), (0.1, -0.02, -0.4), (0.3, 0, -0.85)], 0.05, "moss")
    k.ball((0, -0.2, 0.15), 0.1, "gold", name="schelle")


def merchant_eye(k):
    eyeball(k, (0, 0, 0), 0.85, pupil="flat_gold")
    k.ball((0, -0.1, 0.72), (0.9, 0.2, 0.12), "s3", name="lid")


def bent_coin(k):
    half = [(0.85 * math.cos(a), 0.85 * math.sin(a)) for a in [math.pi / 2 + i * math.pi / 16 for i in range(17)]]
    k.poly(half, (0, 0, 0), "gold", rot=(0, 0, R(-22)), depth=0.14, name="haelfte_l")
    k.poly([(-x, z) for x, z in half][::-1], (0, 0, 0), "gold", rot=(0, 0, R(22)), depth=0.14, name="haelfte_r")
    k.face_surface("links", (-0.4, -0.2, 0), (0.45, 0.001, 0.8))
    k.decal("links", star(0.28), (0, 0), "gold_d_flat", lift=0.01, name="stern")


def cat_fang(k):
    k.hose([(-0.5, 0, 0.9), (0, -0.05, 0.6), (0.5, 0, 0.9)], 0.04, "s3")
    k.cyl((0.05, 0, -0.1), 0.24, 1.0, "paper", r2=0.0, rot=(0, R(180 + 18), 0), name="zahn")
    k.ball((0, 0, 0.45), (0.26, 0.16, 0.12), "paper", name="wurzel")


def luck_bell(k):
    bell(k, "gold2", bow="blood")


def greed_moth(k):
    for s in (-1, 1):
        k.ball((s * 0.5, 0.05, 0.25), (0.5, 0.06, 0.45), "s1", rot=(0, R(25) * s, 0), name="fluegel_o")
        k.ball((s * 0.42, 0.05, -0.35), (0.34, 0.06, 0.3), "s2", rot=(0, R(-20) * s, 0), name="fluegel_u")
        k.cyl((s * 0.5, -0.02, 0.28), 0.14, 0.04, "gold", rot=FRONT, name="muenzfleck")
        k.hose([(s * 0.05, 0, 0.6), (s * 0.2, -0.02, 0.9), (s * 0.35, 0, 0.95)], 0.02, "ink2")
    k.ball((0, -0.05, 0.05), (0.16, 0.14, 0.6), "ink2", name="leib")


def gold_die(k):
    k.box((0, 0, 0), (1.1, 1.1, 1.1), "gold", rot=(0, 0, R(12)), bevel=0.05, name="wuerfel")
    k.face_surface("vorn", (0.02, -0.66, 0), (0.6, 0.001, 0.6))
    for x, z in ((-0.26, 0.26), (0.0, 0.0), (0.26, -0.26)):
        k.decal("vorn", circle(0.1, n=10), (x, z), "ink", lift=0.01, name="auge")
    k.face_surface("oben", (0.0, 0.0, 0.56), (0.6, 0.001, 0.6))


def star_dust(k):
    k.ball((0, 0, -0.25), 0.62, "indigo2", name="flasche")
    k.cyl((0, 0, 0.45), 0.2, 0.35, "indigo2", name="hals")
    k.cyl((0, 0, 0.72), 0.22, 0.22, "s2", name="korken")
    k.face_surface("flasche", (0, 0, -0.25), (0.62, 0.62, 0.62))
    for x, z, r in ((-0.2, -0.1, 0.16), (0.2, -0.35, 0.12), (0.0, -0.55, 0.1), (0.25, 0.05, 0.08)):
        k.decal("flasche", star(r), (x, z), "flat_gold", lift=0.01, name="stern")


def broken_crown(k):
    k.crown((0, 0, -0.35), 1.6, spikes=5, broken=True)


def world_thread(k):
    k.ball((0, 0, 0), 0.6, "indigo", name="welt")
    k.face_surface("welt", (0, 0, 0), (0.6, 0.6, 0.6))
    k.decal("welt", circle(0.2, sx=1.3), (-0.15, 0.15), "moss", lift=0.008, name="kontinent")
    k.decal("welt", circle(0.14), (0.2, -0.2), "moss", lift=0.008, name="kontinent")
    k.torus((0, 0, 0), 0.8, 0.04, "gold2", rot=(R(70), R(25), 0), name="faden")
    k.torus((0, 0, 0), 0.8, 0.04, "gold2", rot=(R(110), R(-35), 0), name="faden")


# Reihenfolge wie in GameCatalog.Charms
CHARMS = [
    ("blade_pendant", blade_pendant), ("ember_knot", ember_knot), ("blood_moon", blood_moon),
    ("predator_fang", predator_fang), ("hunt_bell", hunt_bell), ("black_nail", black_nail),
    ("falcon_eye", falcon_eye), ("ash_wreath", ash_wreath), ("thorn_ring", thorn_ring),
    ("hangman_chain", hangman_chain), ("iron_coin", iron_coin), ("cup_rim", cup_rim),
    ("white_thread", white_thread), ("salt_seal", salt_seal), ("bone_pearl", bone_pearl),
    ("moon_brooch", moon_brooch), ("emperor_seal", emperor_seal), ("saint_needle", saint_needle),
    ("phoenix_feather", phoenix_feather), ("glass_heart", glass_heart), ("silver_mirror", silver_mirror),
    ("razor_charm", razor_charm), ("blank_card", blank_card), ("thread_spool", thread_spool),
    ("wax_seal", wax_seal), ("crow_feather", crow_feather), ("memory_shard", memory_shard),
    ("twin_coin", twin_coin), ("empty_frame", empty_frame), ("oracle_eye", oracle_eye),
    ("blade_rose", blade_rose), ("wand_weave", wand_weave), ("cup_pearl", cup_pearl),
    ("pentacle_chain", pentacle_chain), ("fourfold_knot", fourfold_knot), ("black_cup", black_cup),
    ("brass_wand", brass_wand), ("silver_blade", silver_blade), ("gold_pentacle", gold_pentacle),
    ("blue_ribbon", blue_ribbon), ("lucky_clover", lucky_clover), ("merchant_eye", merchant_eye),
    ("bent_coin", bent_coin), ("cat_fang", cat_fang), ("luck_bell", luck_bell),
    ("greed_moth", greed_moth), ("gold_die", gold_die), ("star_dust", star_dust),
    ("broken_crown", broken_crown), ("world_thread", world_thread),
]

SIZE = 32
OUTLINE = 1
