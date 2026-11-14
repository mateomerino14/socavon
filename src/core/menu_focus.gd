extends Node
## En los menús, el ratón y el teclado o el mando marcan siempre la misma opción (autoload
## "MenuFocus"): al pasar el ratón por un botón, deslizador o casilla, toma el foco; al moverse con
## las flechas o el mando, la opción bajo el ratón deja de verse marcada.


## Sigue atento también en los menús de pausa.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_viewport().gui_focus_changed.connect(_on_focus_changed)


## El ratón que pasa por una opción la elige.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return
	var control := _focusable(get_viewport().gui_get_hovered_control())
	if control and not control.has_focus():
		control.grab_focus()


## Si el foco se fue a otra opción, la que está bajo el ratón deja de verse marcada.
func _on_focus_changed(focused: Control) -> void:
	_clear_hover(_focusable(get_viewport().gui_get_hovered_control()), focused)


## Apaga el resaltado de un botón bajo el ratón que ya no tiene el foco.
func _clear_hover(hovered: Control, focused: Control) -> void:
	if hovered and hovered != focused and hovered is BaseButton:
		hovered.notification(Control.NOTIFICATION_MOUSE_EXIT)


## El control que puede tomar el foco, subiendo desde el que está bajo el ratón; nulo si no hay.
func _focusable(control: Control) -> Control:
	while control:
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			if control is BaseButton and (control as BaseButton).disabled:
				return null
			return control
		control = control.get_parent_control()
	return null
