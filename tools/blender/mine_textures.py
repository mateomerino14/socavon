"""Genera texturas repetibles de la mina: roca del Cerro Rico, barro con gravilla, madera vieja y hierro oxidado.

Hornea materiales procedurales de Blender sobre un plano usando ruido 4D en un toro, así que
los bordes empalman sin costura. Las normales y la oclusión se calculan de la altura con numpy.

Uso: python3 mine_textures.py <carpeta_salida> <tamaño>
"""

import bpy  # noqa: I001
import addon_utils
import math
import os
import sys

import numpy as np

out_dir, size = sys.argv[-2], int(sys.argv[-1])
addon_utils.enable("cycles", default_set=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 1
os.makedirs(out_dir, exist_ok=True)

bpy.ops.mesh.primitive_plane_add(size=2)
plane = bpy.context.active_object


class Graph:
    """Ayuda a armar nodos de material con menos ruido."""

    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.mat.use_nodes = True
        self.nt = self.mat.node_tree
        self.nt.nodes.clear()
        self.out = self.nt.nodes.new("ShaderNodeOutputMaterial")
        self.emit = self.nt.nodes.new("ShaderNodeEmission")
        self.nt.links.new(self.emit.outputs[0], self.out.inputs[0])
        self.target = self.nt.nodes.new("ShaderNodeTexImage")
        self.nt.nodes.active = self.target
        self._torus()

    def _torus(self):
        """Coordenadas 4D periódicas: (cos u, sin u, cos v) y W = sin v."""
        uv = self.node("ShaderNodeTexCoord").outputs["UV"]
        sep = self.node("ShaderNodeSeparateXYZ")
        self.link(uv, sep.inputs[0])
        parts = []
        for axis, fn in (("X", "COSINE"), ("X", "SINE"), ("Y", "COSINE"), ("Y", "SINE")):
            ang = self.math("MULTIPLY", sep.outputs[axis], math.tau)
            parts.append(self.math(fn, ang))
        comb = self.node("ShaderNodeCombineXYZ")
        for i in range(3):
            self.link(parts[i], comb.inputs[i])
        self.vec = comb.outputs[0]
        self.w = parts[3]

    def node(self, kind, **props):
        n = self.nt.nodes.new(kind)
        for k, v in props.items():
            if k.startswith("in_"):
                n.inputs[k[3:].replace("_", " ")].default_value = v
            else:
                setattr(n, k, v)
        return n

    def link(self, a, b):
        if isinstance(a, (int, float)):
            b.default_value = a
        else:
            self.nt.links.new(a, b)

    def math(self, op, a, b=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        self.link(a, n.inputs[0])
        if b is not None:
            self.link(b, n.inputs[1])
        return n.outputs[0]

    def noise(self, scale, detail=6.0, rough=0.55, distortion=0.0, offset=0.0):
        n = self.node("ShaderNodeTexNoise", noise_dimensions="4D", in_Scale=scale, in_Detail=detail,
                      in_Roughness=rough, in_Distortion=distortion)
        self.link(self._shift(offset), n.inputs["Vector"])
        self.link(self.w, n.inputs["W"])
        return n.outputs["Fac"]

    def voronoi(self, scale, feature="F1", output="Distance", offset=0.0, randomness=1.0):
        n = self.node("ShaderNodeTexVoronoi", voronoi_dimensions="4D", feature=feature, in_Scale=scale,
                      in_Randomness=randomness)
        self.link(self._shift(offset), n.inputs["Vector"])
        self.link(self.w, n.inputs["W"])
        return n.outputs[output]

    def _shift(self, offset):
        if not offset:
            return self.vec
        add = self.node("ShaderNodeVectorMath", operation="ADD")
        self.link(self.vec, add.inputs[0])
        add.inputs[1].default_value = (offset, offset * 1.7, offset * 0.6)
        return add.outputs[0]

    def remap(self, value, a, b, c=0.0, d=1.0):
        n = self.node("ShaderNodeMapRange", in_From_Min=a, in_From_Max=b, in_To_Min=c, in_To_Max=d)
        self.link(value, n.inputs["Value"])
        return n.outputs["Result"]

    def ramp(self, value, stops):
        r = self.node("ShaderNodeValToRGB")
        els = r.color_ramp.elements
        els[0].position, els[0].color = stops[0]
        els[1].position, els[1].color = stops[-1]
        for pos, col in stops[1:-1]:
            els.new(pos).color = col
        self.link(value, r.inputs["Fac"])
        return r.outputs["Color"]

    def mix(self, a, b, fac):
        m = self.node("ShaderNodeMix", data_type="RGBA")
        self.link(fac, m.inputs["Factor"])
        for sock, val in ((m.inputs[6], a), (m.inputs[7], b)):
            if isinstance(val, tuple):
                sock.default_value = val
            else:
                self.link(val, sock)
        return m.outputs[2]

    def bake(self, socket, name, is_color):
        """Hornea una salida a una imagen y devuelve sus píxeles como arreglo."""
        img = bpy.data.images.new(name, size, size, alpha=False, float_buffer=True)
        if not is_color:
            img.colorspace_settings.name = "Non-Color"
        self.target.image = img
        self.nt.links.new(socket, self.emit.inputs["Color"])
        plane.data.materials.clear()
        plane.data.materials.append(self.mat)
        bpy.ops.object.select_all(action="DESELECT")
        plane.select_set(True)
        bpy.context.view_layer.objects.active = plane
        bpy.ops.object.bake(type="EMIT", margin=0)
        px = np.empty(size * size * 4, dtype=np.float32)
        img.pixels.foreach_get(px)
        return px.reshape(size, size, 4)[:, :, :3]


def rock():
    """Roca del Cerro Rico: bloques fracturados ocres y rojizos, estratos, vetas de mineral."""
    g = Graph("Rock")
    chunks = g.voronoi(1.8, "SMOOTH_F1")
    warp = g.noise(2.0, 4.0, 0.5, offset=21.0)
    edges = g.voronoi(1.8, "DISTANCE_TO_EDGE", offset=0.0, randomness=1.0)
    fine_cracks = g.voronoi(5.0, "DISTANCE_TO_EDGE", offset=3.0)
    fbm = g.noise(4.0, 12.0, 0.66, distortion=0.3, offset=1.0)
    strata = g.noise(0.8, 3.0, 0.5, distortion=2.5, offset=7.0)
    ridges = g.math("SUBTRACT", 1.0, g.math("ABSOLUTE", g.math("SUBTRACT", g.noise(2.5, 8.0, 0.6, offset=29.0), 0.5)))
    height = g.math("MULTIPLY", g.remap(edges, 0.0, 0.25), 0.12)
    height = g.math("ADD", height, g.math("MULTIPLY", fbm, 0.6))
    height = g.math("ADD", height, g.math("MULTIPLY", ridges, 0.3))
    height = g.math("ADD", height, g.math("MULTIPLY", warp, 0.2))
    height = g.math("ADD", height, g.math("MULTIPLY", g.remap(fine_cracks, 0.0, 0.015), 0.08))
    height = g.math("SUBTRACT", height, g.math("MULTIPLY", g.remap(chunks, 0.0, 0.5, 0.0, 0.1), 1.0))
    tone = g.math("ADD", g.math("MULTIPLY", strata, 0.6), g.math("MULTIPLY", fbm, 0.4))
    color = g.ramp(tone, [
        (0.3, (0.06, 0.03, 0.02, 1)), (0.42, (0.13, 0.065, 0.04, 1)), (0.52, (0.17, 0.1, 0.06, 1)),
        (0.62, (0.12, 0.05, 0.035, 1)), (0.78, (0.22, 0.14, 0.09, 1))])
    vein_noise = g.noise(2.2, 4.0, 0.6, distortion=2.5, offset=11.0)
    vein = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", vein_noise, 0.5)), 0.03, 0.0)
    color = g.mix(color, (0.2, 0.2, 0.2, 1), vein)
    sulfur = g.remap(g.noise(3.0, 5.0, 0.7, offset=17.0), 0.62, 0.72)
    color = g.mix(color, (0.3, 0.24, 0.06, 1), g.math("MULTIPLY", sulfur, 0.5))
    soot = g.remap(edges, 0.025, 0.0)
    color = g.mix(color, (0.03, 0.02, 0.015, 1), g.math("MULTIPLY", soot, 0.3))
    rough = g.math("SUBTRACT", 0.92, g.math("MULTIPLY", vein, 0.5))
    rough = g.math("SUBTRACT", rough, g.math("MULTIPLY", fbm, 0.15))
    return g, height, color, rough


def ground():
    """Suelo de socavón: barro compacto, gravilla y charcos."""
    g = Graph("Ground")
    pebbles = g.voronoi(26.0, "SMOOTH_F1")
    big = g.voronoi(9.0, "SMOOTH_F1", offset=2.0)
    fbm = g.noise(5.0, 8.0, 0.6, offset=4.0)
    puddle = g.remap(g.noise(1.5, 3.0, 0.5, offset=9.0), 0.56, 0.62)
    stones = g.math("MAXIMUM", g.remap(pebbles, 0.35, 0.0), g.remap(big, 0.3, 0.0, 0.0, 0.8))
    height = g.math("ADD", g.math("MULTIPLY", stones, 0.55), g.math("MULTIPLY", fbm, 0.35))
    height = g.math("MULTIPLY", height, g.math("SUBTRACT", 1.0, g.math("MULTIPLY", puddle, 0.7)))
    mud = g.ramp(fbm, [(0.35, (0.07, 0.05, 0.04, 1)), (0.6, (0.15, 0.11, 0.08, 1)), (0.8, (0.2, 0.15, 0.1, 1))])
    stone_col = g.ramp(g.voronoi(26.0, "F1", "Color"), [(0.0, (0.2, 0.17, 0.15, 1)),
                                                         (1.0, (0.36, 0.26, 0.19, 1))])
    color = g.mix(mud, stone_col, stones)
    color = g.mix(color, (0.04, 0.03, 0.025, 1), g.math("MULTIPLY", puddle, 0.6))
    rough = g.math("SUBTRACT", 0.95, g.math("MULTIPLY", puddle, 0.85))
    return g, height, color, rough


def wood():
    """Madera de callapo: vetas largas, grietas, oscura por el hollín y la humedad."""
    g = Graph("Wood")
    sep = g.node("ShaderNodeSeparateXYZ")
    g.link(g.node("ShaderNodeTexCoord").outputs["UV"], sep.inputs[0])
    grain_noise = g.noise(3.0, 4.0, 0.5, offset=5.0)
    across = g.math("ADD", g.math("MULTIPLY", sep.outputs["X"], 14.0), g.math("MULTIPLY", grain_noise, 0.8))
    grain = g.math("MULTIPLY", g.math("ADD", g.math("SINE", g.math("MULTIPLY", across, math.tau)), 1.0), 0.5)
    fine = g.math("ADD", g.math("MULTIPLY", sep.outputs["X"], 96.0), g.math("MULTIPLY", g.noise(6.0, 4.0, 0.5,
                                                                                             offset=8.0), 1.2))
    fibers = g.math("MULTIPLY", g.math("ADD", g.math("SINE", g.math("MULTIPLY", fine, math.tau)), 1.0), 0.5)
    cracks = g.remap(g.math("ABSOLUTE", g.math("SUBTRACT", g.noise(4.0, 3.0, 0.5, distortion=0.4, offset=13.0),
                                                0.5)), 0.012, 0.0)
    height = g.math("ADD", g.math("MULTIPLY", grain, 0.35), g.math("MULTIPLY", fibers, 0.4))
    height = g.math("SUBTRACT", height, g.math("MULTIPLY", cracks, 0.5))
    tone = g.math("ADD", g.math("MULTIPLY", grain, 0.5), g.math("MULTIPLY", g.noise(2.0, 5.0, 0.6), 0.5))
    color = g.ramp(tone, [(0.2, (0.03, 0.018, 0.01, 1)), (0.5, (0.08, 0.045, 0.025, 1)),
                          (0.8, (0.14, 0.085, 0.045, 1))])
    color = g.mix(color, (0.02, 0.012, 0.008, 1), cracks)
    rough = g.math("ADD", 0.75, g.math("MULTIPLY", fibers, 0.2))
    return g, height, color, rough


def iron():
    """Hierro de carro minero: pintura vieja casi perdida, óxido en capas y golpes."""
    g = Graph("Iron")
    rust_noise = g.noise(4.0, 9.0, 0.65, offset=31.0)
    pits = g.voronoi(30.0, "F1", offset=37.0)
    dents = g.noise(1.6, 3.0, 0.5, offset=41.0)
    paint_left = g.remap(g.noise(2.2, 6.0, 0.6, offset=43.0), 0.58, 0.64)
    height = g.math("ADD", g.math("MULTIPLY", rust_noise, 0.4), g.math("MULTIPLY", dents, 0.4))
    height = g.math("SUBTRACT", height, g.math("MULTIPLY", g.remap(pits, 0.12, 0.0), 0.25))
    rust = g.ramp(rust_noise, [(0.3, (0.06, 0.025, 0.012, 1)), (0.5, (0.2, 0.07, 0.02, 1)),
                               (0.7, (0.32, 0.13, 0.04, 1))])
    color = g.mix(rust, (0.05, 0.06, 0.05, 1), g.math("MULTIPLY", paint_left, 0.85))
    color = g.mix(color, (0.02, 0.015, 0.01, 1), g.remap(pits, 0.1, 0.0))
    rough = g.math("SUBTRACT", 0.92, g.math("MULTIPLY", paint_left, 0.35))
    return g, height, color, rough


def wrap_gradient(h, axis):
    return (np.roll(h, -1, axis) - np.roll(h, 1, axis)) * 0.5


def normal_map(h, strength):
    dx = wrap_gradient(h, 1) * strength * size / 512
    dy = wrap_gradient(h, 0) * strength * size / 512
    n = np.dstack((-dx, -dy, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5


def occlusion(h):
    """Oclusión barata: qué tan hundido está cada punto respecto a su entorno."""
    blurred = h.copy()
    for radius in (2, 4, 8):
        acc = np.zeros_like(h)
        for dy in (-radius, 0, radius):
            for dx in (-radius, 0, radius):
                acc += np.roll(np.roll(h, dy, 0), dx, 1)
        blurred = acc / 9.0
    return np.clip(1.0 - (blurred - h) * 3.0, 0.35, 1.0)


def to_srgb(linear):
    """Las imágenes de 8 bits guardan el color ya codificado en sRGB."""
    linear = np.clip(linear, 0.0, 1.0)
    return np.where(linear <= 0.0031308, linear * 12.92, 1.055 * np.power(linear, 1 / 2.4) - 0.055)


def save(name, rgb, is_color):
    img = bpy.data.images.new(name, size, size, alpha=False)
    if not is_color:
        img.colorspace_settings.name = "Non-Color"
    rgba = np.dstack((rgb, np.ones(rgb.shape[:2], dtype=np.float32))).astype(np.float32)
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(out_dir, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("textura", name)


for name, builder, strength in (("rock", rock, 6.0), ("ground", ground, 6.0), ("wood", wood, 4.0), ("iron", iron, 5.0)):
    graph, height_s, color_s, rough_s = builder()
    height = graph.bake(height_s, name + "_h", False)[:, :, 0]
    color = graph.bake(color_s, name + "_c", True)
    rough = graph.bake(rough_s, name + "_r", False)[:, :, 0]
    ao = occlusion(height)
    save(f"{name}_albedo", to_srgb(color * ao[:, :, None]), True)
    save(f"{name}_normal", normal_map(height, strength), False)
    save(f"{name}_orm", np.dstack((ao, np.clip(rough, 0.0, 1.0), np.zeros_like(ao))), False)
