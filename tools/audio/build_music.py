"""Arma la música que sigue al Tío, en tres capas que suenan juntas y se cruzan:

- calma: el ambiente de caverna de Paul Wortmann (OpenGameArt, CC0), oscurecido;
- tensión: los latidos con piano de congusbongus (OpenGameArt, CC0);
- persecución: sintetizada aquí, un bombo en seis por ocho con un bordón disonante y un raspado
  de cuerdas que tiembla.

Cada capa sale como un bucle sin costura en OGG; el bucle se activa en su .import.

Uso: python3 tools/audio/build_music.py <carpeta_de_descarga> assets/audio/music
Necesita ffmpeg.
"""

import os
import subprocess
import sys
import urllib.request

import numpy as np

RATE = 44100
CROSSFADE = 2.0
CALM_URL = "https://opengameart.org/sites/default/files/dark_cavern_ambient_002.ogg"
TENSION_URL = "https://opengameart.org/sites/default/files/evil.ogg"
CALM_SECONDS = 60.0
TENSION_SECONDS = 48.0
# Persecución: compases de seis corcheas
BEATS_PER_MINUTE = 156
EIGHTHS_PER_BAR = 6
BARS = 8
KICK_PATTERN = (1.0, 0.0, 0.45, 0.8, 0.0, 0.45)
DRONE_HZ = (36.7, 38.9, 55.0)
# Banda del raspado de cuerdas y volumen medio de cada capa
SCRAPE_LOW_HZ, SCRAPE_HIGH_HZ = 600, 3200
MEAN_DB = -24.0
PEAK = 0.7
rng = np.random.default_rng(1975)


def load(path, filters="anull"):
    """Lee el archivo como estéreo a 44,1 kHz, pasándolo por filtros de ffmpeg."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-af", filters, "-ac", "2", "-ar", str(RATE)]
        + ["-f", "f32le", "-"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, 2).copy()


def seamless(x, seconds):
    """Recorta `seconds` y funde el final con el principio para que el bucle no se note."""
    n, cross = int(seconds * RATE), int(CROSSFADE * RATE)
    body, tail = x[:n].copy(), x[n : n + cross]
    ramp = np.linspace(0.0, 1.0, cross, dtype=np.float32)[:, None]
    body[:cross] = body[:cross] * ramp + tail * (1.0 - ramp)
    return body


def kick(seconds=0.5):
    """Bombo legüero: un golpe grave que baja de tono, con el chasquido del cuero."""
    t = np.arange(int(seconds * RATE)) / RATE
    pitch = 45 + 70 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(pitch) / RATE) * np.exp(-t * 7)
    click = rng.uniform(-1, 1, len(t)) * np.exp(-t * 90) * 0.4
    return (body + click).astype(np.float32)


def chase():
    """Bombo en seis por ocho sobre un bordón disonante, con cuerdas raspadas que tiemblan."""
    eighth = 60.0 / BEATS_PER_MINUTE / 2
    length = int(eighth * EIGHTHS_PER_BAR * BARS * RATE)
    t = np.arange(length) / RATE
    out = np.zeros(length, dtype=np.float32)
    hit = kick()
    for bar in range(BARS):
        for step, accent in enumerate(KICK_PATTERN):
            if accent:
                start = int((bar * EIGHTHS_PER_BAR + step) * eighth * RATE)
                end = min(start + len(hit), length)
                out[start:end] += hit[: end - start] * accent
    drone = sum(np.sign(np.sin(2 * np.pi * hz * t + rng.uniform(0, 6))) * 0.12 for hz in DRONE_HZ)
    noise = band(rng.uniform(-1, 1, length).astype(np.float32), SCRAPE_LOW_HZ, SCRAPE_HIGH_HZ)
    tremble = 0.5 + 0.5 * np.sin(2 * np.pi * 9 * t)
    mono = out * 0.8 + drone.astype(np.float32) * 0.5 + noise * tremble.astype(np.float32) * 0.25
    return mono


def band(x, low, high):
    """Deja pasar solo las frecuencias entre `low` y `high`."""
    spectrum = np.fft.rfft(x)
    hz = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spectrum[(hz < low) | (hz > high)] = 0
    return np.fft.irfft(spectrum, len(x)).astype(np.float32)


def to_stereo(mono):
    """Abre un poco la mezcla: el canal derecho llega unos milisegundos después."""
    delay = int(0.012 * RATE)
    right = np.concatenate([mono[-delay:], mono[:-delay]])
    return np.stack([mono, right], axis=1)


def save(path, stereo):
    """Escribe el bucle en OGG con el volumen medio parejo entre capas y sin pasarse del tope."""
    rms = np.sqrt(np.mean(stereo**2)) + 1e-9
    stereo = stereo * (10 ** (MEAN_DB / 20) / rms)
    stereo *= min(1.0, PEAK / np.abs(stereo).max())
    raw = path + ".raw"
    stereo.astype(np.float32).tofile(raw)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-f", "f32le", "-ar", str(RATE), "-ac", "2", "-i", raw]
        + ["-c:a", "libvorbis", "-q:a", "5", path],
        check=True,
    )
    os.remove(raw)


def main():
    """Baja las dos grabaciones y escribe las tres capas."""
    work, out_dir = sys.argv[1:3]
    os.makedirs(work, exist_ok=True)
    os.makedirs(out_dir, exist_ok=True)
    sources = {}
    for name, url in (("calm", CALM_URL), ("tension", TENSION_URL)):
        sources[name] = os.path.join(work, os.path.basename(url))
        if not os.path.exists(sources[name]):
            urllib.request.urlretrieve(url, sources[name])
    calm = seamless(load(sources["calm"], "lowpass=f=1800"), CALM_SECONDS)
    save(os.path.join(out_dir, "calm.ogg"), calm)
    tension = seamless(load(sources["tension"]), TENSION_SECONDS)
    save(os.path.join(out_dir, "tension.ogg"), tension)
    save(os.path.join(out_dir, "chase.ogg"), to_stereo(chase()))
    print("música lista")


main()
