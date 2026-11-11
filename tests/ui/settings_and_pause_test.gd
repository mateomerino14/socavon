extends TestCase
## Pruebas de los ajustes y del menú de pausa: guardar, límites, pausar y aplicar al jugador.

const TUNNEL_SCENE := preload("res://src/world/test_tunnel/test_tunnel.tscn")
const TEST_CONFIG_PATH := "user://ajustes_prueba.cfg"
const DEFAULT_SENSITIVITY := 1.0
const DEFAULT_VOLUME := 1.0

var _tunnel: Node3D


## Usa un archivo de ajustes propio de la prueba y carga el túnel.
func before_each() -> void:
	Settings.config_path = TEST_CONFIG_PATH
	_restore_defaults()
	_tunnel = TUNNEL_SCENE.instantiate()
	add_to_tree(_tunnel)


## Quita la pausa, borra el archivo de prueba y vuelve a los ajustes de siempre.
func after_each() -> void:
	tree.paused = false
	_tunnel.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_CONFIG_PATH))
	_restore_defaults()
	Settings.config_path = Settings.DEFAULT_PATH


## Los ajustes guardados se recuperan al volver a cargarlos.
func test_settings_survive_reload() -> void:
	Settings.set_mouse_sensitivity(1.75)
	Settings.set_crouch_toggles(true)
	Settings.set_master_volume(0.4)
	_restore_defaults()
	Settings.load_settings()
	assert_almost_eq(Settings.mouse_sensitivity, 1.75, "Debe recuperar la sensibilidad")
	assert_true(Settings.crouch_toggles, "Debe recuperar agacharse alterno")
	assert_almost_eq(Settings.master_volume, 0.4, "Debe recuperar el volumen")


## La sensibilidad no sale de sus límites.
func test_sensitivity_is_clamped() -> void:
	Settings.set_mouse_sensitivity(10.0)
	assert_almost_eq(Settings.mouse_sensitivity, Settings.MAX_SENSITIVITY, "Tope máximo")
	Settings.set_mouse_sensitivity(0.0)
	assert_almost_eq(Settings.mouse_sensitivity, Settings.MIN_SENSITIVITY, "Tope mínimo")


## El jugador toma los ajustes al cambiar.
func test_player_applies_settings() -> void:
	var player: Player = _tunnel.get_node("Player")
	Settings.set_crouch_toggles(true)
	assert_true(player.crouch_toggles, "El jugador debe pasar a agacharse alterno")


## Abrir el menú pausa el juego y cerrarlo lo reanuda.
func test_pause_menu_pauses_and_resumes() -> void:
	var menu: PauseMenu = _tunnel.get_node("PauseMenu")
	menu.open()
	assert_true(tree.paused, "Abrir el menú debe pausar")
	assert_true(menu.visible, "El menú debe verse")
	menu.close()
	assert_false(tree.paused, "Cerrar el menú debe reanudar")
	assert_false(menu.visible, "El menú debe ocultarse")


## Deja los ajustes en sus valores por defecto sin escribir en disco.
func _restore_defaults() -> void:
	Settings.mouse_sensitivity = DEFAULT_SENSITIVITY
	Settings.crouch_toggles = false
	Settings.master_volume = DEFAULT_VOLUME
