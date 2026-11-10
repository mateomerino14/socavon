class_name Level
extends Node3D
## Raíz de cada nivel: arranca una partida nueva, guarda el inicio del jugador y anuncia su nombre.

## Nombre que se muestra al empezar; vacío si el nivel abre con su propia cinemática.
@export var title := ""

@onready var _player: Player = $Player


## Reinicia el estado de la partida, guarda la posición inicial y muestra el nombre del nivel.
func _ready() -> void:
	GameState.reset()
	GameState.save_checkpoint(_player.global_transform)
	if not title.is_empty():
		EventBus.notice_requested.emit.call_deferred(title)
