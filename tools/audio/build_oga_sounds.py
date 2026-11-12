"""Arma los sonidos de la mina con grabaciones CC0 de OpenGameArt, en lugar de sintetizarlos.

`oga_sources.json` dice de dónde sale cada grabación y quién la hizo. El script las baja a una
carpeta aparte, las recorta, filtra y mezcla con numpy, y escribe WAV mono con los mismos nombres
que ya usa el juego:

- footstep_rock_1..4: pasos sobre grava, piedra y barro, con algo de eco de galería.
- wade_1..3: pasos en el agua del ramal inundado.
- drip_1..3: gotas sacadas de una grabación de un sótano que gotea.
- stone_hit: la piedra lanzada que golpea la roca.
- collapse_rumble: el derrumbe del principio, con el retumbo que lo sigue.
- mine_ambience_loop: el aire de la galería, en un bucle sin costura.

Uso: python3 tools/audio/build_oga_sounds.py <carpeta_de_descarga> assets/audio
Necesita ffmpeg.
"""

import json
import os
import struct
import subprocess
import sys
import urllib.request
import zipfile

import numpy as np

SOURCES = os.path.join(os.path.dirname(__file__), "oga_sources.json")
RATE = 44100
MAX_AMPLITUDE = 32767
FADE_SECONDS = 0.02
AMBIENCE_SECONDS = 40.0
AMBIENCE_CROSSFADE = 3.0
DRIP_GAP = 0.25
DRIP_SECONDS = 0.35


def download(work):
    """Baja cada grabación a su carpeta y descomprime los paquetes."""
    for name, source in json.load(open(SOURCES)).items():
        folder = os.path.join(work, name)
        if os.path.isdir(folder):
            continue
        os.makedirs(folder)
        target = os.path.join(folder, os.path.basename(source["url"]))
        urllib.request.urlretrieve(source["url"], target)
        if target.endswith(".zip"):
            zipfile.ZipFile(target).extractall(folder)


def load(path, filters="anull"):
    """Lee un archivo como muestras mono a 44,1 kHz, pasándolo por filtros de ffmpeg."""
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-af", filters, "-ac", "1", "-ar", str(RATE)]
        + ["-f", "f32le", "-"],
        capture_output=True,
        check=True,
    ).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()


def first(work, name):
    """Ruta del único archivo de una fuente que no viene comprimida."""
    folder = os.path.join(work, name)
    return os.path.join(folder, sorted(os.listdir(folder))[0])


def find(work, name, file_name):
    """Ruta de un archivo dentro de un paquete, esté en la carpeta que esté."""
    for folder, _, files in os.walk(os.path.join(work, name)):
        if file_name in files:
            return os.path.join(folder, file_name)
    raise FileNotFoundError(file_name)


def trim(x, threshold_db=-40.0, keep=0.6):
    """Corta el silencio del principio y deja como mucho `keep` segundos, con colas suaves."""
    level = 10 ** (threshold_db / 20) * np.abs(x).max()
    start = int(np.argmax(np.abs(x) > level))
    x = x[start : start + int(keep * RATE)]
    return fade(x)


