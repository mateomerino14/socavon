"""Genera las voces provisionales con síntesis de voz (Piper) y las actúa para que den miedo.

Cada línea de src/story/voices/*.tres se parte en tramos con su propia emoción (gritar, susurrar,
temblar, llamar a lo lejos, reír, gruñir). Cada tramo se sintetiza aparte con su ritmo, se le cambia
el tono y la textura, y se unen con respiraciones y silencios antes de darle el eco de la mina.
Para el Tío se siguen ideas del diseño de criaturas: capas graves, agudas y de ruido, respiración
ronca, susurros pegados al oído que estallan en rugidos, y silencio antes del golpe.

Requisitos: pip install piper-tts numpy, ffmpeg en el PATH y el modelo de voz:
  https://github.com/rhasspy/piper/releases/download/v0.0.2/voice-es-carlfm-x-low.tar.gz
Uso: python3 tools/generate_voices.py <carpeta_del_modelo>
"""

import re
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
LINES_DIR = ROOT / "src" / "story" / "voices"
OUTPUT_DIR = ROOT / "assets" / "audio" / "voices"
ROAR_PATH = ROOT / "assets" / "audio" / "tio_roar.wav"
SCREAM_PATH = ROOT / "assets" / "audio" / "tio_scream.wav"
MODEL_NAME = "es-carlfm-x-low.onnx"
SAMPLE_RATE = 16000
OUTPUT_RATE = 44100
PEAK_DB = -1.0
SEED = 1545
TIO = "El Tío"

# Ecos: socavón para todos; el de Wilmer suena lejano y repetido.
CAVE = "apad=pad_dur=1.2,aecho=0.8:0.6:45|110|230|420:0.35|0.25|0.18|0.1"
FAR_CAVE = "lowpass=f=2600,highpass=f=300,apad=pad_dur=2,aecho=0.8:0.85:300|700|1200:0.5|0.35|0.25"
WHISPER = (
    "afftfilt=real='hypot(re,im)*cos(2*PI*random(0))':imag='hypot(re,im)*sin(2*PI*random(1))'"
    ":win_size=512:overlap=0.75,highpass=f=350"
)

# Tono base y eco de cada personaje humano.
CHARACTERS = {
    "Mateo": {"pitch": 1.05, "space": CAVE},
    "Rosendo": {"pitch": 0.93, "space": CAVE},
    "Don Faustino": {"pitch": 0.86, "space": CAVE},
    "Wilmer": {"pitch": 0.97, "space": FAR_CAVE},
}

# Emociones humanas: lentitud, tono, volumen (dB), susurro (0-1), temblor (0-1),
# variación de Piper, saturación y silencio después.
STYLES = {
    "stern": {"length": 1.05, "pitch": 0.97},
    "scoff": {"length": 1.15, "pitch": 0.94, "gain": -2.0, "noise": 0.9},
    "shout": {"length": 0.85, "pitch": 1.2, "gain": 4.0, "drive": True, "noise": 0.9},
    "panic": {"length": 0.78, "pitch": 1.24, "gain": 3.0, "tremble": 0.12, "drive": True, "noise": 1.0},
    "hushed": {"length": 1.12, "gain": -4.0, "whisper": 0.35},
    "uneasy": {"length": 1.18, "pitch": 1.02, "gain": -2.0, "whisper": 0.2, "tremble": 0.06, "pause": 0.5},
    "call": {"length": 1.3, "pitch": 1.1, "gain": 3.0, "pause": 0.9, "noise": 0.9},
    "fear_whisper": {"length": 1.22, "gain": -6.0, "whisper": 0.75, "tremble": 0.1},
    "ghost": {"length": 1.55, "pitch": 0.95, "gain": -3.0, "whisper": 0.6, "pause": 0.7},
}

