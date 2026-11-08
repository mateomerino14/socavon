class_name PauseMenu
extends CanvasLayer
## Menú de pausa: detiene el juego con Escape y deja cambiar los ajustes.

var is_open := false

@onready var _main_panel: Control = %MainPanel
@onready var _options_panel: Control = %OptionsPanel
@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _crouch_toggle: CheckButton = %CrouchToggle
@onready var _volume_slider: HSlider = %VolumeSlider


## Conecta los botones y arranca oculto.
func _ready() -> void:
	%ResumeButton.pressed.connect(close)
	%OptionsButton.pressed.connect(_show_options)
	%QuitButton.pressed.connect(get_tree().quit)
	%BackButton.pressed.connect(_show_main)
	_sensitivity_slider.min_value = Settings.MIN_SENSITIVITY
	_sensitivity_slider.max_value = Settings.MAX_SENSITIVITY
	_sensitivity_slider.value_changed.connect(Settings.set_mouse_sensitivity)
	_crouch_toggle.toggled.connect(Settings.set_crouch_toggles)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	visible = false


## Abre o cierra el menú con Escape.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


## Pausa el juego y muestra el menú principal.
func open() -> void:
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_main()


## Reanuda el juego y oculta el menú.
func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Muestra los botones principales.
func _show_main() -> void:
	_main_panel.visible = true
	_options_panel.visible = false
	%ResumeButton.grab_focus()


## Muestra los ajustes con sus valores actuales.
func _show_options() -> void:
	_sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	_crouch_toggle.set_pressed_no_signal(Settings.crouch_toggles)
	_volume_slider.set_value_no_signal(Settings.master_volume)
	_main_panel.visible = false
	_options_panel.visible = true
	_sensitivity_slider.grab_focus()
