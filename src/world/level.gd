class_name Level
extends Node3D
## Raíz de cada nivel: arranca o restaura la partida, la guarda en cada punto y anuncia su nombre.
## Si se llega desde un tránsito, el nombre ya se vio y el nivel aparece desde el negro.

## Segundos que tarda en aclararse la pantalla al llegar desde un tránsito.
const ARRIVAL_FADE_SECONDS := 1.5
## Capa del negro de llegada, por encima del HUD.
const ARRIVAL_LAYER := 9

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
	if Transition.take_arrival():
		_fade_in_from_black()
	elif not title.is_empty():
		EventBus.notice_requested.emit.call_deferred(title)


## Empieza en negro, como terminó el tránsito, y aclara la pantalla.
func _fade_in_from_black() -> void:
	var layer := CanvasLayer.new()
	layer.layer = ARRIVAL_LAYER
	var curtain := ColorRect.new()
	curtain.color = Color.BLACK
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(curtain)
	add_child(layer)
	var tween := create_tween()
	tween.tween_property(curtain, "modulate:a", 0.0, ARRIVAL_FADE_SECONDS)
	tween.tween_callback(layer.queue_free)


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