# Emociones del Tío: cada una con su cadena de capas.
TIO_STYLES = {
    "whisper": {"length": 1.5, "pause": 0.35},
    "growl": {"length": 1.45, "pause": 0.3},
    "growl_slow": {"length": 1.8, "pause": 0.5},
    "laugh": {"length": 1.35, "pause": 0.25},
    "satisfied": {"length": 1.6, "pause": 0.3},
    "roar": {"length": 1.0, "pause": 0.2},
}
TIO_CHAINS = {
    # Susurro pegado al oído con un rumor grave debajo.
    "whisper": (
        "[0:a]asplit=2[a][b];"
        "[a]asetrate={rate}*0.82,aresample={out},atempo=1.2195," + WHISPER + ",volume=1.6[w];"
        "[b]asetrate={rate}*0.55,aresample={out},atempo=1.8182,lowpass=f=450,volume=0.3[s];"
        "[w][s]amix=inputs=2:normalize=0"
    ),
    # Voz grave con vibrato, una octava abajo y un siseo agudo, saturadas.
    "growl": (
        "[0:a]asplit=3[a][b][c];"
        "[a]asetrate={rate}*0.72,aresample={out},atempo=1.3889,vibrato=f=4:d=0.12[deep];"
        "[b]asetrate={rate}*0.5,aresample={out},atempo=2.0,volume=0.7[sub];"
        "[c]aresample={out}," + WHISPER + ",highpass=f=2500,volume=0.5,tremolo=f=9:d=0.6[hiss];"
        "[deep][sub][hiss]amix=inputs=3:normalize=0,volume=2.2,asoftclip=type=atan,lowpass=f=5000"
    ),
    # Risa: más grave, temblorosa y con eco de garganta.
    "laugh": (
        "[0:a]asplit=2[a][b];"
        "[a]asetrate={rate}*0.62,aresample={out},atempo=1.6129,vibrato=f=7:d=0.3[deep];"
        "[b]asetrate={rate}*0.45,aresample={out},atempo=2.2222,volume=0.6[sub];"
        "[deep][sub]amix=inputs=2:normalize=0,volume=2.5,asoftclip=type=atan,lowpass=f=4000"
    ),
    # Rugido: casi grito, muy saturado, con el chillido agudo encima.
    "roar": (
        "[0:a]asplit=3[a][b][c];"
        "[a]asetrate={rate}*0.8,aresample={out},atempo=1.25,vibrato=f=6:d=0.2[deep];"
        "[b]asetrate={rate}*0.55,aresample={out},atempo=1.8182,volume=0.9[sub];"
        "[c]asetrate={rate}*1.35,aresample={out},atempo=0.7407,highpass=f=1200,volume=0.45[shriek];"
        "[deep][sub][shriek]amix=inputs=3:normalize=0,volume=4.0,asoftclip=type=atan,"
        "acrusher=bits=10:mix=0.25,lowpass=f=6500"
    ),
}
TIO_CHAINS["growl_slow"] = TIO_CHAINS["growl"]
TIO_CHAINS["satisfied"] = TIO_CHAINS["growl"].replace("vibrato=f=4:d=0.12", "vibrato=f=3:d=0.2")

# Actuación de cada línea: tramos de texto con su emoción. "<inhala>" mete una respiración.
DIRECTION = {
    "rosendo_derrumbe": [("¡Mateo!", "shout"), ("¡Agárrate, chango,", "panic"), ("que se viene el techo!", "panic")],
    "faustino_orden": [("Sin ch'alla nomás entramos.", "stern"), ("El Tío no paga mi sueldo.", "scoff")],
    "mateo_altar": [("<inhala>", ""), ("Un altar del Tío.", "hushed"),
                    ("Rosendo siempre decía... que primero se pide permiso.", "uneasy")],
    "mateo_cruce": [("¿Rosendo?", "call"), ("¿Don Faustino?", "call"), ("<inhala>", ""),
                    ("Nadie contesta.", "fear_whisper")],
    "mateo_siete": [("Somos siete...", "uneasy"), ("<inhala>", ""), ("¿Siete qué?", "fear_whisper")],
    "wilmer_llamado": [("Mateo...", "ghost"), ("por acá...", "ghost"), ("sigue mi voz...", "ghost")],
    "mateo_rieles": [("Rieles...", "uneasy"), ("por aquí sacaban el mineral.", "hushed")],
    "mateo_agua": [("Agua...", "hushed"), ("<inhala>", ""), ("Severino se fue por el agua.", "fear_whisper")],
    "wilmer_agua": [("Mateo...", "ghost"), ("aquí abajo...", "ghost"), ("ven...", "ghost")],
    "mateo_lampara": [("Es la lámpara de Wilmer...", "uneasy"), ("<inhala>", ""),
                      ("Entonces, ¿quién me llama?", "panic")],
    "mateo_salida": [("<inhala>", ""), ("Aire...", "hushed"), ("viene aire de arriba.", "uneasy")],
    "tio_sospecha_1": [("<inhala>", ""), ("Mmm...", "growl_slow"), ("huelo carburo.", "whisper")],
    "tio_sospecha_2": [("¿Quién anda...", "whisper"), ("en mi casa?", "growl")],
    "tio_caza_1": [("<inhala>", ""), ("¡Entraste sin pedirme permiso!", "roar")],
    "tio_caza_2": [("Je, je, je...", "laugh"), ("Te veo, wawa.", "whisper")],
    "tio_busqueda_1": [("No te escondas...", "whisper"), ("la mina es mía.", "growl")],
    "tio_busqueda_2": [("Tu lámpara...", "whisper"), ("te va a traicionar.", "growl_slow")],
    "tio_calma_1": [("Eso...", "growl_slow"), ("así se pide.", "satisfied")],
}

