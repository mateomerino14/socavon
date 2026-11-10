class_name ChaseTrigger
extends Area3D
## Zona antes de la salida: si el jugador no pagó, todos los Tíos salen tras él sin rendirse.

const ENEMY_GROUP := &"enemies"

## Quién habla cuando empieza la persecución.
@export var voice: VoicePlayer
@export var lines: Array[VoiceLine] = []

var is_used := false


## Escucha cuando algo entra en la zona.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## La primera vez que entra el jugador sin haber pagado, suelta a los Tíos.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player or GameState.has_paid:
		return
	is_used = true
	for enemy: Tio in get_tree().get_nodes_in_group(ENEMY_GROUP):
		enemy.start_chase()
	if voice:
		voice.say(lines)
