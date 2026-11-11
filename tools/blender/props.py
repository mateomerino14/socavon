"""Modela los objetos de la mina y los exporta como OBJ, una pieza por material.

Cada objeto se arma con primitivas, biseles y algo de ruido para que no parezca de caja.
No llevan UV: en Godot usan materiales triplanares (madera, hierro, roca), así que la textura
se adapta sola a cualquier forma.

Uso: python3 props.py <carpeta_salida>
"""

import bpy  # noqa: I001
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, noise

out_dir = sys.argv[-1]
os.makedirs(out_dir, exist_ok=True)
random.seed(1545)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def active():
    return bpy.context.view_layer.objects.active


def box(name, size, loc, bevel=0.01, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    ob = active()
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return ob


def cylinder(name, radius, depth, loc, rot=(0, 0, 0), verts=16, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(radius=radius, depth=depth, location=loc, rotation=rot, vertices=verts)
    ob = active()
    ob.name = name
    if bevel:
        mod = ob.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    return ob


def roughen(ob, amount, scale, subdivide=0):
    """Deforma la malla con ruido para que no tenga caras perfectas."""
    for mod in list(ob.modifiers):
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if subdivide:
        mod = ob.modifiers.new("Sub", "SUBSURF")
        mod.levels = subdivide
        mod.subdivision_type = "SIMPLE"
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="Sub")
    seed = Vector((random.random() * 50, random.random() * 50, random.random() * 50))
    for v in ob.data.vertices:
        n = noise.noise_vector(v.co * scale + seed)
        v.co += n * amount


def join(objects, name):
    """Aplica modificadores y une las piezas en un objeto."""
    for ob in objects:
        bpy.context.view_layer.objects.active = ob
        for mod in list(ob.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objects:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    ob = active()
    ob.name = name
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    return ob


def export(ob, file_name):
    """Exporta un objeto: en Godot +Y de Blender queda mirando a -Z."""
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.wm.obj_export(
        filepath=os.path.join(out_dir, file_name), export_selected_objects=True, export_materials=False,
        export_uv=False, forward_axis="NEGATIVE_Z", up_axis="Y", apply_modifiers=True,
    )
    print("modelo", file_name, len(ob.data.polygons))


def mine_cart():
    """Carro minero: batea de chapa con pestaña y refuerzos, chasis, ejes y ruedas de rayos."""
    reset()
    parts = []
    # Batea: fondo y cuatro planchas de chapa, un poco abiertas hacia arriba
    parts.append(box("Floor", (0.94, 1.54, 0.03), (0, 0, 0.35), bevel=0.008))
    flare = 0.12
    for side in (-1, 1):
        wall = box("Side", (0.03, 1.6, 0.62), (side * 0.5, 0, 0.65), bevel=0.008, rot=(0, side * flare, 0))
        roughen(wall, 0.006, 3.0, subdivide=2)
        parts.append(wall)
        end = box("End", (1.0, 0.03, 0.62), (0, side * 0.8, 0.65), bevel=0.008, rot=(-side * flare * 0.7, 0, 0))
        roughen(end, 0.006, 3.0, subdivide=2)
        parts.append(end)
    # Pestaña superior y refuerzos verticales
    for side in (-1, 1):
        parts.append(box("RimSide", (0.05, 1.72, 0.04), (side * 0.54, 0, 0.96), bevel=0.01))
        parts.append(box("RimEnd", (1.12, 0.05, 0.04), (0, side * 0.84, 0.96), bevel=0.01))
    for x in (-0.55, 0.55):
        for y in (-0.5, 0.0, 0.5):
            parts.append(box("Rib", (0.03, 0.06, 0.6), (x, y, 0.64), bevel=0.005))
    for y in (-0.82, 0.82):
        parts.append(box("EndRib", (0.7, 0.03, 0.5), (0, y, 0.62), bevel=0.005))
    # Chasis, ejes y enganche
    for x in (-0.36, 0.36):
        parts.append(box("Frame", (0.07, 1.7, 0.08), (x, 0, 0.3), bevel=0.01))
    for y in (-0.5, 0.5):
        parts.append(cylinder("Axle", 0.025, 1.2, (0, y, 0.18), rot=(0, math.pi / 2, 0), verts=10))
    parts.append(box("Hitch", (0.08, 0.3, 0.06), (0, 0.95, 0.3), bevel=0.01))
    # Ruedas con pestaña, cubo y rayos
    for x in (-0.55, 0.55):
        for y in (-0.5, 0.5):
            parts.append(cylinder("Wheel", 0.17, 0.06, (x, y, 0.18), rot=(0, math.pi / 2, 0), verts=24, bevel=0.008))
            parts.append(cylinder("Flange", 0.2, 0.02, (x - 0.035 * math.copysign(1, x), y, 0.18),
                                  rot=(0, math.pi / 2, 0), verts=24))
            parts.append(cylinder("Hub", 0.05, 0.1, (x, y, 0.18), rot=(0, math.pi / 2, 0), verts=12))
    export(join(parts, "MineCart"), "mine_cart.obj")


def timber_frame():
    """Cuadro de callapos: dos postes rollizos algo torcidos, sombrero, cuñas y tablas encima."""
    reset()
    parts = []
    for x, lean in ((-1.3, 0.04), (1.3, -0.03)):
        post = cylinder("Post", 0.11, 2.44, (x, 0, 1.22), rot=(0.02, lean, 0), verts=12)
        bm = bmesh.new()
        bm.from_mesh(post.data)
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 1.0],
                                  cuts=8)
        bm.to_mesh(post.data)
        bm.free()
        roughen(post, 0.018, 2.5)
        parts.append(post)
    beam = cylinder("Cap", 0.13, 2.95, (0, 0, 2.5), rot=(0, math.pi / 2, 0), verts=12)
    roughen(beam, 0.02, 2.0, subdivide=1)
    parts.append(beam)
    for x in (-1.3, 1.3):
        parts.append(box("Wedge", (0.18, 0.2, 0.08), (x, 0.0, 2.36), bevel=0.01, rot=(0, 0, random.uniform(-0.1, 0.1))))
    for i, x in enumerate((-1.05, -0.5, 0.05, 0.6, 1.1)):
        plank = box("Lagging", (0.42, 0.9, 0.04), (x, random.uniform(-0.05, 0.05), 2.65), bevel=0.008,
                    rot=(random.uniform(-0.04, 0.04), 0, random.uniform(-0.08, 0.08)))
        roughen(plank, 0.006, 4.0, subdivide=1)
        parts.append(plank)
    export(join(parts, "TimberFrame"), "timber_frame.obj")


