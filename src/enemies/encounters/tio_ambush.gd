class_name TioAmbush
extends Area3D
## Emboscada: cuando el jugador cruza la zona, el Tío aparece de golpe en un punto y sale a cazarlo,
## con un golpe de susto. Pasa una sola vez y no se repite al continuar la partida.

## Marca con que se recuerda que ya pasó; única en el nivel.
@export var done_id := ""
@export var tio: Tio
## Dónde aparece el Tío, respecto de la zona que lo dispara.
@export var spawn_offset := Vector3(0.0, 0.0, -8.0)
## Solo pasa si el objetivo actual es este; vacío para que pase siempre.
@export var after_objective := ""

@onready var _spawn: Marker3D = $Spawn
@onready var _sting: AudioStreamPlayer = $Sting


## Pone el punto de aparición y escucha al jugador.
func _ready() -> void:
	_spawn.position = spawn_offset
	body_entered.connect(_on_body_entered)


## Hace aparecer al Tío una vez, si toca en este momento de la historia.
func _on_body_entered(body: Node3D) -> void:
	if not body is Player or GameState.is_done(done_id):
		return
	if not after_objective.is_empty() and GameState.objective != after_objective:
		return
	GameState.mark_done(done_id)
	_sting.play()
	tio.ambush(_spawn.global_transform)
