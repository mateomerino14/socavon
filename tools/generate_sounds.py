"""Sintetiza el rugido del Tío, materia prima del grito de captura que arma generate_voices.py, el
aviso de nuevo objetivo (una campana metálica grave), los sonidos de las salidas (reja que chirría,
palanca que golpea, mecha que sisea y explosión de dinamita) y el golpe de susto de las apariciones.

Los demás sonidos de la mina salen de grabaciones reales: ver tools/audio/build_oga_sounds.py.

Uso: python3 tools/generate_sounds.py
Usa solo la biblioteca estándar y una semilla fija, así cada ejecución produce el mismo archivo.
"""

import math
import random
import struct
from pathlib import Path

SAMPLE_RATE = 44100
MAX_AMPLITUDE = 32767
# El rugido no entra al juego: es materia prima para el grito que arma generate_voices.py.
SOURCES_DIR = Path(__file__).resolve().parent / "audio_sources"
SEED = 1545

SCREAM_SECONDS = 1.6

# Aviso de objetivo: campana en fa grave con parciales inarmónicos, como una lámina de metal.
ASSETS_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"
CHIME_SECONDS = 3.2
CHIME_ROOT = 174.6
CHIME_PARTIALS = [(1.0, 1.0, 1.6), (2.0, 0.45, 2.4), (2.76, 0.35, 3.2), (4.07, 0.18, 4.5), (5.4, 0.1, 6.0)]
SWISH_SECONDS = 0.18
CHIME_PEAK = 0.8

# Sonidos de las salidas.
GATE_SECONDS = 2.4
LEVER_SECONDS = 0.9
FUSE_SECONDS = 1.0
BLAST_SECONDS = 4.0
STING_SECONDS = 3.0
# Golpe de susto: cuerdas disonantes que suben de golpe sobre un bombo grave.
STING_NOTES = [146.8, 155.6, 207.7, 220.0, 311.1]


def write_wav(path, samples):
    """Escribe muestras de -1 a 1 como WAV mono de 16 bits."""
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s)) * MAX_AMPLITUDE)) for s in samples
    )
    fmt = struct.pack("<HHIIHH", 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(frames)) + frames
    path.write_bytes(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def low_pass(samples, strength):
    """Suaviza la señal: cuanto más cerca de 1 la fuerza, más grave suena."""
    result = []
    previous = 0.0
    for sample in samples:
        previous = previous * strength + sample * (1.0 - strength)
        result.append(previous)
    return result


def normalize(samples, peak):
    """Escala la señal para que su punto más alto valga el pico indicado."""
    loudest = max(abs(s) for s in samples) or 1.0
    return [s / loudest * peak for s in samples]


def scream(rng):
    """Rugido del Tío, base del grito de captura: rugido grave que tiembla y un chillido que sube, saturados."""
    count = int(SCREAM_SECONDS * SAMPLE_RATE)
    rasp = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.6)
    samples = []
    growl_phase = 0.0
    screech_phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        attack = min(t / 0.04, 1.0)
        release = math.exp(-max(t - 0.9, 0.0) * 5.0)
        growl_freq = 62 + 14 * math.sin(t * 2 * math.pi * 7) + rng.uniform(-6, 6)
        growl_phase += growl_freq / SAMPLE_RATE
        growl = (growl_phase % 1.0) * 2.0 - 1.0
        screech_freq = 700 + 900 * min(t / 0.5, 1.0) + 60 * math.sin(t * 2 * math.pi * 11)
        screech_phase += screech_freq / SAMPLE_RATE
        screech = math.sin(screech_phase * 2 * math.pi) * (
            0.5 + 0.5 * math.sin(t * 2 * math.pi * 23)
        )
        voice = growl * 0.8 + screech * 0.35 + rasp[i] * 0.6 * (0.5 + 0.5 * abs(growl))
        samples.append(math.tanh(voice * 3.0) * attack * release)
    return normalize(samples, 0.95)


