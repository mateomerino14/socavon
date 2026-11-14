"""Genera las voces actuadas del juego con Chatterbox Multilingual, a partir de las VoiceLine.

Cada línea se dice entera, de una sola vez, con la emoción que pide su dirección y el timbre de la
muestra de su personaje (tools/audio_sources/voice_refs, ver tools/audio/build_voice_refs.py).
Después se le pone el eco de la mina; al Tío además se le baja el tono y se le suma una capa grave.
Cada toma se transcribe con Whisper: si no se entiende lo que dice, se pide otra y se queda la mejor.

Uso: python3 tools/generate_voices.py [id ...]
Con ids, solo regenera esas líneas y deja las demás como están; sin ids, también el grito del Tío.
Requiere: chatterbox-tts, faster-whisper, torchaudio y ffmpeg (ver tools/audio/README.md).
"""

import difflib
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import torch
import torchaudio
from chatterbox.mtl_tts import ChatterboxMultilingualTTS
from faster_whisper import WhisperModel

ROOT = Path(__file__).resolve().parent.parent
LINES_DIR = ROOT / "src" / "story" / "voices"
OUTPUT_DIR = ROOT / "assets" / "audio" / "voices"
REFS_DIR = ROOT / "tools" / "audio_sources" / "voice_refs"
ROAR_PATH = ROOT / "tools" / "audio_sources" / "tio_roar.wav"
SCREAM_PATH = ROOT / "assets" / "audio" / "tio_scream.wav"
OUTPUT_RATE = 44100
PEAK_DB = -1.0
SEED = 1545
LANGUAGE = "es"
TIO = "El Tío"
WILMER = "Wilmer"

# Muestra de timbre de cada personaje.
REFERENCES = {
    "Mateo": "mateo.wav",
    "Rosendo": "rosendo.wav",
    "Don Faustino": "faustino.wav",
    "Wilmer": "wilmer.wav",
    TIO: "tio.wav",
}

# Ecos: socavón para los humanos; el de Wilmer suena lejano y repetido. El Tío lleva uno corto,
# porque los ecos largos sobre su voz grave borran las palabras.
CAVE = "apad=pad_dur=1.2,aecho=0.8:0.6:45|110|230|420:0.35|0.25|0.18|0.1"
FAR_CAVE = "lowpass=f=2600,highpass=f=300,apad=pad_dur=2,aecho=0.8:0.85:300|700|1200:0.5|0.35|0.25"
TIO_SPACE = "apad=pad_dur=0.8,aecho=0.8:0.5:40|90:0.3|0.2"

# Voz del Tío: su voz un poco más grave y debajo otra mucho más grave y apagada, comprimidas y
# saturadas. Más grave que esto deja de entenderse.
TIO_PITCH = 0.84
TIO_SUB_PITCH = 0.7
TIO_SUB_VOLUME = 0.35
TIO_CHAIN = (
    "[0:a]asplit=2[a][b];"
    "[a]asetrate={rate}*{pitch},aresample={out},atempo={tempo:.4f}[voice];"
    "[b]asetrate={rate}*{sub},aresample={out},atempo={sub_tempo:.4f},lowpass=f=600,volume={sub_volume}[deep];"
    "[voice][deep]amix=inputs=2:normalize=0,acompressor=threshold=0.15:ratio=3,asoftclip=type=tanh,"
    "lowpass=f=7000"
)

# Emociones: exageración de Chatterbox (más es más intenso) y peso de la guía (menos es más pausado).
EMOTIONS = {
    "calm": (0.45, 0.5),
    "stern": (0.5, 0.5),
    "uneasy": (0.65, 0.35),
    "fear": (0.75, 0.35),
    "call": (0.9, 0.4),
    "panic": (1.4, 0.4),
    "ghost": (0.6, 0.3),
    "slow": (0.55, 0.3),
    "menace": (0.9, 0.3),
    "laugh": (1.0, 0.3),
    "roar": (1.5, 0.35),
}

