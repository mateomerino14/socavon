class_name DripEmitter
extends AudioStreamPlayer3D
## Goteo del techo: suena a intervalos al azar para que la mina nunca esté en silencio.

@export var min_interval := 2.5
@export var max_interval := 8.0

@onready var _timer: Timer = $Timer


## Programa la primera gota.
func _ready() -> void:
	_timer.timeout.connect(_on_timer_timeout)
	_schedule_next()


## Hace sonar una gota y programa la siguiente.
func _on_timer_timeout() -> void:
	play()
	_schedule_next()


## Espera un tiempo al azar antes de la próxima gota.
func _schedule_next() -> void:
	_timer.start(randf_range(min_interval, max_interval))
