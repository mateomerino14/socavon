class_name TioAnimator
extends Node3D
## Anima al Tío: quieto, caminando o corriendo según su rapidez, y la embestida al atrapar.

const IDLE := &"idle"
const WALK := &"walk"
const RUN := &"run"
const CATCH := &"catch"
const LOOPING: Array[StringName] = [IDLE, WALK, RUN]
const NORMAL_SPEED := 1.0
## La embestida entra más rápido que los demás cambios.
const CATCH_BLEND_RATIO := 0.5

## Por debajo de esta rapidez se queda quieto.
@export var idle_below_speed := 0.3
## Desde esta rapidez corre en vez de caminar.
@export var run_from_speed := 3.0
## Metros que avanza en un ciclo de caminata a velocidad normal.
@export var walk_stride := 1.5
## Metros que avanza en un ciclo de carrera a velocidad normal.
@export var run_stride := 2.8
## Segundos de mezcla al cambiar de animación.
@export var blend_seconds := 0.25

var _player: AnimationPlayer
var _is_catching := false


## Busca el reproductor de animaciones del modelo y deja en bucle las que se repiten.
func _ready() -> void:
	_player = find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	for animation_name in LOOPING:
		_player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	_player.play(IDLE)


## Elige la animación según la rapidez y ajusta su velocidad para que los pies no patinen.
func register_movement(speed: float) -> void:
	if _is_catching:
		return
	if speed < idle_below_speed:
		_play(IDLE, NORMAL_SPEED)
	elif speed < run_from_speed:
		_play(WALK, speed / _natural_speed(WALK, walk_stride))
	else:
		_play(RUN, speed / _natural_speed(RUN, run_stride))


## Lanza la embestida y se queda en ella hasta que lo reinicien.
func play_catch() -> void:
	_is_catching = true
	_player.speed_scale = NORMAL_SPEED
	_player.play(CATCH, blend_seconds * CATCH_BLEND_RATIO)


## Vuelve a la pose quieta; se usa al reaparecer.
func reset() -> void:
	_is_catching = false
	_player.speed_scale = NORMAL_SPEED
	_player.play(IDLE)


## Cambia de animación con mezcla solo si es otra, y ajusta su velocidad.
func _play(animation_name: StringName, speed_scale: float) -> void:
	if _player.current_animation != animation_name:
		_player.play(animation_name, blend_seconds)
	_player.speed_scale = speed_scale


## Metros por segundo que cubre la animación a velocidad normal.
func _natural_speed(animation_name: StringName, stride: float) -> float:
	return stride / _player.get_animation(animation_name).length
