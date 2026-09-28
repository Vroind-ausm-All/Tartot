"""Animationen der Blockout-Figuren: 12 fps, "on twos", Squash & Stretch.

    blender -b --factory-startup --python tools/blender/anim.py [-- --nur id1,id2]

Jede Figur bekommt einen Drehpunkt an den Fuessen; alle Teile haengen daran.
Die Zustaende bewegen diesen Drehpunkt (Wippen, Ausholen, Zuschlagen,
Zusammensacken) und lassen Effektteile erscheinen: Tropfen, Ringe,
Strahlen, Akolythen, Sonnen - je nach Boss so, wie es sein Blatt zeigt.

Ergebnis:
    assets/blockout/anim/<id>/<zustand>.png   Streifen, ein Bild neben dem anderen
    assets/blockout/anim/<id>/<zustand>.gif   Vorschau x3
    unity/Assets/Resources/Tartot/Anim/<id>_<zustand>.png + anim.json (Manifest)
"""

import json
import math
import os
import shutil
import sys
import tempfile

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import figuren  # noqa: E402
import kit as kitmod  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "blockout", "anim")
UNITY = os.path.join(ROOT, "unity", "Assets", "Resources", "Tartot", "Anim")
FPS = 12
R = math.radians

# ------------------------------------------------------------------ Effekte
# Jeder Effekt ist eine Funktion (k, t, fx, box) -> baut Teile fuer Zeitpunkt t (0..1).


def _burst(k, t, mat, box, n=8, shape="ball", size=0.12, spread=1.0, up=0.0):
    c = (box[0] + box[1]) / 2
    r = (box[1] - box[0]).length * 0.35 * spread * (0.3 + t)
    for i in range(n):
        a = 2 * math.pi * i / n + t * 0.6
        p = c + Vector((math.cos(a) * r, -0.8, math.sin(a) * r * 0.7 + up * t))
        s = size * (1.2 - 0.6 * t)
        if shape == "cube":
            k.box(p - k.offset, (s * 1.6, s * 1.6, s * 1.6), mat, rot=(a, a, 0), name="fx")
        elif shape == "ring":
            k.torus(p - k.offset, s * 1.2, s * 0.3, mat, rot=(R(90), 0, 0), name="fx")
        else:
            k.ball(p - k.offset, s, mat, name="fx")


