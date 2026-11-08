class_name Interactable
extends Area3D
## Zona que el jugador usa con la tecla de interactuar; su dueño decide qué pasa.

signal interacted(player: Player)

@export var prompt := "Usar"
@export var enabled := true

var _prompt_builder := Callable()


## Permite que el dueño arme el texto según el estado del jugador.
func set_prompt_builder(builder: Callable) -> void:
	_prompt_builder = builder


## Devuelve el texto de la acción para este jugador.
func get_prompt(player: Player) -> String:
	if _prompt_builder.is_valid():
		return _prompt_builder.call(player)
	return prompt


## Avisa al dueño que el jugador lo usó.
func interact(player: Player) -> void:
	if enabled:
		interacted.emit(player)