# Grito del Tío al atrapar: su voz gritando encima del rugido sintético.
SCREAM_TEXT = "¡Aaaaaaaghhh!"

# Piper a veces suelta ruido en vez de voz; si un tramo queda así de fuerte se vuelve a generar.
MAX_MEAN_DB = -11.0
MAX_ATTEMPTS = 6
# Duración razonable de un tramo: segundos por letra según la lentitud, más un margen.
SECONDS_PER_CHAR = 0.1
MIN_SECONDS_PER_CHAR = 0.04
EXTRA_SECONDS = 1.0
BREATH_SECONDS = 0.55
TIO_BREATH_SECONDS = 0.9


def read_line(path):
    """Saca id, personaje y texto de un recurso VoiceLine."""
    text = path.read_text(encoding="utf-8")
    fields = {}
    for key in ("id", "speaker", "text"):
        match = re.search(rf'^{key} = "(.*)"$', text, re.MULTILINE)
        fields[key] = match.group(1).replace('\\"', '"')
    return fields


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", *map(str, args)], check=True)


def synthesize(model, text, length, noise, out_wav):
    """Convierte el texto a voz con Piper; más ruido da una entonación menos plana.

    Los puntos suspensivos se vuelven punto (la pausa la pone la dirección) y si Piper devuelve
    algo demasiado corto, largo o ruidoso para el texto, se vuelve a pedir.
    """
    clean = text.replace("...", ".")
    limit = len(clean) * SECONDS_PER_CHAR * length + EXTRA_SECONDS
    shortest = len(clean) * MIN_SECONDS_PER_CHAR * length
    for _ in range(MAX_ATTEMPTS):
        subprocess.run(
            [sys.executable, "-m", "piper", "-m", str(model), "-f", str(out_wav), "--length-scale", str(length),
             "--noise-scale", str(noise), "--noise-w", str(noise + 0.3)],
            input=clean.encode("utf-8"), check=True, capture_output=True,
        )
        with wave.open(str(out_wav)) as w:
            seconds = w.getnframes() / w.getframerate()
        if shortest <= seconds <= limit and volume_db(out_wav, "mean") < MAX_MEAN_DB:
            return
    raise RuntimeError(f"Piper no logró decir bien: {text}")


