extends Node
## Partida guardada en disco (autoload "SaveGame"): nivel, punto de guardado, bolsa e historia.
##
## Se escribe al empezar cada nivel y cada vez que el jugador guarda en un altar. Al continuar,
## el nivel se carga y toma lo pendiente para dejar al jugador donde estaba.

const DEFAULT_PATH := "user://partida.cfg"
const SECTION := "partida"
const LEVEL_KEY := "nivel"

var save_path := DEFAULT_PATH

var _pending := {}


## Dice si hay una partida guardada para continuar.
func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Guarda el estado actual de la partida en el nivel indicado.
func save(level_path: String, inventory: InventoryComponent) -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, LEVEL_KEY, level_path)
	config.set_value(SECTION, "punto", GameState.checkpoint)
	config.set_value(SECTION, "respeto", GameState.respect)
	config.set_value(SECTION, "pagado", GameState.has_paid)
	config.set_value(SECTION, "notas", GameState.read_notes)
	config.set_value(SECTION, "bolsa", inventory.get_counts())
	config.save(save_path)


## Carga la partida guardada y abre su nivel; el nivel la aplica al empezar.
func continue_game() -> void:
	var level_path := load_pending()
	if not level_path.is_empty():
		get_tree().change_scene_to_file(level_path)


## Lee la partida guardada para que la tome el próximo nivel y devuelve qué nivel era.
func load_pending() -> String:
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return ""
	for key in config.get_section_keys(SECTION):
		_pending[key] = config.get_value(SECTION, key)
	return _pending[LEVEL_KEY]


## Borra lo guardado y empieza desde el nivel indicado.
func new_game(first_level_path: String) -> void:
	clear()
	get_tree().change_scene_to_file(first_level_path)


## Dice si el próximo nivel que cargue debe restaurar una partida.
func has_pending() -> bool:
	return not _pending.is_empty()


## Entrega la partida por restaurar y la olvida.
func take_pending() -> Dictionary:
	var pending := _pending
	_pending = {}
	return pending


## Borra la partida guardada, por ejemplo al terminar el juego.
func clear() -> void:
	_pending = {}
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
