"""Le pone esqueleto al Tío de juego, pinta los pesos, anima y exporta glTF con animaciones.

Uso: python3 rig.py <tio_game.blend> <carpeta_salida>
"""

import bpy  # noqa: I001
import addon_utils
import math
import os
import sys
from mathutils import Euler, Matrix, Vector

src, out_dir = sys.argv[-2], sys.argv[-1]
addon_utils.enable("io_scene_gltf2", default_set=True)
bpy.ops.wm.open_mainfile(filepath=src)
scene = bpy.context.scene
scene.render.fps = 30
mesh = bpy.data.objects["Tio"]
HEAD = Vector((0.0, 0.26, 1.92))

# Huesos: nombre, cabeza, cola, padre, radio del cuerpo alrededor del hueso
BONES = [
    ("root", (0, 0, 0), (0, 0.3, 0), None, 0.0),
    ("hips", (0, 0.0, 0.98), (0, 0.07, 1.2), "root", 0.22),
    ("spine", (0, 0.07, 1.2), (0, 0.07, 1.42), "hips", 0.22),
    ("chest", (0, 0.07, 1.42), (0, 0.2, 1.72), "spine", 0.26),
    ("neck", (0, 0.2, 1.72), (0, 0.24, 1.82), "chest", 0.12),
    ("head", (0, 0.24, 1.82), (0, 0.26, 2.12), "neck", 0.2),
    ("jaw", (0, 0.26, 1.83), (0, 0.44, 1.72), "head", 0.08),
]
for s, side in ((-1, "L"), (1, "R")):
    BONES += [
        (f"clavicle.{side}", (0.05 * s, 0.12, 1.62), (0.37 * s, 0.1, 1.6), "chest", 0.1),
        (f"upper_arm.{side}", (0.37 * s, 0.1, 1.6), (0.47 * s, 0.17, 1.24), f"clavicle.{side}", 0.09),
        (f"forearm.{side}", (0.47 * s, 0.17, 1.24), (0.47 * s, 0.33, 0.94), f"upper_arm.{side}", 0.07),
        (f"hand.{side}", (0.47 * s, 0.33, 0.94), (0.47 * s, 0.46, 0.76), f"forearm.{side}", 0.07),
        (f"thigh.{side}", (0.13 * s, 0.0, 0.96), (0.17 * s, 0.11, 0.52), "hips", 0.14),
        (f"shin.{side}", (0.17 * s, 0.11, 0.52), (0.17 * s, 0.0, 0.11), f"thigh.{side}", 0.09),
        (f"foot.{side}", (0.17 * s, 0.0, 0.11), (0.17 * s, 0.24, 0.045), f"shin.{side}", 0.07),
    ]

