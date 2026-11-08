class_name HidingSpot
extends Node3D
## Escondite: el jugador se mete con la tecla de interactuar y sale con la misma tecla.

## Grupo declarado en cada escena de escondite; el Tío lo usa para revisarlos al buscar.
const GROUP := &"hiding_spots"
const HIDE_PROMPT := "Esconderse"

@onready var _interactable: Interactable = $Interactable
@onready var _hide_point: Marker3D = $HidePoint
@onready var _exit_point: Marker3D = $ExitPoint


## Conecta la interacción.
func _ready() -> void:
	_interactable.prompt = HIDE_PROMPT
	_interactable.interacted.connect(_on_interacted)


## Devuelve dónde queda el jugador escondido y hacia dónde mira.
func get_hide_transform() -> Transform3D:
	return _hide_point.global_transform


## Devuelve dónde sale el jugador al dejar el escondite.
func get_exit_transform() -> Transform3D:
	return _exit_point.global_transform


## Mete al jugador en el escondite.
func _on_interacted(player: Player) -> void:
	player.hide_in(self)
