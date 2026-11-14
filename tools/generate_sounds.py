"""Sintetiza el rugido del Tío, materia prima del grito de captura que arma generate_voices.py, y
el aviso de nuevo objetivo: una campana metálica grave con un siseo que la anuncia.

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


def main():
    """Genera el rugido en tools/audio_sources/ y el aviso de objetivo en assets/audio/."""
    write_wav(SOURCES_DIR / "tio_roar.wav", scream(random.Random(SEED)))
    write_wav(ASSETS_DIR / "objective_chime.wav", chime(random.Random(SEED)))
    print(f"Rugido en {SOURCES_DIR} y aviso de objetivo en {ASSETS_DIR}")


if __name__ == "__main__":
    main()
