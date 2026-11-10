class_name BodySway
extends Node3D
## Balanceo pesado del cuerpo de arcilla del Tío: se mece y se hunde a cada zancada.

## Distancia de una zancada completa (dos pasos).
@export var stride_length := 2.4
## Inclinación máxima hacia los lados, en grados.
@export var max_roll_degrees := 6.0
## Cuánto se hunde el cuerpo en cada paso, en metros.
@export var max_bob := 0.05
## Inclinación hacia adelante al correr, en grados.
@export var max_lean_degrees := 8.0
## Rapidez a la que el balanceo llega al máximo.
@export var full_speed := 4.0
## Qué tan rápido se acomoda al cambiar de rapidez.
@export var settle_speed := 4.0

var _phase := 0.0
var _intensity := 0.0


## Avanza la zancada según lo recorrido y acomoda el balanceo a la rapidez.
func register_movement(distance: float, speed: float, delta: float) -> void:
	_phase = fmod(_phase + distance / stride_length * TAU, TAU)
	var target := clampf(speed / full_speed, 0.0, 1.0)
	_intensity = move_toward(_intensity, target, settle_speed * delta)
	var roll := sin(_phase) * deg_to_rad(max_roll_degrees) * _intensity
	var lean := -deg_to_rad(max_lean_degrees) * _intensity
	rotation = Vector3(lean, 0.0, roll)
	position.y = -absf(sin(_phase)) * max_bob * _intensity