def write_wav(path, samples, rate):
    data = (np.clip(samples, -1.0, 1.0) * 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(data.tobytes())


def breath(path, rng, deep):
    """Inhalación: ruido filtrado que crece y se corta, más ronca y larga en el Tío."""
    seconds = TIO_BREATH_SECONDS if deep else BREATH_SECONDS
    count = int(seconds * OUTPUT_RATE)
    noise = rng.uniform(-1.0, 1.0, count)
    smooth = 0.82 if deep else 0.55
    for i in range(1, count):
        noise[i] = noise[i - 1] * smooth + noise[i] * (1.0 - smooth)
    t = np.linspace(0.0, 1.0, count)
    envelope = np.sin(np.pi * np.clip(t * 1.15, 0.0, 1.0)) ** 2 * (0.6 + 0.4 * t)
    rasp = 1.0 + 0.6 * np.sin(2 * np.pi * 38 * t * seconds) if deep else 1.0
    write_wav(path, noise * envelope * rasp * 0.5, OUTPUT_RATE)


def human_segment(raw, speaker, style, out):
    """Cambia tono, textura y volumen de un tramo humano según su emoción."""
    s = STYLES[style]
    pitch = CHARACTERS[speaker]["pitch"] * s.get("pitch", 1.0)
    base = f"asetrate={SAMPLE_RATE}*{pitch:.4f},aresample={OUTPUT_RATE},atempo={1 / pitch:.4f}"
    whisper = s.get("whisper", 0.0)
    tremble = s.get("tremble", 0.0)
    post = []
    if tremble:
        post.append(f"vibrato=f=7:d={tremble}")
    if s.get("drive"):
        post.append("acompressor=threshold=0.1:ratio=6:attack=5:release=60,volume=2,asoftclip=type=tanh")
    post.append(f"volume={s.get('gain', 0.0)}dB")
    graph = (
        f"[0:a]{base},asplit=2[dry][wet];[wet]{WHISPER}[w];"
        f"[dry][w]amix=inputs=2:weights='{1 - whisper} {whisper * 1.8}':normalize=0,{','.join(post)}"
    )
    ffmpeg("-i", raw, "-filter_complex", graph, "-ar", OUTPUT_RATE, out)


def tio_segment(raw, style, out):
    """Pasa un tramo del Tío por la cadena de capas de su emoción."""
    graph = TIO_CHAINS[style].format(rate=SAMPLE_RATE, out=OUTPUT_RATE)
    ffmpeg("-i", raw, "-filter_complex", graph, "-ar", OUTPUT_RATE, out)


def silence(path, seconds):
    write_wav(path, np.zeros(int(seconds * OUTPUT_RATE)), OUTPUT_RATE)


def volume_db(path, kind):
    """Mide el volumen medio ("mean") o el pico ("max") de un audio en dB."""
    result = subprocess.run(["ffmpeg", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
                            capture_output=True, text=True, check=True)
    return float(re.search(rf"{kind}_volume: (-?[0-9.]+) dB", result.stderr).group(1))


def peak_db(wav):
    return volume_db(wav, "max")


def finish(parts, space, out, tmp, codec):
    """Une los tramos, pone el eco, iguala el pico y quita el silencio final."""
    listing = tmp / "parts.txt"
    listing.write_text("".join(f"file '{p}'\n" for p in parts))
    joined = tmp / "joined.wav"
    ffmpeg("-f", "concat", "-safe", "0", "-i", listing, "-af", "lowpass=f=7500," + space, "-ar", OUTPUT_RATE, joined)
    gain = PEAK_DB - peak_db(joined)
    trim = f"volume={gain:.2f}dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse"
    ffmpeg("-i", joined, "-af", trim, *codec, out)


def render_line(model, line, tmp, rng):
    """Actúa una línea completa tramo por tramo."""
    is_tio = line["speaker"] == TIO
    parts = []
    for index, (text, style) in enumerate(DIRECTION[line["id"]]):
        if text == "<inhala>":
            path = tmp / f"breath_{index}.wav"
            breath(path, rng, is_tio)
            parts.append(path)
            continue
        params = TIO_STYLES[style] if is_tio else STYLES[style]
        raw = tmp / f"raw_{index}.wav"
        synthesize(model, text, params["length"], params.get("noise", 0.8), raw)
        shaped = tmp / f"seg_{index}.wav"
        if is_tio:
            tio_segment(raw, style, shaped)
        else:
            human_segment(raw, line["speaker"], style, shaped)
        parts.append(shaped)
        gap = tmp / f"gap_{index}.wav"
        silence(gap, params.get("pause", 0.25))
        parts.append(gap)
    space = CAVE if is_tio else CHARACTERS[line["speaker"]]["space"]
    out = OUTPUT_DIR / f"{line['id']}.ogg"
    finish(parts, space, out, tmp, ["-c:a", "libvorbis", "-q:a", "5"])


def render_scream(model, tmp):
    """Mezcla al Tío gritando con el rugido sintético de tools/generate_sounds.py."""
    raw = tmp / "scream_raw.wav"
    synthesize(model, SCREAM_TEXT, 1.6, 1.0, raw)
    voice = tmp / "scream_voice.wav"
    tio_segment(raw, "roar", voice)
    mixed = tmp / "scream_mix.wav"
    ffmpeg("-i", voice, "-i", ROAR_PATH, "-filter_complex",
           "[0:a]volume=1.3[v];[1:a]aresample=44100,volume=0.8[r];[v][r]amix=inputs=2:normalize=0:duration=longest",
           "-ar", OUTPUT_RATE, mixed)
    finish([mixed], "aecho=0.8:0.5:40|90:0.3|0.2", SCREAM_PATH, tmp, ["-c:a", "pcm_s16le"])


def main():
    """Genera todas las voces y el grito de captura."""
    model = Path(sys.argv[1]) / MODEL_NAME
    rng = np.random.default_rng(SEED)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in sorted(LINES_DIR.glob("*.tres")):
        line = read_line(path)
        with tempfile.TemporaryDirectory() as tmp:
            render_line(model, line, Path(tmp), rng)
        print("voz", line["id"])
    with tempfile.TemporaryDirectory() as tmp:
        render_scream(model, Path(tmp))
    print("grito del Tío")


if __name__ == "__main__":
    main()
