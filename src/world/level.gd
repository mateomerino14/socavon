class_name Level
extends Node3D
## Raíz de cada nivel: arranca una partida nueva y guarda el inicio del jugador.

@onready var _player: Player = $Player


## Reinicia el estado de la partida y guarda la posición inicial.
func _ready() -> void:
	GameState.reset()
	GameState.save_checkpoint(_player.global_transform)
