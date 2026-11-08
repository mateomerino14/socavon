class_name FirstPersonCamera
extends Node3D
## Cabeza del jugador: el giro horizontal rota el cuerpo y el vertical solo la cabeza.

const MIN_BOB_SPEED_RATIO := 0.1
const MAX_BOB_SPEED_RATIO := 1.6
const BOB_SIDE_FREQUENCY_RATIO := 0.5
const BOB_SIDE_AMPLITUDE_RATIO := 0.6

@export_group("Mirada")
@export var mouse_sensitivity := 0.0022
@export var gamepad_sensitivity := 2.6
@export_range(10.0, 89.0) var max_pitch_degrees := 85.0

@export_group("Balanceo al caminar")
@export var bob_frequency := 1.9
@export var bob_amplitude := 0.035
@export var bob_return_speed := 8.0

@export_group("Altura")
@export var height_transition_speed := 9.0

var look_enabled := true

var _target_height := 0.0
var _bob_time := 0.0

@onready var _body: Node3D = get_parent()
@onready var _camera: Camera3D = $Camera3D


## Toma la altura inicial y captura el ratón.
func _ready() -> void:
	_target_height = position.y
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Mira con el ratón; Escape suelta el ratón y un clic lo vuelve a capturar.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and _can_look_with_mouse():
		_look(event.relative * mouse_sensitivity)


## Mira con el stick derecho y acerca la cabeza a su altura objetivo.
func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_enabled and stick != Vector2.ZERO:
		_look(stick * gamepad_sensitivity * delta)
	position.y = lerpf(position.y, _target_height, height_transition_speed * delta)


## Fija la altura de los ojos respecto al suelo.
func set_target_height(height: float) -> void:
	_target_height = height


## Balancea la cámara según la velocidad relativa a caminar.
func update_bob(delta: float, speed_ratio: float, is_grounded: bool) -> void:
	if is_grounded and speed_ratio > MIN_BOB_SPEED_RATIO:
		_bob_time += delta * bob_frequency * TAU * speed_ratio
		var amplitude := bob_amplitude * minf(speed_ratio, MAX_BOB_SPEED_RATIO)
		_camera.position.y = sin(_bob_time) * amplitude
		_camera.position.x = (
			cos(_bob_time * BOB_SIDE_FREQUENCY_RATIO) * amplitude * BOB_SIDE_AMPLITUDE_RATIO
		)
	else:
		_camera.position = _camera.position.lerp(Vector3.ZERO, bob_return_speed * delta)


## Endereza la cabeza y la cámara, como al reaparecer.
func reset_look() -> void:
	rotation.x = 0.0
	_camera.position = Vector3.ZERO


## Dice si el ratón puede mover la mirada.
func _can_look_with_mouse() -> bool:
	return look_enabled and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


## Gira el cuerpo en horizontal y la cabeza en vertical, con límite de inclinación.
func _look(amount: Vector2) -> void:
	var max_pitch := deg_to_rad(max_pitch_degrees)
	_body.rotate_y(-amount.x)
	rotation.x = clampf(rotation.x - amount.y, -max_pitch, max_pitch)
