class_name Interactor
extends RayCast3D
## Rayo desde los ojos que detecta lo que se puede usar al frente y avisa su texto.

signal focus_changed(prompt: String)

var _focused: Interactable
var _current_prompt := ""


## Busca lo interactuable al frente y avisa si cambió el texto.
func update_focus(player: Player) -> void:
	_focused = null
	if is_colliding():
		var target := get_collider() as Interactable
		if target and target.enabled:
			_focused = target
	var prompt := ""
	if _focused:
		prompt = _focused.get_prompt(player)
	if prompt != _current_prompt:
		_current_prompt = prompt
		focus_changed.emit(prompt)


## Usa lo que está al frente, si hay algo.
func try_interact(player: Player) -> void:
	if _focused:
		_focused.interact(player)
