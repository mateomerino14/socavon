extends TestCase
## Pruebas del nivel 2: se anuncia, se recorre, el Tío ronda los rieles y el agua frena y delata.

const LEVEL_SCENE := preload("res://src/world/level_02/level_02.tscn")
const SETTLE_FRAMES := 20
## El nombre aparece un segundo después de que se ve el nivel, y el objetivo un rato después.
const TITLE_FRAMES := 90
const OBJECTIVE_FRAMES := 240
const WADE_FRAMES := 60
const PATH_TOLERANCE := 1.0
const WATER_SPOT := Vector3(-8.0, 0.05, -12.0)
const DRY_SPOT := Vector3(0.0, 0.05, -5.0)

var _level: Level
var _player: Player
var _tio: Tio
var _last_title := ""


## Carga el nivel y escucha su nombre.
func before_each() -> void:
	EventBus.level_title_requested.connect(_on_title)
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	_player = _level.get_node("Player")
	_tio = _level.get_node("Tio")


## Libera el nivel.
func after_each() -> void:
	EventBus.level_title_requested.disconnect(_on_title)
	_level.free()


## Al empezar muestra el nombre del nivel y después su objetivo.
func test_shows_level_title() -> void:
	await wait_physics_frames(TITLE_FRAMES)
	assert_true(_last_title == _level.title, "Debe anunciar el nivel (fue '%s')" % _last_title)
	await wait_physics_frames(OBJECTIVE_FRAMES)
	assert_true(GameState.objective == _level.objective, "Después da el objetivo del nivel")


## Hay camino desde el inicio al altar, a la nota de Wilmer y a la salida.
func test_key_places_are_reachable() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var altar: Altar = _level.get_node("Altars/RailsAltar")
	var targets := [
		altar.get_respawn_transform().origin,
		_level.get_node("Notes/WilmerNote").global_position,
		_level.get_node("LevelExit").global_position,
	]
	for target: Vector3 in targets:
		var end := _path_end(_player.global_position, target)
		assert_true(_flat_distance(end, target) < PATH_TOLERANCE, "Debe haber camino a %s" % target)


## A diferencia del nivel 1, el Tío anda suelto y puede llegar hasta el jugador.
func test_tio_can_reach_the_player() -> void:
	await wait_physics_frames(SETTLE_FRAMES)
	var end := _path_end(_tio.global_position, _player.global_position)
	assert_true(
		_flat_distance(end, _player.global_position) < PATH_TOLERANCE,
		"El Tío debe poder llegar al jugador"
	)


## En el agua camina más lento y sus pasos son más fuertes; al salir vuelve a la normalidad.
func test_water_slows_and_splashes() -> void:
	var footsteps: FootstepComponent = _player.get_node("FootstepComponent")
	_player.global_position = WATER_SPOT
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(_player.is_wading(), "Debe estar en el agua")
	assert_true(footsteps.is_wet, "Los pasos deben chapotear")
	var heard: Array[float] = []
	var listener := func(_origin: Vector3, loudness: float) -> void: heard.append(loudness)
	EventBus.noise_emitted.connect(listener)
	Input.action_press("move_forward")
	await wait_physics_frames(WADE_FRAMES)
	Input.action_release("move_forward")
	EventBus.noise_emitted.disconnect(listener)
	assert_true(not heard.is_empty(), "Debe hacer ruido al vadear")
	assert_true(heard.max() > footsteps.walk_loudness, "Vadear debe sonar más que caminar en seco")
	_player.global_position = DRY_SPOT
	await wait_physics_frames(SETTLE_FRAMES)
	assert_false(_player.is_wading(), "Fuera del agua no debe vadear")


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


## Guarda el último nombre de nivel anunciado.
func _on_title(text: String) -> void:
	_last_title = text
