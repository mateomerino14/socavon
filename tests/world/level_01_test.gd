extends TestCase
## Pruebas del nivel 1: se puede recorrer, el Tío queda sellado tras la roca y la salida avisa.

const LEVEL_SCENE := preload("res://src/world/level_01/level_01.tscn")
const SETTLE_FRAMES := 20
const WALK_FRAMES := 90
const MIN_WALKED_METERS := 1.5
const PATH_TOLERANCE := 1.0
const SEALED_MIN_DISTANCE := 5.0
const SEALED_GALLERY_MIN_X := 18.0
const LOUD := 1.0
const HUNT_SECONDS := 4
const FRAMES_PER_SECOND := 60

var _level: Level
var _player: Player
var _tio: Tio
var _last_notice := ""


## Carga el nivel y escucha los avisos.
func before_each() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	_player = _level.get_node("Player")
	_tio = _level.get_node("Tio")
	EventBus.notice_requested.connect(_on_notice)


## Suelta las teclas y libera el nivel.
func after_each() -> void:
	Input.action_release("move_forward")
	EventBus.notice_requested.disconnect(_on_notice)
	_level.free()


## Desde el derrumbe se puede caminar hacia el norte.
func test_player_can_leave_the_collapse() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_player.is_on_floor(), "Debe empezar en el suelo")
	var start := _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(WALK_FRAMES)
	var walked := start.z - _player.global_position.z
	assert_true(walked > MIN_WALKED_METERS, "Debe salir del derrumbe (avanzó %.2f m)" % walked)


## Hay camino desde el inicio hasta el primer altar, la salida y la coca del ramal oeste.
func test_altar_and_exit_are_reachable() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var altar: Altar = _level.get_node("Altars/FirstAltar")
	var exit: LevelExit = _level.get_node("LevelExit")
	var coca: Pickup = _level.get_node("Pickups/Coca")
	var targets := [
		altar.get_respawn_transform().origin, exit.global_position, coca.global_position
	]
	for target: Vector3 in targets:
		var end := _path_end(_player.global_position, target)
		assert_true(
			_flat_distance(end, target) < PATH_TOLERANCE, "Debe haber camino hasta %s" % target
		)


## El Tío camina en una galería sellada: no hay camino hasta el jugador.
func test_tio_cannot_reach_the_player() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var end := _path_end(_tio.global_position, _player.global_position)
	assert_true(
		_flat_distance(end, _player.global_position) > SEALED_MIN_DISTANCE,
		"El camino del Tío no debe llegar al jugador"
	)


## Aunque oiga un ruido fuerte, no sale de su galería.
func test_tio_stays_sealed_after_noise() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	EventBus.noise_emitted.emit(_tio.global_position + Vector3(-8.0, 0.0, 0.0), LOUD)
	await wait_physics_frames(HUNT_SECONDS * FRAMES_PER_SECOND)
	assert_true(_tio.global_position.x > SEALED_GALLERY_MIN_X, "El Tío debe seguir en su galería")
	assert_true(_tio.state != Tio.State.SUSPICION, "Debe rendirse al no poder llegar al ruido")


## Al cruzar la salida aparece el aviso de fin del nivel.
func test_exit_shows_end_message() -> void:
	var exit: LevelExit = _level.get_node("LevelExit")
	_player.global_position = exit.global_position
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(exit.is_used, "La salida debe activarse")
	assert_true(_last_notice == exit.message, "Debe mostrar el aviso de fin del nivel")


## Devuelve el último punto del camino entre dos lugares.
func _path_end(from: Vector3, to: Vector3) -> Vector3:
	var map := _level.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, from, to, true)
	if path.is_empty():
		return from
	return path[path.size() - 1]


## Devuelve la distancia en el suelo entre dos puntos.
func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Guarda el último aviso.
func _on_notice(text: String) -> void:
	_last_notice = text