# Emoción de cada línea.
DIRECTION = {
    "rosendo_derrumbe": "panic",
    "faustino_orden": "stern",
    "mateo_altar": "uneasy",
    "mateo_cruce": "call",
    "mateo_siete": "fear",
    "wilmer_llamado": "ghost",
    "mateo_rieles": "uneasy",
    "mateo_agua": "fear",
    "wilmer_agua": "ghost",
    "mateo_lampara": "panic",
    "mateo_salida": "uneasy",
    "mateo_veta": "calm",
    "mateo_gatear": "fear",
    "faustino_eco": "panic",
    "mateo_rosendo": "fear",
    "faustino_llamado": "call",
    "mateo_dos": "fear",
    "mateo_luz": "panic",
    "mateo_transito_rieles": "uneasy",
    "mateo_transito_veta": "fear",
    "mateo_transito_cuadrilla": "uneasy",
    "mateo_transito_bocamina": "fear",
    "tio_cuadrilla": "laugh",
    "tio_cobro": "menace",
    "tio_gracias": "slow",
    "tio_sospecha_1": "slow",
    "tio_sospecha_2": "menace",
    "tio_caza_1": "roar",
    "tio_caza_2": "laugh",
    "tio_busqueda_1": "menace",
    "tio_busqueda_2": "slow",
    "tio_calma_1": "slow",
}

# Palabras que Chatterbox no sabe decir, escritas como suenan. El subtítulo no cambia.
SPOKEN = {"wawa": "guagua", "bocamina": "boca mina"}

# Grito del Tío al atrapar: su voz rugiendo encima del rugido sintético de tools/generate_sounds.py.
SCREAM_TEXT = "¡Aaaaaaaaah!"
SCREAM_EMOTION = (2.0, 0.3)
# Dura lo mismo que el susto: se apaga antes de reaparecer.
SCREAM_SECONDS = 2.9
SCREAM_FADE_SECONDS = 0.6

# Tomas por línea y parecido mínimo entre lo que se oye y el texto para aceptar una toma.
MAX_TAKES = 5
MIN_MATCH = 0.9


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


def spoken(text):
    """El texto como debe pronunciarse."""
    for word, sound in SPOKEN.items():
        text = re.sub(rf"\b{word}\b", sound, text)
    return text


def words(text):
    """Las palabras de un texto, sin signos ni mayúsculas, para compararlo con lo transcrito."""
    return re.sub(r"[^a-záéíóúüñ ]", " ", text.lower().replace("'", "")).split()


def match(heard, text):
    """Qué tanto se parece lo transcrito al texto, de 0 a 1."""
    return difflib.SequenceMatcher(None, words(heard), words(text)).ratio()


def act(model, listener, text, speaker, emotion, out):
    """Dice el texto con la emoción y el timbre del personaje; pide tomas hasta que se entienda."""
    exaggeration, guidance = emotion
    best_score = -1.0
    best_take = None
    for take in range(MAX_TAKES):
        torch.manual_seed(SEED + take)
        wav = model.generate(text, language_id=LANGUAGE, audio_prompt_path=str(REFS_DIR / REFERENCES[speaker]),
                             exaggeration=exaggeration, cfg_weight=guidance)
        torchaudio.save(str(out), wav, model.sr)
        segments, _ = listener.transcribe(str(out), language=LANGUAGE)
        score = match("".join(s.text for s in segments), text)
        if score > best_score:
            best_score = score
            best_take = wav
        if score >= MIN_MATCH:
            break
    torchaudio.save(str(out), best_take, model.sr)
    return best_score


