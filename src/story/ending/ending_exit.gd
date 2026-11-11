class_name EndingExit
extends Area3D
## La bocamina: al llegar, Mateo camina solo hacia la luz y la escena termina según si pagó.
##
## Con el pago hecho, la luz crece hasta cegar y se ve el final "con permiso". Sin pagar,
## el Tío aparece a su espalda justo antes de salir, Mateo se da la vuelta y todo se corta a negro.

const ENEMY_GROUP := &"enemies"

@export var ending_screen: EndingScreen
## La luz de afuera, que crece mientras Mateo se acerca.
@export var daylight: OmniLight3D
## Escena que se carga cuando termina el final.
@export_file("*.tscn") var restart_scene_path := ""

@export_group("Final pagado")
@export var paid_title := ""
@export_multiline var paid_body := ""

@export_group("Final sin pagar")
@export var unpaid_title := ""
@export_multiline var unpaid_body := ""

@export_group("Escena")
## Metros que Mateo camina solo hacia la luz.
@export var walk_distance := 2.5
@export var walk_seconds := 3.5
## Cuánto se multiplica la luz de afuera hasta cegar.
@export var light_growth := 8.0
@export var whiteout_seconds := 3.0
## Segundos que camina antes de que el Tío lo alcance, si no pagó.
@export var ambush_after_seconds := 1.6
@export var turn_seconds := 0.35
@export var ambush_hold_seconds := 1.2
## Distancia a la que aparece el Tío a su espalda.
@export var ambush_distance := 1.3

var is_used := false

@onready var _scream: AudioStreamPlayer = $Scream


## Escucha cuando algo entra en la zona.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


## La primera vez que llega el jugador, juega la escena final y muestra su final.
func _on_body_entered(body: Node3D) -> void:
	if is_used or not body is Player:
		return
	is_used = true
	var player := body as Player
	player.set_controls_enabled(false)
	EventBus.hud_visibility_requested.emit(false)
	if GameState.has_paid:
		await _walk_into_light(player)
		ending_screen.show_ending(paid_title, paid_body)
	else:
		await _ambush(player)
		ending_screen.cut_to_black()
		ending_screen.show_ending(unpaid_title, unpaid_body)
	await ending_screen.finished
	if not restart_scene_path.is_empty():
		get_tree().change_scene_to_file(restart_scene_path)


## Camina hacia la luz mientras crece y la pantalla se vuelve blanca.
func _walk_into_light(player: Player) -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(player, "global_position", _ahead_of(player), walk_seconds)
	if daylight:
		var target := daylight.light_energy * light_growth
		tween.tween_property(daylight, "light_energy", target, walk_seconds)
	await create_tween().tween_interval(walk_seconds - whiteout_seconds).finished
	await ending_screen.flash_white(whiteout_seconds)


## Camina un poco, el Tío aparece detrás, Mateo se da la vuelta y lo ve gritar.
func _ambush(player: Player) -> void:
	var walk := create_tween()
	walk.tween_property(player, "global_position", _ahead_of(player), walk_seconds)
	await create_tween().tween_interval(ambush_after_seconds).finished
	walk.kill()
	var tio := _closest_tio(player)
	if tio == null:
		return
	var behind := player.global_position + player.global_basis.z * ambush_distance
	tio.stage_ambush(behind, player.global_position)
	_scream.play()
	var head: Node3D = player.get_node("Head")
	var turn := create_tween().set_parallel()
	turn.tween_property(player, "rotation:y", player.rotation.y + PI, turn_seconds)
	turn.tween_property(head, "rotation:x", 0.0, turn_seconds)
	await turn.finished
	await create_tween().tween_interval(ambush_hold_seconds).finished


## Punto delante del jugador, hacia donde mira.
func _ahead_of(player: Player) -> Vector3:
	return player.global_position - player.global_basis.z * walk_distance


## Devuelve el Tío más cercano al jugador, o nada si no hay.
func _closest_tio(player: Player) -> Tio:
	var closest: Tio
	var best := INF
	for tio: Tio in get_tree().get_nodes_in_group(ENEMY_GROUP):
		var distance := tio.global_position.distance_to(player.global_position)
		if distance < best:
			best = distance
			closest = tio
	return closest
