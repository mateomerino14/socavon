extends TestCase
## Pruebas de escuchar y asomarse: quietud al escuchar, buses de audio, inclinación y paredes.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const SETTLE_FRAMES := 10
const ACTION_FRAMES := 45
const OPEN_SPOT := Vector3(0.0, 0.05, -8.0)
const NEAR_RIGHT_WALL := Vector3(1.0, 0.05, -11.5)
const MIN_OPEN_LEAN := 0.3

var _tunnel: Node3D
var _player: Player
var _head: FirstPersonCamera


## Carga el túnel.
func before_each() -> void:
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)
	_player = _tunnel.get_node("Player")
	_head = _player.get_node("Head")


## Suelta las acciones y libera el túnel.
func after_each() -> void:
	for action: String in ["listen", "move_forward", "lean_right"]:
		Input.action_release(action)
	_tunnel.free()


## Mientras escucha no avanza y los efectos suben de volumen.
func test_listening_stops_movement_and_boosts_effects() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var start := _player.global_position
	Input.action_press("listen")
	Input.action_press("move_forward")
	await wait_physics_frames(ACTION_FRAMES)
	var moved := ((_player.global_position - start) * Player.HORIZONTAL_PLANE).length()
	assert_true(moved < 0.05, "No debe avanzar mientras escucha (avanzó %.2f m)" % moved)
	var effects_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efectos"))
	assert_true(effects_db > 0.0, "Los efectos deben sonar más fuerte al escuchar")
	Input.action_release("listen")
	await wait_physics_frames(ACTION_FRAMES)
	effects_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Efectos"))
	assert_almost_eq(effects_db, 0.0, "Al dejar de escuchar los efectos vuelven a la normalidad")


## En el pasillo abierto se asoma hacia el lado pedido.
func test_leans_in_open_space() -> void:
	_player.global_position = OPEN_SPOT
	await wait_physics_frames(SETTLE_FRAMES)
	Input.action_press("lean_right")
	await wait_physics_frames(ACTION_FRAMES)
	assert_true(_head.position.x > MIN_OPEN_LEAN, "Debe asomarse a la derecha")


## Pegado a la pared no saca la cabeza a través de la roca.
func test_lean_stops_at_wall() -> void:
	_player.global_position = NEAR_RIGHT_WALL
	await wait_physics_frames(SETTLE_FRAMES)
	Input.action_press("lean_right")
	await wait_physics_frames(ACTION_FRAMES)
	var head_x := _head.global_position.x
	assert_true(
		head_x < 1.5 - Player.LEAN_WALL_MARGIN / 2.0, "La cabeza no debe entrar en la pared"
	)