def chime(rng):
    """Aviso de objetivo: un siseo que crece y una campana grave que se apaga despacio."""
    swish_count = int(SWISH_SECONDS * SAMPLE_RATE)
    swish = low_pass([rng.uniform(-1, 1) for _ in range(swish_count)], 0.3)
    samples = [swish[i] * (i / swish_count) ** 2 * 0.25 for i in range(swish_count)]
    for i in range(int(CHIME_SECONDS * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        attack = min(t / 0.004, 1.0)
        bell = sum(
            amplitude * math.exp(-t * decay) * math.sin(2 * math.pi * CHIME_ROOT * ratio * t)
            for ratio, amplitude, decay in CHIME_PARTIALS
        )
        samples.append(bell * attack)
    return normalize(samples, CHIME_PEAK)


def resonance(samples, frequency, damping):
    """Filtro resonante simple: hace sonar el ruido como una pieza de metal a esa frecuencia."""
    coefficient = 2 * math.cos(2 * math.pi * frequency / SAMPLE_RATE)
    previous = 0.0
    before = 0.0
    result = []
    for sample in samples:
        value = sample + coefficient * damping * previous - damping * damping * before
        before = previous
        previous = value
        result.append(value)
    return result


def gate(rng):
    """Reja de hierro que sube: chirrido que cambia de tono, traqueteo de cadena y golpe al final."""
    count = int(GATE_SECONDS * SAMPLE_RATE)
    noise = [rng.uniform(-1, 1) for _ in range(count)]
    screech = resonance(noise, 1250, 0.9993)
    low = resonance(noise, 180, 0.999)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        wobble = 0.5 + 0.5 * math.sin(2 * math.pi * (3 + 2 * t) * t)
        phase += (900 + 500 * math.sin(2 * math.pi * 0.7 * t)) / SAMPLE_RATE
        squeal = math.sin(2 * math.pi * phase) * 0.15 * wobble
        rattle = low[i] * 0.0016
        if (i // 1800) % 2 == 0:
            rattle = low[i] * 0.004
        envelope = min(t / 0.1, 1.0) * min((GATE_SECONDS - t) / 0.3, 1.0)
        samples.append((screech[i] * 0.0025 * wobble + squeal + rattle) * envelope)
    clang_start = count - int(0.35 * SAMPLE_RATE)
    clang = resonance([rng.uniform(-1, 1) * math.exp(-j / 400) for j in range(count - clang_start)], 420, 0.9996)
    for j, value in enumerate(clang):
        samples[clang_start + j] += value * 0.01
    return normalize(samples, 0.8)


def lever(rng):
    """Palanca de hierro: un raspado corto y un golpe metálico grave."""
    count = int(LEVER_SECONDS * SAMPLE_RATE)
    scrape = resonance([rng.uniform(-1, 1) for _ in range(count)], 700, 0.995)
    hit = resonance([rng.uniform(-1, 1) * math.exp(-i / 300) for i in range(count)], 260, 0.9997)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        drag = scrape[i] * 0.02 * max(0.0, 1.0 - t / 0.25)
        impact = 0.0
        if t > 0.22:
            impact = hit[i - int(0.22 * SAMPLE_RATE)] * 0.012
        samples.append(drag + impact)
    return normalize(samples, 0.85)


def fuse(rng):
    """Mecha encendida: siseo con chispas que chasquean; se repite en bucle."""
    count = int(FUSE_SECONDS * SAMPLE_RATE)
    hiss = [rng.uniform(-1, 1) for _ in range(count)]
    bright = [hiss[i] - hiss[i - 1] for i in range(count)]
    samples = []
    for i in range(count):
        crackle = 0.0
        if rng.random() < 0.0012:
            crackle = rng.uniform(-1, 1) * 1.5
        flutter = 0.7 + 0.3 * math.sin(2 * math.pi * 13 * i / SAMPLE_RATE)
        samples.append(bright[i] * 0.4 * flutter + crackle)
    return normalize(samples, 0.6)


def blast(rng):
    """Explosión de dinamita en un socavón: golpe seco, retumbo grave y piedras que caen."""
    count = int(BLAST_SECONDS * SAMPLE_RATE)
    rumble = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.985)
    crack = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.2)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        thump = math.sin(2 * math.pi * (55 - 25 * min(t, 1.0)) * t) * math.exp(-t * 3.0)
        boom = rumble[i] * 40 * math.exp(-t * 1.1)
        snap = crack[i] * math.exp(-t * 30.0)
        debris = 0.0
        if t > 0.4 and rng.random() < 0.004 * math.exp(-(t - 0.4)):
            debris = rng.uniform(-1, 1)
        samples.append(math.tanh((thump * 1.2 + boom + snap * 1.5 + debris * 0.6) * 1.8))
    return normalize(samples, 0.95)


def sting(rng):
    """Golpe de susto: un siseo que crece al revés y estalla en cuerdas disonantes con un bombo."""
    swell_count = int(0.6 * SAMPLE_RATE)
    swell = low_pass([rng.uniform(-1, 1) for _ in range(swell_count)], 0.5)
    samples = [swell[i] * (i / swell_count) ** 3 * 0.5 for i in range(swell_count)]
    phases = [rng.random() for _ in STING_NOTES]
    for i in range(int(STING_SECONDS * SAMPLE_RATE)):
        t = i / SAMPLE_RATE
        strings = 0.0
        for note, phase in zip(STING_NOTES, phases):
            vibrato = 1.0 + 0.006 * math.sin(2 * math.pi * 5.5 * t + phase * 6)
            saw = (note * vibrato * t + phase) % 1.0 * 2.0 - 1.0
            strings += saw / len(STING_NOTES)
        drum = math.sin(2 * math.pi * (60 - 20 * min(t, 0.5)) * t) * math.exp(-t * 6.0)
        envelope = math.exp(-t * 1.4)
        samples.append(math.tanh((strings * 0.9 * envelope + drum * 1.2) * 1.5))
    return normalize(low_pass(samples, 0.35), 0.85)


def main():
    """Genera el rugido en tools/audio_sources/ y los demás sonidos en assets/audio/."""
    write_wav(SOURCES_DIR / "tio_roar.wav", scream(random.Random(SEED)))
    write_wav(ASSETS_DIR / "objective_chime.wav", chime(random.Random(SEED)))
    write_wav(ASSETS_DIR / "gate_open.wav", gate(random.Random(SEED)))
    write_wav(ASSETS_DIR / "lever_pull.wav", lever(random.Random(SEED)))
    write_wav(ASSETS_DIR / "fuse_hiss.wav", fuse(random.Random(SEED)))
    write_wav(ASSETS_DIR / "dynamite_blast.wav", blast(random.Random(SEED)))
    write_wav(ASSETS_DIR / "tio_sting.wav", sting(random.Random(SEED)))
    print(f"Rugido en {SOURCES_DIR}; aviso de objetivo y sonidos de las salidas en {ASSETS_DIR}")


if __name__ == "__main__":
    main()
