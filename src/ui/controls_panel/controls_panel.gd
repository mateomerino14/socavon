class_name ControlsPanel
extends VBoxContainer
## Tabla de controles, compartida por el menú principal y el de pausa: cada acción con su tecla y su
## botón de mando, tal como están configurados.

signal back_requested

## Cada fila: lo que hace y las acciones que la forman.
const ROWS: Array[Array] = [
	["Caminar", [&"move_forward", &"move_left", &"move_back", &"move_right"]],
	["Mirar", [&"look_left", &"look_right", &"look_up", &"look_down"]],
	["Correr", [&"sprint"]],
	["Agacharse", [&"crouch"]],
	["Encender o apagar la lámpara", [&"lamp_toggle"]],
	["Subir o bajar la llama", [&"lamp_increase", &"lamp_decrease"]],
	["Recargar con carburo", [&"lamp_refill"]],
	["Recoger, leer, ofrendar, esconderse", [&"interact"]],
	["Lanzar una piedra", [&"throw"]],
	["Escuchar (mantener)", [&"listen"]],
	["Asomarse", [&"lean_left", &"lean_right"]],
	["Inventario", [&"inventory"]],
	["Mapa", [&"map"]],
	["Pausa", [&"pause"]],
]
const HEADERS: Array[String] = ["ACCIÓN", "TECLADO Y RATÓN", "MANDO"]
const HEADER_COLOR := Color(0.9, 0.55, 0.25)
const HEADER_FONT_SIZE := 14
const ACTION_COLOR := Color(0.85, 0.8, 0.72)
const KEY_COLOR := Color(1, 0.86, 0.66)
const ROW_FONT_SIZE := 17
## La columna de la acción es más ancha que las de las teclas.
const ACTION_STRETCH := 1.5

@onready var _grid: GridContainer = %Grid
@onready var _back_button: Button = %BackButton


## Arma la tabla, con los títulos de columna en la primera fila, y conecta el botón de volver.
func _ready() -> void:
	for header in HEADERS:
		var header_cell := _cell(header, HEADER_COLOR)
		header_cell.add_theme_font_size_override("font_size", HEADER_FONT_SIZE)
		_grid.add_child(header_cell)
	for row in ROWS:
		var actions: Array[StringName] = []
		actions.assign(row[1])
		var action_cell := _cell(row[0], ACTION_COLOR)
		action_cell.size_flags_stretch_ratio = ACTION_STRETCH
		_grid.add_child(action_cell)
		_grid.add_child(_cell(InputDevice.labels_for(actions, false), KEY_COLOR))
		_grid.add_child(_cell(InputDevice.labels_for(actions, true), KEY_COLOR))
	_back_button.pressed.connect(back_requested.emit)


## Pone el foco en el botón de volver.
func refresh() -> void:
	_back_button.grab_focus()


## Celda de texto de la tabla.
func _cell(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", ROW_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label