def fade(x):
    """Entrada y salida cortas para que no haga clic."""
    n = min(int(FADE_SECONDS * RATE), len(x) // 2)
    ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def mix(*layers):
    """Suma capas (muestras, desde qué segundo, ganancia) en un solo sonido."""
    length = max(int(at * RATE) + len(x) for x, at, _ in layers)
    out = np.zeros(length, dtype=np.float32)
    for x, at, gain in layers:
        start = int(at * RATE)
        out[start : start + len(x)] += x * gain
    return out


def level(x, mean_db):
    """Deja el volumen medio en `mean_db`, sin pasarse del tope."""
    rms = np.sqrt(np.mean(x**2)) + 1e-9
    x = x * (10 ** (mean_db / 20) / rms)
    peak = np.abs(x).max()
    if peak > 0.97:
        x *= 0.97 / peak
    return x


def drips(x):
    """Separa las gotas de una grabación larga: cada pico que asoma sobre el fondo."""
    envelope = np.convolve(np.abs(x), np.ones(441) / 441, mode="same")
    threshold = np.percentile(envelope, 99.5) * 0.5
    found, last = [], -RATE
    for i in np.flatnonzero(envelope > threshold):
        if i - last > DRIP_GAP * RATE:
            found.append(fade(x[max(i - 200, 0) : i + int(DRIP_SECONDS * RATE)].copy()))
            last = i
    found.sort(key=lambda d: -np.abs(d).max())
    return found


def seamless(x, seconds):
    """Recorta `seconds` y funde el final con el principio para que el bucle no se note."""
    n, cross = int(seconds * RATE), int(AMBIENCE_CROSSFADE * RATE)
    body, tail = x[:n].copy(), x[n : n + cross]
    ramp = np.linspace(0.0, 1.0, cross, dtype=np.float32)
    body[:cross] = body[:cross] * ramp + tail * (1.0 - ramp)
    return body


def write_wav(path, samples, loop=False):
    """WAV mono de 16 bits; con loop agrega el bloque smpl para que Godot lo repita."""
    frames = (np.clip(samples, -1.0, 1.0) * MAX_AMPLITUDE).astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, RATE, RATE * 2, 2, 16)
    chunks = b"fmt " + struct.pack("<I", len(fmt)) + fmt
    chunks += b"data" + struct.pack("<I", len(frames)) + frames
    if loop:
        smpl = struct.pack("<9I", 0, 0, 0, 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, len(samples) - 1, 0, 0)
        chunks += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as out:
        out.write(b"RIFF" + struct.pack("<I", 4 + len(chunks)) + b"WAVE" + chunks)


def main():
    """Baja las grabaciones y escribe cada sonido."""
    work, out_dir = sys.argv[1:3]
    download(work)
    gallery = (
        "lowpass=f=5000,acompressor=threshold=-24dB:ratio=6:attack=1:release=80,"
        "aecho=0.8:0.5:60|110:0.25|0.15"
    )
    gravel_path = find(work, "pasos", "gravel.ogg")
    gravel = trim(load(gravel_path, gallery), keep=0.4)
    stone = trim(load(find(work, "pasos", "stone01.ogg"), gallery), keep=0.4)
    mud = trim(load(find(work, "pasos", "mud02.ogg"), gallery), keep=0.4)
    deep = trim(load(gravel_path, "asetrate=39690,aresample=44100," + gallery), keep=0.4)
    steps = [gravel, stone, mix((mud, 0, 1.0), (gravel, 0.01, 0.4)), deep]
    for index, x in enumerate(steps, 1):
        write_wav(os.path.join(out_dir, f"footstep_rock_{index}.wav"), level(x, -19.0))
    for index, name in enumerate(["splash_03", "splash_05", "splash_07"], 1):
        x = trim(load(find(work, "agua", name + ".ogg"), "lowpass=f=3500," + gallery))
        write_wav(os.path.join(out_dir, f"wade_{index}.wav"), level(x, -21.0))
    cave = "aecho=0.8:0.6:180|340:0.35|0.2"
    for index, x in enumerate(drips(load(first(work, "goteo"), cave))[:3], 1):
        write_wav(os.path.join(out_dir, f"drip_{index}.wav"), level(x, -18.5))
    hit = mix(
        (trim(load(find(work, "golpes", "bfh1_rock_hit_01.ogg"), gallery)), 0, 1.0),
        (trim(load(find(work, "golpes", "bfh1_rock_falling_04.ogg"), gallery)), 0.05, 0.5),
    )
    write_wav(os.path.join(out_dir, "stone_hit.wav"), level(fade(hit), -21.0))
    collapse = mix(
        (load(first(work, "derrumbe"), cave), 0, 1.0),
        (load(first(work, "retumbo"), "lowpass=f=400"), 0.3, 0.8),
    )[: int(6.5 * RATE)]
    write_wav(os.path.join(out_dir, "collapse_rumble.wav"), level(fade(collapse), -17.0))
    air = load(first(work, "calabozo"), "lowpass=f=2500")
    rumble = load(first(work, "retumbo"), "lowpass=f=300,aloop=loop=2:size=1000000")
    total = int((AMBIENCE_SECONDS + AMBIENCE_CROSSFADE) * RATE)
    bed = mix((air[:total], 0, 1.0), (np.resize(rumble, total), 0, 0.25))
    write_wav(
        os.path.join(out_dir, "mine_ambience_loop.wav"),
        level(seamless(bed, AMBIENCE_SECONDS), -21.0),
        loop=True,
    )
    print("sonidos de la mina listos")


main()
