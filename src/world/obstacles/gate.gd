class_name Gate
extends Node3D
## Reja de hierro que tapa un paso: se abre con llave o palancas, chirría y recuerda si se abrió.

const IRON := preload("res://src/world/materials/iron.tres")
const BAR_COUNT := 8
const BAR_RADIUS := 0.025
const CROSSBAR_HEIGHTS: Array[float] = [0.35, 1.3, 2.25]
const CROSSBAR_THICKNESS := 0.06
const WIDTH := 3.0
const HEIGHT := 2.6
const UNLOCK_PROMPT := "Abrir el candado con %s"
const UNLOCKED_NOTICE := "Abriste el candado"
## Volumen del chirrido para el oído del Tío: se oye lejos.
const OPEN_LOUDNESS := 1.4

## Marca con que se recuerda que ya se abrió; única en el nivel.
@export var done_id := ""
## Herramienta que abre el candado; vacío si no tiene candado.
@export var key_tool := ""
## Palancas que hay que bajar para que suba; cero si no depende de palancas.
@export var levers_needed := 0
## Lo que se le dice al jugador si intenta abrirla sin poder.
@export var locked_hint := "La reja no se mueve"
## Objetivo una vez abierta; vacío para no cambiarlo.
@export var objective_after := ""
@export var open_height := 2.5
@export var open_seconds := 2.2

var is_open := false

var _levers_down := 0

@onready var _bars: Node3D = $Bars
@onready var _body: StaticBody3D = $Body
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer3D = $Sound


## Arma los barrotes, conecta el candado y queda abierta si ya se abrió antes.
func _ready() -> void:
	_build_bars()
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_restore.call_deferred()


## Una palanca más está abajo; con todas, la reja sube. Sin sonido si se está restaurando.
func add_lever(is_restoring := false) -> void:
	_levers_down += 1
	if _levers_down >= levers_needed:
		open(is_restoring)


## Sube la reja, con su chirrido y su ruido; de golpe y en silencio si se está restaurando.
func open(is_instant := false) -> void:
	if is_open:
		return
	is_open = true
	GameState.mark_done(done_id)
	_interactable.enabled = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instant:
		_bars.position.y = open_height
		return
	_sound.play()
	EventBus.noise_emitted.emit(global_position, OPEN_LOUDNESS)
	var tween := create_tween()
	tween.tween_property(_bars, "position:y", open_height, open_seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not objective_after.is_empty():
		GameState.set_objective(objective_after)


## Si al continuar la partida ya estaba abierta, aparece abierta.
func _restore() -> void:
	if not done_id.is_empty() and GameState.is_done(done_id):
		open(true)


## Barrotes verticales y travesaños de hierro.
func _build_bars() -> void:
	var bar := CylinderMesh.new()
	bar.top_radius = BAR_RADIUS
	bar.bottom_radius = BAR_RADIUS
	bar.height = HEIGHT
	bar.material = IRON
	for index in BAR_COUNT:
		var mesh := MeshInstance3D.new()
		mesh.mesh = bar
		var x := -WIDTH * 0.5 + WIDTH * (index + 0.5) / BAR_COUNT
		mesh.position = Vector3(x, HEIGHT * 0.5, 0.0)
		_bars.add_child(mesh)
	var crossbar := BoxMesh.new()
	crossbar.size = Vector3(WIDTH, CROSSBAR_THICKNESS, CROSSBAR_THICKNESS)
	crossbar.material = IRON
	for height in CROSSBAR_HEIGHTS:
		var mesh := MeshInstance3D.new()
		mesh.mesh = crossbar
		mesh.position = Vector3(0.0, height, 0.0)
		_bars.add_child(mesh)


## Con la llave ofrece abrir el candado; si no, cuenta qué falta.
func _build_prompt(_player: Player) -> String:
	if not key_tool.is_empty() and GameState.has_tool(key_tool):
		return UNLOCK_PROMPT % key_tool
	return locked_hint


## Abre si tiene la llave; si no, no pasa nada más que el aviso.
func _on_interacted(_player: Player) -> void:
	if key_tool.is_empty() or not GameState.has_tool(key_tool):
		return
	GameState.use_tool(key_tool)
	EventBus.notice_requested.emit(UNLOCKED_NOTICE)
	open()
