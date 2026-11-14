extends TestCase
## Pruebas de los encuentros con el Tío: la emboscada caza una vez y la aparición no caza.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const AMBUSH_SCENE := preload("res://src/enemies/encounters/tio_ambush.tscn")
const APPARITION_SCENE := preload("res://src/enemies/encounters/tio_apparition.tscn")
const SETTLE_FRAMES := 5
const CROSS_FRAMES := 30
const QUICK_SECONDS := 0.1
const NEAR_SPAWN := 0.5

var _tunnel: Node3D


## Arma el túnel de pruebas con su Tío y su jugador.
func before_each() -> void:
	GameState.reset()
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)


## Libera el túnel y limpia el estado.
func after_each() -> void:
	_tunnel.free()
	GameState.reset()


## La emboscada trae al Tío a su punto y lo pone a cazar, una sola vez.
func test_ambush_brings_tio_once() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var tio: Tio = _tunnel.get_node("Tio")
	var player: Player = _tunnel.get_node("Player")
	var ambush: TioAmbush = AMBUSH_SCENE.instantiate()
	ambush.done_id = "emboscada"
	ambush.tio = tio
	_tunnel.add_child(ambush)
	ambush.global_position = player.global_position
	var spawn: Marker3D = ambush.get_node("Spawn")
	ambush._on_body_entered(player)
	assert_true(tio.state == Tio.State.HUNT, "Sale a cazar")
	assert_true(tio.global_position.distance_to(spawn.global_position) < NEAR_SPAWN, "Aparece allí")
	assert_true(GameState.is_done("emboscada"), "Se recuerda")
	tio.global_position = player.global_position
	ambush._on_body_entered(player)
	assert_false(
		tio.global_position.distance_to(spawn.global_position) < NEAR_SPAWN, "No se repite"
	)


## La aparición cruza hasta su meta y se esconde.
func test_apparition_crosses_and_vanishes() -> void:
	var apparition: TioApparition = APPARITION_SCENE.instantiate()
	apparition.done_id = "aparicion"
	apparition.walk_seconds = QUICK_SECONDS
	_tunnel.add_child(apparition)
	var model: Node3D = apparition.get_node("Model")
	apparition.appear()
	assert_true(model.visible, "Se deja ver")
	await wait_physics_frames(CROSS_FRAMES)
	assert_false(model.visible, "Se pierde en la oscuridad")
	assert_true(GameState.is_done("aparicion"), "Se recuerda")
