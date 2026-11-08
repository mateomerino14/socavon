class_name StaminaComponent
extends Node
## Aliento del jugador: se gasta al correr y se recupera tras una pausa.

signal changed(current: float, maximum: float)

@export var max_stamina := 100.0
@export var drain_per_second := 22.0
@export var regen_per_second := 15.0
@export var regen_delay := 1.2
## Estamina necesaria para volver a correr tras agotarse por completo.
@export var recover_threshold := 35.0

var current := 0.0
var is_exhausted := false

var _is_draining := false
var _regen_cooldown := 0.0


## Arranca con el aliento lleno.
func _ready() -> void:
	current = max_stamina
	changed.emit(current, max_stamina)


## Gasta o recupera aliento según lo que pidió el jugador este frame.
func _physics_process(delta: float) -> void:
	tick(delta)


## Avanza la simulación del aliento; separada para poder probarla.
func tick(delta: float) -> void:
	var previous := current
	if _is_draining:
		_drain(delta)
	else:
		_regenerate(delta)
	if not is_equal_approx(previous, current):
		changed.emit(current, max_stamina)


## Indica si el jugador está corriendo en este frame.
func set_draining(value: bool) -> void:
	_is_draining = value and can_sprint()
	if _is_draining:
		_regen_cooldown = regen_delay


## Llena el aliento de golpe, como al reaparecer.
func refill() -> void:
	current = max_stamina
	is_exhausted = false
	_regen_cooldown = 0.0
	changed.emit(current, max_stamina)


## Dice si queda aliento para correr.
func can_sprint() -> bool:
	return not is_exhausted and current > 0.0


## Resta aliento y marca el agotamiento al llegar a cero.
func _drain(delta: float) -> void:
	current = maxf(current - drain_per_second * delta, 0.0)
	if current <= 0.0 and not is_exhausted:
		is_exhausted = true
		_is_draining = false


## Suma aliento cuando ya pasó la pausa tras correr.
func _regenerate(delta: float) -> void:
	if _regen_cooldown > 0.0:
		_regen_cooldown -= delta
		return
	current = minf(current + regen_per_second * delta, max_stamina)
	if is_exhausted and current >= recover_threshold:
		is_exhausted = false
