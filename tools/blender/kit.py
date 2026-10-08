"""Teilebaukasten fuer TARTOT-Blockouts in Blender 4.x (headless).

Stilbibel "Schicksal auf Zelluloid" als Technik:
- Toon-Material mit hoechstens zwei Tonstufen, Licht von links oben vorn.
  Es ist ein reiner Emissionsshader - kein Rauschen, keine Lichtberechnung.
- Cycles mit 1 Sample und Kastenfilter 0,01: jedes Pixel trifft genau eine
  Flaeche, es entsteht Pixelgrafik ohne Kantenglaettung.
- Konturen entstehen erst in der Nachbearbeitung: 2 px Tinte aussen um die
  Silhouette, 1 px innen dort, wo zwei Teile aneinanderstossen. Die Linie
  liegt immer auf dem hinteren Teil, damit Augen und Zaehne frei bleiben.
- Teile: Kuchenaugen, Grinsen mit zu vielen Zaehnen, weisse
  Vier-Finger-Handschuhe, Gummischlauch-Glieder ohne Gelenke, Hueten.

Die Ergebnisse sind Blockouts: Proportionen, Silhouette, Farbverteilung.
Ein Artist zeichnet darauf die endgueltigen Sprites.
"""

import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

# ------------------------------------------------------------------ Palette
# Grundlage ist vergilbter Schwarz-Weiss-Film. Farbe ist Belohnung oder
# Warnung - volle Farbe tragen nur die Bosse.
PAL = {
    "ink": "#1A1412", "ink2": "#2B221C", "paper": "#EFE3C8", "s1": "#C9B48E",
    "s2": "#8F7A5A", "s3": "#4E4032", "gold": "#E3A83B", "gold_d": "#A0701F",
    "gold2": "#F4D27A", "blood": "#B3262B", "blood2": "#7E1B1F", "ember": "#E0543A",
    "indigo": "#3B4A8C", "indigo_d": "#28335F", "indigo2": "#7F8FD0",
    "moss": "#6E7A3E", "moss_d": "#454D26", "mouth": "#4A1014",
}

# Material: (Grundton, Schattenton). Gleiche Farbe = flach.
TONES = {
    "paper": ("paper", "s1"),
    "glove": ("paper", "s1"),
    "s1": ("s1", "s2"),
    "s2": ("s2", "s3"),
    "s3": ("s3", "ink2"),
    "ink": ("ink", "ink"),
    "ink2": ("ink2", "ink"),
    "gold": ("gold", "gold_d"),
    "gold2": ("gold2", "gold"),
    "blood": ("blood", "blood2"),
    "blood2": ("blood2", "mouth"),
    "ember": ("ember", "blood"),
    "indigo": ("indigo", "indigo_d"),
    "indigo2": ("indigo2", "indigo"),
    "moss": ("moss", "moss_d"),
    # flache Toene fuer Gesichter: Pupillen, Mundhoehle, Zaehne, Zunge
    "pupil": ("ink", "ink"),
    "mouth": ("mouth", "mouth"),
    "teeth": ("paper", "paper"),
    "tongue": ("blood", "blood"),
    "flame": ("gold2", "gold2"),
    "crack": ("ember", "ember"),
    "flat_paper": ("paper", "paper"),
    "flat_gold": ("gold", "gold"),
    "flat_blood": ("blood", "blood"),
    "flat_indigo2": ("indigo2", "indigo2"),
    "gold_d_flat": ("gold_d", "gold_d"),
}

# Materialien, auf denen keine Innenlinie gezeichnet wird (sie sind selbst
# schon Tinte oder sollen weich im Nachbarn aufgehen).
NO_LINE = {"pupil", "ink", "mouth", "crack", "flame"}

LIGHT = Vector((-0.45, -0.75, 0.55)).normalized()


def srgb(hexcode):
    h = hexcode.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


