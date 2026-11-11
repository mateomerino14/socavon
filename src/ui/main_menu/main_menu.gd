class_name MainMenu
extends Node3D
## Pantalla de inicio: la mina en penumbra con el Tío al fondo, y las opciones para jugar.

const FIRST_LEVEL := "res://src/world/level_01/level_01.tscn"
const IDLE_ANIMATION := &"idle"
const OPAQUE := 1.0
const CLEAR := 0.0
## El vaivén vertical va a otro ritmo para que no dibuje un círculo.
const VERTICAL_DRIFT_RATIO := 1.7

## Vaivén lento de la cámara, como si alguien respirara mirando el túnel.
@export var drift_amount := Vector2(0.12, 0.05)
@export var drift_speed := 0.18
@export var fade_in_seconds := 2.5

var _time := 0.0
var _camera_origin: Vector3

@onready var _camera: Camera3D = $Camera3D
@onready var _curtain: ColorRect = %Curtain
@onready var _main_panel: Control = %MainPanel
@onready var _options_panel: OptionsPanel = %OptionsPanel
@onready var _credits_panel: Control = %CreditsPanel
@onready var _continue_button: Button = %ContinueButton


## Prepara los botones, muestra el ratón y aparece desde negro.
func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_camera_origin = _camera.position
	_continue_button.disabled = not SaveGame.has_save()
	_continue_button.pressed.connect(SaveGame.continue_game)
	%NewGameButton.pressed.connect(SaveGame.new_game.bind(FIRST_LEVEL))
	%OptionsButton.pressed.connect(_show_options)
	%CreditsButton.pressed.connect(_show_credits)
	%QuitButton.pressed.connect(get_tree().quit)
	%CreditsBackButton.pressed.connect(_show_main)
	_options_panel.back_requested.connect(_show_main)
	var players := find_children("*", "AnimationPlayer", true, false)
	for player: AnimationPlayer in players:
		player.get_animation(IDLE_ANIMATION).loop_mode = Animation.LOOP_LINEAR
		player.play(IDLE_ANIMATION)
	_show_main()
	_curtain.modulate.a = OPAQUE
	create_tween().tween_property(_curtain, "modulate:a", CLEAR, fade_in_seconds)


## Mece la cámara despacio.
func _process(delta: float) -> void:
	_time += delta * drift_speed
	var offset := Vector3(
		sin(_time) * drift_amount.x, sin(_time * VERTICAL_DRIFT_RATIO) * drift_amount.y, 0.0
	)
	_camera.position = _camera_origin + offset


## Muestra los botones principales con el foco en el primero disponible.
func _show_main() -> void:
	_main_panel.visible = true
	_options_panel.visible = false
	_credits_panel.visible = false
	if _continue_button.disabled:
		%NewGameButton.grab_focus()
	else:
		_continue_button.grab_focus()


## Muestra los ajustes.
func _show_options() -> void:
	_main_panel.visible = false
	_options_panel.visible = true
	_options_panel.refresh()


## Muestra los créditos.
func _show_credits() -> void:
	_main_panel.visible = false
	_credits_panel.visible = true
	%CreditsBackButton.grab_focus()
