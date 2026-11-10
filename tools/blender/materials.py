"""Pinta al Tío: arcilla roja barnizada y gastada, pintura negra, mixtura, ojos de vidrio, cuernos y serpentinas.

Uso: python3 materials.py <entrada.blend> <salida.blend>
"""

import bpy  # noqa: I001
import sys
from mathutils import Vector

src, out = sys.argv[-2], sys.argv[-1]
bpy.ops.wm.open_mainfile(filepath=src)
HEAD = Vector((0.0, 0.26, 1.92))


def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out_node = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs[0], out_node.inputs[0])
    return m, nt, bsdf


def node(nt, kind, **props):
    n = nt.nodes.new(kind)
    for k, v in props.items():
        if k.startswith("in_"):
            n.inputs[k[3:].replace("_", " ")].default_value = v
        else:
            setattr(n, k, v)
    return n


def ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0]
    els[1].position, els[1].color = stops[-1]
    for pos, col in stops[1:-1]:
        e = els.new(pos)
        e.color = col
    return r


def mix(nt, a, b, fac, blend="MIX"):
    m = nt.nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = blend
    L = nt.links
    if isinstance(fac, float):
        m.inputs["Factor"].default_value = fac
    else:
        L.new(fac, m.inputs["Factor"])
    for sock, val in ((m.inputs[6], a), (m.inputs[7], b)):
        if isinstance(val, tuple):
            sock.default_value = val
        else:
            L.new(val, sock)
    return m.outputs[2]


def sphere_mask(nt, pos, center, radii, softness):
    """1 dentro de un elipsoide en espacio de objeto, con borde suave."""
    L = nt.links
    sub = node(nt, "ShaderNodeVectorMath", operation="SUBTRACT")
    sub.inputs[1].default_value = center
    L.new(pos, sub.inputs[0])
    div = node(nt, "ShaderNodeVectorMath", operation="DIVIDE")
    div.inputs[1].default_value = radii
    L.new(sub.outputs[0], div.inputs[0])
    length = node(nt, "ShaderNodeVectorMath", operation="LENGTH")
    L.new(div.outputs[0], length.inputs[0])
    mr = node(nt, "ShaderNodeMapRange", in_From_Min=1.0, in_From_Max=1.0 - softness, in_To_Min=0.0, in_To_Max=1.0)
    L.new(length.outputs["Value"], mr.inputs["Value"])
    return mr.outputs["Result"]