# ------------------------------------------------------------------ Szene
class Kit:
    """Haelt Materialien, Objektzaehler und die aktuelle Figur."""

    def __init__(self):
        self.mats = {}
        self.next_index = 1
        self.collection = None
        self.faces = {}

    # ---------------------------------------------------------- Materialien
    def mat(self, name):
        if name in self.mats:
            return self.mats[name]
        base, shade = TONES[name]
        m = bpy.data.materials.new("T_" + name)
        m.use_nodes = True
        m.pass_index = len(self.mats) + 1
        nt = m.node_tree
        nt.nodes.clear()
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        dot = nt.nodes.new("ShaderNodeVectorMath")
        dot.operation = "DOT_PRODUCT"
        dot.inputs[1].default_value = LIGHT
        fac = nt.nodes.new("ShaderNodeMath")
        fac.operation = "MULTIPLY_ADD"
        fac.inputs[1].default_value = 0.5
        fac.inputs[2].default_value = 0.5
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.interpolation = "CONSTANT"
        e0, e1 = ramp.color_ramp.elements
        e0.position, e1.position = 0.0, 0.52
        e0.color = (*lin(srgb(PAL[shade])), 1)
        e1.color = (*lin(srgb(PAL[base])), 1)
        emit = nt.nodes.new("ShaderNodeEmission")
        emit.inputs["Strength"].default_value = 1.0
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(geo.outputs["Normal"], dot.inputs[0])
        nt.links.new(dot.outputs["Value"], fac.inputs[0])
        nt.links.new(fac.outputs["Value"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], emit.inputs["Color"])
        nt.links.new(emit.outputs["Emission"], out.inputs["Surface"])
        m.diffuse_color = (*lin(srgb(PAL[base])), 1)
        m["tartot_tone"] = name
        self.mats[name] = m
        return m

    def palette(self):
        names = set()
        for tone in self.mats:
            names.update(TONES[tone])
        names.add("ink")
        return np.array([srgb(PAL[n]) for n in sorted(names)], dtype=np.float32)

    # ---------------------------------------------------------- Figuren
    def begin(self, name, offset=(0, 0, 0)):
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
        self.collection = coll
        self.offset = Vector(offset)
        self.faces = {}
        return coll

    def _link(self, obj, material, group=None):
        self.collection.objects.link(obj)
        if material:
            m = self.mat(material)
            if obj.data is not None and hasattr(obj.data, "materials"):
                obj.data.materials.clear()
                obj.data.materials.append(m)
        if group is None:
            obj.pass_index = self.next_index
            self.next_index += 1
        else:
            key = (self.collection.name, group)
            if key not in self.faces:
                self.faces[key] = self.next_index
                self.next_index += 1
            obj.pass_index = self.faces[key]
        return obj

    def _mesh_obj(self, name, bm, material, group=None, smooth=True):
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        if smooth:
            for p in me.polygons:
                p.use_smooth = True
        obj = bpy.data.objects.new(name, me)
        return self._link(obj, material, group)

    def P(self, v):
        return Vector(v) + self.offset

    # ---------------------------------------------------------- Grundformen
    def ball(self, loc, size, material, rot=(0, 0, 0), group=None, seg=32, taper=0.0, name="ball"):
        """Ellipsoid. taper > 0 macht eine Birne: unten breiter als oben."""
        if isinstance(size, (int, float)):
            size = (size, size, size)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=seg // 2, radius=1.0)
        for v in bm.verts:
            k = 1.0 + taper * (-v.co.z)
            v.co.x *= size[0] * k
            v.co.y *= size[1] * k
            v.co.z *= size[2]
        obj = self._mesh_obj(name, bm, material, group)
        obj.location = self.P(loc)
        obj.rotation_euler = rot
        return obj

    def cyl(self, loc, r, depth, material, rot=(0, 0, 0), r2=None, group=None, seg=32, name="cyl", smooth=True):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=depth)
        obj = self._mesh_obj(name, bm, material, group, smooth=smooth)
        if smooth and hasattr(obj.data, "use_auto_smooth"):
            obj.data.use_auto_smooth = True
            obj.data.auto_smooth_angle = math.radians(40)
        obj.location = self.P(loc)
        obj.rotation_euler = rot
        return obj

    def box(self, loc, size, material, rot=(0, 0, 0), group=None, bevel=0.0, name="box"):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co.x *= size[0]
            v.co.y *= size[1]
            v.co.z *= size[2]
        obj = self._mesh_obj(name, bm, material, group, smooth=False)
        obj.location = self.P(loc)
        obj.rotation_euler = rot
        if bevel:
            mod = obj.modifiers.new("bevel", "BEVEL")
            mod.width = bevel
            mod.segments = 3
        return obj

    def torus(self, loc, R, r, material, rot=(0, 0, 0), group=None, name="torus", arc=2 * math.pi, seg=40):
        bm = bmesh.new()
        ring = []
        steps = seg if arc >= 2 * math.pi - 1e-3 else seg + 1
        for i in range(steps):
            a = arc * i / seg
            c = Vector((R * math.cos(a), R * math.sin(a), 0))
            n = Vector((math.cos(a), math.sin(a), 0))
            loop = []
            for j in range(12):
                b = 2 * math.pi * j / 12
                loop.append(bm.verts.new(c + n * (r * math.cos(b)) + Vector((0, 0, r * math.sin(b)))))
            ring.append(loop)
        closed = arc >= 2 * math.pi - 1e-3
        for i in range(len(ring) - (0 if closed else 1)):
            a, b = ring[i], ring[(i + 1) % len(ring)]
            for j in range(12):
                bm.faces.new((a[j], a[(j + 1) % 12], b[(j + 1) % 12], b[j]))
        if not closed:
            bm.faces.new(ring[0][::-1])
            bm.faces.new(ring[-1])
        bm.normal_update()
        obj = self._mesh_obj(name, bm, material, group)
        obj.location = self.P(loc)
        obj.rotation_euler = rot
        return obj

    def hose(self, points, r, material, group=None, name="hose", taper=None):
        """Gummischlauch: Bezierkurve mit runder Dicke, ohne Gelenk."""
        cu = bpy.data.curves.new(name, "CURVE")
        cu.dimensions = "3D"
        cu.bevel_depth = r
        cu.bevel_resolution = 4
        cu.use_fill_caps = True
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(points) - 1)
        for bp, p in zip(sp.bezier_points, points):
            bp.co = self.P(p)
            bp.handle_left_type = bp.handle_right_type = "AUTO"
        if taper:
            for bp, t in zip(sp.bezier_points, taper):
                bp.radius = t
        obj = bpy.data.objects.new(name, cu)
        if group is None:
            group = "schlauch%d" % self.next_index
        self._link(obj, material, group)
        # runde Enden, gleiche Kennung wie der Schlauch: keine Linie dazwischen
        for p, t in ((points[0], taper[0] if taper else 1), (points[-1], taper[-1] if taper else 1)):
            self.ball(p, r * t, material, group=group, seg=16, name=name + "_ende")
        return obj

    def poly(self, pts2d, loc, material, rot=(0, 0, 0), depth=0.0, group=None, name="poly"):
        """Flache Form in der XZ-Ebene (zur Kamera), optional mit Tiefe."""
        bm = bmesh.new()
        vs = [bm.verts.new((x, 0, z)) for x, z in pts2d]
        bm.faces.new(vs)
        if depth:
            ext = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
            for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
                v.co.y += depth
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        obj = self._mesh_obj(name, bm, material, group, smooth=False)
        obj.location = self.P(loc)
        obj.rotation_euler = rot
        return obj

    # ---------------------------------------------------------- Flaechen
    def face_surface(self, key, center, radii):
        """Merkt sich ein Ellipsoid, auf dessen Vorderseite Gesichter sitzen."""
        self.faces[("surf", key)] = (self.P(center), Vector(radii))

    def front(self, key, dx, dz, lift=0.0):
        """Punkt auf der Vorderseite (-Y) einer gemerkten Flaeche."""
        c, r = self.faces[("surf", key)]
        u = min(0.999, (dx / r.x) ** 2 + (dz / r.z) ** 2)
        y = c.y - r.y * math.sqrt(1 - u) - lift
        return Vector((c.x + dx, y, c.z + dz))

    def decal(self, key, pts2d, anchor, material, lift=0.01, group=None, name="decal"):
        """Flache Form, auf die Flaeche projiziert (Mund, Pupille, Riss)."""
        bm = bmesh.new()
        vs = []
        for x, z in pts2d:
            p = self.front(key, anchor[0] + x, anchor[1] + z, lift)
            vs.append(bm.verts.new(p - self.offset))
        bm.faces.new(vs)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        obj = self._mesh_obj(name, bm, material, group, smooth=False)
        obj.location = self.offset
        return obj

    # ---------------------------------------------------------- Gesicht
    def eye(self, key, dx, dz, size, look=(0.0, 0.0), pie=True, lid=0.0, white="paper", name="eye", angry=0.0,
            lid_mat="ink", pupil="pupil"):
        """Kuchenauge: weisses Oval, schwarze Pupille mit Tortenstueck-Kerbe."""
        w, h = size * 0.62, size
        base = self.front(key, dx, dz, 0.0)
        c = base + Vector((0, 0.35 * w, 0))
        self.ball(c - self.offset, (w, w * 0.55, h), white, name=name + "_weiss")
        # Pupille auf die Vorderseite des Augapfels
        eye_key = name + str(self.next_index)
        self.face_surface(eye_key, c - self.offset, (w, w * 0.55, h))
        pr = w * 0.62
        px, pz = look[0] * w * 0.35, -h * 0.18 + look[1] * h * 0.3
        pts = []
        cut = math.radians(55) if pie else 0
        start = math.radians(20)
        if pie:
            pts.append((px, pz))
        steps = 18
        for i in range(steps + 1):
            a = start + cut + (2 * math.pi - cut) * i / steps
            pts.append((px + pr * 0.8 * math.cos(a), pz + pr * 1.25 * math.sin(a)))
        if not pie:
            pts = pts[:-1]
        self.decal(eye_key, pts, (0, 0), pupil, lift=0.004, name=name + "_pupille")
        if lid > 0:
            pts = [(-w * 1.1, h * (1 - 2 * lid)), (w * 1.1, h * (1 - 2 * lid)), (w * 1.1, h * 1.3), (-w * 1.1, h * 1.3)]
            self.decal(eye_key, pts, (0, 0), lid_mat, lift=0.006, name=name + "_lid")
        if angry:
            self.brow(key, dx, dz + h * 1.08, w * 2.3, slant=angry * (1 if dx < 0 else -1), thick=h * 0.22)
        return c

    def grin(self, key, dz, width, height, teeth=7, lower=0, curve=0.28, tongue=False, dx=0.0, name="grin",
             mouth="mouth", tooth="teeth"):
        """Zu breit, zu viele Zaehne, immer offen."""
        n = 24
        top, bot = [], []
        for i in range(n + 1):
            t = -1 + 2 * i / n
            x = t * width / 2
            top.append((x, -curve * height * (1 - t * t) + 0.12 * height * t * t))
            bot.append((x, -height * (1 - t * t) + 0.12 * height * t * t))
        outline = top + bot[::-1][1:-1]
        self.decal(key, outline, (dx, dz), mouth, lift=0.006, name=name + "_mund")
        # obere Zahnreihe haengt an der Oberlippe
        for i in range(teeth):
            t0 = -0.86 + 1.72 * i / teeth
            t1 = t0 + 1.72 / teeth * 0.86
            tm = (t0 + t1) / 2
            y0 = lambda t: -curve * height * (1 - t * t) + 0.12 * height * t * t
            depth = height * (0.30 if abs(tm) < 0.6 else 0.22)
            pts = [(t0 * width / 2, y0(t0) + 0.01), (t1 * width / 2, y0(t1) + 0.01),
                   (t1 * width / 2, y0(t1) - depth), (t0 * width / 2, y0(t0) - depth)]
            self.decal(key, pts, (dx, dz), tooth, lift=0.009, name=name + "_zahn")
        for i in range(lower):
            t0 = -0.6 + 1.2 * i / lower
            t1 = t0 + 1.2 / lower * 0.8
            yb = lambda t: -height * (1 - t * t) + 0.12 * height * t * t
            depth = height * 0.22
            pts = [(t0 * width / 2, yb(t0) - 0.01), (t1 * width / 2, yb(t1) - 0.01),
                   (t1 * width / 2, yb(t1) + depth), (t0 * width / 2, yb(t0) + depth)]
            self.decal(key, pts, (dx, dz), tooth, lift=0.009, name=name + "_unterzahn")
        if tongue:
            pts = [(width * 0.2 * math.cos(a), -height * 0.97 + height * 0.42 * math.sin(a))
                   for a in np.linspace(0, math.pi, 14)]
            self.decal(key, pts, (dx, dz), "tongue", lift=0.008, name=name + "_zunge")

    def brow(self, key, dx, dz, width, slant=0.3, thick=0.05, material="ink"):
        """Augenbraue als schraeger Tintenbalken - Wut oder Hochmut."""
        hw = width / 2
        pts = [(-hw, slant * hw), (hw, -slant * hw), (hw, -slant * hw + thick), (-hw, slant * hw + thick)]
        return self.decal(key, pts, (dx, dz), material, lift=0.01, name="braue")

    def nose(self, key, dx, dz, r, material="ink"):
        p = self.front(key, dx, dz, -r * 0.3)
        return self.ball(p - self.offset, (r * 1.2, r, r), material, name="nase")

    # ---------------------------------------------------------- Haende, Fuesse
    def glove(self, loc, size=0.28, rot=(0, 0, 0), pose="open", material="glove", cuff=True, mirror=False, name="glove"):
        """Weisser Vier-Finger-Handschuh (drei Finger und ein Daumen)."""
        s = size
        g = ("glove", name + str(self.next_index))
        root = bpy.data.objects.new(name, None)
        self.collection.objects.link(root)
        root.location = self.P(loc)
        root.rotation_euler = rot
        parts = []
        parts.append(self.ball((0, 0, 0), (s * 0.55, s * 0.32, s * 0.5), material, name=name + "_hand"))
        m = -1 if mirror else 1
        if pose == "fist":
            for i in range(3):
                parts.append(self.ball((m * (-0.18 + 0.18 * i) * s, -0.22 * s, 0.18 * s), (s * 0.17, s * 0.15, s * 0.2),
                                       material, name=name + "_knoechel"))
        else:
            angles = {"open": (-28, -2, 24), "point": (0, 170, 170), "wave": (-18, 0, 18)}[pose]
            lengths = {"open": (0.62, 0.7, 0.62), "point": (0.8, 0.35, 0.35), "wave": (0.66, 0.72, 0.66)}[pose]
            for i, (a, l) in enumerate(zip(angles, lengths)):
                ang = math.radians(a) * m
                base = Vector((m * (-0.2 + 0.2 * i) * s, 0, 0.3 * s))
                if pose == "point" and i > 0:
                    parts.append(self.ball(base + Vector((0, -0.12 * s, -0.02 * s)), (s * 0.16, s * 0.14, s * 0.16),
                                           material, name=name + "_knoechel"))
                    continue
                tip = base + Vector((math.sin(ang) * l * s, 0, math.cos(ang) * l * s))
                mid = (base + tip) / 2
                parts.append(self.ball(mid, (s * 0.15, s * 0.15, (tip - base).length / 2 + s * 0.08), material,
                                       rot=(0, ang, 0), name=name + "_finger"))
        thumb = Vector((m * -0.5 * s, -0.05 * s, 0.05 * s))
        parts.append(self.ball(thumb, (s * 0.15, s * 0.14, s * 0.28), material, rot=(0, math.radians(-50) * m, 0),
                               name=name + "_daumen"))
        if cuff:
            parts.append(self.cyl((0, 0, -0.5 * s), s * 0.42, s * 0.28, material, r2=s * 0.33, name=name + "_stulpe"))
        for p in parts:
            p.location = p.location - self.offset
            p.parent = root
        return root

    def shoe(self, loc, size=0.3, material="ink2", mirror=False):
        m = -1 if mirror else 1
        return self.ball((loc[0] + m * size * 0.25, loc[1] - size * 0.2, loc[2]), (size * 0.8, size * 0.6, size * 0.42),
                         material, name="schuh")

    # ---------------------------------------------------------- Huete
    def tophat(self, loc, size=0.5, material="ink2", band="blood", tilt=0.0):
        root = bpy.data.objects.new("zylinder", None)
        self.collection.objects.link(root)
        root.location = self.P(loc)
        root.rotation_euler = (0, tilt, 0)
        parts = [
            self.cyl((0, 0, 0), size * 0.9, size * 0.08, material, name="krempe"),
            self.cyl((0, 0, size * 0.5), size * 0.52, size * 0.95, material, r2=size * 0.56, name="hut"),
            self.cyl((0, 0, size * 0.17), size * 0.535, size * 0.18, band, name="hutband"),
        ]
        for p in parts:
            p.location = p.location - self.offset
            p.parent = root
        return root

    def bowler(self, loc, size=0.5, material="ink2", tilt=0.0):
        root = bpy.data.objects.new("melone", None)
        self.collection.objects.link(root)
        root.location = self.P(loc)
        root.rotation_euler = (0, tilt, 0)
        parts = [
            self.cyl((0, 0, 0), size * 0.85, size * 0.07, material, name="krempe"),
            self.ball((0, 0, 0.02), (size * 0.55, size * 0.55, size * 0.6), material, name="kuppel"),
        ]
        for p in parts:
            p.location = p.location - self.offset
            p.parent = root
        return root

    def crown(self, loc, size=0.5, material="gold", spikes=5, broken=False):
        root = bpy.data.objects.new("krone", None)
        self.collection.objects.link(root)
        root.location = self.P(loc)
        parts = [self.cyl((0, 0, 0), size * 0.6, size * 0.3, material, name="kronreif")]
        for i in range(spikes):
            a = math.pi * (0.15 + 0.7 * i / (spikes - 1))
            if broken and i == spikes - 2:
                continue
            p = Vector((math.cos(a) * size * 0.55, -math.sin(a) * size * 0.55, size * 0.3))
            parts.append(self.cyl(p, size * 0.12, size * 0.5, material, r2=0.0, name="zacke"))
            parts.append(self.ball(p + Vector((0, 0, size * 0.3)), size * 0.07, "blood", name="stein"))
        for p in parts:
            p.location = p.location - self.offset
            p.parent = root
        return root

    # ---------------------------------------------------------- Werkzeuge
    def cut(self, obj, loc, size, seg=48):
        """Boolesches Wegschneiden mit einem Ellipsoid (z. B. Mondsichel)."""
        cutter = self.ball(loc, size, "ink", seg=seg, name=obj.name + "_schnitt")
        cutter.hide_render = True
        cutter.hide_viewport = True
        cutter.display_type = "WIRE"
        mod = obj.modifiers.new("schnitt", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.object = cutter
        return cutter

    def turn(self, pivot, rot):
        """Dreht alles bisher Gebaute der Figur um einen Punkt (verkehrt haengen)."""
        piv = bpy.data.objects.new("drehpunkt", None)
        self.collection.objects.link(piv)
        piv.location = self.P(pivot)
        bpy.context.view_layer.update()
        for obj in list(self.collection.objects):
            if obj is piv or obj.parent is not None:
                continue
            mw = obj.matrix_world.copy()
            obj.parent = piv
            obj.matrix_parent_inverse = piv.matrix_world.inverted()
            obj.matrix_world = mw
        piv.rotation_euler = rot
        bpy.context.view_layer.update()
        return piv

    def bolt(self, loc, size, material="flame", rot=(0, 0, 0)):
        pts = [(0.0, 1.0), (0.35, 1.0), (0.12, 0.45), (0.42, 0.45), (-0.2, -1.0), (0.02, 0.2), (-0.25, 0.2)]
        return self.poly([(x * size, z * size) for x, z in pts], loc, material, rot=rot, depth=0.02, name="blitz")


# ------------------------------------------------------------------ Render
def setup_scene(tmpdir):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 1
    scene.cycles.preview_samples = 1
    scene.cycles.use_denoising = False
    scene.cycles.pixel_filter_type = "BOX"
    scene.cycles.filter_width = 0.01
    scene.cycles.max_bounces = 0
    scene.cycles.use_adaptive_sampling = False
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.resolution_percentage = 100
    scene.render.use_compositing = True
    scene.frame_current = 1

    vl = scene.view_layers[0]
    vl.use_pass_z = True
    vl.use_pass_object_index = True
    vl.use_pass_material_index = True

    cam_data = bpy.data.cameras.new("Kamera")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("Kamera", cam_data)
    scene.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(86), 0, 0)
    scene.camera = cam

    scene.use_nodes = True
    tree = scene.node_tree
    tree.nodes.clear()
    rl = tree.nodes.new("CompositorNodeRLayers")
    comp = tree.nodes.new("CompositorNodeComposite")
    fo = tree.nodes.new("CompositorNodeOutputFile")
    fo.base_path = tmpdir
    fo.format.file_format = "OPEN_EXR"
    fo.format.color_depth = "32"
    fo.format.color_mode = "RGBA"
    fo.file_slots.clear()
    for slot in ("rgba", "ob", "ma", "z"):
        fo.file_slots.new(slot)
    tree.links.new(rl.outputs["Image"], comp.inputs["Image"])
    tree.links.new(rl.outputs["Image"], fo.inputs["rgba"])
    tree.links.new(rl.outputs["IndexOB"], fo.inputs["ob"])
    tree.links.new(rl.outputs["IndexMA"], fo.inputs["ma"])
    tree.links.new(rl.outputs["Depth"], fo.inputs["z"])
    return cam


