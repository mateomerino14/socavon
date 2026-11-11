extends TestCase
## Pruebas de los niveles 3 a 5: se anuncian, se recorren, encadenan y cada uno tiene su peligro.

const LEVEL_03 := preload("res://src/world/level_03/level_03.tscn")
const LEVEL_04 := preload("res://src/world/level_04/level_04.tscn")
const LEVEL_05 := preload("res://src/world/level_05/level_05.tscn")
const SETTLE_FRAMES := 20
const PATH_TOLERANCE := 1.0
const CRAWL_CENTER := Vector3(-8.0, 0.0, -8.0)
## El gateadero es bajo: la malla del Tío no debe pasar cerca de su centro.
const CRAWL_CLEARANCE := 1.5
const SQUAD_SIZE := 2
const CRAWL_ENTRANCE := Vector3(-1.5, 0.05, -8.0)
const FACING_WEST := PI / 2.0
const CRAWL_FRAMES := 240
## Metros que debe avanzar agachado dentro del gateadero.
const MIN_CRAWLED := 4.0

var _level: Level
var _player: Player
var _last_notice := ""


## Escucha los avisos.
func before_each() -> void:
	EventBus.notice_requested.connect(_on_notice)


## Libera el nivel cargado.
func after_each() -> void:
	EventBus.notice_requested.disconnect(_on_notice)
	if _level:
		_level.free()
		_level = null


## Cada nivel anuncia su nombre al empezar.
func test_levels_show_their_titles() -> void:
	for scene: PackedScene in [LEVEL_03, LEVEL_04, LEVEL_05]:
		await _load(scene)
		assert_true(_last_notice == _level.title, "Debe anunciar '%s'" % _level.title)
		_level.free()
		_level = null


## Las salidas encadenan los niveles 3, 4 y 5.
func test_exits_chain_to_the_next_level() -> void:
	await _load(LEVEL_03)
	var exit: LevelExit = _level.get_node("LevelExit")
	assert_true(exit.next_level_path.ends_with("level_04.tscn"), "El nivel 3 debe llevar al 4")
	_level.free()
	await _load(LEVEL_04)
	exit = _level.get_node("LevelExit")
	assert_true(exit.next_level_path.ends_with("level_05.tscn"), "El nivel 4 debe llevar al 5")


## Nivel 3: hay camino al altar, a la veta y a la salida, y el Tío no cabe en el gateadero.
func test_vein_level_is_walkable_and_crawlway_is_safe() -> void:
	await _load(LEVEL_03)
	_assert_reachable(["Altars/CrawlAltar", "Notes/HelmetNote", "LevelExit"])
	var map := _level.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, CRAWL_CENTER)
	assert_true(
		_flat_distance(closest, CRAWL_CENTER) > CRAWL_CLEARANCE,
		"El Tío no debe poder entrar al gateadero"
	)


## Nivel 3: agachado se puede cruzar el gateadero.
func test_player_can_crawl_through() -> void:
	await _load(LEVEL_03)
	_player.global_position = CRAWL_ENTRANCE
	_player.rotation.y = FACING_WEST
	Input.action_press("crouch")
	await wait_physics_frames(SETTLE_FRAMES)
	Input.action_press("move_forward")
	await wait_physics_frames(CRAWL_FRAMES)
	Input.action_release("move_forward")
	Input.action_release("crouch")
	var crawled := CRAWL_ENTRANCE.x - _player.global_position.x
	assert_true(crawled > MIN_CRAWLED, "Debe avanzar por el gateadero (avanzó %.2f m)" % crawled)


## Nivel 4: dos Tíos rondan y se llega al altar, a las notas y a la salida.
func test_squad_level_has_two_tios() -> void:
	await _load(LEVEL_04)
	_assert_reachable(["Altars/SquadAltar", "Notes/RosendoNote", "Notes/FaustinoDeal", "LevelExit"])
	var tios := tree.get_nodes_in_group(&"enemies")
	assert_true(tios.size() == SQUAD_SIZE, "Debe haber dos Tíos (hay %d)" % tios.size())


## Nivel 5: se llega a las tres ofrendas, al altar del pago y a la bocamina.
func test_mouth_level_is_walkable() -> void:
	await _load(LEVEL_05)
	_assert_reachable(
		[
			"Pickups/Coca",
			"Pickups/Alcohol",
			"Pickups/Cigarette",
			"Altars/PaymentAltar",
			"EndingExit"
		]
	)


## Carga un nivel, espera a que se asiente y toma al jugador.
func _load(scene: PackedScene) -> void:
	_level = scene.instantiate()
	add_to_tree(_level)
	_player = _level.get_node("Player")
	await wait_physics_frames(SETTLE_FRAMES)


## Comprueba que hay camino desde el inicio hasta cada nodo; a un altar se llega por su frente.
func _assert_reachable(paths: Array[String]) -> void:
	var map := _level.get_world_3d().navigation_map
	for path in paths:
		var node := _level.get_node(path) as Node3D
		var target := node.global_position
		if node is Altar:
			target = (node as Altar).get_respawn_transform().origin
		var route := NavigationServer3D.map_get_path(map, _player.global_position, target, true)
		var end := _player.global_position
		if not route.is_empty():
			end = route[route.size() - 1]
		assert_true(_flat_distance(end, target) < PATH_TOLERANCE, "Debe haber camino a %s" % path)


## Devuelve la distancia en el suelo entre dos puntos.
func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Guarda el último aviso.
func _on_notice(text: String) -> void:
	_last_notice = text
