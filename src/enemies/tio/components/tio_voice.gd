class_name TioVoice
extends VoicePlayer
## Voz del Tío: dice una línea al azar al cambiar de estado, sin repetirse demasiado seguido.

const MSEC_PER_SECOND := 1000.0

@export var suspicion_lines: Array[VoiceLine] = []
@export var hunt_lines: Array[VoiceLine] = []
@export var search_lines: Array[VoiceLine] = []
@export var calm_lines: Array[VoiceLine] = []
## Segundos mínimos entre dos frases.
@export var cooldown := 6.0

var _last_spoken_msec := -1


## Dice una frase acorde al nuevo estado, si ya pasó la pausa.
func react_to_state(state: Tio.State) -> void:
	var options := _lines_for(state)
	if options.is_empty() or not _cooldown_passed():
		return
	_last_spoken_msec = Time.get_ticks_msec()
	var chosen: Array[VoiceLine] = [options.pick_random()]
	say(chosen)


## Devuelve las frases de ese estado.
func _lines_for(state: Tio.State) -> Array[VoiceLine]:
	match state:
		Tio.State.SUSPICION:
			return suspicion_lines
		Tio.State.HUNT:
			return hunt_lines
		Tio.State.SEARCH:
			return search_lines
		Tio.State.CALM:
			return calm_lines
		_:
			return []


## Dice si ya pasó la pausa desde la última frase.
func _cooldown_passed() -> bool:
	if _last_spoken_msec < 0:
		return true
	return Time.get_ticks_msec() - _last_spoken_msec >= cooldown * MSEC_PER_SECOND
