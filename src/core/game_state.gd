extends Node
## Estado de la partida (autoload "GameState"): respeto, guardado, notas leídas, pago al Tío y
## objetivo actual. Al pasar de nivel se conservan el respeto, las notas y la bolsa.

signal respect_changed(value: float)
## Se guardó un punto de reaparición; la partida en disco se actualiza.
signal checkpoint_saved

const MIN_RESPECT := 0.0
const MAX_RESPECT := 100.0
const STARTING_RESPECT := 50.0

var respect := STARTING_RESPECT
var checkpoint := Transform3D.IDENTITY
var read_notes := PackedStringArray()
## Verdadero si el jugador le pagó al Tío en la bocamina; decide el final.
var has_paid := false
## Lo que el jugador tiene que hacer ahora.
var objective := ""

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


## Empieza el nivel siguiente: guarda respeto, notas y pago, y deja sin punto ni objetivo.
func start_next_level() -> void:
	checkpoint = Transform3D.IDENTITY
	objective = ""


## Vuelve al estado de una partida nueva.
func reset() -> void:
	respect = STARTING_RESPECT
	checkpoint = Transform3D.IDENTITY
	read_notes.clear()
	has_paid = false
	objective = ""
	_carried_bag = {}
	_is_carrying = false
	respect_changed.emit(respect)
