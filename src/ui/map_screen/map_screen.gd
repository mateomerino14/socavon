class_name MapScreen
extends CanvasLayer
## Mapa: pausa y muestra los túneles recorridos, dónde está Mateo, los altares y la salida.

const OBJECTIVE_FORMAT := "Objetivo: %s"
const TITLE_FORMAT := "Mapa · %s"
const PLAIN_TITLE := "Mapa"
## Cada cuánto anota por dónde anda el jugador.
const TRACK_SECONDS := 0.25

var is_open := false

var _track_time := 0.0
var _is_hud_visible := true

@onready var _view: MapView = %MapView
@onready var _title_label: Label = %MapTitle
@onready var _objective_label: Label = %MapObjective


## Arranca cerrado.
func _ready() -> void:
	EventBus.hud_visibility_requested.connect(_on_hud_visibility_requested)
	visible = false


## Mientras se juega, anota lo que alumbra la lámpara.
func _process(delta: float) -> void:
	if is_open or get_tree().paused:
		return
	_track_time += delta
	if _track_time < TRACK_SECONDS:
		return
	_track_time = 0.0
	var player := _player()
	if player:
		GameState.explore_around(player.global_position)


## M abre o cierra; abierto, Escape también cierra.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("map"):
		if is_open:
			close()
		elif _can_open():
			open()
		else:
			return
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


## Detiene el juego y dibuja el mapa como está.
func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	_fill()


## Cierra y sigue el juego.
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


## Solo se abre jugando: no en cinemáticas, sustos, pausa ni con otra pantalla abierta.
func _can_open() -> bool:
	return _is_hud_visible and not get_tree().paused and _player() != null


## Pasa al dibujo los túneles, las marcas, el jugador y el objetivo.
func _fill() -> void:
	var level := _player().owner
	var player := _player()
	GameState.explore_around(player.global_position)
	_view.rooms = MineMap.rooms_of(level)
	_view.marks = {
		MapView.Mark.ALTAR: _positions(level.find_children("*", "Altar", true, false)),
		MapView.Mark.EXIT: _exits(level),
		MapView.Mark.BLOCK: _blocks(level),
	}
	_view.player_position = Vector2(player.global_position.x, player.global_position.z)
	_view.player_heading = player.global_rotation.y
	_view.refresh()
	_title_label.text = PLAIN_TITLE
	if level is Level and not (level as Level).title.is_empty():
		_title_label.text = TITLE_FORMAT % (level as Level).title
	_objective_label.text = OBJECTIVE_FORMAT % GameState.objective
	_objective_label.visible = not GameState.objective.is_empty()


## La salida del nivel: la de siempre o la bocamina.
func _exits(level: Node) -> Array[Vector2]:
	var exits := level.find_children("*", "LevelExit", true, false)
	exits.append_array(level.find_children("*", "EndingExit", true, false))
	return _positions(exits)


## Rejas cerradas y derrumbes sin volar.
func _blocks(level: Node) -> Array[Vector2]:
	var blocks: Array[Node] = []
	for gate: Gate in level.find_children("*", "Gate", true, false):
		if not gate.is_open:
			blocks.append(gate)
	for rubble: Rubble in level.find_children("*", "Rubble", true, false):
		if not rubble.is_cleared:
			blocks.append(rubble)
	return _positions(blocks)


## Dónde están en el suelo.
func _positions(nodes: Array[Node]) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for node: Node3D in nodes:
		points.append(Vector2(node.global_position.x, node.global_position.z))
	return points


## Recuerda si el HUD está a la vista; si no, hay una cinemática o un susto.
func _on_hud_visibility_requested(is_visible: bool) -> void:
	_is_hud_visible = is_visible


## El jugador del nivel, si hay uno.
func _player() -> Player:
	return get_tree().get_first_node_in_group(Player.GROUP) as Player
