"""Hornea el Tío de alta resolución a una malla de juego con texturas y exporta .glb.

Uso: python3 bake.py <pintado.blend> <carpeta_salida> <tamaño_textura>
"""

import bpy  # noqa: I001
import addon_utils
import os
import sys

src, out_dir, size = sys.argv[-3], sys.argv[-2], int(sys.argv[-1])
addon_utils.enable("cycles", default_set=True)
addon_utils.enable("io_scene_gltf2", default_set=True)
bpy.ops.wm.open_mainfile(filepath=src)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
os.makedirs(out_dir, exist_ok=True)

BODY_RATIO = 0.075

high = [o for o in scene.objects if o.type == "MESH"]
for o in high:
    o.select_set(False)

# Copias de juego: aplica modificadores y simplifica el cuerpo
low_parts = []
deps = bpy.context.evaluated_depsgraph_get()
for o in high:
    me = bpy.data.meshes.new_from_object(o.evaluated_get(deps))
    me.transform(o.matrix_world)
    copy = bpy.data.objects.new(o.name + "_low", me)
    scene.collection.objects.link(copy)
    if o.name == "TioHigh":
        dec = copy.modifiers.new("Dec", "DECIMATE")
        dec.ratio = BODY_RATIO
        bpy.context.view_layer.objects.active = copy
        bpy.ops.object.modifier_apply(modifier="Dec")
    low_parts.append(copy)

bpy.ops.object.select_all(action="DESELECT")
for o in low_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = low_parts[0]
bpy.ops.object.join()
low = bpy.context.active_object
low.name = "Tio"
low.data.name = "Tio"
for uv in list(low.data.uv_layers):
    low.data.uv_layers.remove(uv)
low.data.uv_layers.new(name="UVMap")
low.data.materials.clear()
for poly in low.data.polygons:
    poly.use_smooth = True
print("caras de juego", len(low.data.polygons))

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.uv.pack_islands(margin=0.003)
bpy.ops.object.mode_set(mode="OBJECT")

# Material de juego con las imágenes a hornear
mat = bpy.data.materials.new("TioBaked")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
low.data.materials.append(mat)


def image(name, non_color):
    img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    img.filepath_raw = os.path.join(out_dir, name + ".png")
    img.file_format = "PNG"
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    return img, tex


bakes = {
    "tio_albedo": ("DIFFUSE", False),
    "tio_roughness": ("ROUGHNESS", True),
    "tio_emission": ("EMIT", False),
    "tio_normal": ("NORMAL", True),
}
textures = {}
for name, (kind, non_color) in bakes.items():
    textures[name] = image(name, non_color)

bpy.ops.object.select_all(action="DESELECT")
for o in high:
    o.select_set(True)
low.select_set(True)
bpy.context.view_layer.objects.active = low
bake = scene.render.bake
bake.use_selected_to_active = True
bake.cage_extrusion = 0.006
bake.max_ray_distance = 0.012
bake.margin = 6
bake.use_pass_direct = False
bake.use_pass_indirect = False
bake.use_pass_color = True

for name, (kind, _) in bakes.items():
    img, tex = textures[name]
    for n in nt.nodes:
        n.select = False
    tex.select = True
    nt.nodes.active = tex
    bpy.ops.object.bake(type=kind)
    img.save()
    print("horneado", name)

L = nt.links
L.new(textures["tio_albedo"][1].outputs["Color"], bsdf.inputs["Base Color"])
L.new(textures["tio_roughness"][1].outputs["Color"], bsdf.inputs["Roughness"])
L.new(textures["tio_emission"][1].outputs["Color"], bsdf.inputs["Emission Color"])
bsdf.inputs["Emission Strength"].default_value = 1.0
normal_map = nt.nodes.new("ShaderNodeNormalMap")
L.new(textures["tio_normal"][1].outputs["Color"], normal_map.inputs["Color"])
L.new(normal_map.outputs["Normal"], bsdf.inputs["Normal"])

for o in high:
    bpy.data.objects.remove(o)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "tio_game.blend"))
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(out_dir, "tio.glb"), use_selection=True,
                          export_format="GLB", export_image_format="AUTO")
print("exportado")
