extends TestCase
## Pruebas de la opción marcada en los menús: el ratón elige el botón bajo él, y al moverse con las
## flechas el botón bajo el ratón deja de verse marcado.

var _column: VBoxContainer
var _first: Button
var _second: Button


## Dos botones en columna.
func before_each() -> void:
	_column = VBoxContainer.new()
	_first = Button.new()
	_second = Button.new()
	_column.add_child(_first)
	_column.add_child(_second)
	add_to_tree(_column)


## Libera los botones.
func after_each() -> void:
	_column.free()


## Desde una etiqueta dentro de un botón se llega al botón; uno desactivado no cuenta.
func test_finds_the_focusable_control() -> void:
	var label := Label.new()
	_first.add_child(label)
	assert_true(MenuFocus._focusable(label) == _first, "Debe subir hasta el botón")
	_first.disabled = true
	assert_true(MenuFocus._focusable(_first) == null, "Un botón desactivado no se elige")


## Si el foco pasa a otro botón, el que tenía el ratón deja de verse marcado.
func test_hover_follows_focus() -> void:
	_first.notification(Control.NOTIFICATION_MOUSE_ENTER)
	assert_true(_first.is_hovered(), "El ratón está sobre el primero")
	MenuFocus._clear_hover(_first, _second)
	assert_false(_first.is_hovered(), "Al bajar con las flechas, el primero se apaga")
