"""Arma las muestras de timbre de cada personaje que imita Chatterbox (tools/generate_voices.py).

Todas leen la misma frase neutra. Mateo y Don Faustino salen de Kokoro (voces em_alex y em_santa;
Mateo un poco más agudo, por sus 17 años), Rosendo y Wilmer de Piper (ald y claude) y el Tío de
em_santa bajada de tono. Las muestras ya están en tools/audio_sources/voice_refs; este script solo
hace falta para cambiarlas.

Uso: python3 tools/audio/build_voice_refs.py <carpeta de los modelos de Piper>
Requiere: kokoro, soundfile, piper-tts y ffmpeg.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro import KPipeline

OUTPUT_DIR = Path(__file__).resolve().parent.parent / "audio_sources" / "voice_refs"
SENTENCE = (
    "Hace muchos años que trabajo en esta mina. Cada mañana subimos al cerro antes de que salga "
    "el sol, y bajamos con la lámpara encendida."
)
KOKORO_RATE = 24000
KOKORO_SPEED = 0.95
# Personaje: (motor, voz, tono). Un tono mayor que 1 aclara la voz y uno menor la oscurece.
VOICES = {
    "mateo": ("kokoro", "em_alex", 1.08),
    "faustino": ("kokoro", "em_santa", 1.0),
    "tio": ("kokoro", "em_santa", 0.84),
    "rosendo": ("piper", "es_MX-ald-medium.onnx", 1.0),
    "wilmer": ("piper", "es_MX-claude-high.onnx", 1.0),
}


def kokoro_voice(pipeline, voice, out):
    """Lee la frase con una voz de Kokoro."""
    audio = np.concatenate([chunk for _, _, chunk in pipeline(SENTENCE, voice=voice, speed=KOKORO_SPEED)])
    sf.write(out, audio, KOKORO_RATE)


def piper_voice(models, model, out):
    """Lee la frase con una voz de Piper."""
    subprocess.run([sys.executable, "-m", "piper", "-m", str(models / model), "-f", str(out)],
                   input=SENTENCE.encode("utf-8"), check=True, capture_output=True)


def shift_pitch(source, pitch, out):
    """Cambia el tono sin cambiar la duración."""
    rate = sf.info(source).samplerate
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(source), "-af",
                    f"asetrate={rate}*{pitch},aresample={rate},atempo={1 / pitch:.4f}", str(out)], check=True)


def main():
    """Genera una muestra por personaje."""
    models = Path(sys.argv[1])
    pipeline = KPipeline(lang_code="e", repo_id="hexgrad/Kokoro-82M")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, (engine, voice, pitch) in VOICES.items():
        with tempfile.TemporaryDirectory() as tmp:
            plain = Path(tmp) / "plain.wav"
            if engine == "kokoro":
                kokoro_voice(pipeline, voice, plain)
            else:
                piper_voice(models, voice, plain)
            shift_pitch(plain, pitch, OUTPUT_DIR / f"{name}.wav")
        print("muestra", name)


if __name__ == "__main__":
    main()
