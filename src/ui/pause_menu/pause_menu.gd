class_name PauseMenu
extends CanvasLayer
## Menú de pausa: detiene el juego con Escape, deja cambiar los ajustes o volver al menú principal.

const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"

var is_open := false

@onready var _main_panel: Control = %MainPanel
@onready var _options_panel: OptionsPanel = %OptionsPanel


## Conecta los botones y arranca oculto.
func _ready() -> void:
	%ResumeButton.pressed.connect(close)
	%OptionsButton.pressed.connect(_show_options)
	%MenuButton.pressed.connect(_go_to_main_menu)
	%QuitButton.pressed.connect(get_tree().quit)
	_options_panel.back_requested.connect(_show_main)
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
	_main_panel.visible = false
	_options_panel.visible = true
	_options_panel.refresh()


## Quita la pausa y vuelve al menú principal; la partida queda en el último guardado.
func _go_to_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
