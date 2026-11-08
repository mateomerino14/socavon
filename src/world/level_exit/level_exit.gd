class_name LevelExit
extends Area3D
## Salida del nivel: al cruzarla avisa al jugador y carga el siguiente nivel si hay uno.

@export var message := "Saliste del nivel"
## Escena del siguiente nivel; vacía mientras no exista.
@export_file("*.tscn") var next_level_path := ""

var is_used := false


## Escucha cuando algo entra en la zona.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## La primera vez que entra el jugador, avisa y pasa al siguiente nivel.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player:
		return
	is_used = true
	EventBus.notice_requested.emit(message)
	if not next_level_path.is_empty():
		get_tree().change_scene_to_file.call_deferred(next_level_path)
