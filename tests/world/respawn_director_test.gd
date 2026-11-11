extends TestCase
## Pruebas de la muerte: al ser atrapado, el jugador vuelve al último guardado y el Tío a su lugar.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const FAST_SECONDS := 0.05
const SETTLE_FRAMES := 10
const SEQUENCE_FRAMES := 40
const CLOSE_OFFSET := Vector3(-0.8, 0.05, 0.0)

var _tunnel: Node3D
var _player: Player
var _tio: Tio
var _director: RespawnDirector


## Carga el túnel con la secuencia de muerte acelerada.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")
	_tio = _tunnel.get_node("Tio")
	_director = _tunnel.get_node("RespawnDirector")
	_director.black_hold_seconds = FAST_SECONDS
	_director.scare_seconds = FAST_SECONDS
	var death_screen: DeathScreen = _director.get_node("DeathScreen")
	death_screen.fade_out_seconds = FAST_SECONDS
	death_screen.fade_in_seconds = FAST_SECONDS
	_tio.patrol_points.clear()


## Libera el túnel.
func after_each() -> void:
	_tunnel.free()


## Atrapado, reaparece en el guardado y el Tío vuelve a patrullar desde su inicio.
func test_caught_player_respawns_at_checkpoint() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var checkpoint := GameState.checkpoint.origin
	var tio_spawn := _tio.global_position
	_player.global_position = tio_spawn + CLOSE_OFFSET
	await wait_physics_frames(SEQUENCE_FRAMES)
	assert_false(_director.is_respawning, "La secuencia debe haber terminado")
	assert_true(
		_player.global_position.distance_to(checkpoint) < 0.5,
		"El jugador debe volver al último guardado"
	)
	assert_true(_tio.global_position.distance_to(tio_spawn) < 0.5, "El Tío debe volver a su inicio")
	assert_true(_tio.state == Tio.State.PATROL, "El Tío debe volver a patrullar")


## Durante la muerte el jugador no se mueve aunque se pulse adelante.
func test_controls_are_disabled_while_dead() -> void:
	_player.set_controls_enabled(false)
	var start := _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(SETTLE_FRAMES * 3)
	Input.action_release("move_forward")
	var moved := (_player.global_position - start) * Player.HORIZONTAL_PLANE
	assert_true(moved.length() < 0.05, "No debe moverse sin controles")
