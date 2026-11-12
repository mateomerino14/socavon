"""Arma un personaje humano con MakeHuman (CC0) y lo anima con la biblioteca de Quaternius (CC0).

El cuerpo sale de la malla base de MakeHuman deformada con sus objetivos (género, edad, origen,
estatura); la ropa, el pelo, los ojos y las cejas se ajustan al cuerpo con sus archivos .mhclo, y
todo se pesa al esqueleto por defecto de MakeHuman. Las animaciones de Quaternius se pasan a ese
esqueleto comparando cada hueso con su pose de descanso en T.

Uso: python3 make_human.py <personaje.json> <makehuman/data> <assets_sistema> <animaciones.gltf> <salida>

El JSON describe al personaje; ver characters/tio.json. Con "extras" se le suma un script que
agrega piezas propias (cuernos, barba...) colgadas de los huesos.
"""

import bpy  # noqa: I001
import addon_utils
import bmesh
import json
import os
import sys

import numpy as np
from bpy_extras import anim_utils
from mathutils import Matrix, Vector

spec_path, mh_data, assets, ual_path, out_dir = sys.argv[-5:]
spec = json.load(open(spec_path))
addon_utils.enable("io_scene_gltf2", default_set=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
FPS = 30
scene.render.fps = FPS
# MakeHuman mide en decímetros
UNIT = 0.1
BODY_VERTS = 13380


# --- Lectura de archivos de MakeHuman ---


def read_obj(path):
    """Lee vértices, coordenadas de textura y caras (con su grupo) de un OBJ."""
    verts, uvs, faces, groups = [], [], [], []
    group = ""
    for line in open(path):
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "v":
            verts.append([float(x) for x in parts[1:4]])
        elif parts[0] == "vt":
            uvs.append([float(x) for x in parts[1:3]])
        elif parts[0] == "g":
            group = parts[1] if len(parts) > 1 else ""
        elif parts[0] == "f":
            corners = [p.split("/") for p in parts[1:]]
            vi = [int(c[0]) - 1 for c in corners]
            ti = [int(c[1]) - 1 if len(c) > 1 and c[1] else -1 for c in corners]
            faces.append((vi, ti))
            groups.append(group)
    return np.array(verts), np.array(uvs) if uvs else np.zeros((0, 2)), faces, groups


def read_target(path):
    """Lee un objetivo: desplazamientos por índice de vértice."""
    idx, delta = [], []
    for line in open(path):
        if line.startswith("#") or not line.strip():
            continue
        parts = line.split()
        idx.append(int(parts[0]))
        delta.append([float(x) for x in parts[1:4]])
    return np.array(idx, dtype=int), np.array(delta).reshape(-1, 3)


def read_mhclo(path):
    """Lee un .mhclo: referencias al cuerpo, escalas y vértices del cuerpo que tapa."""
    refs, scales, deleted = [], {}, []
    obj_file, material = None, None
    section = None
    for line in open(path):
        if line.startswith("#"):
            continue
        parts = line.split()
        if not parts:
            continue
        key = parts[0]
        if key in ("x_scale", "y_scale", "z_scale"):
            scales[key[0]] = (int(parts[1]), int(parts[2]), float(parts[3]))
        elif key == "obj_file":
            obj_file = parts[1]
        elif key == "material":
            material = parts[1]
        elif key == "verts":
            section = "verts"
        elif key == "delete_verts":
            section = "delete"
        elif section == "verts" and key[0].isdigit():
            if len(parts) == 1:
                refs.append(((int(parts[0]),) * 3, (1.0, 0.0, 0.0), (0.0, 0.0, 0.0)))
            else:
                refs.append(
                    (
                        tuple(int(x) for x in parts[0:3]),
                        tuple(float(x) for x in parts[3:6]),
                        tuple(float(x) for x in parts[6:9]),
                    )
                )
        elif section == "delete":
            i = 0
            while i < len(parts):
                if i + 2 < len(parts) and parts[i + 1] == "-":
                    deleted.extend(range(int(parts[i]), int(parts[i + 2]) + 1))
                    i += 3
                else:
                    deleted.append(int(parts[i]))
                    i += 1
    return refs, scales, deleted, obj_file, material


def read_mhmat(path):
    """Lee las texturas de un material de MakeHuman."""
    textures = {}
    for line in open(path):
        parts = line.split()
        if len(parts) == 2 and parts[0].endswith("Texture"):
            textures[parts[0]] = os.path.join(os.path.dirname(path), os.path.basename(parts[1]))
    return textures


# --- Cuerpo ---

base_verts, base_uvs, base_faces, base_groups = read_obj(
    os.path.join(mh_data, "3dobjs", "base.obj")
)
coords = base_verts.copy()
for name, weight in spec["targets"].items():
    idx, delta = read_target(os.path.join(mh_data, "targets", name + ".target"))
    coords[idx] += delta * weight


# Los pies quedan sobre el suelo
GROUND = coords[:BODY_VERTS, 1].min()


def to_blender(points):
    """De MakeHuman (Y arriba, mirando a +Z, decímetros) a Blender (Z arriba, mirando a −Y)."""
    p = np.asarray(points) * UNIT
    return np.stack([p[..., 0], -p[..., 2], p[..., 1] - GROUND * UNIT], axis=-1)


skel = json.load(open(os.path.join(mh_data, "rigs", "default.mhskel")))
bone_weights = json.load(open(os.path.join(mh_data, "rigs", "default_weights.mhw")))["weights"]
vertex_weights = [dict() for _ in range(len(coords))]
for bone, pairs in bone_weights.items():
    for v, w in pairs:
        vertex_weights[v][bone] = w


def joint(name):
    """Posición de una articulación: el centro de sus vértices de ayuda."""
    return to_blender(coords[skel["joints"][name]].mean(axis=0))


# --- Esqueleto ---

rig_data = bpy.data.armatures.new("HumanRig")
rig = bpy.data.objects.new(spec["name"] + "Rig", rig_data)
scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
order = []


def add_bone(name):
    """Crea un hueso después de su padre, con el giro que marca su plano."""
    if name in rig_data.edit_bones:
        return
    info = skel["bones"][name]
    if info["parent"]:
        add_bone(info["parent"])
    bone = rig_data.edit_bones.new(name)
    bone.head = Vector(joint(info["head"]))
    bone.tail = Vector(joint(info["tail"]))
    if (bone.tail - bone.head).length < 1e-4:
        bone.tail = bone.head + Vector((0, 0, 0.01))
    if info["parent"]:
        bone.parent = rig_data.edit_bones[info["parent"]]
    plane = skel["planes"].get(info["rotation_plane"]) if info["rotation_plane"] else None
    if plane:
        a, b, c = (Vector(joint(j)) for j in plane)
        normal = (b - a).cross(c - b)
        if normal.length > 1e-6:
            bone.align_roll(normal.normalized())
    order.append(name)


for bone_name in skel["bones"]:
    add_bone(bone_name)
bpy.ops.object.mode_set(mode="OBJECT")


def make_mesh(name, verts, uvs, faces, weights, material):
    """Crea una malla pesada al esqueleto con su material."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], [f[0] for f in faces])
    if len(uvs):
        layer = mesh.uv_layers.new(name="UV")
        loop_uvs = []
        for vi, ti in faces:
            loop_uvs.extend(uvs[t] if t >= 0 else (0.0, 0.0) for t in ti)
        layer.data.foreach_set("uv", np.array(loop_uvs).ravel())
    mesh.polygons.foreach_set("use_smooth", [True] * len(mesh.polygons))
    mesh.materials.append(material)
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    ob.parent = rig
    ob.modifiers.new("Armature", "ARMATURE").object = rig
    groups = {}
    for v, vw in enumerate(weights):
        for bone, w in vw.items():
            if w < 0.001:
                continue
            if bone not in groups:
                groups[bone] = ob.vertex_groups.new(name=bone)
            groups[bone].add([v], w, "REPLACE")
    return ob


def tinted(path, tint, name):
    """Carga la textura y la tiñe en los píxeles, para que el color viaje dentro del glTF."""
    image = bpy.data.images.load(path)
    if tuple(tint) == (1, 1, 1):
        return image
    pixels = np.empty(len(image.pixels), dtype=np.float32)
    image.pixels.foreach_get(pixels)
    pixels = pixels.reshape(-1, 4)
    pixels[:, :3] *= np.array(tint, dtype=np.float32)
    copy = bpy.data.images.new(name + "_color", image.size[0], image.size[1], alpha=True)
    copy.pixels.foreach_set(pixels.ravel())
    folder = os.path.join(out_dir, "tenidas")
    os.makedirs(folder, exist_ok=True)
    copy.filepath_raw = os.path.join(folder, name.lower() + "_color.png")
    copy.file_format = "PNG"
    copy.save()
    return copy


def material(name, textures, tint=(1, 1, 1), alpha=False, roughness=0.8):
    """Material con la textura difusa (teñida), normales y transparencia recortada si hace falta."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    diffuse = textures.get("diffuseTexture")
    if diffuse and os.path.exists(diffuse):
        tex = nodes.new("ShaderNodeTexImage")
        tex.image = tinted(diffuse, tint, name)
        links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha:
            links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            mat.blend_method = "CLIP"
    normal = textures.get("normalmapTexture")
    if normal and os.path.exists(normal):
        ntex = nodes.new("ShaderNodeTexImage")
        ntex.image = bpy.data.images.load(normal)
        ntex.image.colorspace_settings.name = "Non-Color"
        nmap = nodes.new("ShaderNodeNormalMap")
        links.new(ntex.outputs["Color"], nmap.inputs["Color"])
        links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


hidden = set()
pieces = []
for piece in spec["pieces"]:
    folder = os.path.join(assets, piece["path"])
    mhclo = [f for f in os.listdir(folder) if f.endswith(".mhclo")][0]
    refs, scales, deleted, obj_file, mat_file = read_mhclo(os.path.join(folder, mhclo))
    hidden.update(deleted)
    pieces.append((piece, folder, refs, scales, obj_file, mat_file))

# El cuerpo, sin los vértices de ayuda ni lo que tapa la ropa
body_faces = []
for (vi, ti), group in zip(base_faces, base_groups):
    if group == "body" and not any(v in hidden for v in vi):
        body_faces.append((vi, ti))
used = sorted({v for vi, _ in body_faces for v in vi})
remap = {v: i for i, v in enumerate(used)}
skin = spec["skin"]
skin_mat = material(
    "Piel",
    read_mhmat(os.path.join(assets, skin["path"], os.path.basename(skin["path"]) + ".mhmat")),
    skin["tint"],
    roughness=0.6,
)
make_mesh(
    spec["name"] + "Cuerpo",
    to_blender(coords[used]),
    base_uvs,
    [([remap[v] for v in vi], ti) for vi, ti in body_faces],
    [vertex_weights[v] for v in used],
    skin_mat,
)


def fit(refs, scales):
    """Ubica cada vértice de una pieza según sus tres vértices del cuerpo y le copia sus pesos."""
    axis_scale = []
    for axis, i in (("x", 0), ("y", 1), ("z", 2)):
        a, b, den = scales[axis]
        axis_scale.append(abs(coords[a][i] - coords[b][i]) / den)
    fitted, weights = [], []
    for r, w, d in refs:
        p = coords[r[0]] * w[0] + coords[r[1]] * w[1] + coords[r[2]] * w[2]
        fitted.append(p + np.array(d) * np.array(axis_scale))
        vw = {}
        for ri, wi in zip(r, w):
            for bone, bw in vertex_weights[ri].items():
                vw[bone] = vw.get(bone, 0.0) + bw * wi
        weights.append(vw)
    return to_blender(fitted), weights


fitted_pieces = {p[0]["name"]: fit(p[2], p[3])[0] for p in pieces}

# Ropa, pelo, ojos y cejas: cada vértice sigue a tres vértices del cuerpo
for piece, folder, refs, scales, obj_file, mat_file in pieces:
    verts, uvs, faces, _ = read_obj(os.path.join(folder, obj_file))
    fitted, weights = fit(refs, scales)
    if "under" in piece:
        # Lo que quedaría dentro de otra pieza (el pelo bajo el sombrero) se recorta
        ceiling = fitted_pieces[piece["under"]][:, 2].min() + piece.get("margin", 0.0)
        faces = [f for f in faces if fitted[f[0], 2].max() < ceiling]
    textures = read_mhmat(os.path.join(folder, mat_file))
    mat = material(piece["name"], textures, piece.get("tint", (1, 1, 1)), piece.get("alpha", False))
    make_mesh(spec["name"] + piece["name"], fitted, uvs, faces, weights, mat)


# --- Animaciones de Quaternius ---

# Cada hueso de MakeHuman copia el giro del hueso de Quaternius que le corresponde
MAP = {
    "spine05": "DEF-hips",
    "spine04": "DEF-spine.001",
    "spine03": "DEF-spine.001",
    "spine02": "DEF-spine.002",
    "spine01": "DEF-spine.003",
    "neck01": "DEF-neck",
    "neck02": "DEF-neck",
    "neck03": "DEF-neck",
    "head": "DEF-head",
    "jaw": "DEF-head",
}
for side in ("L", "R"):
    MAP.update(
        {
            f"clavicle.{side}": f"DEF-shoulder.{side}",
            f"shoulder01.{side}": f"DEF-upper_arm.{side}",
            f"upperarm01.{side}": f"DEF-upper_arm.{side}",
            f"upperarm02.{side}": f"DEF-upper_arm.{side}",
            f"lowerarm01.{side}": f"DEF-forearm.{side}",
            f"lowerarm02.{side}": f"DEF-forearm.{side}",
            f"wrist.{side}": f"DEF-hand.{side}",
            f"pelvis.{side}": "DEF-hips",
            f"upperleg01.{side}": f"DEF-thigh.{side}",
            f"upperleg02.{side}": f"DEF-thigh.{side}",
            f"lowerleg01.{side}": f"DEF-shin.{side}",
            f"lowerleg02.{side}": f"DEF-shin.{side}",
            f"foot.{side}": f"DEF-foot.{side}",
        }
    )
    for n in range(1, 6):
        MAP[f"toe{n}-1.{side}"] = f"DEF-toe.{side}"
    fingers = {1: "thumb", 2: "f_index", 3: "f_middle", 4: "f_ring", 5: "f_pinky"}
    for n, ual in fingers.items():
        for j in range(1, 4):
            if ual == "thumb":
                MAP[f"finger{n}-{j}.{side}"] = f"DEF-thumb.0{j}.{side}"
            else:
                MAP[f"finger{n}-{j}.{side}"] = f"DEF-{ual}.0{j}.{side}"
        if n > 1:
            MAP[f"metacarpal{n - 1}.{side}"] = f"DEF-hand.{side}"

bpy.ops.import_scene.gltf(filepath=ual_path)
source = bpy.data.objects["Rig"]
for ob in [o for o in scene.objects if o.type == "MESH" and o.parent == source]:
    bpy.data.objects.remove(ob)
for ob in [o for o in scene.objects if o.name.startswith("Icosphere")]:
    bpy.data.objects.remove(ob)
source.animation_data_create()
source.animation_data.action = None
for track in list(source.animation_data.nla_tracks):
    source.animation_data.nla_tracks.remove(track)


def world_rest(arm, name):
    """Matriz de descanso del hueso en el mundo."""
    return arm.matrix_world @ arm.data.bones[name].matrix_local


# Huesos que no tienen un par con la misma dirección: solo copian el giro, sin enderezarse
KEEP_DIRECTION = ("spine05", "jaw", "pelvis", "metacarpal", "toe", "neck", "head")

# Pose en T del esqueleto de MakeHuman: cada hueso apunta como su par de Quaternius en descanso
rest = {name: rig.data.bones[name].matrix_local.copy() for name in order}
t_pose = {}
for name in order:
    bone = rig.data.bones[name]
    parent = bone.parent
    if parent:
        local = rest[parent.name].inverted() @ rest[name]
        matrix = t_pose[parent.name] @ local
    else:
        matrix = rest[name].copy()
    if name in MAP and not name.startswith(KEEP_DIRECTION):
        wanted = (world_rest(source, MAP[name]).to_3x3() @ Vector((0, 1, 0))).normalized()
        current = matrix.to_3x3() @ Vector((0, 1, 0))
        turn = current.rotation_difference(wanted).to_matrix()
        matrix = Matrix.Translation(matrix.translation) @ (turn @ matrix.to_3x3()).to_4x4()
    t_pose[name] = matrix

source_hips = world_rest(source, "DEF-hips").translation
hip_scale = rest["spine05"].translation.z / source_hips.z


def retarget(action_name, new_name):
    """Pasa una animación de Quaternius al esqueleto del personaje, cuadro a cuadro."""
    action = bpy.data.actions[action_name]
    source.animation_data.action = action
    first, last = (int(round(x)) for x in action.frame_range)
    target = bpy.data.actions.new(new_name)
    target.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = target
    slot = target.slots.new("OBJECT", rig.name)
    rig.animation_data.action_slot = slot
    curves = anim_utils.action_ensure_channelbag_for_slot(target, slot).fcurves
    channels = {name: [] for name in order}
    for f in range(first, last + 1):
        scene.frame_set(f)
        pose = {}
        for name in order:
            bone = rig.data.bones[name]
            parent = bone.parent
            if parent:
                local = rest[parent.name].inverted() @ rest[name]
                base = pose[parent.name] @ local
            else:
                base = rest[name].copy()
            if name in MAP:
                src = MAP[name]
                now = source.matrix_world @ source.pose.bones[src].matrix
                delta = now.to_3x3() @ world_rest(source, src).to_3x3().inverted()
                rotation = delta @ t_pose[name].to_3x3()
                position = base.translation
                if parent is None or name == "spine05":
                    moved = (now.translation - world_rest(source, src).translation) * hip_scale
                    position = rest[name].translation + moved
                base = Matrix.Translation(position) @ rotation.to_4x4()
            pose[name] = base
        for name in order:
            bone = rig.data.bones[name]
            if bone.parent:
                local = rest[bone.parent.name].inverted() @ rest[name]
                basis = local.inverted() @ pose[bone.parent.name].inverted() @ pose[name]
            else:
                basis = rest[name].inverted() @ pose[name]
            channels[name].append(basis)
    count = last - first + 1
    for name in order:
        path = f'pose.bones["{name}"]'
        mats = channels[name]
        loc = np.array([list(m.to_translation()) for m in mats])
        rot = np.array([list(m.to_quaternion()) for m in mats])
        for i in range(1, count):
            if np.dot(rot[i], rot[i - 1]) < 0:
                rot[i] = -rot[i]
        for index in range(4):
            curve = curves.new(path + ".rotation_quaternion", index=index, group_name=name)
            curve.keyframe_points.add(count)
            curve.keyframe_points.foreach_set(
                "co", np.stack([np.arange(count), rot[:, index]], 1).ravel()
            )
        if name == "spine05" or rig.data.bones[name].parent is None:
            for index in range(3):
                curve = curves.new(path + ".location", index=index, group_name=name)
                curve.keyframe_points.add(count)
                curve.keyframe_points.foreach_set(
                    "co", np.stack([np.arange(count), loc[:, index]], 1).ravel()
                )
    for curve in curves:
        curve.update()
    track = rig.animation_data.nla_tracks.new()
    track.name = new_name
    track.strips.new(new_name, 0, target)
    rig.animation_data.action = None
    print(f"{new_name}: {count} cuadros")


for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
for source_name, new_name in spec["animations"].items():
    retarget(source_name, new_name)

bpy.data.objects.remove(source)
for pb in rig.pose.bones:
    pb.matrix_basis = Matrix.Identity(4)

# Piezas propias del personaje (cuernos, barba, cigarro...): un script aparte las agrega al esqueleto
extras = spec.get("extras")
if extras:
    extras_path = os.path.join(os.path.dirname(os.path.abspath(spec_path)), extras)
    exec(compile(open(extras_path).read(), extras_path, "exec"), {"__name__": "extras"})

os.makedirs(out_dir, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, spec["file"] + ".blend"))


