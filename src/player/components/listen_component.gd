class_name ListenComponent
extends Node
## Escuchar: baja el ambiente, sube los efectos y cierra un poco la vista al concentrarse.

const AMBIENCE_BUS := &"Ambiente"
const EFFECTS_BUS := &"Efectos"
const NORMAL_DB := 0.0

@export var ambience_listening_db := -18.0
@export var effects_listening_db := 6.0
@export var fov_reduction := 8.0
@export var transition_speed := 4.0

var is_listening := false

var _weight := 0.0
var _base_fov := 0.0

@onready var _ambience_bus := AudioServer.get_bus_index(AMBIENCE_BUS)
@onready var _effects_bus := AudioServer.get_bus_index(EFFECTS_BUS)


## Indica si el jugador está escuchando en este frame.
func set_listening(value: bool) -> void:
	is_listening = value


## Acerca los buses de audio y la vista al estado de escucha o al normal.
func update_listening(delta: float, camera: Camera3D) -> void:
	if _base_fov == 0.0:
		_base_fov = camera.fov
	var target := 0.0
	if is_listening:
		target = 1.0
	_weight = move_toward(_weight, target, transition_speed * delta)
	AudioServer.set_bus_volume_db(_ambience_bus, lerpf(NORMAL_DB, ambience_listening_db, _weight))
	AudioServer.set_bus_volume_db(_effects_bus, lerpf(NORMAL_DB, effects_listening_db, _weight))
	camera.fov = _base_fov - fov_reduction * _weight
