class_name Pickup
extends Node3D
## Objeto en el suelo que el jugador recoge a su bolsa.

const PICK_PROMPT := "Recoger %s"
const FULL_PROMPT := "No cabe más %s"

## Modelo de cada tipo de objeto, hecho en Blender.
const VISUALS := {
	ItemCatalog.Type.CARBIDE: preload("res://src/items/visuals/carbide.tscn"),
	ItemCatalog.Type.COCA: preload("res://src/items/visuals/coca.tscn"),
	ItemCatalog.Type.ALCOHOL: preload("res://src/items/visuals/alcohol.tscn"),
	ItemCatalog.Type.CIGARETTE: preload("res://src/items/visuals/cigarette.tscn"),
	ItemCatalog.Type.STONE: preload("res://src/items/visuals/stone.tscn"),
}

@export var item_type := ItemCatalog.Type.COCA
@export var amount := 1

@onready var _interactable: Interactable = $Interactable


## Conecta la interacción y pone el modelo de su tipo.
func _ready() -> void:
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	add_child((VISUALS[item_type] as PackedScene).instantiate())


## Arma el texto según si cabe en la bolsa.
func _build_prompt(player: Player) -> String:
	var item_name := ItemCatalog.display_name(item_type)
	if player.inventory.can_add(item_type):
		return PICK_PROMPT % item_name
	return FULL_PROMPT % item_name


## Pasa el objeto a la bolsa y desaparece si entró.
func _on_interacted(player: Player) -> void:
	if player.inventory.add(item_type, amount):
		queue_free()
