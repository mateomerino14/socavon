extends Node
## Recuerda si el jugador juega con teclado y ratón o con mando (autoload "InputDevice") y dice con
## qué tecla o botón se hace cada acción, para mostrarlo en pantalla tal como lo tiene configurado.

## Cambió el aparato con que se juega.
signal changed

## Inclinación del stick a partir de la cual cuenta como uso del mando.
const STICK_DEADZONE := 0.5
## Píxeles que debe moverse el ratón para que cuente como uso del teclado y ratón.
const MOUSE_MOTION_THRESHOLD := 8.0
const JOY_BUTTON_NAMES: Dictionary[JoyButton, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "Cruceta arriba",
	JOY_BUTTON_DPAD_DOWN: "Cruceta abajo",
	JOY_BUTTON_DPAD_LEFT: "Cruceta izquierda",
	JOY_BUTTON_DPAD_RIGHT: "Cruceta derecha",
}
const JOY_AXIS_NAMES: Dictionary[JoyAxis, String] = {
	JOY_AXIS_LEFT_X: "Stick izquierdo",
	JOY_AXIS_LEFT_Y: "Stick izquierdo",
	JOY_AXIS_RIGHT_X: "Stick derecho",
	JOY_AXIS_RIGHT_Y: "Stick derecho",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}
## Teclas cuyo nombre en inglés se cambia por uno más claro.
const KEY_NAMES: Dictionary[Key, String] = {
	KEY_LEFT: "←",
	KEY_RIGHT: "→",
	KEY_UP: "↑",
	KEY_DOWN: "↓",
	KEY_ESCAPE: "Esc",
	KEY_SPACE: "Espacio",
}
const MOUSE_BUTTON_NAMES: Dictionary[MouseButton, String] = {
	MOUSE_BUTTON_LEFT: "Clic izquierdo",
	MOUSE_BUTTON_RIGHT: "Clic derecho",
	MOUSE_BUTTON_MIDDLE: "Clic central",
	MOUSE_BUTTON_WHEEL_UP: "Rueda arriba",
	MOUSE_BUTTON_WHEEL_DOWN: "Rueda abajo",
}
## Acciones que con teclado y ratón no tienen tecla: se hacen moviendo el ratón.
const MOUSE_LOOK_ACTIONS: Array[StringName] = [
	&"look_left", &"look_right", &"look_up", &"look_down"
]
const MOUSE_LOOK_NAME := "Ratón"
const UNBOUND_NAME := "?"
const KEY_FORMAT := "[%s]"
## Sin pantalla no se conoce la distribución del teclado.
const HEADLESS_SERVER := "headless"

var uses_gamepad := false


## Sigue atento al aparato aunque el juego esté en pausa.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Cambia de aparato cuando el jugador usa el otro.
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		_set_gamepad(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) > STICK_DEADZONE:
			_set_gamepad(true)
	elif event is InputEventKey or event is InputEventMouseButton:
		_set_gamepad(false)
	elif event is InputEventMouseMotion:
		if (event as InputEventMouseMotion).relative.length() > MOUSE_MOTION_THRESHOLD:
			_set_gamepad(false)


## Nombre de la tecla o botón de una acción en el aparato actual.
func label(action: StringName) -> String:
	return label_for(action, uses_gamepad)


## Nombre de la tecla o botón de una acción en el mando o en el teclado y ratón.
func label_for(action: StringName, is_gamepad: bool) -> String:
	for event in InputMap.action_get_events(action):
		var event_name := _event_name(event, is_gamepad)
		if not event_name.is_empty():
			return event_name
	if not is_gamepad and action in MOUSE_LOOK_ACTIONS:
		return MOUSE_LOOK_NAME
	return UNBOUND_NAME


## Nombres de varias acciones en el aparato actual, sin repetir; por ejemplo "W A S D".
func labels(actions: Array[StringName]) -> String:
	return labels_for(actions, uses_gamepad)


## Nombres de varias acciones en un aparato, sin repetir; por ejemplo "Stick izquierdo".
func labels_for(actions: Array[StringName], is_gamepad: bool) -> String:
	var names := PackedStringArray()
	for action in actions:
		var action_name := label_for(action, is_gamepad)
		if not action_name in names:
			names.append(action_name)
	return " ".join(names)


## Cambia en un texto cada grupo de acciones entre llaves, separadas por "|", por sus teclas o
## botones entre corchetes; por ejemplo "{map} abre el mapa" queda "[M] abre el mapa".
func fill(template: String) -> String:
	var parts := template.split("{")
	var result := parts[0]
	for index in range(1, parts.size()):
		var closing := parts[index].find("}")
		var actions: Array[StringName] = []
		for action in parts[index].left(closing).split("|"):
			actions.append(StringName(action))
		result += KEY_FORMAT % labels(actions) + parts[index].substr(closing + 1)
	return result


## Cambia el aparato y avisa si es otro.
func _set_gamepad(value: bool) -> void:
	if uses_gamepad == value:
		return
	uses_gamepad = value
	changed.emit()


## Nombre de un evento si es del aparato pedido; vacío si es del otro.
func _event_name(event: InputEvent, is_gamepad: bool) -> String:
	if is_gamepad:
		if event is InputEventJoypadButton:
			return JOY_BUTTON_NAMES.get((event as InputEventJoypadButton).button_index, "")
		if event is InputEventJoypadMotion:
			return JOY_AXIS_NAMES.get((event as InputEventJoypadMotion).axis, "")
		return ""
	if event is InputEventKey:
		return _key_name(event as InputEventKey)
	if event is InputEventMouseButton:
		return MOUSE_BUTTON_NAMES.get((event as InputEventMouseButton).button_index, "")
	return ""


## Nombre de una tecla según la distribución del teclado del jugador.
func _key_name(event: InputEventKey) -> String:
	var keycode := event.keycode
	if event.physical_keycode != KEY_NONE:
		keycode = event.physical_keycode
		if DisplayServer.get_name() != HEADLESS_SERVER:
			keycode = DisplayServer.keyboard_get_keycode_from_physical(event.physical_keycode)
	return KEY_NAMES.get(keycode, OS.get_keycode_string(keycode))