arm_data = bpy.data.armatures.new("TioRig")
rig = bpy.data.objects.new("TioRig", arm_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, head, tail, parent, _ in BONES:
    bone = arm_data.edit_bones.new(name)
    bone.head = head
    bone.tail = tail
    bone.roll = 0.0
    if parent:
        bone.parent = arm_data.edit_bones[parent]
        bone.use_connect = False
bpy.ops.object.mode_set(mode="OBJECT")
arm_data.bones["root"].use_deform = False


def segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (p - (a + ab * t)).length


def jaw_weight(co):
    """Mandíbula: lo que queda bajo la boca y al frente de la cabeza."""
    if (co - HEAD).length > 0.3 or co.y < 0.3:
        return 0.0
    return max(0.0, min(1.0, (1.79 - co.z) / 0.03))


# Pesos: cada vértice sigue a los huesos más cercanos según el grosor del cuerpo
deforming = [(n, Vector(h), Vector(t), r) for n, h, t, _, r in BONES if n not in ("root", "jaw")]
groups = {n: mesh.vertex_groups.new(name=n) for n, *_ in BONES if n != "root"}
for v in mesh.data.vertices:
    co = v.co
    scores = []
    for name, a, b, radius in deforming:
        d = max(segment_distance(co, a, b), 0.01)
        scores.append(((radius / d) ** 6, name))
    scores.sort(reverse=True)
    top = scores[:3]
    total = sum(w for w, _ in top)
    if (co - HEAD).length < 0.3:
        top, total = [(1.0, "head")], 1.0
    jaw = jaw_weight(co)
    for w, name in top:
        weight = w / total * (1.0 - jaw)
        if weight > 0.01:
            groups[name].add([v.index], weight, "REPLACE")
    if jaw > 0.0:
        groups["jaw"].add([v.index], jaw, "REPLACE")

mesh.parent = rig
mod = mesh.modifiers.new("Armature", "ARMATURE")
mod.object = rig

# Animación: rotaciones en ejes del mundo (X lateral, Y al frente, Z arriba) en grados
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"


def pose(rotations, offsets=None):
    for pb in rig.pose.bones:
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
    for name, (x, y, z) in rotations.items():
        rest = rig.data.bones[name].matrix_local.to_3x3()
        world = Euler((math.radians(x), math.radians(y), math.radians(z)), "XYZ").to_matrix()
        local = rest.inverted() @ world @ rest
        rig.pose.bones[name].rotation_quaternion = local.to_quaternion()
    for name, offset in (offsets or {}).items():
        rest = rig.data.bones[name].matrix_local.to_3x3()
        rig.pose.bones[name].location = rest.inverted() @ Vector(offset)


def key_all(frame):
    for pb in rig.pose.bones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def make_action(name, frames, step, builder):
    rig.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    for frame in list(range(0, frames, step)) + [frames]:
        rotations, offsets = builder(frame / frames)
        pose(rotations, offsets)
        key_all(frame)
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    track.strips.new(name, 0, action)
    rig.animation_data.action = None


def legs(t, swing, knee, lift):
    rot = {}
    for side, phase in (("L", 0.0), ("R", math.pi)):
        a = t + phase
        thigh = swing * math.sin(a)
        bend = -(8 + knee * max(0.0, math.cos(a)))
        rot[f"thigh.{side}"] = (thigh + lift, 0, 0)
        rot[f"shin.{side}"] = (bend, 0, 0)
        rot[f"foot.{side}"] = (-(thigh + bend) * 0.5, 0, 0)
    return rot


def arms(t, swing, elbow, raise_deg):
    rot = {}
    for side, phase, s in (("L", math.pi, -1), ("R", 0.0, 1)):
        a = t + phase
        rot[f"upper_arm.{side}"] = (swing * math.sin(a) + raise_deg, 0, 6 * s)
        rot[f"forearm.{side}"] = (elbow + elbow * 0.5 * max(0.0, math.sin(a)), 0, 0)
        rot[f"hand.{side}"] = (10, 0, 0)
    return rot


def idle(p):
    t = p * math.tau
    rot = arms(t, 2, 12, 0)
    rot.update(legs(0, 0, 0, 0))
    rot["spine"] = (-10 + 1.5 * math.sin(t), 0, 0)
    rot["chest"] = (-6 + 2.5 * math.sin(t), 0, 0)
    rot["neck"] = (8, 0, 0)
    rot["head"] = (6, 10 * math.sin(t * 0.5) ** 3, 25 * math.sin(t))
    rot["jaw"] = (-3 - 3 * max(0.0, math.sin(t)), 0, 0)
    return rot, {"hips": (0, 0, -0.02 + 0.01 * math.sin(t))}


def walk(p):
    t = p * math.tau
    rot = legs(t, 24, 38, 0)
    rot.update(arms(t, 16, 14, 0))
    rot["hips"] = (0, 5 * math.sin(t), 7 * math.sin(t))
    rot["spine"] = (-12, 0, -4 * math.sin(t))
    rot["chest"] = (-6, -3 * math.sin(t), -5 * math.sin(t))
    rot["neck"] = (10, 0, 0)
    rot["head"] = (6, 12, 4 * math.sin(t))
    rot["jaw"] = (-4, 0, 0)
    return rot, {"hips": (0, 0, -0.03 - 0.04 * abs(math.sin(t)))}


def run(p):
    t = p * math.tau
    rot = legs(t, 42, 85, 12)
    rot.update(arms(t, 40, 45, 10))
    rot["hips"] = (-8, 6 * math.sin(t), 10 * math.sin(t))
    rot["spine"] = (-22, 0, -6 * math.sin(t))
    rot["chest"] = (-12, -4 * math.sin(t), -8 * math.sin(t))
    rot["neck"] = (22, 0, 0)
    rot["head"] = (16, 8, 0)
    rot["jaw"] = (-18, 0, 0)
    return rot, {"hips": (0, 0.05, -0.1 - 0.07 * abs(math.sin(t)))}


def catch(p):
    lunge = min(1.0, p / 0.3)
    ease = 1 - (1 - lunge) ** 3
    shake = math.sin(p * 60) * 3 * min(1.0, p * 3)
    rot = legs(0, 0, 0, 0)
    rot["thigh.L"] = (30 * ease, 0, 0)
    rot["shin.L"] = (-45 * ease, 0, 0)
    rot["thigh.R"] = (-15 * ease, 0, 0)
    for side, s in (("L", -1), ("R", 1)):
        rot[f"upper_arm.{side}"] = (95 * ease, 0, -18 * s * ease)
        rot[f"forearm.{side}"] = (25 * ease, 0, 0)
        rot[f"hand.{side}"] = (-25 * ease, 0, 0)
    rot["spine"] = (-10 * ease, 0, 0)
    rot["chest"] = (-8 * ease + shake, 0, 0)
    rot["neck"] = (20 * ease, 0, 0)
    rot["head"] = (10 * ease, 18 * ease + shake, shake)
    rot["jaw"] = (-35 * ease, 0, 0)
    return rot, {"hips": (0, 0.06 * ease, -0.06 * ease)}


make_action("idle", 90, 3, idle)
make_action("walk", 32, 2, walk)
make_action("run", 20, 1, run)
make_action("catch", 36, 1, catch)
pose({}, {})

os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "tio_rigged.blend"))
bpy.ops.object.select_all(action="DESELECT")
mesh.select_set(True)
rig.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=os.path.join(out_dir, "tio.gltf"),
    use_selection=True,
    export_format="GLTF_SEPARATE",
    export_image_format="AUTO",
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_force_sampling=True,
)
print("rig exportado")
