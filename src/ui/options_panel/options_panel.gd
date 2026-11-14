class_name OptionsPanel
extends VBoxContainer
## Ajustes del jugador, compartidos por el menú principal y el de pausa.

signal back_requested

## Color del nombre de un deslizador elegido; los deslizadores no dibujan su foco.
const FOCUS_COLOR := Color(1, 0.86, 0.66)

@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _crouch_toggle: CheckButton = %CrouchToggle
@onready var _volume_slider: HSlider = %VolumeSlider
@onready var _music_slider: HSlider = %MusicSlider
@onready var _quality_toggle: CheckButton = %QualityToggle
@onready var _hints_toggle: CheckButton = %HintsToggle


## Conecta los controles a los ajustes guardados.
func _ready() -> void:
	_sensitivity_slider.min_value = Settings.MIN_SENSITIVITY
	_sensitivity_slider.max_value = Settings.MAX_SENSITIVITY
	_sensitivity_slider.value_changed.connect(Settings.set_mouse_sensitivity)
	_crouch_toggle.toggled.connect(Settings.set_crouch_toggles)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	_music_slider.value_changed.connect(Settings.set_music_volume)
	_quality_toggle.toggled.connect(Settings.set_high_quality)
	_hints_toggle.toggled.connect(Settings.set_hints_enabled)
	%BackButton.pressed.connect(back_requested.emit)
	for slider: HSlider in [_sensitivity_slider, _volume_slider, _music_slider]:
		var label: Label = get_child(slider.get_index() - 1)
		slider.focus_entered.connect(_mark_label.bind(label, true))
		slider.focus_exited.connect(_mark_label.bind(label, false))


## Muestra los valores actuales y pone el foco en el primer control.
func refresh() -> void:
	_sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	_crouch_toggle.set_pressed_no_signal(Settings.crouch_toggles)
	_volume_slider.set_value_no_signal(Settings.master_volume)
	_music_slider.set_value_no_signal(Settings.music_volume)
	_quality_toggle.set_pressed_no_signal(Settings.high_quality)
	_hints_toggle.set_pressed_no_signal(Settings.hints_enabled)
	_sensitivity_slider.grab_focus()


## Resalta el nombre del deslizador que tiene el foco, como se resalta un botón.
func _mark_label(label: Label, is_focused: bool) -> void:
	if is_focused:
		label.add_theme_color_override("font_color", FOCUS_COLOR)
	else:
		label.remove_theme_color_override("font_color")
