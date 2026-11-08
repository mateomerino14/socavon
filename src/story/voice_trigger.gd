class_name VoiceTrigger
extends Area3D
## Zona que, la primera vez que el jugador la cruza, hace que alguien diga unas líneas.

@export var lines: Array[VoiceLine] = []
## Quién habla; si se deja vacío, habla desde la propia zona.
@export var voice: VoicePlayer

var is_used := false

@onready var _own_voice: VoicePlayer = $VoicePlayer


## Escucha cuando algo entra en la zona.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Dice las líneas una sola vez cuando entra el jugador.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player:
		return
	is_used = true
	var speaker := _own_voice
	if voice:
		speaker = voice
	speaker.say(lines)
