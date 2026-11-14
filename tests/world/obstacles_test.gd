extends TestCase
## Pruebas de lo que abre las salidas: reja con candado o con palancas, derrumbe con dinamita,
## herramientas, zonas de objetivo, y que todo quede como estaba al continuar la partida.

const GATE_SCENE := preload("res://src/world/obstacles/gate.tscn")
const LEVER_SCENE := preload("res://src/world/obstacles/lever.tscn")
const RUBBLE_SCENE := preload("res://src/world/obstacles/rubble.tscn")
const TOOL_SCENE := preload("res://src/items/tool_pickup/tool_pickup.tscn")
const TRIGGER_SCENE := preload("res://src/story/objective_trigger/objective_trigger.tscn")
const PLAYER_SCENE := preload("res://src/player/player.tscn")
const KEY := "la llave del candado"
const DYNAMITE := "la dinamita"
const OBJECTIVE := "Baja por la chimenea"
const OTHER_OBJECTIVE := "Busca la palanca"
const QUICK_SECONDS := 0.05
const SETTLE_FRAMES := 5
const OPEN_FRAMES := 20

var _nodes: Array[Node] = []
var _heard_loudness := 0.0


## Partida limpia y oído atento a los ruidos.
func before_each() -> void:
	GameState.reset()
	_heard_loudness = 0.0
	EventBus.noise_emitted.connect(_on_noise)


## Libera lo creado y limpia el estado.
func after_each() -> void:
	EventBus.noise_emitted.disconnect(_on_noise)
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	GameState.reset()


## Con la llave se abre el candado: la reja sube, la llave se gasta y se anota.
func test_gate_opens_with_key() -> void:
	var gate := _gate("reja_llave")
	gate.key_tool = KEY
	gate.objective_after = OBJECTIVE
	gate.open_seconds = QUICK_SECONDS
	gate.get_node("Interactable").interact(null)
	assert_false(gate.is_open, "Sin llave no se abre")
	GameState.add_tool(KEY)
	gate.get_node("Interactable").interact(null)
	await wait_physics_frames(OPEN_FRAMES)
	assert_true(gate.is_open, "Con la llave se abre")
	assert_false(GameState.has_tool(KEY), "La llave se queda en el candado")
	assert_true(GameState.is_done("reja_llave"), "Se recuerda abierta")
	assert_true(GameState.objective == OBJECTIVE, "Da el objetivo siguiente")
	assert_true(_heard_loudness > 0.0, "El chirrido se oye")


## Una reja de dos palancas sube con la segunda.
func test_gate_needs_all_levers() -> void:
	var gate := _gate("reja_palancas")
	gate.levers_needed = 2
	var first := _lever("palanca_1", gate)
	var second := _lever("palanca_2", gate)
	first.pull()
	assert_false(gate.is_open, "Con una palanca no sube")
	second.pull()
	assert_true(gate.is_open, "Con las dos sube")


## Al continuar, lo que ya se abrió aparece abierto y las palancas abajo.
func test_restores_done_obstacles() -> void:
	GameState.mark_done("reja_guardada")
	GameState.mark_done("palanca_guardada")
	GameState.mark_done("derrumbe_guardado")
	var gate := _gate("reja_guardada")
	var lever_gate := _gate("reja_de_palanca")
	lever_gate.levers_needed = 1
	var lever := _lever("palanca_guardada", lever_gate)
	var rubble := _rubble("derrumbe_guardado")
	await wait_physics_frames(SETTLE_FRAMES)
	assert_true(gate.is_open, "La reja abierta sigue abierta")
	assert_true(lever.is_down and lever_gate.is_open, "La palanca sigue abajo y su reja arriba")
	assert_true(rubble.is_cleared, "El derrumbe volado sigue libre")


## Con dinamita, la mecha arde y el derrumbe revienta con un estruendo que se oye lejos.
func test_rubble_blasts_with_dynamite() -> void:
	var rubble := _rubble("derrumbe")
	rubble.fuse_seconds = QUICK_SECONDS
	rubble.objective_after = OBJECTIVE
	rubble.get_node("Interactable").interact(null)
	assert_false(rubble.is_lit, "Sin dinamita no pasa nada")
	GameState.add_tool(DYNAMITE)
	rubble.get_node("Interactable").interact(null)
	assert_true(rubble.is_lit, "La mecha se enciende")
	assert_false(GameState.has_tool(DYNAMITE), "La dinamita se gasta")
	await wait_physics_frames(OPEN_FRAMES)
	assert_true(rubble.is_cleared, "Revienta y deja el paso libre")
	assert_true(_heard_loudness >= Rubble.BLAST_LOUDNESS, "El Tío oye el estruendo")
	assert_true(GameState.objective == OBJECTIVE, "Da el objetivo siguiente")


## Recoger una herramienta la guarda, da el objetivo y la quita del suelo.
func test_tool_pickup() -> void:
	var tool: ToolPickup = TOOL_SCENE.instantiate()
	tool.tool_name = DYNAMITE
	tool.objective_after = OBJECTIVE
	_add(tool)
	tool.get_node("Interactable").interact(null)
	assert_true(GameState.has_tool(DYNAMITE), "Lleva la dinamita")
	assert_true(GameState.objective == OBJECTIVE, "Da el objetivo siguiente")
	assert_true(tool.is_queued_for_deletion(), "Ya no está en el suelo")


## La zona da su objetivo solo si toca en ese momento de la historia, y una sola vez.
func test_objective_trigger_follows_story() -> void:
	var trigger: ObjectiveTrigger = TRIGGER_SCENE.instantiate()
	trigger.objective = OBJECTIVE
	trigger.after_objective = OTHER_OBJECTIVE
	_add(trigger)
	var player: Player = PLAYER_SCENE.instantiate()
	_nodes.append(player)
	trigger._on_body_entered(player)
	assert_false(GameState.objective == OBJECTIVE, "Todavía no toca")
	GameState.set_objective(OTHER_OBJECTIVE)
	trigger._on_body_entered(player)
	assert_true(GameState.objective == OBJECTIVE, "Ahora sí da el objetivo")


## Crea una reja con su marca.
func _gate(done_id: String) -> Gate:
	var gate: Gate = GATE_SCENE.instantiate()
	gate.done_id = done_id
	_add(gate)
	return gate


## Crea una palanca con su marca y su reja.
func _lever(done_id: String, gate: Gate) -> Lever:
	var lever: Lever = LEVER_SCENE.instantiate()
	lever.done_id = done_id
	lever.gate = gate
	_add(lever)
	return lever


## Crea un derrumbe con su marca.
func _rubble(done_id: String) -> Rubble:
	var rubble: Rubble = RUBBLE_SCENE.instantiate()
	rubble.done_id = done_id
	_add(rubble)
	return rubble


## Agrega al árbol y recuerda para liberar.
func _add(node: Node) -> void:
	add_to_tree(node)
	_nodes.append(node)


## Anota el ruido más fuerte que se oyó.
func _on_noise(_origin: Vector3, loudness: float) -> void:
	_heard_loudness = maxf(_heard_loudness, loudness)
