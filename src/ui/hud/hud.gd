class_name Hud
extends CanvasLayer
## HUD mínimo: barras de carburo y aliento que se desvanecen cuando están llenas.

const FULL_RATIO := 0.995
const SHOWN_ALPHA := 1.0
const HIDDEN_ALPHA := 0.0
const FADE_SPEED := 3.0

var _target_alpha := {}

@onready var _fuel_bar: ProgressBar = %FuelBar
@onready var _stamina_bar: ProgressBar = %StaminaBar


## Escucha al bus y arranca con las barras ocultas.
func _ready() -> void:
	for bar: ProgressBar in [_fuel_bar, _stamina_bar]:
		bar.modulate.a = HIDDEN_ALPHA
		_target_alpha[bar] = HIDDEN_ALPHA
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.lamp_fuel_changed.connect(_on_lamp_fuel_changed)


## Acerca la transparencia de cada barra a la que le toca.
func _process(delta: float) -> void:
	for bar: ProgressBar in _target_alpha:
		bar.modulate.a = move_toward(bar.modulate.a, _target_alpha[bar], FADE_SPEED * delta)


## Actualiza la barra de aliento.
func _on_stamina_changed(current: float, maximum: float) -> void:
	_update_bar(_stamina_bar, current, maximum)


## Actualiza la barra de carburo.
func _on_lamp_fuel_changed(current: float, maximum: float) -> void:
	_update_bar(_fuel_bar, current, maximum)


## Pone el valor de la barra y la muestra solo si no está llena.
func _update_bar(bar: ProgressBar, current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current
	_target_alpha[bar] = HIDDEN_ALPHA
	if current / maximum < FULL_RATIO:
		_target_alpha[bar] = SHOWN_ALPHA
