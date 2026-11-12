"""Casco de minero con su lámpara de carburo, para los personajes de la mina. make_human.py
ejecuta este archivo con el cuerpo y el esqueleto ya armados.

El casco se pesa entero al hueso de la cabeza, así la sigue al moverse. El personaje mira hacia −Y.
"""

import bmesh
import bpy
from mathutils import Matrix, Vector

SHELL_RADIUS = 0.125
BRIM_RADIUS = 0.155
BRIM_THICKNESS = 0.012
QUARTER_TURN = 1.5708

rig = next(ob for ob in bpy.context.scene.objects if ob.type == "ARMATURE")


def material(name, color, roughness, metallic=0.0, emission=None):
    """Material liso, con brillo propio si se pide."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = 4.0
    return mat


def add(name, mesh, mat):
    """Crea el objeto y lo pesa entero al hueso de la cabeza."""
    data = bpy.data.meshes.new(name)
    mesh.to_mesh(data)
    mesh.free()
    data.materials.append(mat)
    for poly in data.polygons:
        poly.use_smooth = True
    ob = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(ob)
    group = ob.vertex_groups.new(name="head")
    group.add([v.index for v in data.vertices], 1.0, "REPLACE")
    ob.parent = rig
    modifier = ob.modifiers.new("Esqueleto", "ARMATURE")
    modifier.object = rig
    return ob


def lying(mesh, at):
    """Acuesta la pieza hacia adelante y la lleva a su lugar."""
    bmesh.ops.rotate(mesh, matrix=Matrix.Rotation(QUARTER_TURN, 3, "X"), verts=mesh.verts)
    bmesh.ops.translate(mesh, vec=at, verts=mesh.verts)
    return mesh


head = rig.data.bones["head"]
top = rig.matrix_world @ head.tail_local
neck = rig.matrix_world @ head.head_local
crown = neck + (top - neck) * 0.78

# Cáscara: media esfera algo alargada hacia adelante y atrás
shell = bmesh.new()
bmesh.ops.create_uvsphere(shell, u_segments=24, v_segments=12, radius=SHELL_RADIUS)
bmesh.ops.delete(shell, geom=[v for v in shell.verts if v.co.z < -0.005], context="VERTS")
bmesh.ops.scale(shell, vec=Vector((0.95, 1.12, 0.85)), verts=shell.verts)
bmesh.ops.translate(shell, vec=crown, verts=shell.verts)
shell_mat = material("Casco", (0.55, 0.42, 0.18), 0.55)
add("Casco", shell, shell_mat)

# Ala: un anillo plano alrededor de la base
brim = bmesh.new()
bmesh.ops.create_cone(
    brim, segments=24, radius1=BRIM_RADIUS, radius2=BRIM_RADIUS, depth=BRIM_THICKNESS
)
bmesh.ops.scale(brim, vec=Vector((0.95, 1.15, 1.0)), verts=brim.verts)
bmesh.ops.translate(brim, vec=crown + Vector((0.0, -0.01, 0.0)), verts=brim.verts)
add("Ala", brim, shell_mat)

# Lámpara de carburo al frente: cuerpo de bronce, reflector y llama
brass = material("Bronce", (0.7, 0.5, 0.25), 0.35, 1.0)
front = crown + Vector((0.0, -SHELL_RADIUS * 1.08, 0.035))
lamp = bmesh.new()
bmesh.ops.create_cone(lamp, segments=12, radius1=0.022, radius2=0.022, depth=0.05)
add("Lampara", lying(lamp, front), brass)
reflector = bmesh.new()
bmesh.ops.create_cone(reflector, segments=16, radius1=0.012, radius2=0.04, depth=0.02)
add("Reflector", lying(reflector, front + Vector((0.0, -0.03, 0.0))), brass)
flame = bmesh.new()
bmesh.ops.create_uvsphere(flame, u_segments=8, v_segments=6, radius=0.008)
bmesh.ops.translate(flame, vec=front + Vector((0.0, -0.035, 0.0)), verts=flame.verts)
add("Llama", flame, material("Llama", (1.0, 0.7, 0.3), 0.5, emission=(1.0, 0.65, 0.25)))
