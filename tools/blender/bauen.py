"""Baut alle Blockouts headless.

    blender -b --factory-startup --python tools/blender/bauen.py -- [figuren] [charms] [--nur id1,id2]

Schreibt nach assets/blockout/:
    figuren/<id>.png       Sprite in Originalgroesse (Pixel 1:1)
    figuren/x4/<id>.png    vierfach vergroessert, ohne Glaettung
    charms/...             dasselbe fuer die Charms (32 x 32)
    kontaktbogen_*.png     Uebersicht mit Namen
    figuren.blend, charms.blend
"""

import math
import os
import sys
import tempfile

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import kit as kitmod  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "blockout")


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    if "--nur" in argv:
        only = set(argv[argv.index("--nur") + 1].split(","))
    parts = [a for a in argv if a in ("figuren", "charms")] or ["figuren", "charms"]
    return parts, only


def build(kind, only):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    tmp = tempfile.mkdtemp(prefix="tartot_")
    cam = kitmod.setup_scene(tmp)
    k = kitmod.Kit()
    if kind == "figuren":
        import figuren as mod
        entries = [(i, mod.SIZE[t], b) for i, t, b in mod.FIGUREN]
        spacing = 5.0
        outline = 2
    else:
        import charms as mod
        entries = [(i, mod.SIZE, b) for i, b in mod.CHARMS]
        spacing = 3.0
        outline = mod.OUTLINE
        cam.rotation_euler.x = math.radians(80)
    if only:
        entries = [e for e in entries if e[0] in only]
    done = []
    per_row = 8
    for n, (ident, size, builder) in enumerate(entries):
        offset = ((n % per_row) * spacing, 0, -(n // per_row) * spacing * 1.2)
        coll = k.begin(ident, offset)
        builder(k)
        png = os.path.join(OUT, kind, ident + ".png")
        kitmod.render_sprite(k, cam, coll, size, tmp, png, outline=outline)
        kitmod.upscale(png, os.path.join(OUT, kind, "x4", ident + ".png"))
        done.append(ident)
        print("TARTOT gerendert:", kind, ident, size)
    for c in bpy.context.scene.collection.children:
        c.hide_render = False
    if not only:
        bpy.context.preferences.filepaths.save_version = 0
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT, kind + ".blend"), compress=True)
    return done


def main():
    parts, only = args()
    for kind in parts:
        build(kind, only)
        import kontakt
        print("TARTOT Kontaktbogen:", kontakt.run(kind))


main()