def export(file_name):
    """Exporta el esqueleto y sus mallas a un glTF con todas las animaciones."""
    bpy.ops.object.select_all(action="DESELECT")
    for ob in scene.objects:
        ob.select_set(ob == rig or ob.parent == rig)
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, file_name + ".gltf"),
        use_selection=True,
        export_format="GLTF_SEPARATE",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_image_format="JPEG",
        export_jpeg_quality=88,
    )


export(spec["file"])
print("personaje exportado")

# Versión en primera persona: solo los brazos y las manos, con las animaciones de las manos
arms = spec.get("first_person")
if arms:
    ARM_BONES = ("clavicle", "shoulder", "upperarm", "lowerarm", "wrist", "metacarpal", "finger")
    # Se quedan las caras que tocan el brazo: así las mangas salen enteras y no en pedazos sueltos.
    for ob in [o for o in scene.objects if o.type == "MESH" and o.parent == rig]:
        names = {g.index: g.name for g in ob.vertex_groups}
        on_arm = set()
        for v in ob.data.vertices:
            weight = sum(g.weight for g in v.groups if names[g.group].startswith(ARM_BONES))
            if weight >= arms["min_weight"]:
                on_arm.add(v.index)
        if not on_arm:
            bpy.data.objects.remove(ob)
            continue
        mesh = bmesh.new()
        mesh.from_mesh(ob.data)
        doomed = [f for f in mesh.faces if not any(v.index in on_arm for v in f.verts)]
        bmesh.ops.delete(mesh, geom=doomed, context="FACES_ONLY")
        loose = [v for v in mesh.verts if not v.link_faces]
        bmesh.ops.delete(mesh, geom=loose, context="VERTS")
        mesh.to_mesh(ob.data)
        mesh.free()
    for track in list(rig.animation_data.nla_tracks):
        if track.name not in arms["animations"]:
            rig.animation_data.nla_tracks.remove(track)
    export(arms["file"])
    print("brazos exportados")
