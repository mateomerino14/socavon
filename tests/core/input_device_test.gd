extends TestCase
## Pruebas del aparato con que se juega: cambia con el teclado o el mando y nombra las teclas y los
## botones de cada acción.

var _was_gamepad := false
var _changes := 0


## Recuerda el aparato y cuenta los cambios.
func before_each() -> void:
	_was_gamepad = InputDevice.uses_gamepad
	InputDevice.changed.connect(_on_changed)


## Deja el aparato como estaba.
func after_each() -> void:
	InputDevice.changed.disconnect(_on_changed)
	InputDevice.uses_gamepad = _was_gamepad


## Un botón del mando pasa a mando; una tecla, a teclado; avisa solo cuando cambia.
func test_switches_with_last_used_device() -> void:
	InputDevice.uses_gamepad = false
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_A
	InputDevice._input(button)
	assert_true(InputDevice.uses_gamepad, "El mando debe pasar a mando")
	InputDevice._input(button)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	InputDevice._input(key)
	assert_false(InputDevice.uses_gamepad, "Una tecla debe volver al teclado")
	assert_true(_changes == 2, "Debe avisar dos veces (avisó %d)" % _changes)


## Un roce del stick no cuenta como usar el mando.
func test_ignores_stick_drift() -> void:
	InputDevice.uses_gamepad = false
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = 0.1
	InputDevice._input(motion)
	assert_false(InputDevice.uses_gamepad, "El roce del stick no cambia de aparato")


## Cada acción tiene su nombre en los dos aparatos.
func test_names_each_action() -> void:
	assert_true(InputDevice.label_for(&"interact", false) == "E", "Usar es la E")
	assert_true(InputDevice.label_for(&"interact", true) == "A", "En el mando, usar es la A")
	assert_true(InputDevice.label_for(&"throw", true) == "RT", "Lanzar es el gatillo derecho")
	assert_true(InputDevice.label_for(&"pause", false) == "Esc", "La pausa es Esc")
	assert_true(InputDevice.label_for(&"look_left", false) == "Ratón", "Se mira con el ratón")
	var move: Array[StringName] = [&"move_forward", &"move_left"]
	assert_true(InputDevice.labels_for(move, true) == "Stick izquierdo", "Sin repetir el stick")


## Los textos con acciones entre llaves quedan con las teclas entre corchetes.
func test_fills_templates() -> void:
	InputDevice.uses_gamepad = false
	assert_true(InputDevice.fill("{map} Cerrar") == "[M] Cerrar", "Debe poner la tecla del mapa")
	InputDevice.uses_gamepad = true
	assert_true(InputDevice.fill("{map} Cerrar") == "[R3] Cerrar", "Debe poner el botón del mapa")


## Cuenta los cambios de aparato.
func _on_changed() -> void:
	_changes += 1
