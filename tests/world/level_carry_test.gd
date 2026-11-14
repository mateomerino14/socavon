extends TestCase
## Pruebas del paso de nivel: la bolsa y el respeto siguen en el nivel siguiente, y una partida nueva
## empieza de cero.

const LEVEL_SCENE := preload("res://src/world/level_02/level_02.tscn")
const SETTLE_FRAMES := 10
const COCA_CARRIED := 2
const RESPECT_EARNED := 20.0

var _level: Level


## Deja el estado como el de una partida nueva.
func before_each() -> void:
	GameState.reset()


## Libera el nivel y limpia el estado.
func after_each() -> void:
	if _level:
		_level.free()
	GameState.reset()


## Lo que trae el jugador del nivel anterior sigue en su bolsa y el Tío lo recuerda.
func test_next_level_keeps_bag_and_respect() -> void:
	GameState.add_respect(RESPECT_EARNED)
	var respect := GameState.respect
	GameState.carry_to_next_level({ItemCatalog.Type.COCA: COCA_CARRIED})
	await _open_level()
	var player: Player = _level.get_node("Player")
	assert_true(player.inventory.count(ItemCatalog.Type.COCA) == COCA_CARRIED, "Trae su coca")
	assert_almost_eq(GameState.respect, respect, "El respeto se conserva")
	assert_false(GameState.is_carrying(), "La bolsa ya se entregó")


## Sin nada que traer, el nivel empieza una partida nueva.
func test_new_game_starts_empty() -> void:
	GameState.add_respect(RESPECT_EARNED)
	await _open_level()
	var player: Player = _level.get_node("Player")
	assert_true(player.inventory.count(ItemCatalog.Type.COCA) == 0, "La bolsa empieza vacía")
	assert_almost_eq(GameState.respect, GameState.STARTING_RESPECT, "El respeto vuelve al inicio")


## Abre el nivel de prueba y espera a que se acomode.
func _open_level() -> void:
	_level = LEVEL_SCENE.instantiate()
	add_to_tree(_level)
	await wait_physics_frames(SETTLE_FRAMES)
