class_name HintTrigger
extends Area3D
## Zona que pide un consejo de controles cuando el jugador la cruza; el consejo no se repite.

## Identificador del consejo en HintCatalog.
@export var hint_id := ""


## Escucha al jugador.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Pide el consejo al entrar el jugador.
func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		EventBus.hint_requested.emit(hint_id)
