extends Node
## Estado de la partida (autoload "GameState"): respeto del Tío y último punto de guardado.

signal respect_changed(value: float)
signal checkpoint_saved(checkpoint: Transform3D)

const MIN_RESPECT := 0.0
const MAX_RESPECT := 100.0
const STARTING_RESPECT := 50.0

var respect := STARTING_RESPECT
var checkpoint := Transform3D.IDENTITY
var has_checkpoint := false


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
	has_checkpoint = true
	checkpoint_saved.emit(checkpoint)


## Vuelve al estado de una partida nueva.
func reset() -> void:
	respect = STARTING_RESPECT
	checkpoint = Transform3D.IDENTITY
	has_checkpoint = false
	respect_changed.emit(respect)
