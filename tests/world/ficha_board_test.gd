extends TestCase
## Pruebas del tablero de fichas: cuelga, cuenta las que faltan, abre la reja y las recuerda.

const BOARD_SCENE := preload("res://src/world/obstacles/ficha_board.tscn")
const GATE_SCENE := preload("res://src/world/obstacles/gate.tscn")
const MINERS: PackedStringArray = ["Severino Mamani", "Justo Condori", "Efraín Choque"]
const GATE_ID := "reja_fichas"
const OBJECTIVE := "Sal por la galería"
const QUICK_SECONDS := 0.05
const SETTLE_FRAMES := 5
const OPEN_FRAMES := 20

var _board: FichaBoard
var _gate: Gate


## Partida limpia.
func before_each() -> void:
	GameState.reset()


## Libera lo creado y limpia el estado.
func after_each() -> void:
	for node: Node in [_board, _gate]:
		if is_instance_valid(node):
			node.free()
	GameState.reset()


## Cuelga solo las fichas que lleva y da cuántas faltan; la reja sigue cerrada.
func test_hangs_carried_fichas() -> void:
	await _build()
	GameState.add_tool(FichaBoard.TOOL_PREFIX + MINERS[0])
	_board.get_node("Interactable").interact(null)
	assert_true(_board.hung_count() == 1, "Debe colgar la ficha que lleva")
	assert_false(
		GameState.has_tool(FichaBoard.TOOL_PREFIX + MINERS[0]), "La ficha queda en el tablero"
	)
	assert_true(GameState.objective == FichaBoard.MISSING_MANY_OBJECTIVE % 2, "Dice cuántas faltan")
	assert_false(_gate.is_open, "Con una ficha la reja no sube")
	GameState.add_tool(FichaBoard.TOOL_PREFIX + MINERS[1])
	_board.get_node("Interactable").interact(null)
	assert_true(GameState.objective == FichaBoard.MISSING_ONE_OBJECTIVE, "Avisa que falta una")


## Con todas las fichas en su gancho la reja sube sola y da el objetivo siguiente.
func test_all_fichas_open_the_gate() -> void:
	await _build()
	for miner in MINERS:
		GameState.add_tool(FichaBoard.TOOL_PREFIX + miner)
	_board.get_node("Interactable").interact(null)
	await wait_physics_frames(OPEN_FRAMES)
	assert_true(_board.hung_count() == MINERS.size(), "Cuelgan todas")
	assert_true(_gate.is_open, "La reja sube con todas")
	assert_true(GameState.objective == OBJECTIVE, "Da el objetivo de la reja")


## Al continuar, las fichas colgadas siguen en su gancho y cuentan para la reja.
func test_restores_hung_fichas() -> void:
	for miner in MINERS:
		GameState.mark_done(FichaBoard.DONE_PREFIX + miner)
	await _build()
	assert_true(_board.hung_count() == MINERS.size(), "Siguen colgadas")
	assert_true(_gate.is_open, "La reja sigue abierta")


## Sin fichas en la mano, el tablero dice cuántas faltan.
func test_prompt_counts_missing() -> void:
	await _build()
	var prompt: String = _board._build_prompt(null)
	assert_true(prompt == FichaBoard.MISSING_PROMPT % MINERS.size(), "Debe decir cuántas faltan")


## Arma la reja y su tablero, y espera a que se restauren.
func _build() -> void:
	_gate = GATE_SCENE.instantiate()
	_gate.done_id = GATE_ID
	_gate.levers_needed = MINERS.size()
	_gate.open_seconds = QUICK_SECONDS
	_gate.objective_after = OBJECTIVE
	add_to_tree(_gate)
	_board = BOARD_SCENE.instantiate()
	_board.miners = MINERS
	_board.gate = _gate
	add_to_tree(_board)
	await wait_physics_frames(SETTLE_FRAMES)
