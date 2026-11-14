class_name ObjectiveTrigger
extends Area3D
## Zona que da un nuevo objetivo la primera vez que el jugador la cruza.

## Lo que el jugador tiene que hacer desde aquí.
@export var objective := ""
## Solo cambia el objetivo si el actual es este; vacío para cambiarlo siempre.
@export var after_objective := ""

var is_used := false


## Escucha al jugador.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Da el objetivo una sola vez, si toca en este momento de la historia.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player:
		return
	if not after_objective.is_empty() and GameState.objective != after_objective:
		return
	is_used = true
	GameState.set_objective(objective)
