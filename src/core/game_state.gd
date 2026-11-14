extends Node
## Estado de la partida (autoload "GameState"): respeto, guardado, notas, pago, objetivo y nivel.

signal respect_changed(value: float)
## Se guardó un punto de reaparición; la partida en disco se actualiza.
signal checkpoint_saved

const MIN_RESPECT := 0.0
const MAX_RESPECT := 100.0
const STARTING_RESPECT := 50.0
## Lado de cada celda del mapa y hasta dónde alumbra la lámpara al dibujarlo, en metros.
const MAP_CELL := 2.0
const MAP_REACH := 4.0

var respect := STARTING_RESPECT
var checkpoint := Transform3D.IDENTITY
var read_notes := PackedStringArray()
## Verdadero si el jugador le pagó al Tío en la bocamina; decide el final.
var has_paid := false
## Lo que el jugador tiene que hacer ahora.
var objective := ""
## Herramientas que lleva para abrir la salida del nivel (dinamita, una llave), por su nombre.
var tools := PackedStringArray()
## Lo que ya pasó en el nivel y no se deshace al reaparecer o continuar: rejas abiertas, palancas
## bajadas, derrumbes volados.
var done := PackedStringArray()
## Celdas del nivel que el jugador ya recorrió, para el mapa.
var explored := {}

## Bolsa que lleva el jugador al nivel siguiente, mientras cruza de uno a otro.
var _carried_bag := {}
var _is_carrying := false


## Suma o resta respeto dentro de sus límites.
func add_respect(amount: float) -> void:
	respect = clampf(respect + amount, MIN_RESPECT, MAX_RESPECT)
	respect_changed.emit(respect)


## Devuelve el respeto como proporción de 0 a 1.
func get_respect_ratio() -> float:
	return (respect - MIN_RESPECT) / (MAX_RESPECT - MIN_RESPECT)


## Guarda el lugar donde reaparecerá el jugador.
func save_checkpoint(new_checkpoint: Transform3D) -> void:
	checkpoint = new_checkpoint
	checkpoint_saved.emit()


## Recuerda que el jugador leyó una nota.
func mark_note_read(note_id: String) -> void:
	if not has_read_note(note_id):
		read_notes.append(note_id)


## Dice si el jugador ya leyó esa nota.
func has_read_note(note_id: String) -> bool:
	return read_notes.has(note_id)


## Cambia el objetivo y lo anuncia, solo si es otro.
func set_objective(text: String) -> void:
	if text == objective:
		return
	objective = text
	EventBus.objective_changed.emit(text)


## Recoge una herramienta.
func add_tool(tool_name: String) -> void:
	if not has_tool(tool_name):
		tools.append(tool_name)


## Dice si lleva esa herramienta.
func has_tool(tool_name: String) -> bool:
	return tools.has(tool_name)


## Gasta una herramienta, por ejemplo al encender la dinamita.
func use_tool(tool_name: String) -> void:
	if has_tool(tool_name):
		tools.remove_at(tools.find(tool_name))


## Anota que algo del nivel ya pasó.
func mark_done(event_id: String) -> void:
	if not is_done(event_id):
		done.append(event_id)


## Dice si algo del nivel ya pasó.
func is_done(event_id: String) -> bool:
	return done.has(event_id)


## Marca en el mapa lo que se alcanza a ver alrededor de un punto.
func explore_around(point: Vector3) -> void:
	var reach := ceili(MAP_REACH / MAP_CELL)
	var center := map_cell(point)
	for x in range(-reach, reach + 1):
		for z in range(-reach, reach + 1):
			explored[center + Vector2i(x, z)] = true


## Dice si ya se vio la zona de ese punto.
func is_explored(point: Vector3) -> bool:
	return explored.has(map_cell(point))


## Celda del mapa que contiene un punto.
static func map_cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / MAP_CELL), floori(point.z / MAP_CELL))


## Guarda la bolsa para el nivel siguiente: el próximo nivel sigue la partida en vez de empezarla.
func carry_to_next_level(bag: Dictionary) -> void:
	_carried_bag = bag.duplicate()
	_is_carrying = true


## Dice si el nivel que se abre continúa desde el anterior.
func is_carrying() -> bool:
	return _is_carrying


## Entrega la bolsa que viene del nivel anterior y la olvida.
func take_carried_bag() -> Dictionary:
	var bag := _carried_bag
	_carried_bag = {}
	_is_carrying = false
	return bag


## Pasa al nivel siguiente: guarda respeto, notas y pago; olvida punto, objetivo y herramientas.
func start_next_level() -> void:
	checkpoint = Transform3D.IDENTITY
	objective = ""
	tools.clear()
	done.clear()
	explored.clear()


## Vuelve al estado de una partida nueva.
func reset() -> void:
	respect = STARTING_RESPECT
	checkpoint = Transform3D.IDENTITY
	read_notes.clear()
	has_paid = false
	objective = ""
	tools.clear()
	done.clear()
	explored.clear()
	_carried_bag = {}
	_is_carrying = false
	respect_changed.emit(respect)
