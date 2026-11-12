class_name IntroCinematic
extends Node3D
## Cinemática del derrumbe: la orden de Faustino, el temblor, el grito de Rosendo y el despertar.
## La cuadrilla está frente a la cámara: Faustino habla, todos se cubren al temblar y, cuando vuelve
## la luz, Mateo está solo.

const OPAQUE := 1.0
const CLEAR := 0.0
## Inclinación de la cabeza al despertar, mirando el techo caído.
const WAKE_PITCH_DEGREES := -55.0
const IDLE := &"idle"
const TALK := &"talk"
const COVER := &"cover"
const LOOPED: Array[StringName] = [&"idle", &"talk", &"cover"]
const BLEND_SECONDS := 0.3

## Si es falso no se reproduce; las pruebas lo apagan para empezar a jugar de inmediato.
@export var enabled := true
@export var order_line: VoiceLine
@export var warning_line: VoiceLine
## Quien da la orden de entrar.
@export var foreman: Node3D
## Toda la cuadrilla que se ve en la cinemática, el capataz incluido.
@export var crew: Array[Node3D] = []

@export_group("Tiempos (s)")
@export var fade_seconds := 1.5
@export var calm_seconds := 2.5
@export var shake_seconds := 3.5
@export var black_seconds := 2.0
@export var wake_seconds := 3.0
@export var title_seconds := 3.0

@export_group("Temblor")
@export var max_shake := 0.08

var is_playing := false

var _shake := 0.0
var _player: Player
var _skip_requested := false

@onready var _camera: Camera3D = $Camera3D
@onready var _voice: VoicePlayer = $VoicePlayer
@onready var _rumble: AudioStreamPlayer = $Rumble
@onready var _dust: CPUParticles3D = $Dust
@onready var _curtain: ColorRect = %Curtain
@onready var _title: Label = %Title
@onready var _step_timer: Timer = $StepTimer


## Empieza sola al cargar el nivel, si está activada y no se viene de continuar una partida.
func _ready() -> void:
	_curtain.modulate.a = CLEAR
	_title.modulate.a = CLEAR
	if enabled and not SaveGame.has_pending():
		play.call_deferred()


## Mueve la cámara mientras tiembla.
func _process(_delta: float) -> void:
	_camera.h_offset = randf_range(-_shake, _shake)
	_camera.v_offset = randf_range(-_shake, _shake)


## Escape o interactuar saltan la cinemática.
func _input(event: InputEvent) -> void:
	if is_playing and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		_skip_requested = true
		get_viewport().set_input_as_handled()
		if not _step_timer.is_stopped():
			_step_timer.stop()
			_step_timer.timeout.emit()


## Reproduce la cinemática completa y devuelve el control al jugador.
func play() -> void:
	_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	is_playing = true
	_player.set_controls_enabled(false)
	EventBus.hud_visibility_requested.emit(false)
	_curtain.modulate.a = OPAQUE
	for miner in crew:
		miner.visible = true
		_animate(miner, IDLE)
	if foreman:
		_animate(foreman, TALK)
	_say(order_line)
	if await _wait(calm_seconds):
		_camera.make_current()
		await _fade(_curtain, CLEAR)
	if await _wait(calm_seconds):
		_start_collapse()
	if await _wait(shake_seconds):
		await _fade(_curtain, OPAQUE)
	_stop_collapse()
	if await _wait(black_seconds):
		await _wake_up()
	_finish()


## Hace temblar la mina, grita Rosendo y la cuadrilla se cubre.
func _start_collapse() -> void:
	for miner in crew:
		_animate(miner, COVER)
	_shake = max_shake
	_dust.emitting = true
	_rumble.play()
	_say(warning_line)


## Detiene el temblor y el polvo. Cuando vuelve la luz, la cuadrilla ya no está.
func _stop_collapse() -> void:
	_shake = 0.0
	_dust.emitting = false
	for miner in crew:
		miner.visible = false


## Hace sonar una animación del minero, en bucle si es de las que se repiten.
func _animate(miner: Node3D, animation_name: StringName) -> void:
	var player := miner.find_child("AnimationPlayer") as AnimationPlayer
	var animation := player.get_animation(animation_name)
	if animation_name in LOOPED:
		animation.loop_mode = Animation.LOOP_LINEAR
	player.play(animation_name, BLEND_SECONDS)


## Mateo despierta mirando el techo caído y baja la vista mientras se aclara la pantalla.
func _wake_up() -> void:
	_player.take_view(deg_to_rad(WAKE_PITCH_DEGREES))
	_player.level_view(wake_seconds)
	var tween := create_tween().set_parallel()
	tween.tween_property(_curtain, "modulate:a", CLEAR, wake_seconds)
	tween.tween_property(_title, "modulate:a", OPAQUE, fade_seconds)
	await tween.finished
	if await _wait(title_seconds):
		await _fade(_title, CLEAR)


## Deja todo listo para jugar, se haya visto entera o se haya saltado.
func _finish() -> void:
	for miner in crew:
		miner.visible = false
	_stop_collapse()
	_rumble.stop()
	_curtain.modulate.a = CLEAR
	_title.modulate.a = CLEAR
	_player.take_view(0.0)
	_player.set_controls_enabled(true)
	EventBus.hud_visibility_requested.emit(true)
	is_playing = false


## Dice una línea si está asignada.
func _say(line: VoiceLine) -> void:
	if line:
		var lines: Array[VoiceLine] = [line]
		_voice.say(lines)


## Desvanece un elemento de la pantalla hacia la transparencia indicada.
func _fade(control: Control, alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(control, "modulate:a", alpha, fade_seconds)
	await tween.finished


## Espera unos segundos; devuelve falso si el jugador saltó la cinemática.
func _wait(seconds: float) -> bool:
	if _skip_requested:
		return false
	_step_timer.start(seconds)
	await _step_timer.timeout
	return not _skip_requested
