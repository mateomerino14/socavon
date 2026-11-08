class_name DeathScreen
extends CanvasLayer
## Pantalla de muerte: funde a negro con un mensaje y vuelve a mostrar el juego.

const OPAQUE := 1.0
const CLEAR := 0.0

@export var fade_out_seconds := 0.35
@export var fade_in_seconds := 1.2

@onready var _curtain: ColorRect = %Curtain
@onready var _message: Label = %Message


## Arranca invisible.
func _ready() -> void:
	_curtain.modulate.a = CLEAR
	_message.modulate.a = CLEAR


## Funde a negro y muestra el mensaje; termina cuando la pantalla está negra.
func fade_out() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_curtain, "modulate:a", OPAQUE, fade_out_seconds)
	tween.tween_property(_message, "modulate:a", OPAQUE, fade_out_seconds)
	await tween.finished


## Quita el negro y el mensaje; termina cuando el juego se ve de nuevo.
func fade_in() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_curtain, "modulate:a", CLEAR, fade_in_seconds)
	tween.tween_property(_message, "modulate:a", CLEAR, fade_in_seconds)
	await tween.finished
