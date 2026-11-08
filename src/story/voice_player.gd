class_name VoicePlayer
extends Node3D
## Dice líneas desde su posición: suena la grabación si existe y siempre muestra el subtítulo.

const SECONDS_PER_CHARACTER := 0.065
const MIN_LINE_SECONDS := 2.0
const PAUSE_BETWEEN_LINES := 0.3

var is_speaking := false

var _sequence := 0

@onready var _audio: AudioStreamPlayer3D = $Audio
@onready var _line_timer: Timer = $LineTimer


## Dice las líneas en orden; una nueva secuencia interrumpe la anterior.
func say(lines: Array[VoiceLine]) -> void:
	_sequence += 1
	var sequence := _sequence
	is_speaking = true
	for line in lines:
		var seconds := get_line_seconds(line)
		EventBus.subtitle_requested.emit(line.speaker, line.text, seconds)
		_audio.stop()
		if line.audio:
			_audio.stream = line.audio
			_audio.play()
		_line_timer.start(seconds + PAUSE_BETWEEN_LINES)
		await _line_timer.timeout
		if sequence != _sequence:
			return
	is_speaking = false


## Devuelve cuánto dura la línea: lo que dura su audio o una estimación por su largo.
static func get_line_seconds(line: VoiceLine) -> float:
	if line.audio:
		return line.audio.get_length()
	return maxf(line.text.length() * SECONDS_PER_CHARACTER, MIN_LINE_SECONDS)
