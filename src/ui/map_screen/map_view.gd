class_name MapView
extends Control
## Dibujo del mapa: los túneles ya recorridos con tinta sobre papel, el jugador como una flecha y
## marcas para altares, salida y lo que la tapa. El norte queda arriba.

enum Mark { ALTAR, EXIT, BLOCK }

const PAPER := Color(0.83, 0.75, 0.6)
const FLOOR := Color(0.93, 0.87, 0.74)
const INK := Color(0.24, 0.17, 0.11)
const ALTAR_COLOR := Color(0.75, 0.38, 0.12)
const EXIT_COLOR := Color(0.62, 0.12, 0.08)
const PLAYER_COLOR := Color(0.62, 0.12, 0.08)
const MARGIN := 24.0
## Grosor del borde de tinta alrededor de los túneles, en píxeles.
const WALL_INK := 2.5
const MARK_SIZE := 7.0
const MARK_LINE := 3.5
## Proporción del alto de un bloqueo respecto de su ancho.
const BLOCK_THICKNESS := 0.35
const ARROW_LENGTH := 20.0
const ARROW_WIDTH := 12.0
## Cuánto de la flecha queda delante del punto del jugador.
const ARROW_FRONT := 0.6
const EMPTY_FONT_SIZE := 18
const EMPTY_TEXT := "Todavía no recorriste nada"

var rooms: Array[Rect2] = []
## Marcas por tipo: posiciones en el suelo (x, z).
var marks := {}
var player_position := Vector2.ZERO
## Hacia dónde mira el jugador, en radianes alrededor del eje vertical.
var player_heading := 0.0

var _bounds := Rect2()
var _scale := 1.0
var _offset := Vector2.ZERO


## Vuelve a dibujar con lo que se recorrió hasta ahora.
func refresh() -> void:
	queue_redraw()


## Papel, túneles recorridos, marcas y flecha, encajados en el tamaño que tenga el recuadro.
func _draw() -> void:
	_fit()
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	var explored: Array[Rect2] = []
	for room in rooms:
		if MineMap.is_room_explored(room):
			explored.append(room)
	if explored.is_empty():
		var font := get_theme_default_font()
		draw_string(
			font, size / 2.0, EMPTY_TEXT, HORIZONTAL_ALIGNMENT_CENTER, -1, EMPTY_FONT_SIZE, INK
		)
		return
	for room in explored:
		draw_rect(_to_map(room).grow(WALL_INK), INK)
	for room in explored:
		draw_rect(_to_map(room), FLOOR)
	_draw_marks()
	_draw_player()


## Encaja todos los túneles del nivel en el recuadro, sin deformarlos.
func _fit() -> void:
	if rooms.is_empty():
		return
	_bounds = rooms[0]
	for room in rooms:
		_bounds = _bounds.merge(room)
	var available := size - Vector2.ONE * MARGIN * 2.0
	_scale = minf(available.x / _bounds.size.x, available.y / _bounds.size.y)
	_offset = (size - _bounds.size * _scale) / 2.0


## Pasa un rectángulo del suelo al dibujo.
func _to_map(room: Rect2) -> Rect2:
	return Rect2(_point(room.position), room.size * _scale)


## Pasa un punto del suelo al dibujo.
func _point(ground: Vector2) -> Vector2:
	return _offset + (ground - _bounds.position) * _scale


## Altares, salida y bloqueos, solo donde ya se pasó.
func _draw_marks() -> void:
	for kind: Mark in marks:
		for ground: Vector2 in marks[kind]:
			if not GameState.is_explored(Vector3(ground.x, 0.0, ground.y)):
				continue
			var at := _point(ground)
			match kind:
				Mark.ALTAR:
					draw_circle(at, MARK_SIZE, ALTAR_COLOR)
				Mark.EXIT:
					var arm := Vector2.ONE * MARK_SIZE
					var cross := Vector2(arm.x, -arm.y)
					draw_line(at - arm, at + arm, EXIT_COLOR, MARK_LINE)
					draw_line(at - cross, at + cross, EXIT_COLOR, MARK_LINE)
				Mark.BLOCK:
					var half := Vector2(MARK_SIZE, MARK_SIZE * BLOCK_THICKNESS)
					draw_rect(Rect2(at - half, half * 2.0), INK)


## La flecha del jugador, apuntando hacia donde mira.
func _draw_player() -> void:
	var at := _point(player_position)
	var forward := Vector2(-sin(player_heading), -cos(player_heading))
	var side := Vector2(-forward.y, forward.x)
	var tip := at + forward * ARROW_LENGTH * ARROW_FRONT
	var back := at - forward * ARROW_LENGTH * (1.0 - ARROW_FRONT)
	var wing := side * ARROW_WIDTH / 2.0
	draw_colored_polygon(PackedVector2Array([tip, back + wing, back - wing]), PLAYER_COLOR)
