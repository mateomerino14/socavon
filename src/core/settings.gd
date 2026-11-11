extends Node
## Ajustes del jugador (autoload "Settings"): se guardan en disco y avisan cuando cambian.

signal changed

const SECTION := "controles"
const AUDIO_SECTION := "audio"
const DEFAULT_PATH := "user://ajustes.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 2.5
const MASTER_BUS := 0

var config_path := DEFAULT_PATH
var mouse_sensitivity := 1.0
var crouch_toggles := false
var master_volume := 1.0


## Carga los ajustes guardados al iniciar.
func _ready() -> void:
	load_settings()


## Lee los ajustes del disco; si no hay archivo, quedan los valores por defecto.
func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(config_path) == OK:
		mouse_sensitivity = config.get_value(SECTION, "sensibilidad_raton", mouse_sensitivity)
		crouch_toggles = config.get_value(SECTION, "agacharse_alterno", crouch_toggles)
		master_volume = config.get_value(AUDIO_SECTION, "volumen_general", master_volume)
	_apply_volume()
	changed.emit()


## Escribe los ajustes actuales en el disco.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "sensibilidad_raton", mouse_sensitivity)
	config.set_value(SECTION, "agacharse_alterno", crouch_toggles)
	config.set_value(AUDIO_SECTION, "volumen_general", master_volume)
	config.save(config_path)


## Cambia la sensibilidad del ratón dentro de sus límites.
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	_commit()


## Elige si agacharse se mantiene o se alterna.
func set_crouch_toggles(value: bool) -> void:
	crouch_toggles = value
	_commit()


## Cambia el volumen general, de 0 a 1.
func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_commit()


## Guarda y avisa del cambio.
func _commit() -> void:
	save_settings()
	changed.emit()


## Aplica el volumen al bus principal de audio.
func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(master_volume))
