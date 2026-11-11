"""Modela al Tío en alta resolución con un cuerpo de una sola pieza.

Cuerpo: esqueleto de vértices con el modificador Skin (piel), subdividido.
Cabeza: volúmenes superpuestos que se funden con remallado por vóxeles, más
boca y cuencas talladas con booleanos. Cuernos, ojos, dientes, chiva, cigarro y
serpentinas van como piezas aparte con su propio material.

Uso: python3 build_tio.py <salida.blend>
El Tío mira hacia +Y y mide unos 2,15 m con los pies en z = 0.
"""

import bpy  # noqa: I001  (bpy primero: registra bmesh y mathutils)
import bmesh
import math
import random
import sys
from mathutils import Vector

OUT = sys.argv[-1]
HEAD = Vector((0.0, 0.26, 1.92))
random.seed(7)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(ob):
    bpy.context.collection.objects.link(ob)
    return ob


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active or objs[0]


def apply_all(ob):
    select_only([ob])
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


# ---------------------------------------------------------------- cuerpo

def build_body():
    """Esqueleto con radios por vértice; Skin lo convierte en una malla continua."""
    joints, radii, edges = {}, {}, []

    def j(name, co, r):
        joints[name] = Vector(co)
        radii[name] = r if isinstance(r, tuple) else (r, r)

    def e(a, b):
        edges.append((a, b))

    j("pelvis", (0, 0.0, 1.0), (0.22, 0.17))
    j("belly", (0, 0.07, 1.2), (0.22, 0.2))
    j("chest", (0, 0.07, 1.42), (0.27, 0.19))
    j("upper", (0, 0.11, 1.6), (0.28, 0.16))
    j("neck", (0, 0.2, 1.72), (0.12, 0.12))
    j("nape", (0, 0.24, 1.82), (0.11, 0.11))
    for a, b in (("pelvis", "belly"), ("belly", "chest"), ("chest", "upper"), ("upper", "neck"), ("neck", "nape")):
        e(a, b)
    for s, side in ((-1, "L"), (1, "R")):
        j(f"clav{side}", (0.2 * s, 0.12, 1.62), 0.1)
        j(f"shoulder{side}", (0.37 * s, 0.1, 1.6), 0.105)
        j(f"bicep{side}", (0.43 * s, 0.13, 1.42), 0.09)
        j(f"elbow{side}", (0.47 * s, 0.17, 1.24), 0.07)
        j(f"forearm{side}", (0.48 * s, 0.25, 1.08), 0.07)
        j(f"wrist{side}", (0.47 * s, 0.33, 0.94), 0.045)
        j(f"palm{side}", (0.47 * s, 0.38, 0.86), (0.075, 0.04))
        for a, b in (("upper", f"clav{side}"), (f"clav{side}", f"shoulder{side}"),
                     (f"shoulder{side}", f"bicep{side}"), (f"bicep{side}", f"elbow{side}"),
                     (f"elbow{side}", f"forearm{side}"), (f"forearm{side}", f"wrist{side}"),
                     (f"wrist{side}", f"palm{side}")):
            e(a, b)
        for i, off in enumerate((-0.048, -0.016, 0.016, 0.048)):
            base = Vector((0.47 * s + off * s, 0.41, 0.82))
            length = 0.085 + (0.02 if i in (1, 2) else 0)
            p1 = base + Vector((off * 0.3 * s, 0.03, -length))
            p2 = p1 + Vector((off * 0.2 * s, 0.035, -length * 0.8))
            j(f"f{i}a{side}", base, 0.024)
            j(f"f{i}b{side}", p1, 0.021)
            j(f"f{i}c{side}", p2, 0.017)
            CLAW_ROOTS.append((p2, p2 - p1))
            e(f"palm{side}", f"f{i}a{side}")
            e(f"f{i}a{side}", f"f{i}b{side}")
            e(f"f{i}b{side}", f"f{i}c{side}")
        j(f"thumb_a{side}", (0.42 * s, 0.41, 0.88), 0.026)
        j(f"thumb_b{side}", (0.39 * s, 0.48, 0.82), 0.02)
        CLAW_ROOTS.append((Vector((0.39 * s, 0.48, 0.82)), Vector((-0.02 * s, 0.07, -0.06))))
        e(f"palm{side}", f"thumb_a{side}")
        e(f"thumb_a{side}", f"thumb_b{side}")
        j(f"hip{side}", (0.13 * s, 0.0, 0.96), 0.15)
        j(f"thigh{side}", (0.16 * s, 0.07, 0.74), 0.14)
        j(f"knee{side}", (0.17 * s, 0.11, 0.52), 0.095)
        j(f"shin{side}", (0.17 * s, 0.05, 0.3), 0.08)
        j(f"ankle{side}", (0.17 * s, 0.0, 0.11), 0.065)
        j(f"foot{side}", (0.17 * s, 0.13, 0.06), (0.075, 0.055))
        j(f"toe{side}", (0.17 * s, 0.24, 0.045), (0.07, 0.04))
        for a, b in (("pelvis", f"hip{side}"), (f"hip{side}", f"thigh{side}"), (f"thigh{side}", f"knee{side}"),
                     (f"knee{side}", f"shin{side}"), (f"shin{side}", f"ankle{side}"),
                     (f"ankle{side}", f"foot{side}"), (f"foot{side}", f"toe{side}")):
            e(a, b)

    names = list(joints)
    me = bpy.data.meshes.new("TioSkeleton")
    me.from_pydata([joints[n] for n in names], [(names.index(a), names.index(b)) for a, b in edges], [])
    ob = link(bpy.data.objects.new("TioBody", me))
    skin = ob.modifiers.new("Skin", "SKIN")
    skin.use_smooth_shade = True
    skin.branch_smoothing = 0.6
    for i, n in enumerate(names):
        sv = me.skin_vertices[0].data[i]
        sv.radius = radii[n]
        sv.use_root = n == "pelvis"
    sub = ob.modifiers.new("Subsurf", "SUBSURF")
    sub.levels = 2
    apply_all(ob)
    return ob


