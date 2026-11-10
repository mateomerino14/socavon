class_name EndingExit
extends Area3D
## La bocamina: al salir muestra el final según si el jugador le pagó al Tío y vuelve a empezar.

@export var ending_screen: EndingScreen
## Escena que se carga cuando termina el final.
@export_file("*.tscn") var restart_scene_path := ""

@export_group("Final pagado")
@export var paid_title := ""
@export_multiline var paid_body := ""

@export_group("Final sin pagar")
@export var unpaid_title := ""
@export_multiline var unpaid_body := ""

var is_used := false


## Escucha cuando algo entra en la zona.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## La primera vez que sale el jugador, lo detiene y muestra su final.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player:
		return
	is_used = true
	body.set_controls_enabled(false)
	if GameState.has_paid:
		ending_screen.show_ending(paid_title, paid_body)
	else:
		ending_screen.show_ending(unpaid_title, unpaid_body)
	await ending_screen.finished
	if not restart_scene_path.is_empty():
		get_tree().change_scene_to_file(restart_scene_path)
