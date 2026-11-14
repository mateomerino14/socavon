class_name TioApparition
extends Node3D
## Aparición: al cruzar la zona, el Tío cruza al fondo del túnel y se pierde, sin cazar.

const WALK := &"walk"
const BLEND_SECONDS := 0.2

## Marca con que se recuerda que ya pasó; única en el nivel.
@export var done_id := ""
## Dónde aparece y hacia dónde camina, respecto de la zona que lo dispara.
@export var start_offset := Vector3(-4.0, 0.0, -10.0)
@export var goal_offset := Vector3(4.0, 0.0, -10.0)
## Segundos que tarda en cruzar.
@export var walk_seconds := 3.0
## Pasos del Tío mientras cruza.
@export var step_seconds := 0.55
## Solo pasa si el objetivo actual es este; vacío para que pase siempre.
@export var after_objective := ""

var is_walking := false

@onready var _trigger: Area3D = $Trigger
@onready var _model: Node3D = $Model
@onready var _goal: Marker3D = $Goal
@onready var _sting: AudioStreamPlayer = $Sting
@onready var _steps: AudioStreamPlayer3D = $Model/Steps
@onready var _step_timer: Timer = $StepTimer


## Pone los puntos de partida y llegada y queda escondido hasta que el jugador cruce la zona.
func _ready() -> void:
	_model.position = start_offset
	_goal.position = goal_offset
	_model.visible = false
	_trigger.body_entered.connect(_on_body_entered)
	_step_timer.timeout.connect(_steps.play)


## Cruza del punto de partida a la meta y desaparece.
func appear() -> void:
	is_walking = true
	GameState.mark_done(done_id)
	_model.visible = true
	var goal := _goal.global_position
	goal.y = _model.global_position.y
	_model.look_at(goal)
	var player := _model.find_child("AnimationPlayer") as AnimationPlayer
	player.get_animation(WALK).loop_mode = Animation.LOOP_LINEAR
	player.play(WALK, BLEND_SECONDS)
	_sting.play()
	_step_timer.start(step_seconds)
	var tween := create_tween()
	tween.tween_property(_model, "global_position", _goal.global_position, walk_seconds)
	await tween.finished
	_step_timer.stop()
	_model.visible = false
	is_walking = false


## Aparece una vez, si toca en este momento de la historia.
func _on_body_entered(body: Node3D) -> void:
	if not body is Player or is_walking or GameState.is_done(done_id):
		return
	if not after_objective.is_empty() and GameState.objective != after_objective:
		return
	appear()
