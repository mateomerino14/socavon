extends TestCase
## Pruebas del guardado: cada altar escribe la partida y al continuar todo vuelve a su lugar.

const LEVEL_SCENE := preload("res://src/world/level_02/level_02.tscn")
const MAIN_MENU_SCENE := preload("res://src/ui/main_menu/main_menu.tscn")
const SETTLE_FRAMES := 10
const POSITION_TOLERANCE := 0.3
const COCA_COUNT := 2

var _level: Level


## Empieza sin partida guardada.
func before_each() -> void:
	SaveGame.clear()


## Libera lo que haya quedado y borra la partida de prueba.
func after_each() -> void:
	if _level:
		_level.free()
	SaveGame.clear()


## Al empezar un nivel ya queda una partida para continuar.
func test_starting_a_level_saves() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(SaveGame.has_save(), "Debe guardarse al empezar el nivel")


## Guardar en el altar y continuar deja al jugador frente al altar, con su bolsa y sus notas.
func test_continue_restores_checkpoint_and_bag() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)
	var player: Player = _level.get_node("Player")
	var altar: Altar = _level.get_node("Altars/RailsAltar")
	player.inventory.add(ItemCatalog.Type.COCA, COCA_COUNT + 1)
	GameState.mark_note_read("lista_raya")
	altar.get_node("Interactable").interact(player)
	var spot := altar.get_respawn_transform().origin
	_level.free()
	_level = null
	var level_path := SaveGame.load_pending()
	assert_true(level_path.ends_with("level_02.tscn"), "Debe recordar el nivel")
	_level = (load(level_path) as PackedScene).instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)
	player = _level.get_node("Player")
	assert_true(
		player.global_position.distance_to(spot) < POSITION_TOLERANCE,
		"Debe aparecer frente al altar"
	)
	assert_true(
		player.inventory.count(ItemCatalog.Type.COCA) == COCA_COUNT,
		"Debe conservar la coca que no ofrendó"
	)
	assert_true(GameState.has_read_note("lista_raya"), "Debe recordar las notas leídas")


## En el menú, Continuar solo se puede usar si hay partida guardada.
func test_menu_continue_needs_a_save() -> void:
	var menu: Node = MAIN_MENU_SCENE.instantiate()
	add_to_tree(menu)
	var button: Button = menu.get_node("%ContinueButton")
	assert_true(button.disabled, "Sin partida, Continuar debe estar apagado")
	menu.free()
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)
	menu = MAIN_MENU_SCENE.instantiate()
	add_to_tree(menu)
	button = menu.get_node("%ContinueButton")
	assert_false(button.disabled, "Con partida, Continuar debe estar disponible")
	menu.free()