def volume_db(path):
    """Mide el pico de un audio en dB."""
    result = subprocess.run(["ffmpeg", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
                            capture_output=True, text=True, check=True)
    return float(re.search(r"max_volume: (-?[0-9.]+) dB", result.stderr).group(1))


def tio_voice(raw, rate, out):
    """Baja el tono del Tío y le suma su capa grave."""
    graph = TIO_CHAIN.format(rate=rate, out=OUTPUT_RATE, pitch=TIO_PITCH, tempo=1 / TIO_PITCH,
                             sub=TIO_PITCH * TIO_SUB_PITCH, sub_tempo=1 / (TIO_PITCH * TIO_SUB_PITCH),
                             sub_volume=TIO_SUB_VOLUME)
    ffmpeg("-i", raw, "-filter_complex", graph, "-ar", OUTPUT_RATE, out)


def finish(source, space, out, tmp, codec):
    """Pone el eco, iguala el pico y quita el silencio final."""
    spaced = tmp / "spaced.wav"
    ffmpeg("-i", source, "-af", "lowpass=f=7500," + space, "-ar", OUTPUT_RATE, spaced)
    gain = PEAK_DB - volume_db(spaced)
    trim = f"volume={gain:.2f}dB,areverse,silenceremove=start_periods=1:start_threshold=-55dB,areverse"
    ffmpeg("-i", spaced, "-af", trim, *codec, out)


def space_for(speaker):
    """El eco que lleva la voz de cada personaje."""
    if speaker == TIO:
        return TIO_SPACE
    if speaker == WILMER:
        return FAR_CAVE
    return CAVE


def render_line(model, listener, line, tmp):
    """Actúa una línea completa y la deja lista para el juego."""
    raw = tmp / "raw.wav"
    score = act(model, listener, spoken(line["text"]), line["speaker"], EMOTIONS[DIRECTION[line["id"]]], raw)
    voice = raw
    if line["speaker"] == TIO:
        voice = tmp / "tio.wav"
        tio_voice(raw, model.sr, voice)
    finish(voice, space_for(line["speaker"]), OUTPUT_DIR / f"{line['id']}.ogg", tmp, ["-c:a", "libvorbis", "-q:a", "5"])
    return score


def render_scream(model, tmp):
    """Mezcla al Tío rugiendo con el rugido sintético."""
    exaggeration, guidance = SCREAM_EMOTION
    torch.manual_seed(SEED)
    wav = model.generate(SCREAM_TEXT, language_id=LANGUAGE, audio_prompt_path=str(REFS_DIR / REFERENCES[TIO]),
                         exaggeration=exaggeration, cfg_weight=guidance)
    raw = tmp / "scream_raw.wav"
    torchaudio.save(str(raw), wav, model.sr)
    voice = tmp / "scream_voice.wav"
    tio_voice(raw, model.sr, voice)
    mixed = tmp / "scream_mix.wav"
    ffmpeg("-i", voice, "-i", ROAR_PATH, "-filter_complex",
           "[0:a]volume=1.3[v];[1:a]aresample=44100,volume=0.8[r];[v][r]amix=inputs=2:normalize=0:duration=longest,"
           f"atrim=0:{SCREAM_SECONDS},afade=t=out:st={SCREAM_SECONDS - SCREAM_FADE_SECONDS}:d={SCREAM_FADE_SECONDS}",
           "-ar", OUTPUT_RATE, mixed)
    finish(mixed, TIO_SPACE, SCREAM_PATH, tmp, ["-c:a", "pcm_s16le"])


def main():
    """Genera todas las voces y el grito; con ids, solo esas líneas."""
    only = set(sys.argv[1:])
    model = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
    listener = WhisperModel("small", device="cpu", compute_type="int8")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for path in sorted(LINES_DIR.glob("*.tres")):
        line = read_line(path)
        if only and line["id"] not in only:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            score = render_line(model, listener, line, Path(tmp))
        print(f"voz {line['id']} (se entiende {score:.0%})", flush=True)
    if only:
        return
    with tempfile.TemporaryDirectory() as tmp:
        render_scream(model, Path(tmp))
    print("grito del Tío")


if __name__ == "__main__":
    main()
