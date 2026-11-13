class_name FirstPersonBody
extends Node3D
## Los brazos de Mateo vistos desde sus ojos: quietos quedan abajo, fuera de la vista, y aparecen al
## lanzar una piedra. Van en su propia capa de render.

const IDLE := &"idle"
const THROW := &"throw"
const GESTURES: Array[StringName] = [&"throw"]
const BLEND_SECONDS := 0.2

@export var stone_thrower: StoneThrower
## Capa de render del cuerpo propio.
@export_flags_3d_render var render_layers := 2048

var _animation: AnimationPlayer


## Prepara los brazos y escucha a la mano que lanza.
func _ready() -> void:
	_animation = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	_animation.get_animation(IDLE).loop_mode = Animation.LOOP_LINEAR
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.layers = render_layers
	_animation.animation_finished.connect(_on_animation_finished)
	stone_thrower.thrown.connect(_play.bind(THROW))
	_animation.play(IDLE)


## Hace el gesto desde el principio, aunque ya estuviera haciéndolo.
func _play(gesture: StringName) -> void:
	_animation.play(gesture, BLEND_SECONDS)
	_animation.seek(0.0, true)


## Al terminar el gesto, los brazos vuelven a bajar.
func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name in GESTURES:
		_animation.play(IDLE, BLEND_SECONDS)
