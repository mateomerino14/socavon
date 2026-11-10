class_name EndingScreen
extends CanvasLayer
## Pantalla del final: funde a negro, cuenta qué pasó con Mateo y avisa cuando terminó.

signal finished

const OPAQUE := 1.0
const CLEAR := 0.0

@export var fade_seconds := 2.5
@export var text_delay_seconds := 1.0
## Segundos que se deja leer el final antes de terminar.
@export var hold_seconds := 14.0

var is_showing := false

@onready var _curtain: ColorRect = %Curtain
@onready var _text_box: Control = %TextBox
@onready var _title: Label = %Title
@onready var _body: Label = %Body


## Arranca invisible.
func _ready() -> void:
	_curtain.modulate.a = CLEAR
	_text_box.modulate.a = CLEAR


## Muestra un final con su título y su texto.
func show_ending(title: String, body: String) -> void:
	is_showing = true
	_title.text = title
	_body.text = body
	EventBus.hud_visibility_requested.emit(false)
	var tween := create_tween()
	tween.tween_property(_curtain, "modulate:a", OPAQUE, fade_seconds)
	tween.tween_interval(text_delay_seconds)
	tween.tween_property(_text_box, "modulate:a", OPAQUE, fade_seconds)
	tween.tween_interval(hold_seconds)
	await tween.finished
	finished.emit()
