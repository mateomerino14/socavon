class_name Rubble
extends Node3D
## Derrumbe que tapa un paso. Con dinamita se le enciende la mecha y, tras unos segundos, revienta:
## destello, temblor y un estruendo que el Tío oye desde lejos. Recuerda si ya se voló.

const ROCK_MESH := preload("res://assets/models/props/stone.obj")
const ROCK_MATERIAL := preload("res://src/world/materials/rock.tres")
const DYNAMITE := preload("res://src/items/visuals/dynamite.tscn")
const ROCK_COUNT := 34
const ROCK_SEED := 1545
const PILE_HALF_WIDTH := 1.4
const PILE_HEIGHT := 2.4
const PILE_DEPTH := 0.8
## Cuánto se angosta la pila hacia arriba.
const PILE_TAPER := 0.35
const MIN_ROCK_SCALE := 3.5
const MAX_ROCK_SCALE := 7.0
const PLANT_PROMPT := "Poner %s"
const LIT_NOTICE := "¡La mecha está encendida! Aléjate"
const LIT_PROMPT := "La mecha está encendida"
## Dónde queda la carga, delante del derrumbe.
const CHARGE_OFFSET := Vector3(0.3, 0.05, 0.9)
const SPARK_ENERGY := 1.5
const SPARK_FLICKER := 0.8
const FLASH_ENERGY := 14.0
const FLASH_SECONDS := 0.7
const SHAKE_SECONDS := 1.2
## Nube de polvo: espesa al reventar y se asienta despacio.
const DUST_DENSITY := 0.9
const DUST_SECONDS := 6.0
const MAX_SHAKE := 0.12
## Volumen del estruendo para el oído del Tío: lo oye en todo el nivel.
const BLAST_LOUDNESS := 3.0

## Marca con que se recuerda que ya se voló; única en el nivel.
@export var done_id := ""
## Herramienta que lo vuela.
@export var charge_tool := "la dinamita"
## Lo que se le dice al jugador si no tiene con qué volarlo.
@export var blocked_hint := "Un derrumbe tapa el paso"
## Segundos que arde la mecha.
@export var fuse_seconds := 5.0
## Objetivo una vez volado; vacío para no cambiarlo.
@export var objective_after := ""

var is_lit := false
var is_cleared := false

var _shake := 0.0
var _charge: Node3D

@onready var _rocks: Node3D = $Rocks
@onready var _body: StaticBody3D = $Body
@onready var _interactable: Interactable = $Interactable
@onready var _spark: OmniLight3D = $Spark
@onready var _flash: OmniLight3D = $Flash
@onready var _fuse_sound: AudioStreamPlayer3D = $FuseSound
@onready var _blast_sound: AudioStreamPlayer3D = $BlastSound
@onready var _dust: FogVolume = $Dust
@onready var _fuse_timer: Timer = $FuseTimer


## Apila las piedras, conecta la carga y queda libre si ya se voló antes.
func _ready() -> void:
	_pile_rocks()
	_spark.visible = false
	_flash.light_energy = 0.0
	_interactable.set_prompt_builder(_build_prompt)
	_interactable.interacted.connect(_on_interacted)
	_fuse_timer.timeout.connect(_blast)
	_fuse_sound.finished.connect(_on_fuse_sound_finished)
	_restore.call_deferred()


## La chispa tiembla mientras arde la mecha y la cámara tiembla tras el estallido.
func _process(delta: float) -> void:
	if is_lit:
		_spark.light_energy = SPARK_ENERGY + randf_range(-SPARK_FLICKER, SPARK_FLICKER)
	if _shake > 0.0:
		_shake = maxf(_shake - delta / SHAKE_SECONDS * MAX_SHAKE, 0.0)
		var camera := get_viewport().get_camera_3d()
		if camera:
			camera.h_offset = randf_range(-_shake, _shake)
			camera.v_offset = randf_range(-_shake, _shake)


## Enciende la mecha: la carga queda en el suelo y empieza la cuenta.
func light_fuse() -> void:
	if is_lit or is_cleared:
		return
	is_lit = true
	_interactable.enabled = false
	_charge = DYNAMITE.instantiate()
	add_child(_charge)
	_charge.position = CHARGE_OFFSET
	_spark.position = CHARGE_OFFSET
	_spark.visible = true
	_fuse_sound.play()
	EventBus.notice_requested.emit(LIT_NOTICE)
	_fuse_timer.start(fuse_seconds)


## Revienta: destello, estruendo, polvo y temblor; el paso queda libre.
func _blast() -> void:
	is_lit = false
	_spark.visible = false
	_fuse_sound.stop()
	_blast_sound.play()
	var dust := _dust.material as FogMaterial
	dust.density = DUST_DENSITY
	create_tween().tween_property(dust, "density", 0.0, DUST_SECONDS)
	_shake = MAX_SHAKE
	EventBus.noise_emitted.emit(global_position, BLAST_LOUDNESS)
	_flash.light_energy = FLASH_ENERGY
	create_tween().tween_property(_flash, "light_energy", 0.0, FLASH_SECONDS)
	_clear()
	if not objective_after.is_empty():
		GameState.set_objective(objective_after)


## Quita las piedras, la carga y el bloqueo, y lo anota.
func _clear() -> void:
	is_cleared = true
	GameState.mark_done(done_id)
	_rocks.visible = false
	_body.process_mode = Node.PROCESS_MODE_DISABLED
	_interactable.enabled = false
	if _charge:
		_charge.queue_free()


## Si al continuar ya estaba volado, aparece libre.
func _restore() -> void:
	if not done_id.is_empty() and GameState.is_done(done_id):
		_clear()


## Piedras de distintos tamaños apiladas a lo ancho del túnel, siempre en el mismo orden.
func _pile_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = ROCK_SEED
	for index in ROCK_COUNT:
		var rock := MeshInstance3D.new()
		rock.mesh = ROCK_MESH
		rock.material_override = ROCK_MATERIAL
		var height := rng.randf() * PILE_HEIGHT
		var half_width := PILE_HALF_WIDTH * (1.0 - PILE_TAPER * height / PILE_HEIGHT)
		rock.position = Vector3(
			rng.randf_range(-half_width, half_width),
			height,
			rng.randf_range(-PILE_DEPTH, PILE_DEPTH) / 2.0
		)
		rock.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		rock.scale = Vector3.ONE * rng.randf_range(MIN_ROCK_SCALE, MAX_ROCK_SCALE)
		_rocks.add_child(rock)


## Con dinamita ofrece ponerla; si no, cuenta que el paso está tapado.
func _build_prompt(_player: Player) -> String:
	if GameState.has_tool(charge_tool):
		return PLANT_PROMPT % charge_tool
	if is_lit:
		return LIT_PROMPT
	return blocked_hint


## Pone la dinamita si la tiene.
func _on_interacted(_player: Player) -> void:
	if not GameState.has_tool(charge_tool):
		return
	GameState.use_tool(charge_tool)
	light_fuse()


## La mecha sisea sin parar hasta que revienta.
func _on_fuse_sound_finished() -> void:
	if is_lit:
		_fuse_sound.play()
