class_name Transition
extends Node3D
## Tránsito entre niveles: Mateo cruza un socavón con su lámpara y dice lo que piensa; la pantalla
## funde a negro y se carga el nivel siguiente, que muestra su nombre al empezar.

## Termina el tránsito, visto entero o saltado.
signal finished

const SCENE_PATH := "res://src/story/transition/transition.tscn"
const OPAQUE := 1.0
const CLEAR := 0.0
const WALK := &"walk"
const BLEND_SECONDS := 0.3
const SUBTITLE_FORMAT := "%s: %s"
## Metros por segundo que cubre la caminata de Mateo a velocidad normal de la animación.
const MATEO_NATURAL_SPEED := 0.8
## El Tío camina más lento que su animación normal: acecha.
const TIO_ANIMATION_SPEED := 0.6

## Tránsito pendiente: lo deja la salida del nivel y lo toma esta escena al abrirse.
static var _pending_data: TransitionData
static var _pending_level := ""
## Queda en verdadero hasta que el nivel siguiente toma la llegada.
static var _has_arrival := false

## Si es falso no se reproduce solo; las pruebas lo apagan para controlarlo.
@export var enabled := true
@export var data: TransitionData
## Nivel que se carga al terminar; vacío en las pruebas.
@export_file("*.tscn") var next_level_path := ""

@export_group("Recorrido")
## Metros que Mateo camina hacia la cámara.
@export var walk_distance := 9.0
## Metros que el Tío avanza detrás de él.
@export var tio_walk_distance := 2.5

@export_group("Tiempos (s)")
@export var fade_seconds := 1.2
@export var walk_seconds := 10.0
@export var line_delay_seconds := 1.5
## Segundos en negro antes de cargar el nivel, para que Mateo termine de hablar.
@export var hold_seconds := 1.5
## Pasos de Mateo: uno por cada media vuelta de la caminata.
@export var step_seconds := 0.59

var is_playing := false

var _skip_requested := false
var _mateo_start := Vector3.ZERO
var _tio_start := Vector3.ZERO

@onready var _mateo: Node3D = $Mateo
@onready var _tio: Node3D = $Tio
@onready var _tio_light: OmniLight3D = $Tio/EyeGlow
@onready var _rails: Node3D = $Rails
@onready var _voice: VoicePlayer = $Mateo/VoicePlayer
@onready var _steps: AudioStreamPlayer3D = $Mateo/Steps
@onready var _step_timer: Timer = $StepTimer
@onready var _wait_timer: Timer = $WaitTimer
@onready var _curtain: ColorRect = %Curtain
@onready var _subtitle: Label = %Subtitle
@onready var _subtitle_timer: Timer = $SubtitleTimer


## Abre el tránsito hacia un nivel; la escena toma lo pendiente al cargarse.
static func go(tree: SceneTree, transition_data: TransitionData, level_path: String) -> void:
	_pending_data = transition_data
	_pending_level = level_path
	tree.change_scene_to_file.call_deferred(SCENE_PATH)


## Dice si el nivel que se abre viene de un tránsito, y lo olvida para la próxima vez.
static func take_arrival() -> bool:
	var arrived := _has_arrival
	_has_arrival = false
	return arrived


## Toma el tránsito pendiente, arma el socavón y empieza solo si está activado.
func _ready() -> void:
	if _pending_data:
		data = _pending_data
		next_level_path = _pending_level
		_pending_data = null
		_pending_level = ""
	_mateo_start = _mateo.position
	_tio_start = _tio.position
	_curtain.modulate.a = OPAQUE
	_subtitle.text = ""
	_step_timer.timeout.connect(_steps.play)
	_subtitle_timer.timeout.connect(_subtitle.set_text.bind(""))
	EventBus.subtitle_requested.connect(_on_subtitle_requested)
	_apply_data()
	if enabled:
		play.call_deferred()


## Escape o interactuar saltan el tránsito.
func _input(event: InputEvent) -> void:
	if is_playing and (event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		get_viewport().set_input_as_handled()
		skip()


## Reproduce el tránsito completo y carga el nivel siguiente.
func play() -> void:
	is_playing = true
	_start_walking()
	await _fade(_curtain, CLEAR)
	if await _wait(line_delay_seconds):
		_say()
	if await _wait(walk_seconds - line_delay_seconds - fade_seconds * 2.0):
		await _fade(_curtain, OPAQUE)
	_stop_walking()
	await _wait(hold_seconds)
	_finish()


## Corta lo que falta y pasa al nivel siguiente.
func skip() -> void:
	_skip_requested = true
	if not _wait_timer.is_stopped():
		_wait_timer.stop()
		_wait_timer.timeout.emit()


## Muestra rieles y al Tío según el tránsito.
func _apply_data() -> void:
	_rails.visible = data != null and data.has_rails
	_tio.visible = data != null and data.shows_tio
	_tio_light.visible = _tio.visible


## Mateo camina hacia la cámara con sus pasos, y el Tío lo sigue despacio si aparece.
func _start_walking() -> void:
	var speed := walk_distance / walk_seconds
	_animate(_mateo, WALK, speed / MATEO_NATURAL_SPEED)
	var tween := create_tween().set_parallel()
	tween.tween_property(
		_mateo, "position", _mateo_start + Vector3.BACK * walk_distance, walk_seconds
	)
	if _tio.visible:
		_animate(_tio, WALK, TIO_ANIMATION_SPEED)
		tween.tween_property(
			_tio, "position", _tio_start + Vector3.BACK * tio_walk_distance, walk_seconds
		)
	_step_timer.start(step_seconds)


## Detiene los pasos al terminar o al saltar.
func _stop_walking() -> void:
	_step_timer.stop()


## Hace sonar una animación del modelo en bucle, con la velocidad indicada.
func _animate(model: Node3D, animation_name: StringName, speed_scale: float) -> void:
	var player := model.find_child("AnimationPlayer") as AnimationPlayer
	player.get_animation(animation_name).loop_mode = Animation.LOOP_LINEAR
	player.play(animation_name, BLEND_SECONDS)
	player.speed_scale = speed_scale


## Mateo dice su línea, si el tránsito tiene una.
func _say() -> void:
	if data and data.line:
		var lines: Array[VoiceLine] = [data.line]
		_voice.say(lines)


## Deja la pantalla en negro, avisa la llegada y abre el nivel siguiente.
func _finish() -> void:
	_stop_walking()
	_curtain.modulate.a = OPAQUE
	is_playing = false
	finished.emit()
	if not next_level_path.is_empty():
		_has_arrival = true
		get_tree().change_scene_to_file.call_deferred(next_level_path)


## Muestra el subtítulo de lo que dice Mateo y lo borra cuando termina.
func _on_subtitle_requested(speaker: String, text: String, seconds: float) -> void:
	_subtitle.text = SUBTITLE_FORMAT % [speaker, text]
	_subtitle_timer.start(seconds)


## Desvanece un elemento de la pantalla hacia la transparencia indicada.
func _fade(control: Control, alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(control, "modulate:a", alpha, fade_seconds)
	await tween.finished


## Espera unos segundos; devuelve falso si el jugador saltó el tránsito.
func _wait(seconds: float) -> bool:
	if _skip_requested:
		return false
	_wait_timer.start(seconds)
	await _wait_timer.timeout
	return not _skip_requested
