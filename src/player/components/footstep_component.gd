class_name FootstepComponent
extends Node
## Convierte la distancia recorrida en pasos, y cada paso en un ruido que el Tío puede oír.

@export_group("Distancia entre pasos (m)")
@export var walk_step_distance := 0.75
@export var sprint_step_distance := 1.05
@export var crouch_step_distance := 0.6

@export_group("Volumen del paso (0 a 1)")
@export var walk_loudness := 0.35
@export var sprint_loudness := 1.0
@export var crouch_loudness := 0.08

var _distance_since_step := 0.0


## Suma lo que avanzó el jugador y emite un paso al completar el tramo.
func register_movement(distance: float, state: Player.MoveState, origin: Vector3) -> void:
	if state == Player.MoveState.IDLE:
		_distance_since_step = 0.0
		return
	_distance_since_step += distance
	if _distance_since_step >= _step_distance_for(state):
		_distance_since_step = 0.0
		EventBus.noise_emitted.emit(origin, _loudness_for(state))


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
