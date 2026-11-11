class_name Level
extends Node3D
## Raíz de cada nivel: arranca o restaura la partida, la guarda en cada punto y anuncia su nombre.

## Nombre que se muestra al empezar; vacío si el nivel abre con su propia cinemática.
@export var title := ""

@onready var _player: Player = $Player


## Reinicia el estado, restaura una partida pendiente o guarda el inicio, y muestra el nombre.
func _ready() -> void:
	GameState.checkpoint_saved.connect(_on_checkpoint_saved)
	GameState.reset()
	var pending := SaveGame.take_pending()
	if pending.is_empty():
		GameState.save_checkpoint(_player.global_transform)
	else:
		_restore(pending)
	if not title.is_empty():
		EventBus.notice_requested.emit.call_deferred(title)


## Deja la partida como estaba guardada y al jugador en su último punto.
func _restore(pending: Dictionary) -> void:
	GameState.add_respect(pending["respeto"] - GameState.respect)
	GameState.has_paid = pending["pagado"]
	GameState.read_notes = pending["notas"]
	var bag: Dictionary = pending["bolsa"]
	for type: ItemCatalog.Type in bag:
		_player.inventory.add(type, bag[type])
	var checkpoint: Transform3D = pending["punto"]
	_player.respawn_at(checkpoint)
	GameState.save_checkpoint(checkpoint)


## Cada punto de guardado también queda en disco.
func _on_checkpoint_saved() -> void:
	SaveGame.save(scene_file_path, _player.inventory)