def altar():
    """Altar del Tío: mesa de piedra labrada, aguayo encima, velas con chorreado y ofrendas."""
    reset()
    stone = []
    base = box("Base", (1.1, 0.6, 0.62), (0, 0, 0.31), bevel=0.03)
    roughen(base, 0.012, 3.0, subdivide=2)
    stone.append(base)
    top = box("Top", (1.22, 0.7, 0.08), (0, 0, 0.66), bevel=0.02)
    roughen(top, 0.008, 4.0, subdivide=1)
    stone.append(top)
    export(join(stone, "AltarStone"), "altar_stone.obj")
    reset()
    cloth = box("Aguayo", (1.0, 0.62, 0.012), (0, 0, 0.706), bevel=0)
    flap = box("Flap", (1.0, 0.012, 0.22), (0, -0.312, 0.6), bevel=0)
    export(join([cloth, flap], "Aguayo"), "altar_cloth.obj")
    reset()
    wax = []
    for x, y, h in ((-0.4, 0.05, 0.16), (0.38, 0.0, 0.12), (0.3, -0.18, 0.2)):
        candle = cylinder("Candle", 0.025, h, (x, y, 0.712 + h / 2), verts=12)
        roughen(candle, 0.002, 20.0)
        wax.append(candle)
        pool = cylinder("Pool", 0.06, 0.008, (x, y, 0.716), verts=16)
        roughen(pool, 0.01, 12.0)
        wax.append(pool)
    export(join(wax, "Candles"), "altar_candles.obj")