def bounds(coll):
    """Achsenbox aller renderbaren Objekte einer Sammlung (ausgewertet)."""
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for obj in coll.all_objects:
        if obj.type not in {"MESH", "CURVE"} or obj.hide_render:
            continue
        ev = obj.evaluated_get(dg)
        for corner in ev.bound_box:
            w = ev.matrix_world @ Vector(corner)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    return lo, hi


def frame(cam, coll, size_px, margin_px=4):
    lo, hi = bounds(coll)
    center = (lo + hi) / 2
    w, h = hi.x - lo.x, hi.z - lo.z
    usable = (size_px - 2 * margin_px) / size_px
    scale = max(w, h * 1.03) / usable
    cam.data.ortho_scale = scale
    tilt = cam.rotation_euler.x
    dist = 30
    direction = Vector((0, math.sin(tilt), -math.cos(tilt)))  # Blickrichtung der Kamera
    cam.location = center - direction * dist
    cam.data.clip_end = dist * 3


def _load(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    arr = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(arr)
    bpy.data.images.remove(img)
    return arr.reshape(h, w, 4)[::-1]


def frame_box(cam, lo, hi, size_px, pad=1.0, margin_px=4):
    """Feste Kamera fuer Animationen: Box um die Ruhepose, mit Luft fuer Bewegung und Effekte."""
    center = (lo + hi) / 2
    w, h = (hi.x - lo.x) * pad, (hi.z - lo.z) * pad
    cam.data.ortho_scale = max(w, h * 1.03) / ((size_px - 2 * margin_px) / size_px)
    tilt = cam.rotation_euler.x
    direction = Vector((0, math.sin(tilt), -math.cos(tilt)))
    cam.location = center - direction * 30
    cam.data.clip_end = 90


def render_fixed(kit, cam, coll, size_px, tmpdir, outline=2):
    """Ein Bild mit der aktuellen Kamera rendern und nachbearbeiten, ohne Speichern."""
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = size_px
    for c in scene.collection.children:
        c.hide_render = c is not coll
    for f in os.listdir(tmpdir):
        os.remove(os.path.join(tmpdir, f))
    scene.render.filepath = os.path.join(tmpdir, "combined")
    bpy.ops.render.render(write_still=False)
    rgba = _load(os.path.join(tmpdir, "rgba0001.exr"))
    ob = _load(os.path.join(tmpdir, "ob0001.exr"))[..., 0]
    ma = _load(os.path.join(tmpdir, "ma0001.exr"))[..., 0]
    z = _load(os.path.join(tmpdir, "z0001.exr"))[..., 0]
    return postprocess(kit, rgba, ob, ma, z, outline)


def render_sprite(kit, cam, coll, size_px, tmpdir, out_png, outline=2):
    scene = bpy.context.scene
    scene.render.resolution_x = scene.render.resolution_y = size_px
    for c in scene.collection.children:
        c.hide_render = c is not coll
    frame(cam, coll, size_px, margin_px=outline + 2)
    for f in os.listdir(tmpdir):
        os.remove(os.path.join(tmpdir, f))
    scene.render.filepath = os.path.join(tmpdir, "combined")
    bpy.ops.render.render(write_still=False)
    rgba = _load(os.path.join(tmpdir, "rgba0001.exr"))
    ob = _load(os.path.join(tmpdir, "ob0001.exr"))[..., 0]
    ma = _load(os.path.join(tmpdir, "ma0001.exr"))[..., 0]
    z = _load(os.path.join(tmpdir, "z0001.exr"))[..., 0]
    img = postprocess(kit, rgba, ob, ma, z, outline)
    save_png(img, out_png)
    return img


def postprocess(kit, rgba, ob, ma, z, outline):
    h, w = ob.shape
    mask = rgba[..., 3] > 0.5
    # linear -> sRGB, dann auf die Palette einrasten
    c = np.clip(rgba[..., :3], 0, 1)
    c = np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)
    pal = kit.palette()
    d = ((c[:, :, None, :] - pal[None, None, :, :]) ** 2).sum(-1)
    col = pal[d.argmin(-1)]
    ink = np.array(srgb(PAL["ink"]), dtype=np.float32)

    # Innenlinien: wo Objekt oder Material wechselt, auf dem hinteren Pixel.
    key = ob.astype(np.int64) * 1000 + ma.astype(np.int64)
    noline_ids = {m.pass_index for n, m in kit.mats.items() if n in NO_LINE}
    noline = np.isin(ma.astype(np.int64), list(noline_ids))
    line = np.zeros_like(mask)
    for dy, dx in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nk = np.roll(key, (dy, dx), (0, 1))
        nz = np.roll(z, (dy, dx), (0, 1))
        nm = np.roll(mask, (dy, dx), (0, 1))
        line |= mask & nm & (nk != key) & (z > nz + 1e-4)
    line &= ~noline
    col[line] = ink

    # Aussenkontur: 2 px, erst 8er-, dann 4er-Nachbarschaft -> runde Ecken
    grown = mask.copy()
    shapes = [((1, 1, 1), (1, 0, 1), (1, 1, 1)), ((0, 1, 0), (1, 0, 1), (0, 1, 0))]
    for ring in range(outline):
        k = shapes[0] if ring == 0 else shapes[1]
        nxt = grown.copy()
        for yy in range(3):
            for xx in range(3):
                if k[yy][xx]:
                    nxt |= np.roll(grown, (yy - 1, xx - 1), (0, 1))
        grown = nxt
    edge = grown & ~mask
    out = np.zeros((h, w, 4), dtype=np.float32)
    out[..., :3] = col
    out[..., 3] = mask
    out[edge, :3] = ink
    out[edge, 3] = 1
    return out


def save_png(img, path):
    from PIL import Image
    os.makedirs(os.path.dirname(path), exist_ok=True)
    arr = (np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)
    Image.fromarray(arr, "RGBA").save(path)


def upscale(path_in, path_out, factor=4):
    from PIL import Image
    im = Image.open(path_in)
    os.makedirs(os.path.dirname(path_out), exist_ok=True)
    im.resize((im.width * factor, im.height * factor), Image.NEAREST).save(path_out)