def _columns(k, t, mat, box, n=3):
    lo, hi = box
    h = (hi.z - lo.z) * min(1, t * 1.6)
    w = hi.x - lo.x
    for i in range(n):
        # neben der Figur, nicht davor: links und rechts abwechselnd
        side = -1 if i % 2 == 0 else 1
        x = (lo.x - 0.18 * w - 0.15 * w * (i // 2)) if side < 0 else (hi.x + 0.18 * w + 0.15 * w * (i // 2))
        k.cyl((x - k.offset.x, 0.3, lo.z - k.offset.z + h / 2), 0.12, max(0.02, h), mat, name="fx")


def _minions(k, t, mat, box, face="paper", n=3):
    lo, hi = box
    rise = min(1, t * 1.5)
    for i in range(n):
        x = lo.x - 0.3 + (hi.x - lo.x + 0.6) * i / max(1, n - 1)
        z = lo.z + 0.25 * rise
        base = Vector((x, -0.9, z)) - k.offset
        k.cyl(base, 0.16 * rise + 0.01, 0.5 * rise + 0.01, mat, r2=0.03, name="fx")
        k.ball(base + Vector((0, -0.1, 0.12 * rise)), 0.08 * rise + 0.01, face, name="fx")


def _orbit(k, t, mat, box, n=5):
    c = (box[0] + box[1]) / 2
    r = (box[1] - box[0]).length * 0.4
    for i in range(n):
        a = 2 * math.pi * (i / n + t * 0.5)
        k.ball(Vector((c.x + math.cos(a) * r, -0.9, c.z + math.sin(a) * r * 0.8)) - k.offset, 0.14, mat, name="fx")


def _chain(k, t, mat, box):
    lo, hi = box
    reach = t * 1.8
    for i in range(int(8 * t) + 1):
        x = hi.x + 0.2 + reach * i / 8
        rot = (R(90), 0, 0) if i % 2 == 0 else (0, 0, R(90))
        k.torus(Vector((x, -0.9, (lo.z + hi.z) / 2)) - k.offset, 0.1, 0.03, mat, rot=rot, name="fx")


FX = {
    "tropfen_wasser": lambda k, t, b: _burst(k, t, "indigo2", b, 10),
    "tropfen_feuer": lambda k, t, b: _burst(k, t, "ember", b, 10),
    "mischen": lambda k, t, b: (_burst(k, t, "indigo2", b, 6), _orbit(k, t, "ember", b, 6)),
    "quellen": lambda k, t, b: (_columns(k, t, "indigo2", b, 2), _columns(k, t * 0.8, "ember", b, 1)),
    "segen": lambda k, t, b: _burst(k, t, "gold", b, 6, shape="ring", size=0.2),
    "akolythen": lambda k, t, b: _minions(k, t, "paper", b, face="ink2", n=4),
    "strahl": lambda k, t, b: _columns(k, t, "gold2", b, 3),
    "wuerfel": lambda k, t, b: _burst(k, t, "paper", b, 6, shape="cube", size=0.14),
    "kette": lambda k, t, b: _chain(k, t, "s2", b),
    "diener": lambda k, t, b: _minions(k, t, "blood", b, face="paper", n=3),
    "spiegel": lambda k, t, b: _burst(k, t, "indigo2", b, 6, shape="ring", size=0.22),
    "projektile": lambda k, t, b: _burst(k, t, "paper", b, 8, size=0.16, spread=1.4),
    "illusion": lambda k, t, b: _minions(k, t, "ink2", b, face="paper", n=4),
    "schatten": lambda k, t, b: _minions(k, t, "ink", b, face="paper", n=3),
    "strahlen": lambda k, t, b: _columns(k, t, "gold2", b, 4),
    "rotation": lambda k, t, b: _orbit(k, t, "gold", b, 6),
    "sonnen": lambda k, t, b: _orbit(k, t, "gold2", b, 4),
    "supernova": lambda k, t, b: _burst(k, t, "gold2", b, 14, size=0.2, spread=1.8),
    "stoss": lambda k, t, b: _burst(k, t, "s1", b, 6, size=0.1, spread=0.8),
    "blitz": lambda k, t, b: _columns(k, t, "flame", b, 2),
    "konfetti": lambda k, t, b: _burst(k, t, "gold", b, 12, size=0.07, spread=1.6, up=0.6),
}

# Zustaende je Boss wie auf den Blaettern. Alle anderen: idle, attack, hit, death.
SHEETS = {
    "boss_maessigkeit": [("attack1", 6, "tropfen_wasser"), ("attack2", 6, "tropfen_feuer"),
                         ("attack3", 6, "mischen"), ("summon", 6, "quellen")],
    "boss_hierophant": [("attack1", 6, "segen"), ("attack2", 6, "akolythen"), ("attack3", 6, "strahl")],
    "boss_teufel": [("attack1", 6, "wuerfel"), ("attack2", 6, "kette"), ("summon", 6, "diener")],
    "boss_mond": [("attack1", 6, "spiegel"), ("attack2", 6, "projektile"), ("attack3", 6, "illusion"),
                  ("summon", 6, "schatten")],
    "boss_sonne": [("attack1", 6, "strahlen"), ("attack2", 6, "rotation"), ("summon", 6, "sonnen"),
                   ("supernova", 8, "supernova")],
    "boss_turm": [("attack1", 6, "blitz")],
}
BASE = [("idle", 4, None), ("attack", 6, "stoss"), ("hit", 3, None), ("phase2", 8, None), ("death", 8, "konfetti")]


def states_for(ident, tier):
    states = [s for s in BASE if s[0] != "phase2" or tier in ("boss", "finale")]
    return states + SHEETS.get(ident, [])


def pose(state, i, n):
    """(Versatz x/z, Neigung, Skala x/z) fuer Bild i von n."""
    t = i / max(1, n - 1)
    if state == "idle":
        s = [0, 1, 0, -1][i % 4]
        return 0, 0.03 * s, 0, 1 - 0.03 * s, 1 + 0.04 * s
    if state == "hit":
        return [(-0.12, 0, R(-8), 1.15, 0.8), (-0.06, 0, R(-4), 1.05, 0.93), (0, 0, 0, 1, 1)][i]
    if state == "death":
        return 0, 0, R(6) * t, 1 + 0.35 * t, max(0.1, 1 - 0.9 * t)
    if state == "phase2":
        j = 0.06 * (1 if i % 2 else -1) * (1 - t)
        return j, 0, j, 1 + 0.08 * math.sin(t * math.pi), 1 + 0.12 * math.sin(t * math.pi)
    if state in ("summon",):
        return 0, 0.15 * math.sin(t * math.pi), 0, 1 - 0.05 * math.sin(t * math.pi), 1 + 0.1 * math.sin(t * math.pi)
    # Angriffe: ausholen, zuschlagen, zurueck
    curve = [(-0.06, R(-10), 1.05, 0.9), (-0.1, R(-14), 1.08, 0.85), (0.12, R(12), 0.9, 1.15),
             (0.16, R(10), 0.92, 1.1), (0.06, R(4), 0.98, 1.03), (0, 0, 1, 1), (0, 0, 1, 1), (0, 0, 1, 1)]
    dx, rot, sx, sz = curve[min(i, len(curve) - 1)]
    return dx, 0, rot, sx, sz


def rig(k, coll):
    lo, hi = kitmod.bounds(coll)
    piv = bpy.data.objects.new("drehpunkt", None)
    coll.objects.link(piv)
    piv.location = Vector(((lo.x + hi.x) / 2, 0, lo.z))
    bpy.context.view_layer.update()
    for obj in list(coll.objects):
        if obj is piv or obj.parent is not None:
            continue
        mw = obj.matrix_world.copy()
        obj.parent = piv
        obj.matrix_parent_inverse = piv.matrix_world.inverted()
        obj.matrix_world = mw
    return piv, (lo, hi)


def tint(img, state, i, n):
    """Treffer blitzt weiss, Phase 2 blutet rot ein."""
    rgb, a = img[..., :3], img[..., 3] > 0
    ink = np.array(kitmod.srgb(kitmod.PAL["ink"]), dtype=np.float32)
    notink = a & (np.abs(rgb - ink).sum(-1) > 0.05)
    if state == "hit" and i == 0:
        rgb[notink] = kitmod.srgb(kitmod.PAL["paper"])
    if state == "phase2" and i % 2 == 0:
        light = rgb.mean(-1) > 0.55
        rgb[notink & light] = kitmod.srgb(kitmod.PAL["ember"])
        rgb[notink & ~light] = kitmod.srgb(kitmod.PAL["blood2"])
    return img


def render_state(k, cam, coll, piv, box, rest, size, tmp, state, n, fx):
    frames = []
    for i in range(n):
        dx, dz, rot, sx, sz = pose(state, i, n)
        piv.location = rest + Vector((dx, 0, dz))
        piv.rotation_euler = (0, rot, 0)
        piv.scale = (sx, 1, sz)
        made = []
        if fx and state != "idle":
            before = set(coll.objects)
            t = i / max(1, n - 1)
            if state.startswith("attack") or state == "supernova":
                t = max(0.0, (i - 1) / max(1, n - 2))
            if t > 0 or state in ("summon",):
                FX[fx](k, t, box)
            made = [o for o in coll.objects if o not in before]
        img = kitmod.render_fixed(k, cam, coll, size, tmp)
        frames.append(tint(img, state, i, n))
        for o in made:
            bpy.data.objects.remove(o, do_unlink=True)
    piv.location, piv.rotation_euler, piv.scale = rest, (0, 0, 0), (1, 1, 1)
    return frames


def save_strip(frames, path):
    from PIL import Image
    h, w = frames[0].shape[:2]
    strip = np.concatenate(frames, axis=1)
    kitmod.save_png(strip, path)
    ims = [Image.fromarray((np.clip(f, 0, 1) * 255).astype(np.uint8), "RGBA").resize((w * 3, h * 3), Image.NEAREST)
           for f in frames]
    bg = [Image.new("RGBA", im.size, (143, 122, 90, 255)) for im in ims]
    for b, im in zip(bg, ims):
        b.alpha_composite(im)
    gif = path[:-4] + ".gif"
    bg[0].convert("P", palette=Image.ADAPTIVE).save(
        gif, save_all=True, append_images=[b.convert("P", palette=Image.ADAPTIVE) for b in bg[1:]],
        duration=int(1000 / FPS * 2), loop=0, disposal=2)
    return w


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(argv[argv.index("--nur") + 1].split(",")) if "--nur" in argv else None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tmp = tempfile.mkdtemp(prefix="tartot_anim_")
    cam = kitmod.setup_scene(tmp)
    k = kitmod.Kit()
    os.makedirs(UNITY, exist_ok=True)
    manifest_path = os.path.join(UNITY, "anim.json")
    manifest = json.load(open(manifest_path)) if only and os.path.exists(manifest_path) else {}
    for n, (ident, tier, builder) in enumerate(figuren.FIGUREN):
        if only and ident not in only:
            continue
        coll = k.begin(ident, (n * 8.0, 0, 0))
        builder(k)
        size = int(figuren.SIZE[tier] * 1.25) // 4 * 4
        piv, box = rig(k, coll)
        lo, hi = box
        kitmod.frame_box(cam, lo, hi, size, pad=1.45)
        entry = {"size": size, "fps": FPS, "states": {}}
        for state, count, fx in states_for(ident, tier):
            frames = render_state(k, cam, coll, piv, box, piv.location.copy(), size, tmp, state, count, fx)
            path = os.path.join(OUT, ident, state + ".png")
            save_strip(frames, path)
            shutil.copy(path, os.path.join(UNITY, "%s_%s.png" % (ident, state)))
            entry["states"][state] = count
        manifest[ident] = entry
        coll.hide_render = True
        print("TARTOT animiert:", ident, ", ".join(entry["states"]))
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=1, sort_keys=True)


main()
