extends TestCase
## Pruebas del inventario: muestra la bolsa, el objetivo y el ánimo del Tío, y pausa el juego.

const SCREEN_SCENE := preload("res://src/ui/inventory_screen/inventory_screen.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const COCA_COUNT := 2
const OBJECTIVE := "Busca la palanca de la compuerta"
const ANGRY_RESPECT := 10.0
const RESPECTED_RESPECT := 80.0
const COCA_INDEX := 1

var _screen: InventoryScreen
var _player: Player


## Arma un jugador con coca en la bolsa y el inventario cerrado.
func before_each() -> void:
	GameState.reset()
	_player = PLAYER_SCENE.instantiate()
	add_to_tree(_player)
	_player.inventory.add(ItemCatalog.Type.COCA, COCA_COUNT)
	_screen = SCREEN_SCENE.instantiate()
	add_to_tree(_screen)


## Cierra, libera y deja el juego sin pausa.
func after_each() -> void:
	_screen.get_tree().paused = false
	_screen.free()
	_player.free()
	_player = null
	GameState.reset()


## Abierto, muestra lo que lleva, el objetivo, el ánimo del Tío y elige el primer objeto que tiene.
func test_shows_bag_objective_and_mood() -> void:
	GameState.set_objective(OBJECTIVE)
	_screen.open()
	assert_true(_screen.get_tree().paused, "Detiene el juego")
	var coca: InventorySlot = _screen.get_node("%SlotRow").get_child(COCA_INDEX)
	assert_true(coca.type == ItemCatalog.Type.COCA, "La segunda casilla es la coca")
	assert_true((coca.get_node("%CountLabel") as Label).text == "2 / 5", "Cuenta lo que lleva")
	assert_true(
		(_screen.get_node("%ObjectiveLabel") as Label).text.ends_with(OBJECTIVE), "Objetivo"
	)
	assert_true(
		(_screen.get_node("%DetailName") as Label).text == "Hojas de coca",
		"Elige lo primero que lleva"
	)
	_screen.close()
	assert_false(_screen.get_tree().paused, "Al cerrar sigue el juego")


## Durante una cinemática o un susto no se abre.
func test_does_not_open_without_hud() -> void:
	EventBus.hud_visibility_requested.emit(false)
	var event := InputEventAction.new()
	event.action = &"inventory"
	event.pressed = true
	_screen._input(event)
	assert_false(_screen.is_open, "No se abre en una cinemática")
	EventBus.hud_visibility_requested.emit(true)


## El ánimo del Tío sigue al respeto.
func test_mood_follows_respect() -> void:
	assert_true(InventoryScreen.mood_for(ANGRY_RESPECT).contains("furioso"), "Poco respeto")
	assert_true(InventoryScreen.mood_for(RESPECTED_RESPECT).contains("respeta"), "Mucho respeto")