# ---------------------------------------------------------------- cabeza

def blob(name, center, scale, rot=(0, 0, 0), segs=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=1.0, location=center,
                                         rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return ob


def build_head_volumes():
    h = HEAD
    parts = [
        blob("Skull", h + Vector((0, -0.03, 0.06)), (0.17, 0.17, 0.165)),
        blob("Brow", h + Vector((0, 0.11, 0.075)), (0.15, 0.07, 0.055), rot=(math.radians(-15), 0, 0)),
        blob("CheekL", h + Vector((-0.1, 0.1, -0.03)), (0.075, 0.07, 0.065)),
        blob("CheekR", h + Vector((0.1, 0.1, -0.03)), (0.075, 0.07, 0.065)),
        blob("NoseBridge", h + Vector((0, 0.17, 0.02)), (0.035, 0.05, 0.05)),
        blob("Nose", h + Vector((0, 0.21, -0.035)), (0.06, 0.05, 0.04)),
        blob("Muzzle", h + Vector((0, 0.12, -0.11)), (0.14, 0.12, 0.1)),
        blob("UpperLip", h + Vector((0, 0.2, -0.085)), (0.11, 0.045, 0.032)),
        blob("LowerLip", h + Vector((0, 0.18, -0.2)), (0.1, 0.045, 0.035)),
        blob("Jaw", h + Vector((0, 0.08, -0.17)), (0.135, 0.11, 0.08)),
        blob("Chin", h + Vector((0, 0.15, -0.24)), (0.065, 0.055, 0.05)),
    ]
    for s, side in ((-1, "L"), (1, "R")):
        parts.append(blob(f"Ear{side}", h + Vector((0.2 * s, -0.01, 0.04)), (0.1, 0.022, 0.045),
                          rot=(0, math.radians(-25 * s), math.radians(-20 * s))))
    return parts


def build_muscles():
    """Volúmenes de músculo que se funden con el cuerpo: espalda encorvada, pecho, brazos y piernas."""
    parts = [
        blob("Hunch", Vector((0, -0.04, 1.6)), (0.25, 0.13, 0.17)),
        blob("Abs", Vector((0, 0.16, 1.22)), (0.15, 0.08, 0.17)),
        blob("Ribs", Vector((0, 0.1, 1.38)), (0.25, 0.15, 0.13)),
    ]
    for s, side in ((-1, "L"), (1, "R")):
        parts += [
            blob(f"Pec{side}", Vector((0.12 * s, 0.2, 1.53)), (0.13, 0.055, 0.075), rot=(math.radians(10), 0, 0)),
            blob(f"Trap{side}", Vector((0.17 * s, 0.05, 1.71)), (0.14, 0.09, 0.06), rot=(0, math.radians(-20 * s), 0)),
            blob(f"Delt{side}", Vector((0.39 * s, 0.1, 1.58)), (0.1, 0.11, 0.12)),
            blob(f"Lat{side}", Vector((0.22 * s, 0.0, 1.42)), (0.08, 0.12, 0.17)),
            blob(f"Bicep{side}", Vector((0.44 * s, 0.17, 1.42)), (0.065, 0.065, 0.1)),
            blob(f"Forearm{side}", Vector((0.48 * s, 0.22, 1.13)), (0.06, 0.065, 0.1), rot=(math.radians(-30), 0, 0)),
            blob(f"Glute{side}", Vector((0.11 * s, -0.07, 0.98)), (0.12, 0.09, 0.11)),
            blob(f"Quad{side}", Vector((0.16 * s, 0.13, 0.76)), (0.1, 0.07, 0.15)),
            blob(f"Calf{side}", Vector((0.17 * s, 0.0, 0.37)), (0.07, 0.07, 0.13)),
            blob(f"Knee{side}", Vector((0.17 * s, 0.15, 0.52)), (0.055, 0.04, 0.055)),
            blob(f"Knuckles{side}", Vector((0.47 * s, 0.41, 0.83)), (0.065, 0.025, 0.02)),
        ]
    return parts


def carve(target, cutters):
    for c in cutters:
        mod = target.modifiers.new("Carve", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "MANIFOLD"
        mod.object = c
        select_only([target])
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(c)


def blend_body(ob):
    """Funde los músculos con el cuerpo con un suavizado fuerte que no toca la cara."""
    group = ob.vertex_groups.new(name="BodyOnly")
    palms = [Vector((0.47 * s, 0.4, 0.85)) for s in (-1, 1)]
    for v in ob.data.vertices:
        to_face = (v.co - HEAD).length
        weight = 0.25 + 0.75 * min(1.0, max(0.0, (to_face - 0.2) / 0.12))
        to_hand = min((v.co - p).length for p in palms)
        weight *= min(1.0, max(0.0, (to_hand - 0.1) / 0.08))
        group.add([v.index], weight, "REPLACE")
    smooth = ob.modifiers.new("Blend", "LAPLACIANSMOOTH")
    smooth.iterations = 20
    smooth.lambda_factor = 1.2
    smooth.vertex_group = group.name
    apply_all(ob)


def fuse_and_sculpt(body, head_parts):
    head_parts = [*head_parts, *build_muscles()]
    select_only([body, *head_parts], body)
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = "TioHigh"
    ob.data.remesh_voxel_size = 0.012
    bpy.ops.object.voxel_remesh()
    blend_body(ob)
    h = HEAD
    mouth = blob("MouthCut", h + Vector((0, 0.2, -0.145)), (0.085, 0.09, 0.05))
    sockets = [blob(f"Socket{s}", h + Vector((0.072 * s, 0.17, 0.015)), (0.052, 0.05, 0.048)) for s in (-1, 1)]
    nostrils = [blob(f"Nostril{s}", h + Vector((0.022 * s, 0.25, -0.05)), (0.014, 0.02, 0.012)) for s in (-1, 1)]
    carve(ob, [mouth, *sockets, *nostrils])
    ob.data.remesh_voxel_size = 0.006
    select_only([ob])
    bpy.ops.object.voxel_remesh()
    smooth = ob.modifiers.new("Smooth", "CORRECTIVE_SMOOTH")
    smooth.iterations = 6
    smooth.factor = 0.6
    lumps = bpy.data.textures.new("ClayLumps", "VORONOI")
    lumps.noise_scale = 0.03
    d1 = ob.modifiers.new("Lumps", "DISPLACE")
    d1.texture = lumps
    d1.texture_coords = "OBJECT"
    d1.strength = -0.003
    clouds = bpy.data.textures.new("ClayClouds", "CLOUDS")
    clouds.noise_scale = 0.06
    d2 = ob.modifiers.new("Clouds", "DISPLACE")
    d2.texture = clouds
    d2.texture_coords = "OBJECT"
    d2.strength = 0.004
    apply_all(ob)
    select_only([ob])
    bpy.ops.object.shade_smooth()
    return ob


# ---------------------------------------------------------------- piezas aparte

CLAW_ROOTS = []


def build_claws():
    """Uñas negras y curvas en la punta de cada dedo."""
    claws = []
    for idx, (tip, direction) in enumerate(CLAW_ROOTS):
        d = direction.normalized()
        start = tip + d * 0.004
        mid = start + d * 0.03 + Vector((0, 0.008, 0))
        end = mid + d * 0.02 + Vector((0, 0.012, -0.01))
        claws.append(tube(f"Claw{idx}", [start, mid, end], [0.014, 0.009, 0.001], segs=8))
    return claws


def tube(name, points, radii, segs=12, ridge=0.0, ridge_freq=0.0, cap_tip=True):
    """Tubo a lo largo de una polilínea con radio variable."""
    bm = bmesh.new()
    rings = []
    n = len(points)
    for i, p in enumerate(points):
        t = (points[min(i + 1, n - 1)] - points[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
        u = t.cross(ref).normalized()
        v = u.cross(t).normalized()
        rr = radii[i] * (1.0 + ridge * math.sin(i * ridge_freq))
        rings.append([bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * rr)
                      for a in (2 * math.pi * k / segs for k in range(segs))])
    for i in range(n - 1):
        for k in range(segs):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % segs], rings[i + 1][(k + 1) % segs], rings[i + 1][k]))
    bm.faces.new(list(reversed(rings[0])))
    if cap_tip:
        tip = bm.verts.new(points[-1] + (points[-1] - points[-2]).normalized() * radii[-1])
        for k in range(segs):
            bm.faces.new((rings[-1][k], rings[-1][(k + 1) % segs], tip))
    else:
        bm.faces.new(rings[-1])
    uv = bm.loops.layers.uv.new("UVMap")
    ring_of = {}
    for i, ring in enumerate(rings):
        for k, vert in enumerate(ring):
            ring_of[vert] = (k / segs, i / max(n - 1, 1))
    for face in bm.faces:
        for loop in face.loops:
            u, v = ring_of.get(loop.vert, (0.5, 1.0))
            loop[uv].uv = (u, v)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    for poly in me.polygons:
        poly.use_smooth = True
    return ob


