class_name MineMap
extends RefCounted
## Planta de un nivel para el mapa: los huecos de cada pieza de túnel vistos desde arriba.

const MINE_NODE := "Mine"
const BOX_CORNERS: Array[Vector3] = [
	Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(-1, 0, 1), Vector3(1, 0, 1)
]


## Los huecos de todas las piezas de la mina del nivel.
static func rooms_of(level: Node) -> Array[Rect2]:
	var rooms: Array[Rect2] = []
	var mine := level.get_node_or_null(MINE_NODE)
	if mine == null:
		return rooms
	for box: CSGBox3D in mine.find_children("*", "CSGBox3D", true, false):
		if box.operation == CSGShape3D.OPERATION_SUBTRACTION:
			rooms.append(footprint(box))
	return rooms


## Rectángulo que ocupa una caja en el suelo, ya girada y puesta en su lugar.
static func footprint(box: CSGBox3D) -> Rect2:
	var half := box.size / 2.0
	var rect := Rect2()
	var is_first := true
	for corner in BOX_CORNERS:
		var point := box.global_transform * (corner * half)
		var flat := Vector2(point.x, point.z)
		if is_first:
			rect = Rect2(flat, Vector2.ZERO)
			is_first = false
		else:
			rect = rect.expand(flat)
	return rect


## Dice si el jugador ya vio alguna parte del rectángulo.
static func is_room_explored(room: Rect2) -> bool:
	var first := GameState.map_cell(Vector3(room.position.x, 0.0, room.position.y))
	var last := GameState.map_cell(Vector3(room.end.x, 0.0, room.end.y))
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			if GameState.explored.has(Vector2i(x, z)):
				return true
	return false
