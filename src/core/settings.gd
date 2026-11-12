extends Node
## Ajustes del jugador (autoload "Settings"): se guardan en disco y avisan cuando cambian.

signal changed

const SECTION := "controles"
const AUDIO_SECTION := "audio"
const VIDEO_SECTION := "video"
const DEFAULT_PATH := "user://ajustes.cfg"
const MIN_SENSITIVITY := 0.25
const MAX_SENSITIVITY := 2.5
const MASTER_BUS := 0
const MUSIC_BUS := &"Musica"

var config_path := DEFAULT_PATH
var mouse_sensitivity := 1.0
var crouch_toggles := false
var master_volume := 1.0
var music_volume := 0.8
## Luz rebotada, luz indirecta en pantalla y niebla volumétrica; en baja se apagan.
var high_quality := true


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
		music_volume = config.get_value(AUDIO_SECTION, "volumen_musica", music_volume)
		high_quality = config.get_value(VIDEO_SECTION, "calidad_alta", high_quality)
	_apply_volume()
	changed.emit()


## Escribe los ajustes actuales en el disco.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "sensibilidad_raton", mouse_sensitivity)
	config.set_value(SECTION, "agacharse_alterno", crouch_toggles)
	config.set_value(AUDIO_SECTION, "volumen_general", master_volume)
	config.set_value(AUDIO_SECTION, "volumen_musica", music_volume)
	config.set_value(VIDEO_SECTION, "calidad_alta", high_quality)
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


## Cambia el volumen de la música, de 0 a 1.
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume()
	_commit()


## Elige entre gráficos en calidad alta o baja.
func set_high_quality(value: bool) -> void:
	high_quality = value
	_commit()


## Guarda y avisa del cambio.
func _commit() -> void:
	save_settings()
	changed.emit()


## Aplica los volúmenes al bus principal y al de la música.
func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(MASTER_BUS, linear_to_db(master_volume))
	var music_bus := AudioServer.get_bus_index(MUSIC_BUS)
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
