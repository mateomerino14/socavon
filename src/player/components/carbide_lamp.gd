class_name CarbideLamp
extends Node3D
## Lámpara de carburo: más llama ilumina más, pero gasta más carburo y delata más ante el Tío.

signal fuel_changed(current: float, maximum: float)
signal state_changed(is_lit: bool, level: int)

const MIN_LEVEL := 1
const MAX_LEVEL := 3
const MIN_FLICKER_FACTOR := 0.05
const FLICKER_NOISE_SPAN := 2.0
const GLOW_ENERGY_RATIO := 0.35
const GLOW_RANGE_RATIO := 0.3

@export_group("Combustible")
## Segundos de duración con la llama en nivel medio.
@export var max_fuel := 300.0
@export var starting_fuel := 300.0
@export_range(0.0, 1.0) var low_fuel_ratio := 0.15

@export_group("Niveles de llama (bajo, medio, alto)")
@export var fuel_rate_by_level := PackedFloat32Array([0.5, 1.0, 1.8])
@export var range_by_level := PackedFloat32Array([5.0, 9.0, 14.0])
@export var energy_by_level := PackedFloat32Array([0.7, 1.3, 2.1])

@export_group("Parpadeo")
@export var flicker_strength := 0.12
@export var flicker_speed := 7.0
@export var low_fuel_flicker_strength := 0.55

var fuel := 0.0
var level := 2
var is_lit := true

var _flicker_noise := FastNoiseLite.new()
var _time := 0.0

@onready var _spot: SpotLight3D = $Spot
@onready var _glow: OmniLight3D = $Glow


## Carga el combustible inicial y publica el estado de la lámpara.
func _ready() -> void:
	fuel = clampf(starting_fuel, 0.0, max_fuel)
	_flicker_noise.seed = randi()
	_apply_light(1.0)
	fuel_changed.emit(fuel, max_fuel)
	state_changed.emit(is_lit, level)


## Gasta carburo y hace temblar la llama mientras está encendida.
func _process(delta: float) -> void:
	if not is_lit:
		return
	consume_fuel(delta)
	_time += delta
	_apply_light(_flicker_factor())


## Enciende o apaga la lámpara.
func toggle() -> void:
	set_lit(not is_lit)


## Enciende o apaga; sin carburo no enciende.
func set_lit(value: bool) -> void:
	if value and fuel <= 0.0:
		return
	if value == is_lit:
		return
	is_lit = value
	_spot.visible = is_lit
	_glow.visible = is_lit
	state_changed.emit(is_lit, level)


## Sube un nivel la llama.
func increase_level() -> void:
	_set_level(level + 1)


## Baja un nivel la llama.
func decrease_level() -> void:
	_set_level(level - 1)


## Recarga carburo sin pasar del máximo.
func add_fuel(amount: float) -> void:
	fuel = minf(fuel + amount, max_fuel)
	fuel_changed.emit(fuel, max_fuel)


## Resta el carburo de este frame según el nivel; separada para poder probarla.
func consume_fuel(delta: float) -> void:
	fuel = maxf(fuel - fuel_rate_by_level[level - 1] * delta, 0.0)
	fuel_changed.emit(fuel, max_fuel)
	if fuel <= 0.0:
		set_lit(false)


## Devuelve cuánto delata la lámpara, de 0 (apagada) a 1 (llama alta).
func get_light_intensity() -> float:
	if not is_lit:
		return 0.0
	return float(level) / float(MAX_LEVEL)


## Devuelve el carburo como proporción de 0 a 1.
func get_fuel_ratio() -> float:
	return fuel / max_fuel


## Cambia el nivel de llama dentro de los límites.
func _set_level(new_level: int) -> void:
	new_level = clampi(new_level, MIN_LEVEL, MAX_LEVEL)
	if new_level == level:
		return
	level = new_level
	state_changed.emit(is_lit, level)


## Devuelve el multiplicador de energía del parpadeo; tironea cuando queda poco carburo.
func _flicker_factor() -> float:
	var strength := flicker_strength
	if get_fuel_ratio() < low_fuel_ratio:
		strength = low_fuel_flicker_strength
	var noise := _flicker_noise.get_noise_1d(_time * flicker_speed)
	return maxf(1.0 + noise * strength * FLICKER_NOISE_SPAN, MIN_FLICKER_FACTOR)


## Aplica alcance y energía del nivel actual a las dos luces.
func _apply_light(factor: float) -> void:
	var index := level - 1
	_spot.light_energy = energy_by_level[index] * factor
	_spot.spot_range = range_by_level[index]
	_glow.light_energy = energy_by_level[index] * GLOW_ENERGY_RATIO * factor
	_glow.omni_range = range_by_level[index] * GLOW_RANGE_RATIO
