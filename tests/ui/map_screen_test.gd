extends TestCase
## Pruebas del mapa: la planta, lo recorrido, las marcas y la pausa.

const LEVEL_SCENE := preload("res://src/world/level_02/level_02.tscn")
const SETTLE_FRAMES := 10
const START := Vector3(0, 0, -2)
const FAR_AWAY := Vector3(0, 0, -50)
const GATE_POSITION := Vector2(0, -38.6)

var _level: Level


## Abre el nivel 2 con el estado limpio.
func before_each() -> void:
	GameState.reset()
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)


## Libera el nivel y deja el juego sin pausa.
func after_each() -> void:
	_level.get_tree().paused = false
	_level.free()
	GameState.reset()


## La planta tiene un hueco por cada tramo de túnel, y solo cuenta como visto lo recorrido.
func test_rooms_come_from_the_mine() -> void:
	var rooms := MineMap.rooms_of(_level)
	assert_true(
		rooms.size() > _level.get_node("Mine").get_child_count(), "Hay huecos de cada pieza"
	)
	GameState.explore_around(START)
	var seen := 0
	for room in rooms:
		if MineMap.is_room_explored(room):
			seen += 1
	assert_true(seen > 0 and seen < rooms.size(), "Solo se ve lo recorrido")
	assert_false(GameState.is_explored(FAR_AWAY), "Lo lejano sigue sin dibujar")


## Abierto, pausa el juego y lleva la salida y la reja del buzón; cerrado, sigue el juego.
func test_map_marks_exit_and_gate() -> void:
	var screen: MapScreen = _level.find_child("MapScreen", true, false)
	screen.open()
	assert_true(_level.get_tree().paused, "Detiene el juego")
	var view: MapView = screen.get_node("%MapView")
	assert_false((view.marks[MapView.Mark.EXIT] as Array).is_empty(), "Marca la salida")
	assert_true((view.marks[MapView.Mark.BLOCK] as Array).has(GATE_POSITION), "Marca la reja")
	screen.close()
	assert_false(_level.get_tree().paused, "Al cerrar sigue el juego")
