class_name KeyHintLabel
extends Label
## Texto con teclas entre llaves, como "{map} Cerrar", que cambian según teclado o mando.

@export var template := ""


## Escribe el texto y lo reescribe si cambia el aparato.
func _ready() -> void:
	InputDevice.changed.connect(_write)
	_write()


## Pone las teclas o botones del aparato actual.
func _write() -> void:
	text = InputDevice.fill(template)
