class_name FootstepComponent
extends Node3D
## Convierte la distancia recorrida en pasos: cada paso suena y es un ruido que el Tío puede oír.

## Volumen de la pisada más fuerte; las demás bajan según su volumen de ruido.
const LOUDEST_STEP_DB := 0.0
const QUIETEST_STEP_DB := -24.0

@export_group("Distancia entre pasos (m)")
@export var walk_step_distance := 0.75
@export var sprint_step_distance := 1.05
@export var crouch_step_distance := 0.6

@export_group("Volumen del paso (0 a 1)")
@export var walk_loudness := 0.35
@export var sprint_loudness := 1.0
@export var crouch_loudness := 0.08

@export_group("En el agua")
## Pisadas que suenan al caminar por agua.
@export var wet_stream: AudioStream
## Cuánto más fuerte (y audible para el Tío) es un paso en el agua.
@export var wet_loudness_scale := 2.5

var is_wet := false

var _distance_since_step := 0.0
var _dry_stream: AudioStream

@onready var _audio: AudioStreamPlayer3D = $Audio


## Recuerda el sonido de pisada en seco.
func _ready() -> void:
	_dry_stream = _audio.stream


## Cambia a pisadas de agua o de vuelta a roca.
func set_wet(wet: bool) -> void:
	is_wet = wet
	_audio.stream = _dry_stream
	if wet:
		_audio.stream = wet_stream


## Suma lo que avanzó el jugador y emite un paso al completar el tramo.
func register_movement(distance: float, state: Player.MoveState, origin: Vector3) -> void:
	if state == Player.MoveState.IDLE:
		_distance_since_step = 0.0
		return
	_distance_since_step += distance
	if _distance_since_step >= _step_distance_for(state):
		_distance_since_step = 0.0
		var loudness := _loudness_for(state)
		if is_wet:
			loudness = minf(loudness * wet_loudness_scale, 1.0)
		_audio.volume_db = lerpf(QUIETEST_STEP_DB, LOUDEST_STEP_DB, loudness)
		_audio.play()
		EventBus.noise_emitted.emit(origin, loudness)


## Devuelve el largo del paso para el estado de movimiento.
func _step_distance_for(state: Player.MoveState) -> float:
	match state:
		Player.MoveState.SPRINT:
			return sprint_step_distance
		Player.MoveState.CROUCH:
			return crouch_step_distance
		_:
			return walk_step_distance


## Devuelve qué tan fuerte suena el paso para el estado de movimiento.
func _loudness_for(state: Player.MoveState) -> float:
	match state:
		Player.MoveState.SPRINT:
			return sprint_loudness
		Player.MoveState.CROUCH:
			return crouch_loudness
		_:
			return walk_loudness
