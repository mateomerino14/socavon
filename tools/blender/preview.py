"""Renderiza vistas de revisión del Tío: python3 preview.py <archivo.blend> <prefijo_salida> [muestras]"""

import math
import sys

import bpy
from mathutils import Vector

import addon_utils

blend, prefix = sys.argv[-3], sys.argv[-2]
samples = int(sys.argv[-1])
addon_utils.enable("cycles", default_set=True)
bpy.ops.wm.open_mainfile(filepath=blend)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = samples
scene.cycles.use_denoising = True
scene.render.resolution_x = 720
scene.render.resolution_y = 900
scene.render.film_transparent = False
scene.view_settings.view_transform = "AgX"
scene.view_settings.look = "AgX - Medium High Contrast"

world = bpy.data.worlds.new("Dark") if not scene.world else scene.world
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.01, 0.01, 0.012, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.0

# Material provisional para objetos sin material
grey = bpy.data.materials.get("PreviewClay") or bpy.data.materials.new("PreviewClay")
grey.use_nodes = True
grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.18, 0.1, 1)
for ob in scene.objects:
    if ob.type == "MESH" and not ob.data.materials:
        ob.data.materials.append(grey)

for ob in [o for o in scene.objects if o.type in {"LIGHT", "CAMERA"}]:
    bpy.data.objects.remove(ob)


def light(name, kind, loc, energy, color, size=1.0):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == "AREA":
        data.size = size
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    ob.location = loc
    direction = Vector((0, 0, 1.5)) - Vector(loc)
    ob.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return ob


# Luz cálida de lámpara de carburo desde abajo-adelante, contraluz fría
light("Lamp", "AREA", (0.6, 2.2, 1.2), 260, (1.0, 0.68, 0.38), 0.6)
light("Rim", "AREA", (-1.2, -1.6, 2.6), 180, (0.45, 0.55, 0.9), 1.0)
light("Fill", "AREA", (-1.8, 1.4, 1.6), 30, (1.0, 0.8, 0.6), 2.0)

floor_mesh = bpy.data.meshes.new("Floor")
import bmesh  # noqa: E402

bm = bmesh.new()
bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=6)
bm.to_mesh(floor_mesh)
floor = bpy.data.objects.new("Floor", floor_mesh)
scene.collection.objects.link(floor)
fm = bpy.data.materials.new("FloorMat")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.05, 0.04, 0.035, 1)
floor_mesh.materials.append(fm)

cam_data = bpy.data.cameras.new("Cam")
cam_data.lens = 50
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

views = {
    "frente": (Vector((0.9, 3.6, 1.55)), Vector((0, 0.2, 1.25))),
    "cara": (Vector((0.35, 1.35, 1.98)), Vector((0, 0.35, 1.88))),
    "perfil": (Vector((3.6, 0.6, 1.5)), Vector((0, 0.15, 1.2))),
}
for name, (loc, target) in views.items():
    cam.location = loc
    cam.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 85 if name == "cara" else 45
    scene.render.filepath = f"{prefix}_{name}.png"
    bpy.ops.render.render(write_still=True)
    print("render", name)
del math