def build_horns():
    horns = []
    for s, side in ((-1, "L"), (1, "R")):
        base = HEAD + Vector((0.09 * s, 0.02, 0.15))
        pts, rad = [], []
        steps = 40
        for i in range(steps + 1):
            t = i / steps
            out = 0.26 * math.sin(min(t * 1.4, 1.0) * math.pi / 2)
            pts.append(base + Vector((
                s * (0.02 + out - 0.06 * t * t),
                -0.12 * math.sin(t * math.pi) + 0.05 * t,
                0.05 * t + 0.27 * t * t,
            )))
            rad.append(0.062 * (1 - t) ** 1.1 + 0.003)
        horns.append(tube(f"Horn{side}", pts, rad, segs=18, ridge=0.025, ridge_freq=2.4))
    return horns


def build_eyes():
    eyes = []
    for s, side in ((-1, "L"), (1, "R")):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=0.039,
                                             location=HEAD + Vector((0.072 * s, 0.158, 0.015)))
        ob = bpy.context.active_object
        ob.name = f"Eye{side}"
        bpy.ops.object.shade_smooth()
        eyes.append(ob)
    return eyes


def build_teeth():
    teeth = []
    for z, sign in ((-0.112, -1), (-0.182, 1)):
        for i in range(9):
            a = (i - 4) / 4.0
            fang = i in (1, 7)
            length = 0.055 if fang else 0.028 + random.uniform(-0.004, 0.006)
            r = 0.012 if fang else 0.009
            bpy.ops.mesh.primitive_cone_add(vertices=10, radius1=r, radius2=0.0015, depth=length,
                                            location=HEAD + Vector((a * 0.07, 0.205 - 0.035 * a * a,
                                                                    z + sign * length / 2)))
            ob = bpy.context.active_object
            ob.rotation_euler = (0 if sign > 0 else math.pi, random.uniform(-0.15, 0.15), 0)
            teeth.append(ob)
    select_only(teeth)
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = "Teeth"
    bpy.ops.object.shade_smooth()
    return ob