def items():
    """Ofrendas y objetos que se recogen."""
    reset()
    bag = cylinder("Bag", 0.07, 0.12, (0, 0, 0.06), verts=16)
    roughen(bag, 0.012, 8.0, subdivide=2)
    bm = bmesh.new()
    bm.from_mesh(bag.data)
    for v in bm.verts:
        if v.co.z > 0.1:
            v.co.x *= 0.55
            v.co.y *= 0.55
    bm.to_mesh(bag.data)
    bm.free()
    export(join([bag], "CocaBag"), "coca_bag.obj")
    reset()
    leaves = []
    for i in range(7):
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.03, segments=8, ring_count=4,
                                             location=(random.uniform(-0.05, 0.05), random.uniform(-0.05, 0.05), 0.12))
        leaf = active()
        leaf.scale = (1.0, 0.45, 0.06)
        leaf.rotation_euler = (0, 0, random.uniform(0, math.pi))
        bpy.ops.object.transform_apply(scale=True, rotation=True)
        leaves.append(leaf)
    export(join(leaves, "CocaLeaves"), "coca_leaves.obj")
    reset()
    body = cylinder("Bottle", 0.035, 0.15, (0, 0, 0.075), verts=20, bevel=0.01)
    neck = cylinder("Neck", 0.013, 0.07, (0, 0, 0.18), verts=14)
    shoulder = cylinder("Shoulder", 0.03, 0.02, (0, 0, 0.155), verts=20)
    export(join([body, neck, shoulder], "Bottle"), "bottle_glass.obj")
    reset()
    cap = cylinder("Cap", 0.015, 0.022, (0, 0, 0.225), verts=14)
    label = cylinder("Label", 0.0365, 0.07, (0, 0, 0.07), verts=20)
    export(join([cap, label], "BottleLabel"), "bottle_label.obj")
    reset()
    pack = box("Pack", (0.055, 0.085, 0.022), (0, 0, 0.011), bevel=0.003)
    export(join([pack], "Pack"), "cigarette_pack.obj")
    reset()
    sticks = [cylinder("Cig", 0.004, 0.07, (-0.02 + i * 0.012, 0.06, 0.006), rot=(math.pi / 2, 0, 0.2 * i), verts=8)
              for i in range(3)]
    export(join(sticks, "Cigarettes"), "cigarettes.obj")
    reset()
    rocks = []
    for i in range(4):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.035,
                                              location=(random.uniform(-0.04, 0.04), random.uniform(-0.04, 0.04), 0.03))
        rock = active()
        roughen(rock, 0.012, 25.0)
        rocks.append(rock)
    export(join(rocks, "Carbide"), "carbide_chunks.obj")
    reset()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3, radius=0.06, location=(0, 0, 0.045))
    stone_ob = active()
    stone_ob.scale = (1.0, 0.85, 0.7)
    bpy.ops.object.transform_apply(scale=True)
    roughen(stone_ob, 0.015, 12.0)
    export(join([stone_ob], "Stone"), "stone.obj")


def silver_vein():
    """Veta de plata: una costra metálica irregular pegada a la pared, no un palo flotando."""
    reset()
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=96, y_subdivisions=32, size=1)
    vein = active()
    vein.scale = (2.2, 0.7, 1)
    bpy.ops.object.transform_apply(scale=True)
    bm = bmesh.new()
    bm.from_mesh(vein.data)
    keep = []
    for v in bm.verts:
        band = 0.07 + 0.05 * noise.noise(Vector((v.co.x * 3, 0, 0))) + 0.03 * noise.noise(Vector((v.co.x * 11, 4, 0)))
        center = 0.12 * math.sin(v.co.x * 2.5) + 0.04 * noise.noise(Vector((v.co.x * 6, 9, 0)))
        if abs(v.co.y - center) > band:
            keep.append(v)
    bmesh.ops.delete(bm, geom=keep, context="VERTS")
    for v in bm.verts:
        v.co.z = 0.015 + noise.noise(v.co * 9) * 0.01
    bm.to_mesh(vein.data)
    bm.free()
    mod = vein.modifiers.new("Thick", "SOLIDIFY")
    mod.thickness = 0.02
    # La veta queda en el plano YZ: se pega a una pared que mira hacia +X
    vein.rotation_euler = (math.pi / 2, 0, math.pi / 2)
    bpy.ops.object.transform_apply(rotation=True)
    export(join([vein], "SilverVein"), "silver_vein.obj")


for build in (mine_cart, timber_frame, altar, items, silver_vein):
    build()
