"""Genera las voces provisionales con síntesis de voz (Piper) y las procesa para que den miedo.

Lee cada línea de src/story/voices/*.tres, la sintetiza con la voz española "carlfm" de Piper,
le da el carácter de cada personaje con ffmpeg (tono, velocidad, eco de mina, distorsión del Tío)
y guarda el resultado en assets/audio/voices/<id>.ogg.

Requisitos: pip install piper-tts, ffmpeg en el PATH y el modelo de voz:
  https://github.com/rhasspy/piper/releases/download/v0.0.2/voice-es-carlfm-x-low.tar.gz
Uso: python3 tools/generate_voices.py <carpeta_del_modelo>
"""

import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LINES_DIR = ROOT / "src" / "story" / "voices"
OUTPUT_DIR = ROOT / "assets" / "audio" / "voices"
MODEL_NAME = "es-carlfm-x-low.onnx"
SAMPLE_RATE = 16000
OUTPUT_RATE = 44100

# Eco de socavón: rebotes cortos y una cola larga.
CAVE = "apad=pad_dur=1.2,aecho=0.8:0.6:45|110|230|420:0.35|0.25|0.18|0.1"

# Por personaje: lentitud del habla, factor de tono y filtros extra.
PROFILES = {
    "Mateo": {"length": 1.0, "pitch": 1.05, "extra": CAVE},
    "Rosendo": {"length": 0.88, "pitch": 0.93, "extra": "volume=1.4," + CAVE},
    "Don Faustino": {"length": 1.12, "pitch": 0.86, "extra": "vibrato=f=5:d=0.08," + CAVE},
    "Wilmer": {
        "length": 1.35,
        "pitch": 0.97,
        "extra": "lowpass=f=2600,highpass=f=300,apad=pad_dur=2,aecho=0.8:0.85:300|700|1200:0.5|0.35|0.25",
    },
}

# El Tío: tres capas de la misma voz (grave, una octava abajo y un susurro agudo),
# saturadas y con eco de cueva.
TIO_LENGTH = 1.45
TIO_FILTER = (
    "[0:a]asplit=3[a][b][c];"
    "[a]asetrate={rate}*0.72,aresample={out},atempo=1.3889,vibrato=f=4:d=0.12[deep];"
    "[b]asetrate={rate}*0.5,aresample={out},atempo=2.0,volume=0.7[sub];"
    "[c]aresample={out},highpass=f=2500,volume=0.35,tremolo=f=9:d=0.6[hiss];"
    "[deep][sub][hiss]amix=inputs=3:normalize=0,volume=2.2,asoftclip=type=atan,"
    "lowpass=f=5000," + CAVE
)
# Pico final de cada voz, en dB.
PEAK_DB = -1.0


def read_line(path):
    """Saca id, personaje y texto de un recurso VoiceLine."""
    text = path.read_text(encoding="utf-8")
    fields = {}
    for key in ("id", "speaker", "text"):
        match = re.search(rf'^{key} = "(.*)"$', text, re.MULTILINE)
        fields[key] = match.group(1).replace('\\"', '"')
    return fields


def synthesize(model, text, length, out_wav):
    """Convierte el texto a voz con Piper."""
    subprocess.run(
        [sys.executable, "-m", "piper", "-m", str(model), "-f", str(out_wav), "--length-scale", str(length)],
        input=text.encode("utf-8"),
        check=True,
        capture_output=True,
    )


def peak_db(wav):
    """Mide el pico de un audio en dB."""
    result = subprocess.run(
        ["ffmpeg", "-i", str(wav), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True, text=True, check=True,
    )
    return float(re.search(r"max_volume: (-?[0-9.]+) dB", result.stderr).group(1))


def process(raw_wav, speaker, out_ogg):
    """Aplica el carácter del personaje, iguala el pico, quita el silencio final y guarda en Ogg Vorbis."""
    if speaker == "El Tío":
        graph = TIO_FILTER.format(rate=SAMPLE_RATE, out=OUTPUT_RATE)
        args = ["-filter_complex", graph]
    else:
        profile = PROFILES[speaker]
        pitch = profile["pitch"]
        chain = (
            f"asetrate={SAMPLE_RATE}*{pitch},aresample={OUTPUT_RATE},atempo={1 / pitch:.4f},"
            f"{profile['extra']}"
        )
        args = ["-af", chain]
    shaped = raw_wav.with_name(raw_wav.stem + "_shaped.wav")
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(raw_wav), *args, "-ar", str(OUTPUT_RATE), str(shaped)],
        check=True,
    )
    gain = PEAK_DB - peak_db(shaped)
    finish = f"volume={gain:.2f}dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-i", str(shaped), "-af", finish, "-c:a", "libvorbis",
         "-q:a", "5", str(out_ogg)],
        check=True,
    )


def main():
    """Genera todas las voces."""
    model = Path(sys.argv[1]) / MODEL_NAME
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for path in sorted(LINES_DIR.glob("*.tres")):
            line = read_line(path)
            is_tio = line["speaker"] == "El Tío"
            length = TIO_LENGTH if is_tio else PROFILES[line["speaker"]]["length"]
            raw = Path(tmp) / f"{line['id']}.wav"
            synthesize(model, line["text"], length, raw)
            process(raw, line["speaker"], OUTPUT_DIR / f"{line['id']}.ogg")
            print("voz", line["id"])


if __name__ == "__main__":
    main()
