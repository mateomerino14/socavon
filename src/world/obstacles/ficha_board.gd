class_name FichaBoard
extends Node3D
## Tablero de la lampistería, con un gancho y un nombre por cada minero de la cuadrilla. Cada ficha
## que se cuelga devuelve a uno de ellos y cuenta para la reja: con todas en su gancho, la reja sube
## sola. Recuerda qué fichas ya se colgaron.

const FICHA_VISUAL := preload("res://src/items/visuals/ficha.tscn")
const IRON := preload("res://src/world/materials/iron.tres")
## Así se llama la herramienta que es la ficha de un minero.
const TOOL_PREFIX := "la ficha de "
## Marca con que se recuerda que la ficha de un minero ya cuelga.
const DONE_PREFIX := "tablero:"
const HANG_ONE_PROMPT := "Colgar %s"
const HANG_MANY_PROMPT := "Colgar las %d fichas que llevas"
const MISSING_PROMPT := "En el tablero faltan %d fichas"
const FULL_PROMPT := "Todas las fichas están en su gancho"
const HUNG_ONE_NOTICE := "Colgaste %s"
const HUNG_MANY_NOTICE := "Colgaste %d fichas"
const MISSING_MANY_OBJECTIVE := "Faltan %d fichas: búscalas en la galería"
const MISSING_ONE_OBJECTIVE := "Falta una ficha: búscala en la galería"
const BOARD_WIDTH := 1.6
const HOOK_HEIGHT := 1.54
const HOOK_SIZE := Vector3(0.02, 0.02, 0.07)
const HOOK_DEPTH := 0.09
const FICHA_DROP := 0.07
const FICHA_DEPTH := 0.075
const NAME_HEIGHT := 1.21
const NAME_DEPTH := 0.056
const NAME_FONT_SIZE := 28
const NAME_PIXEL_SIZE := 0.0016
const NAME_WIDTH := 140.0
const NAME_COLOR := Color(0.78, 0.7, 0.55)
## Volumen del tintineo para el oído del Tío: apenas se oye.
const HANG_LOUDNESS := 0.4

## Reja que se abre con todas las fichas; debe pedir tantas palancas como mineros hay.
@export var gate: Gate
## Nombres de los mineros, en el orden de sus ganchos.
@export var miners: PackedStringArray = []

var _fichas: Dictionary[String, Node3D] = {}

@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer3D = $Sound


## Arma los ganchos con sus nombres y cuelga las fichas que ya se habían colgado.
func _ready() -> void:
	_build_hooks()
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_restore.call_deferred()


## Cuántas fichas cuelgan ya.
func hung_count() -> int:
	var count := 0
	for miner in miners:
		if _fichas[miner].visible:
			count += 1
	return count


## Cuelga las fichas que lleva el jugador, con su tintineo, y dice cuántas faltan.
func hang_carried() -> void:
	var carried := _carried()
	if carried.is_empty():
		return
	for miner in carried:
		GameState.use_tool(TOOL_PREFIX + miner)
		_hang(miner, false)
	_sound.play()
	EventBus.noise_emitted.emit(global_position, HANG_LOUDNESS)
	if carried.size() == 1:
		EventBus.notice_requested.emit(HUNG_ONE_NOTICE % (TOOL_PREFIX + carried[0]))
	else:
		EventBus.notice_requested.emit(HUNG_MANY_NOTICE % carried.size())
	var missing := miners.size() - hung_count()
	if missing == 1:
		GameState.set_objective(MISSING_ONE_OBJECTIVE)
	elif missing > 1:
		GameState.set_objective(MISSING_MANY_OBJECTIVE % missing)


## Si al continuar ya había fichas colgadas, aparecen en su gancho y cuentan sin ruido.
func _restore() -> void:
	for miner in miners:
		if GameState.is_done(DONE_PREFIX + miner):
			_hang(miner, true)


## Muestra la ficha de un minero, lo recuerda y avisa a la reja.
func _hang(miner: String, is_restoring: bool) -> void:
	_fichas[miner].visible = true
	GameState.mark_done(DONE_PREFIX + miner)
	if gate:
		gate.add_lever(is_restoring)


## Mineros cuyas fichas lleva el jugador.
func _carried() -> PackedStringArray:
	var carried := PackedStringArray()
	for miner in miners:
		if GameState.has_tool(TOOL_PREFIX + miner):
			carried.append(miner)
	return carried


## Un gancho de hierro por minero, su nombre debajo y su ficha escondida hasta que se cuelgue.
func _build_hooks() -> void:
	var hook_mesh := BoxMesh.new()
	hook_mesh.size = HOOK_SIZE
	hook_mesh.material = IRON
	var spacing := BOARD_WIDTH / miners.size()
	for index in miners.size():
		var x := -BOARD_WIDTH * 0.5 + spacing * (index + 0.5)
		var hook := MeshInstance3D.new()
		hook.mesh = hook_mesh
		hook.position = Vector3(x, HOOK_HEIGHT, HOOK_DEPTH)
		add_child(hook)
		var ficha: Node3D = FICHA_VISUAL.instantiate()
		ficha.position = Vector3(x, HOOK_HEIGHT - FICHA_DROP, FICHA_DEPTH)
		ficha.rotation.x = PI / 2.0
		ficha.visible = false
		add_child(ficha)
		_fichas[miners[index]] = ficha
		add_child(_name_label(miners[index], x))


## Nombre del minero escrito bajo su gancho, en dos renglones.
func _name_label(miner: String, x: float) -> Label3D:
	var label := Label3D.new()
	label.text = miner.replace(" ", "\n")
	label.font_size = NAME_FONT_SIZE
	label.pixel_size = NAME_PIXEL_SIZE
	label.width = NAME_WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.modulate = NAME_COLOR
	label.outline_size = 0
	label.position = Vector3(x, NAME_HEIGHT, NAME_DEPTH)
	return label


## Ofrece colgar lo que lleva o cuenta cuántas faltan.
func _build_prompt(_player: Player) -> String:
	var carried := _carried()
	if carried.size() == 1:
		return HANG_ONE_PROMPT % (TOOL_PREFIX + carried[0])
	if carried.size() > 1:
		return HANG_MANY_PROMPT % carried.size()
	var missing := miners.size() - hung_count()
	if missing == 0:
		return FULL_PROMPT
	return MISSING_PROMPT % missing


## El jugador cuelga sus fichas.
func _on_interacted(_player: Player) -> void:
	hang_carried()
