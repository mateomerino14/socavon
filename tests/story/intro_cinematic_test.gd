extends TestCase
## Pruebas de la cinemática de inicio: bloquea al jugador mientras dura y se puede saltar.

const LEVEL_SCENE := preload("res://src/world/level_01/level_01.tscn")
const FAST_SECONDS := 0.05
const RUN_FRAMES := 10
const FINISH_FRAMES := 120

var _level: Level
var _intro: IntroCinematic
var _player: Player


## Carga el nivel 1 con la cinemática acelerada.
func before_each() -> void:
	_level = LEVEL_SCENE.instantiate()
	_intro = _level.get_node("IntroCinematic")
	for property: String in [
		"fade_seconds",
		"calm_seconds",
		"shake_seconds",
		"black_seconds",
		"wake_seconds",
		"title_seconds"
	]:
		_intro.set(property, FAST_SECONDS)
	add_to_tree(_level)
	_player = _level.get_node("Player")


## Libera el nivel.
func after_each() -> void:
	Input.action_release("move_forward")
	_level.free()


## Mientras dura, el jugador no se mueve; al terminar recupera el control con su cámara.
func test_intro_blocks_then_returns_control() -> void:
	await wait_physics_frames(RUN_FRAMES)
	assert_true(_intro.is_playing, "La cinemática debe empezar sola")
	var start := _player.global_position
	Input.action_press("move_forward")
	await wait_physics_frames(RUN_FRAMES)
	assert_true(
		_player.global_position.distance_to(start) < 0.05, "No debe moverse en la cinemática"
	)
	Input.action_release("move_forward")
	await wait_physics_frames(FINISH_FRAMES)
	assert_false(_intro.is_playing, "La cinemática debe terminar")
	var camera: Camera3D = _player.get_node("Head/Camera3D")
	assert_true(camera.current, "Al terminar se ve por los ojos del jugador")


## Escape la salta y devuelve el control.
func test_intro_can_be_skipped() -> void:
	_intro.calm_seconds = 30.0
	await wait_physics_frames(RUN_FRAMES)
	var skip := InputEventAction.new()
	skip.action = "pause"
	skip.pressed = true
	Input.parse_input_event(skip)
	await wait_physics_frames(RUN_FRAMES * 3)
	assert_false(_intro.is_playing, "Escape debe saltar la cinemática")
