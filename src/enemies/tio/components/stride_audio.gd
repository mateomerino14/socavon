class_name StrideAudio
extends Node3D
## Pasos del Tío: suenan cada cierto tramo, más fuerte cuanto más rápido va.

@export var stride_length := 1.2
@export var quiet_db := -10.0
@export var loud_db := 4.0
## Rapidez a la que los pasos suenan al máximo.
@export var loud_speed := 4.0

var _distance := 0.0

@onready var _audio: AudioStreamPlayer3D = $Audio


## Suma lo que avanzó y hace sonar un paso al completar la zancada.
func register_movement(distance: float, speed: float) -> void:
	_distance += distance
	if _distance < stride_length:
		return
	_distance = 0.0
	_audio.volume_db = lerpf(quiet_db, loud_db, clampf(speed / loud_speed, 0.0, 1.0))
	_audio.play()
