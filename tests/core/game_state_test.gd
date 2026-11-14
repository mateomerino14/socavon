extends TestCase
## Pruebas del estado de la partida: el objetivo solo se anuncia cuando cambia y una partida nueva
## lo borra.

const OBJECTIVE := "Busca la palanca de la compuerta"

var _announced := 0


## Escucha los anuncios de objetivo.
func before_each() -> void:
	GameState.reset()
	_announced = 0
	EventBus.objective_changed.connect(_on_objective_changed)


## Deja de escuchar y limpia el estado.
func after_each() -> void:
	EventBus.objective_changed.disconnect(_on_objective_changed)
	GameState.reset()


## Repetir el mismo objetivo no lo vuelve a anunciar.
func test_objective_is_announced_once() -> void:
	GameState.set_objective(OBJECTIVE)
	GameState.set_objective(OBJECTIVE)
	assert_true(_announced == 1, "Se anuncia una sola vez")
	assert_true(GameState.objective == OBJECTIVE, "Queda como objetivo actual")


## Una partida nueva empieza sin objetivo.
func test_reset_clears_objective() -> void:
	GameState.set_objective(OBJECTIVE)
	GameState.reset()
	assert_true(GameState.objective.is_empty(), "La partida nueva no tiene objetivo")


## Cuenta los anuncios.
func _on_objective_changed(_text: String) -> void:
	_announced += 1
