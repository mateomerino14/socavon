class_name CaughtReaction
extends Node
## Susto al ser atrapado: la vista gira a la cara del Tío, se acerca, tiembla y suena su grito.

const ENEMY_GROUP := &"enemies"
## El temblor vertical va a otro ritmo que el horizontal para que no parezca un círculo.
const SHAKE_VERTICAL_RATIO := 1.3

## Rapidez con la que la mirada se clava en la cara.
@export var turn_speed := 9.0
## Metros que la vista se arrastra hacia la cara.
@export var pull_distance := 0.15
@export var pull_speed := 3.0
## Temblor de la vista en el momento del susto, que se va calmando.
@export var shake_strength := 0.03
@export var shake_decay := 1.6
@export var shake_frequency := 38.0

var is_active := false

var _catcher: Tio
var _shake := 0.0
var _time := 0.0

@onready var _body: Node3D = owner
@onready var _head: Node3D = owner.get_node("Head")
@onready var _camera: Camera3D = owner.get_node("Head/Camera3D")
@onready var _scream: AudioStreamPlayer = $Scream


## Escucha las capturas.
func _ready() -> void:
	EventBus.player_caught.connect(_on_player_caught)
	set_process(false)


## Mira a la cara del captor, se acerca y tiembla.
func _process(delta: float) -> void:
	_time += delta
	var face := _catcher.get_face_position()
	var to_face := face - _head.global_position
	var flat := Vector2(to_face.x, to_face.z)
	var yaw := atan2(-to_face.x, -to_face.z)
	var pitch := atan2(to_face.y, flat.length())
	_body.rotation.y = lerp_angle(_body.rotation.y, yaw, turn_speed * delta)
	_head.rotation.x = lerp_angle(_head.rotation.x, pitch, turn_speed * delta)
	var target_pull := Vector3.FORWARD * pull_distance
	_camera.position = _camera.position.move_toward(target_pull, pull_speed * delta)
	_shake = move_toward(_shake, 0.0, shake_decay * shake_strength * delta)
	_camera.h_offset = sin(_time * shake_frequency) * _shake
	_camera.v_offset = cos(_time * shake_frequency * SHAKE_VERTICAL_RATIO) * _shake


## Deja la vista quieta y normal; se usa al reaparecer.
func reset() -> void:
	is_active = false
	_catcher = null
	EventBus.hud_visibility_requested.emit(true)
	set_process(false)
	_camera.position = Vector3.ZERO
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0


## Busca al captor más cercano y empieza el susto.
func _on_player_caught() -> void:
	_catcher = _closest_enemy()
	if _catcher == null:
		return
	is_active = true
	_time = 0.0
	_shake = shake_strength
	_scream.play()
	EventBus.hud_visibility_requested.emit(false)
	set_process(true)


## Devuelve el enemigo más cercano al jugador, o nada si no hay.
func _closest_enemy() -> Tio:
	var closest: Tio
	var best := INF
	for enemy: Tio in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var distance := enemy.global_position.distance_to(_body.global_position)
		if distance < best:
			best = distance
			closest = enemy
	return closest
