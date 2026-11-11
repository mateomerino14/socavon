"""Genera los sonidos provisionales del prototipo en assets/audio/ sin bancos externos.

Uso: python3 tools/generate_sounds.py
Usa solo la biblioteca estándar y una semilla fija, así cada ejecución produce los mismos archivos.
"""

import math
import random
import struct
from pathlib import Path

SAMPLE_RATE = 44100
MAX_AMPLITUDE = 32767
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "audio"
# El rugido no entra al juego: es materia prima para el grito que arma generate_voices.py.
SOURCES_DIR = Path(__file__).resolve().parent / "audio_sources"
SEED = 1545

FOOTSTEP_VARIANTS = 4
FOOTSTEP_SECONDS = 0.16
DRIP_VARIANTS = 3
DRIP_SECONDS = 0.35
STONE_HIT_SECONDS = 0.25
AMBIENCE_SECONDS = 12.0
RUMBLE_SECONDS = 5.0
SCREAM_SECONDS = 1.6
WADE_VARIANTS = 3
WADE_SECONDS = 0.45


def write_wav(path, samples, loop=False):
    """Escribe muestras de -1 a 1 como WAV mono de 16 bits; con loop agrega el bloque smpl para que Godot lo repita."""
    frames = b"".join(
        struct.pack("<h", int(max(-1.0, min(1.0, s)) * MAX_AMPLITUDE)) for s in samples
    )
    fmt = struct.pack("<HHIIHH", 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(frames)) + frames
    if loop:
        smpl = struct.pack("<9I", 0, 0, 0, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
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


def footstep(rng):
    """Pisada sobre roca y grava: un golpe grave más un crujido corto."""
    count = int(FOOTSTEP_SECONDS * SAMPLE_RATE)
    thump = []
    for i in range(count):
        t = i / SAMPLE_RATE
        thump.append(math.sin(2 * math.pi * rng.uniform(70, 95) * t) * math.exp(-t * 45))
    grit = low_pass([rng.uniform(-1, 1) * math.exp(-i / SAMPLE_RATE * 30) for i in range(count)], 0.55)
    return normalize([a * 0.7 + b * 0.6 for a, b in zip(thump, grit)], 0.8)


def drip(rng):
    """Gota que cae en un charco: tono que sube rápido y se apaga."""
    count = int(DRIP_SECONDS * SAMPLE_RATE)
    base = rng.uniform(900, 1400)
    samples = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        phase += 2 * math.pi * base * (1 + t * 6) / SAMPLE_RATE
        samples.append(math.sin(phase) * math.exp(-t * 18))
    return normalize(samples, 0.6)


def stone_hit(rng):
    """Piedra que golpea roca: chasquido seco con algo de resonancia."""
    count = int(STONE_HIT_SECONDS * SAMPLE_RATE)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        click = rng.uniform(-1, 1) * math.exp(-t * 90)
        ring = math.sin(2 * math.pi * 620 * t) * math.exp(-t * 25) * 0.4
        samples.append(click + ring)
    return normalize(low_pass(samples, 0.3), 0.9)


def ambience(rng):
    """Fondo de mina: ruido marrón grave con un rumor lento que respira; empalma sin corte al repetirse."""
    count = int(AMBIENCE_SECONDS * SAMPLE_RATE)
    brown = []
    value = 0.0
    for _ in range(count):
        value = (value + rng.uniform(-1, 1) * 0.02) * 0.998
        brown.append(value)
    rumble = low_pass(brown, 0.97)
    breathing = [0.6 + 0.4 * math.sin(2 * math.pi * i / count * 3) for i in range(count)]
    mixed = [r * b for r, b in zip(rumble, breathing)]
    fade = int(SAMPLE_RATE * 0.5)
    for i in range(fade):
        weight = i / fade
        mixed[i] = mixed[i] * weight + mixed[count - fade + i] * (1 - weight)
    return normalize(mixed[: count - fade], 0.5)


def wade(rng):
    """Paso en agua hasta el tobillo: chapoteo grave, salpicadura y burbujas que se apagan."""
    count = int(WADE_SECONDS * SAMPLE_RATE)
    slosh = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.93)
    splash = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.35)
    samples = []
    for i in range(count):
        t = i / SAMPLE_RATE
        body = slosh[i] * min(t / 0.03, 1.0) * math.exp(-t * 9.0) * 2.5
        spray = splash[i] * math.exp(-t * 22.0) * 0.6
        samples.append(body + spray)
    for _ in range(rng.randint(4, 7)):
        start = rng.uniform(0.05, WADE_SECONDS * 0.7)
        freq = rng.uniform(500, 1400)
        for j in range(int(SAMPLE_RATE * 0.04)):
            t = j / SAMPLE_RATE
            index = int(start * SAMPLE_RATE) + j
            if index < count:
                chirp = math.sin(2 * math.pi * freq * (1 + t * 12) * t)
                samples[index] += chirp * math.exp(-t * 90) * 0.12
    return normalize(samples, 0.7)


def rumble(rng):
    """Derrumbe: estruendo grave que crece, golpea y se apaga, con piedras sueltas."""
    count = int(RUMBLE_SECONDS * SAMPLE_RATE)
    noise = low_pass([rng.uniform(-1, 1) for _ in range(count)], 0.985)
    samples = []
    for i, value in enumerate(noise):
        t = i / SAMPLE_RATE
        swell = min(t / 1.5, 1.0) * math.exp(-max(t - 2.2, 0.0) * 1.4)
        samples.append(value * swell)
    for _ in range(40):
        start = rng.randint(int(SAMPLE_RATE * 1.4), count - SAMPLE_RATE // 2)
        for j in range(int(SAMPLE_RATE * 0.05)):
            samples[start + j] += rng.uniform(-1, 1) * math.exp(-j / SAMPLE_RATE * 80) * 0.02
    return normalize(samples, 0.95)


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
        screech = math.sin(screech_phase * 2 * math.pi) * (0.5 + 0.5 * math.sin(t * 2 * math.pi * 23))
        voice = growl * 0.8 + screech * 0.35 + rasp[i] * 0.6 * (0.5 + 0.5 * abs(growl))
        samples.append(math.tanh(voice * 3.0) * attack * release)
    return normalize(samples, 0.95)


def main():
    """Genera todos los sonidos en assets/audio/."""
    rng = random.Random(SEED)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for index in range(1, FOOTSTEP_VARIANTS + 1):
        write_wav(OUTPUT_DIR / f"footstep_rock_{index}.wav", footstep(rng))
    for index in range(1, DRIP_VARIANTS + 1):
        write_wav(OUTPUT_DIR / f"drip_{index}.wav", drip(rng))
    write_wav(OUTPUT_DIR / "stone_hit.wav", stone_hit(rng))
    write_wav(OUTPUT_DIR / "mine_ambience_loop.wav", ambience(rng), loop=True)
    write_wav(OUTPUT_DIR / "collapse_rumble.wav", rumble(rng))
    write_wav(SOURCES_DIR / "tio_roar.wav", scream(rng))
    for index in range(1, WADE_VARIANTS + 1):
        write_wav(OUTPUT_DIR / f"wade_{index}.wav", wade(rng))
    print(f"Sonidos generados en {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
