class_name Lever
extends Node3D
## Palanca de hierro: al bajarla suena un golpe que el Tío oye y cuenta para su reja.

const PULL_PROMPT := "Bajar la palanca"
const DONE_PROMPT := "La palanca ya está abajo"
const UP_ANGLE := -0.7
const DOWN_ANGLE := 0.7
const PULL_SECONDS := 0.35
## Volumen del golpe para el oído del Tío.
const PULL_LOUDNESS := 1.0

## Marca con que se recuerda que ya se bajó; única en el nivel.
@export var done_id := ""
## Reja que abre.
@export var gate: Gate
## Objetivo una vez bajada; vacío para no cambiarlo.
@export var objective_after := ""

var is_down := false

@onready var _handle: Node3D = $Handle
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer3D = $Sound


## Arriba por defecto; abajo si ya se bajó antes.
func _ready() -> void:
	_handle.rotation.x = UP_ANGLE
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_restore.call_deferred()


## La baja con su golpe y su ruido, y avisa a su reja.
func pull() -> void:
	if is_down:
		return
	is_down = true
	GameState.mark_done(done_id)
	_sound.play()
	EventBus.noise_emitted.emit(global_position, PULL_LOUDNESS)
	create_tween().tween_property(_handle, "rotation:x", DOWN_ANGLE, PULL_SECONDS)
	if not objective_after.is_empty():
		GameState.set_objective(objective_after)
	if gate:
		gate.add_lever()


## Si al continuar ya estaba abajo, aparece abajo y cuenta para la reja sin ruido.
func _restore() -> void:
	if done_id.is_empty() or not GameState.is_done(done_id):
		return
	is_down = true
	_handle.rotation.x = DOWN_ANGLE
	if gate:
		gate.add_lever(true)


## Ofrece bajarla mientras esté arriba.
func _build_prompt(_player: Player) -> String:
	if is_down:
		return DONE_PROMPT
	return PULL_PROMPT


## El jugador la baja.
func _on_interacted(_player: Player) -> void:
	pull()
