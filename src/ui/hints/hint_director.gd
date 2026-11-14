class_name HintDirector
extends Node
## Pide los consejos que dependen de lo que pasa en el juego, como recoger algo o que el Tío cace.

const START_HINTS: Array[String] = ["caminar", "lampara"]
const ITEM_HINTS: Dictionary[ItemCatalog.Type, String] = {
	ItemCatalog.Type.CARBIDE: "carburo",
	ItemCatalog.Type.STONE: "piedra",
}


## Pide los consejos del comienzo y escucha al juego.
func _ready() -> void:
	EventBus.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	_start.call_deferred()


## Ya con todo el nivel cargado: los consejos del comienzo y los Tíos que cazan.
func _start() -> void:
	for id in START_HINTS:
		EventBus.hint_requested.emit(id)
	for tio: Tio in get_tree().get_nodes_in_group(&"enemies"):
		tio.state_changed.connect(_on_tio_state_changed)


## Lo primero que se puede usar enseña la tecla de usar.
func _on_interaction_prompt_changed(prompt: String) -> void:
	if not prompt.is_empty():
		EventBus.hint_requested.emit("usar")


## Al llevar algo, cómo ver la bolsa; con carburo o piedras, cómo usarlos.
func _on_inventory_changed(type: ItemCatalog.Type, count: int) -> void:
	if count <= 0:
		return
	EventBus.hint_requested.emit("inventario")
	if ITEM_HINTS.has(type):
		EventBus.hint_requested.emit(ITEM_HINTS[type])


## La primera vez que el Tío caza, cómo escapar.
func _on_tio_state_changed(state: Tio.State) -> void:
	if state == Tio.State.HUNT:
		EventBus.hint_requested.emit("caza")
