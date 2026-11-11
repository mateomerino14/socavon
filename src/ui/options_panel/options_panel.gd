class_name OptionsPanel
extends VBoxContainer
## Ajustes del jugador, compartidos por el menú principal y el de pausa.

signal back_requested

@onready var _sensitivity_slider: HSlider = %SensitivitySlider
@onready var _crouch_toggle: CheckButton = %CrouchToggle
@onready var _volume_slider: HSlider = %VolumeSlider


## Conecta los controles a los ajustes guardados.
func _ready() -> void:
	_sensitivity_slider.min_value = Settings.MIN_SENSITIVITY
	_sensitivity_slider.max_value = Settings.MAX_SENSITIVITY
	_sensitivity_slider.value_changed.connect(Settings.set_mouse_sensitivity)
	_crouch_toggle.toggled.connect(Settings.set_crouch_toggles)
	_volume_slider.value_changed.connect(Settings.set_master_volume)
	%BackButton.pressed.connect(back_requested.emit)


## Muestra los valores actuales y pone el foco en el primer control.
func refresh() -> void:
	_sensitivity_slider.set_value_no_signal(Settings.mouse_sensitivity)
	_crouch_toggle.set_pressed_no_signal(Settings.crouch_toggles)
	_volume_slider.set_value_no_signal(Settings.master_volume)
	_sensitivity_slider.grab_focus()
