class_name RespawnDirector
extends Node
## Dirige la muerte: funde a negro, lleva al jugador al último altar y reinicia a los enemigos.

const ENEMY_GROUP := &"enemies"

## Segundos en negro antes de reaparecer.
@export var black_hold_seconds := 1.6

var is_respawning := false

@onready var _death_screen: DeathScreen = $DeathScreen
@onready var _hold_timer: Timer = $HoldTimer


## Escucha las capturas del jugador.
func _ready() -> void:
	EventBus.player_caught.connect(_on_player_caught)


## Corre la secuencia completa de muerte y reaparición.
func _on_player_caught() -> void:
	if is_respawning:
		return
	is_respawning = true
	var player := get_tree().get_first_node_in_group(Player.GROUP) as Player
	player.set_controls_enabled(false)
	await _death_screen.fade_out()
	_hold_timer.start(black_hold_seconds)
	await _hold_timer.timeout
	player.respawn_at(GameState.checkpoint)
	for enemy: Tio in get_tree().get_nodes_in_group(ENEMY_GROUP):
		enemy.reset()
	await _death_screen.fade_in()
	player.set_controls_enabled(true)
	is_respawning = false