def build_goatee():
    parts = []
    for k in range(5):
        off = (k - 2) * 0.012
        top = HEAD + Vector((off, 0.18, -0.25))
        bot = HEAD + Vector((off * 0.4, 0.22, -0.38 - 0.015 * (2 - abs(k - 2))))
        pts = [top.lerp(bot, t) + Vector((0, 0.02 * math.sin(t * 3), 0)) for t in (0, 0.33, 0.66, 1)]
        parts.append(tube(f"Goatee{k}", pts, [0.03, 0.024, 0.014, 0.002], segs=10))
    select_only(parts)
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = "Goatee"
    ob.data.remesh_voxel_size = 0.004
    bpy.ops.object.voxel_remesh()
    bpy.ops.object.shade_smooth()
    return ob


def build_cigarette():
    start = HEAD + Vector((0.05, 0.19, -0.14))
    end = start + Vector((0.045, 0.11, -0.012))
    cig = tube("Cigarette", [start, end], [0.0068, 0.0068], segs=12, cap_tip=False)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=0.0072, location=end)
    ember = bpy.context.active_object
    ember.name = "Ember"
    return cig, ember


def build_streamers():
    """Serpentinas de papel de colores colgando de cuernos y hombros."""
    ribbons = []
    anchors = [
        (HEAD + Vector((-0.24, -0.05, 0.32)), 0.9),
        (HEAD + Vector((0.22, -0.02, 0.3)), 0.8),
        (Vector((-0.34, 0.12, 1.7)), 0.6),
        (Vector((0.33, 0.1, 1.72)), 0.7),
        (Vector((0.0, 0.25, 1.62)), 0.45),
    ]
    for idx, (start, length) in enumerate(anchors):
        for strip in range(3):
            bm = bmesh.new()
            steps = 30
            phase = random.uniform(0, math.pi * 2)
            drift = random.uniform(-1, 1)
            prev_pair = None
            freq = random.uniform(6, 14)
            amp = random.uniform(0.006, 0.02)
            length *= random.uniform(0.6, 1.1)
            for i in range(steps + 1):
                t = i / steps
                wob = math.sin(t * freq + phase)
                p = start + Vector((amp * wob + drift * 0.06 * t + 0.02 * strip,
                                    amp * math.cos(t * freq * 0.7 + phase) + 0.025 * strip + 0.03 * t * t,
                                    -length * t))
                twist = t * freq * 0.5 + phase
                side = Vector((math.cos(twist), math.sin(twist) * 0.6, 0.15)).normalized() * 0.011
                pair = (bm.verts.new(p - side), bm.verts.new(p + side))
                if prev_pair:
                    bm.faces.new((prev_pair[0], prev_pair[1], pair[1], pair[0]))
                prev_pair = pair
            name = f"Streamer{idx}_{strip}"
            me = bpy.data.meshes.new(name)
            bm.to_mesh(me)
            bm.free()
            ob = link(bpy.data.objects.new(name, me))
            ob["streamer_color"] = (idx * 3 + strip) % 5
            solid = ob.modifiers.new("Thick", "SOLIDIFY")
            solid.thickness = 0.0015
            apply_all(ob)
            ribbons.append(ob)
    return ribbons


def main():
    reset()
    body = build_body()
    tio = fuse_and_sculpt(body, build_head_volumes())
    pieces = [*build_horns(), *build_eyes(), build_teeth(), build_goatee(), *build_cigarette(), *build_claws()]
    build_streamers()
    print("TioHigh", len(tio.data.polygons), "caras")
    for o in pieces:
        print(o.name, len(o.data.polygons))
    bpy.ops.wm.save_as_mainfile(filepath=OUT)


main()