def clay_material():
    m, nt, bsdf = new_mat("TioClay")
    L = nt.links
    coord = node(nt, "ShaderNodeTexCoord")
    pos = coord.outputs["Object"]
    # Pintura roja con variaciones y zonas gastadas donde asoma la arcilla
    paint_noise = node(nt, "ShaderNodeTexNoise", in_Scale=3.5, in_Detail=8.0, in_Roughness=0.6)
    L.new(pos, paint_noise.inputs["Vector"])
    paint = ramp(nt, [(0.3, (0.07, 0.006, 0.005, 1)), (0.55, (0.13, 0.012, 0.008, 1)), (0.8, (0.2, 0.025, 0.012, 1))])
    L.new(paint_noise.outputs["Fac"], paint.inputs["Fac"])
    wear_noise = node(nt, "ShaderNodeTexNoise", in_Scale=7.0, in_Detail=10.0, in_Roughness=0.7)
    L.new(pos, wear_noise.inputs["Vector"])
    wear = ramp(nt, [(0.62, (0, 0, 0, 1)), (0.7, (1, 1, 1, 1))])
    L.new(wear_noise.outputs["Fac"], wear.inputs["Fac"])
    color = mix(nt, paint.outputs["Color"], (0.22, 0.12, 0.07, 1), wear.outputs["Color"])
    # Hollín y suciedad en huecos y pies
    ao = node(nt, "ShaderNodeAmbientOcclusion", samples=8, in_Distance=0.06)
    cavity = ramp(nt, [(0.35, (1, 1, 1, 1)), (0.85, (0, 0, 0, 1))])
    L.new(ao.outputs["AO"], cavity.inputs["Fac"])
    color = mix(nt, color, (0.02, 0.012, 0.01, 1), cavity.outputs["Color"])
    sep = node(nt, "ShaderNodeSeparateXYZ")
    L.new(pos, sep.inputs[0])
    dirt = node(nt, "ShaderNodeMapRange", in_From_Min=0.35, in_From_Max=0.0, in_To_Min=0.0, in_To_Max=0.75)
    L.new(sep.outputs["Z"], dirt.inputs["Value"])
    color = mix(nt, color, (0.05, 0.035, 0.025, 1), dirt.outputs["Result"])
    # Pintura negra: cejas, contorno de ojos y boca
    black = sphere_mask(nt, pos, HEAD + Vector((0, 0.15, 0.075)), (0.15, 0.09, 0.04), 0.35)
    for s in (-1, 1):
        ring = sphere_mask(nt, pos, HEAD + Vector((0.072 * s, 0.16, 0.015)), (0.068, 0.06, 0.062), 0.3)
        black_max = node(nt, "ShaderNodeMath", operation="MAXIMUM")
        L.new(black, black_max.inputs[0])
        L.new(ring, black_max.inputs[1])
        black = black_max.outputs[0]
    mouth = sphere_mask(nt, pos, HEAD + Vector((0, 0.2, -0.145)), (0.1, 0.1, 0.07), 0.25)
    for s in (-1, 1):
        nostril = sphere_mask(nt, pos, HEAD + Vector((0.022 * s, 0.25, -0.05)), (0.022, 0.03, 0.02), 0.4)
        n_max = node(nt, "ShaderNodeMath", operation="MAXIMUM")
        L.new(mouth, n_max.inputs[0])
        L.new(nostril, n_max.inputs[1])
        mouth = n_max.outputs[0]
    mouth_max = node(nt, "ShaderNodeMath", operation="MAXIMUM")
    L.new(black, mouth_max.inputs[0])
    L.new(mouth, mouth_max.inputs[1])
    color = mix(nt, color, (0.012, 0.01, 0.01, 1), mouth_max.outputs[0])
    # Mixtura: papelitos de colores pegados en hombros y cabeza
    vor = node(nt, "ShaderNodeTexVoronoi", in_Scale=55.0)
    L.new(pos, vor.inputs["Vector"])
    dots = node(nt, "ShaderNodeMath", operation="LESS_THAN")
    dots.inputs[1].default_value = 0.07
    L.new(vor.outputs["Distance"], dots.inputs[0])
    high = node(nt, "ShaderNodeMapRange", in_From_Min=1.45, in_From_Max=1.65, in_To_Min=0.0, in_To_Max=1.0)
    L.new(sep.outputs["Z"], high.inputs["Value"])
    sparse = node(nt, "ShaderNodeMath", operation="GREATER_THAN")
    sparse.inputs[1].default_value = 0.55
    L.new(vor.outputs["Color"], sparse.inputs[0])
    confetti_mask = node(nt, "ShaderNodeMath", operation="MULTIPLY")
    L.new(dots.outputs[0], confetti_mask.inputs[0])
    L.new(high.outputs["Result"], confetti_mask.inputs[1])
    confetti_mask2 = node(nt, "ShaderNodeMath", operation="MULTIPLY")
    L.new(confetti_mask.outputs[0], confetti_mask2.inputs[0])
    L.new(sparse.outputs[0], confetti_mask2.inputs[1])
    hue = node(nt, "ShaderNodeCombineColor", mode="HSV", in_Green=0.85, in_Blue=0.8)
    L.new(vor.outputs["Color"], hue.inputs["Red"])
    color = mix(nt, color, hue.outputs["Color"], confetti_mask2.outputs[0])
    L.new(color, bsdf.inputs["Base Color"])
    # Barniz brillante desgastado
    rough = node(nt, "ShaderNodeMapRange", in_To_Min=0.28, in_To_Max=0.7)
    L.new(wear_noise.outputs["Fac"], rough.inputs["Value"])
    L.new(rough.outputs["Result"], bsdf.inputs["Roughness"])
    # Relieve fino de arcilla y grietas
    fine = node(nt, "ShaderNodeTexNoise", in_Scale=140.0, in_Detail=6.0)
    L.new(pos, fine.inputs["Vector"])
    cracks = node(nt, "ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE", in_Scale=9.0, in_Randomness=1.0)
    warp = node(nt, "ShaderNodeTexNoise", in_Scale=4.0, in_Detail=4.0)
    L.new(pos, warp.inputs["Vector"])
    warped = node(nt, "ShaderNodeVectorMath", operation="MULTIPLY_ADD")
    warped.inputs[1].default_value = (0.08, 0.08, 0.08)
    L.new(warp.outputs["Color"], warped.inputs[0])
    L.new(pos, warped.inputs[2])
    L.new(warped.outputs[0], cracks.inputs["Vector"])
    crack_line = node(nt, "ShaderNodeMapRange", in_From_Min=0.0, in_From_Max=0.008, in_To_Min=0.6, in_To_Max=1.0)
    L.new(cracks.outputs["Distance"], crack_line.inputs["Value"])
    height = node(nt, "ShaderNodeMath", operation="MULTIPLY_ADD")
    L.new(fine.outputs["Fac"], height.inputs[0])
    height.inputs[1].default_value = 0.4
    L.new(crack_line.outputs["Result"], height.inputs[2])
    bump = node(nt, "ShaderNodeBump", in_Strength=0.35, in_Distance=0.002)
    L.new(height.outputs[0], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def horn_material():
    m, nt, bsdf = new_mat("TioHorn")
    L = nt.links
    uv = node(nt, "ShaderNodeUVMap")
    sep = node(nt, "ShaderNodeSeparateXYZ")
    L.new(uv.outputs["UV"], sep.inputs[0])
    grad = ramp(nt, [(0.0, (0.03, 0.02, 0.015, 1)), (0.55, (0.22, 0.13, 0.07, 1)), (1.0, (0.75, 0.66, 0.5, 1))])
    L.new(sep.outputs["Y"], grad.inputs["Fac"])
    streak = node(nt, "ShaderNodeTexNoise", in_Scale=30.0, in_Detail=6.0)
    L.new(uv.outputs["UV"], streak.inputs["Vector"])
    col = mix(nt, grad.outputs["Color"], (0.02, 0.015, 0.01, 1), 0.0)
    col_node = col.node
    L.new(streak.outputs["Fac"], col_node.inputs["Factor"])
    col_node.blend_type = "MULTIPLY"
    L.new(col, bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.35
    rings = node(nt, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="Y", in_Scale=6.0,
                 in_Distortion=3.0)
    L.new(uv.outputs["UV"], rings.inputs["Vector"])
    bump = node(nt, "ShaderNodeBump", in_Strength=0.5, in_Distance=0.003)
    L.new(rings.outputs["Fac"], bump.inputs["Height"])
    L.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def eye_material():
    m, nt, bsdf = new_mat("TioEye")
    L = nt.links
    coord = node(nt, "ShaderNodeTexCoord")
    norm = node(nt, "ShaderNodeVectorMath", operation="NORMALIZE")
    L.new(coord.outputs["Object"], norm.inputs[0])
    sep = node(nt, "ShaderNodeSeparateXYZ")
    L.new(norm.outputs[0], sep.inputs[0])
    iris = ramp(nt, [(0.55, (0.75, 0.66, 0.45, 1)), (0.6, (0.35, 0.05, 0.01, 1)),
                     (0.8, (0.9, 0.45, 0.04, 1)), (0.955, (0.6, 0.12, 0.01, 1)), (0.96, (0.0, 0.0, 0.0, 1)),
                     (1.0, (0.0, 0.0, 0.0, 1))])
    L.new(sep.outputs["Y"], iris.inputs["Fac"])
    L.new(iris.outputs["Color"], bsdf.inputs["Base Color"])
    L.new(iris.outputs["Color"], bsdf.inputs["Emission Color"])
    bsdf.inputs["Emission Strength"].default_value = 0.6
    bsdf.inputs["Roughness"].default_value = 0.08
    bsdf.inputs["Coat Weight"].default_value = 1.0
    bsdf.inputs["Coat Roughness"].default_value = 0.02
    return m


def simple(name, color, rough, emission=0.0, metal=0.0):
    m, nt, bsdf = new_mat(name)
    bsdf.inputs["Base Color"].default_value = color
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission:
        bsdf.inputs["Emission Color"].default_value = color
        bsdf.inputs["Emission Strength"].default_value = emission
    return m


STREAMER_COLORS = [(0.9, 0.05, 0.35, 1), (0.95, 0.75, 0.05, 1), (0.05, 0.55, 0.9, 1),
                   (0.15, 0.75, 0.2, 1), (0.95, 0.35, 0.05, 1)]

mats = {
    "clay": clay_material(),
    "horn": horn_material(),
    "eye": eye_material(),
    "teeth": simple("TioTeeth", (0.78, 0.7, 0.52, 1), 0.3),
    "goatee": simple("TioBlackPaint", (0.012, 0.01, 0.01, 1), 0.3),
    "paper": simple("CigarettePaper", (0.85, 0.82, 0.75, 1), 0.6),
    "ember": simple("Ember", (1.0, 0.25, 0.02, 1), 0.5, emission=12.0),
    "streamers": [simple(f"Streamer{i}", c, 0.55) for i, c in enumerate(STREAMER_COLORS)],
}

for ob in bpy.data.objects:
    if ob.type != "MESH":
        continue
    ob.data.materials.clear()
    name = ob.name
    if name == "TioHigh":
        ob.data.materials.append(mats["clay"])
    elif name.startswith("Horn"):
        ob.data.materials.append(mats["horn"])
    elif name.startswith("Eye"):
        ob.data.materials.append(mats["eye"])
    elif name == "Teeth":
        ob.data.materials.append(mats["teeth"])
    elif name == "Goatee" or name.startswith("Claw"):
        ob.data.materials.append(mats["goatee"])
    elif name == "Cigarette":
        ob.data.materials.append(mats["paper"])
    elif name == "Ember":
        ob.data.materials.append(mats["ember"])
    elif name.startswith("Streamer"):
        ob.data.materials.append(mats["streamers"][int(ob.get("streamer_color", 0))])

bpy.ops.wm.save_as_mainfile(filepath=out)
print("materiales listos")
