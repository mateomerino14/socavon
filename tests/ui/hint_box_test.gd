extends TestCase
## Pruebas de los consejos de controles y de la tabla de controles.

const HINT_BOX_SCENE := preload("res://src/ui/hints/hint_box.tscn")
const CONTROLS_SCENE := preload("res://src/ui/controls_panel/controls_panel.tscn")
const OPTIONS_SCENE := preload("res://src/ui/options_panel/options_panel.tscn")

var _box: HintBox


## Consejos activados y sin ver.
func before_each() -> void:
	Settings.hints_enabled = true
	Settings.seen_hints.clear()
	_box = HINT_BOX_SCENE.instantiate()
	add_to_tree(_box)


## Libera el cuadro y deja los consejos como al empezar.
func after_each() -> void:
	_box.free()
	Settings.hints_enabled = true
	Settings.seen_hints.clear()


## Un consejo pedido se muestra con su tecla y queda visto: no se repite.
func test_shows_each_hint_once() -> void:
	EventBus.hint_requested.emit("mapa")
	assert_true(_box.current == "mapa", "Debe mostrar el consejo del mapa")
	assert_true(_box.get_node("%HintLabel").text.contains("abre el mapa"), "Con su texto")
	assert_true("mapa" in Settings.seen_hints, "Queda visto")
	_box.current = ""
	EventBus.hint_requested.emit("mapa")
	assert_true(_box.current.is_empty(), "Uno visto no se repite")


## Uno a la vez: el segundo espera a que acabe el primero y su pausa; el urgente pasa delante.
func test_queues_hints() -> void:
	EventBus.hint_requested.emit("mapa")
	EventBus.hint_requested.emit("piedra")
	EventBus.hint_requested.emit("caza")
	assert_true(_box.current == "mapa", "Sigue el primero")
	_box._on_timeout()
	_box._timer.stop()
	_box._on_timeout()
	assert_true(_box.current == "caza", "El urgente pasa delante")


## Con el HUD oculto espera; al volver, aparece.
func test_waits_while_hud_is_hidden() -> void:
	EventBus.hud_visibility_requested.emit(false)
	EventBus.hint_requested.emit("mapa")
	assert_true(_box.current.is_empty(), "No se muestra en una cinemática")
	EventBus.hud_visibility_requested.emit(true)
	assert_true(_box.current == "mapa", "Aparece al volver el HUD")


## Apagados no se muestran; al encenderlos de nuevo vuelven desde el principio.
func test_can_be_turned_off() -> void:
	Settings.hints_enabled = false
	EventBus.hint_requested.emit("mapa")
	assert_true(_box.current.is_empty(), "Apagados no salen")
	Settings.seen_hints.append("piedra")
	var options: OptionsPanel = OPTIONS_SCENE.instantiate()
	add_to_tree(options)
	var toggle: CheckButton = options.get_node("%HintsToggle")
	toggle.button_pressed = false
	toggle.button_pressed = true
	assert_true(Settings.hints_enabled, "La opción los enciende")
	assert_true(Settings.seen_hints.is_empty(), "Y vuelven a salir todos")
	options.free()


## La tabla de controles tiene, por cada acción, su tecla y su botón.
func test_controls_table_names_every_action() -> void:
	var panel: ControlsPanel = CONTROLS_SCENE.instantiate()
	add_to_tree(panel)
	var cells := panel.get_node("%Grid").get_children()
	var columns := ControlsPanel.HEADERS.size()
	assert_true(cells.size() == (ControlsPanel.ROWS.size() + 1) * columns, "Tres celdas por acción")
	for cell: Label in cells:
		assert_false(cell.text == InputDevice.UNBOUND_NAME, "Ninguna acción sin tecla")
	panel.free()
